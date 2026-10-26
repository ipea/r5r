package org.ipea.r5r.Planner;

import com.conveyal.r5.analyst.cluster.AnalysisWorkerTask;
import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.api.util.StreetSegment;
import com.conveyal.r5.profile.*;
import com.conveyal.r5.streets.EdgeStore;
import com.conveyal.r5.streets.StreetRouter;
import com.conveyal.r5.streets.R5REgressRouter;
import com.conveyal.r5.transit.TransportNetwork;
import com.conveyal.r5.transit.path.Path;
import gnu.trove.iterator.TIntObjectIterator;
import gnu.trove.map.TIntIntMap;
import gnu.trove.map.hash.TIntIntHashMap;
import gnu.trove.map.TObjectIntMap;
import org.ipea.r5r.R5.R5TravelTimeComputer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.reflect.Field;
import java.util.*;
import java.util.function.BiConsumer;
import java.util.function.IntFunction;
import java.util.stream.Collectors;

/**
 * Point to point trip planner, based on Conveyal's PointToPointQuery and ParetoServer
 */
public class TripPlanner {
    private static final Logger LOG = LoggerFactory.getLogger(TripPlanner.class);

    private String fromId;
    private String toId;
    private boolean shortestPath;
    private boolean OSMLinkIds;
    private boolean fastRaptor;

    private final TransportNetwork transportNetwork;
    private final ProfileRequest request;

    public void setOD(String fromId, String toId) {
        this.fromId = fromId;
        this.toId = toId;
    }

    public void setShortestPath(boolean shortestPath) {
        this.shortestPath = shortestPath;
    }

    public void setOSMLinkIds(boolean OSMLinkIds) {
        this.OSMLinkIds = OSMLinkIds;
    }

    // route transit with R5's FastRaptorWorker instead of McRAPTOR: fastest trip only, no fares (#464)
    public void setFastRaptor(boolean fastRaptor) {
        this.fastRaptor = fastRaptor;
    }

    public TripPlanner(TransportNetwork transportNetwork, ProfileRequest request) {
        this.transportNetwork = transportNetwork;
        this.request = request;
        this.shortestPath = false;
    }

    //Does point to point routing with data from request
    public List<Trip> plan() {

        // find direct paths
        Map<String, Trip> trips = new HashMap<>();

        findDirectPaths(request, trips);

        Map<LegMode, StreetRouter> accessRouter = null;
        Map<LegMode, StreetRouter> egressRouter = null;

        if (request.hasTransit() && fastRaptor) {
            if (request.inRoutingFareCalculator != null) {
                throw new IllegalStateException("FastRaptor itineraries do not support fares");
            }
            FastRaptorOrigin origin = sharedOrigin;
            TIntIntMap egressTimes = sharedEgressTimes;
            if (egressTimes == null) {
                egressRouter = findEgressPaths(request);
                egressTimes = egressTimesAtStops(egressRouter);
            }
            if (origin == null && !shared && !egressTimes.isEmpty()) {
                BitSet retainPathsToStops = new BitSet();
                egressTimes.forEachKey(stop -> { retainPathsToStops.set(stop); return true; });
                origin = searchFastRaptorOrigin(retainPathsToStops);
            }
            if (origin != null) {
                accessRouter = origin.accessRouter;
                addFastRaptorTrip(trips, origin, egressTimes);
            }
        } else if (request.hasTransit()) {
            // Find access paths and times
            accessRouter = findAccessPaths(request);
            egressRouter = findEgressPaths(request);

            AccessTimes accessTimes = new AccessTimes(); // resets R5's target pruning per draw, see AccessTimes
            accessRouter.forEach((mode, r) -> accessTimes.put(mode, r.getReachedStops()));
            Map<LegMode, TIntIntMap> egressTimes = egressRouter.entrySet().stream()
                    .collect(Collectors.toMap(Map.Entry::getKey, e -> e.getValue().getReachedStops()));

            // Build RAPTOR router
            IntFunction<DominatingList> listSupplier;

            if (request.inRoutingFareCalculator != null) {
                listSupplier = (departureTime) -> new FareDominatingList(
                        request.inRoutingFareCalculator,
                        request.maxFare,
                        // while I appreciate the use of symbolic constants, I certainly hope the number of seconds per
                        // minute does not change
                        // in fact, we have been moving in the opposite direction with leap-second smearing
                        departureTime + request.maxTripDurationMinutes * FastRaptorWorker.SECONDS_PER_MINUTE);
            } else {
                // R5 keeps states up to the end of the time window + max_trip_duration for every draw, but plan() drops
                // trips longer than max_trip_duration from the draw's departure t: reject those states early, as the
                // FareDominatingList above does with its maxClockTime
                // with shortest_path only the fastest trip is returned, so the limit shrinks to the duration of the best
                // trip found so far: direct trips, then each draw's arrivals at the destination (stop == -1)
                final int[] maxDuration = {request.maxTripDurationMinutes * FastRaptorWorker.SECONDS_PER_MINUTE};
                if (shortestPath) trips.values().forEach(trip -> maxDuration[0] = Math.min(maxDuration[0], trip.getTotalDurationSeconds()));
                listSupplier = (t) -> new SuboptimalDominatingList(Math.max(request.suboptimalMinutes, 0)) {
                    @Override
                    public boolean add(McRaptorSuboptimalPathProfileRouter.McRaptorState state) {
                        if (state.time - t > maxDuration[0] || !super.add(state)) return false;
                        if (shortestPath && state.stop == -1) maxDuration[0] = Math.min(maxDuration[0], state.time - t);
                        return true;
                    }
                };
            }

            McRaptorSuboptimalPathProfileRouter router = new McRaptorSuboptimalPathProfileRouter(transportNetwork,
                    request, accessTimes, egressTimes, listSupplier,
                    null, true);
            // each origin gets its own sample of departure times (#601)
            R5TravelTimeComputer.seedOffsets(router, null, request.fromLat, request.fromLon);

            int maxFare = request.maxFare;
            if (request.inRoutingFareCalculator == null) {
                request.maxFare = -1; // turns on R5's target pruning, see AccessTimes
                accessTimes.bestTimesAtTarget = bestTimesAtTarget(router);
            }
            router.route();
            request.maxFare = maxFare; // the fare filter below needs the original value
            if (accessTimes.bestTimesAtTarget != null && accessTimes.draws != request.monteCarloDraws) {
                throw new IllegalStateException("R5's McRAPTOR router no longer works as TripPlanner.AccessTimes expects");
            }

            for (TIntObjectIterator<Collection<McRaptorSuboptimalPathProfileRouter.McRaptorState>> it =
                 router.finalStatesByDepartureTime.iterator(); it.hasNext();) {
                it.advance();

                int departureTime = it.key();

                for (McRaptorSuboptimalPathProfileRouter.McRaptorState state : it.value()) {
                    Trip newTrip = new Trip(state, departureTime, transportNetwork, request);
                    newTrip.setOD(fromId, toId, request);

                    if (!trips.containsKey(newTrip.getKey()) ||
                            trips.get(newTrip.getKey()).getTotalDurationSeconds() > newTrip.getTotalDurationSeconds()) {
                        trips.put(newTrip.getKey(), newTrip);
                    }
                }
            }

        }

        List<Trip> tripList = new ArrayList<>(trips.values());

        tripList = tripList.stream()
                .filter(trip -> trip.getTotalDurationSeconds() <= request.maxTripDurationMinutes * 60 && trip.getTotalFare() <= request.maxFare)
                .sorted(Comparator.comparingInt(Trip::directFirst).thenComparingInt(Trip::getNumberOfLegs).thenComparingInt(Trip::getTotalDurationSeconds))
                .collect(Collectors.toList());

        if (shortestPath && !tripList.isEmpty()) {
            tripList = List.of(tripList.stream().min(Comparator.comparingInt(Trip::getTotalDurationSeconds)).get());
        }

        // with egress times shared by the destination, the egress search is only needed for a transit trip's leg
        if (fastRaptor && egressRouter == null && tripList.stream().anyMatch(trip -> trip.directFirst() == 1)) {
            egressRouter = findEgressPaths(request);
        }

        // build street paths and geometries only for the trips that are returned
        List<Trip> completedTrips = new ArrayList<>();
        for (Trip trip : tripList) {
            try {
                trip.augment(accessRouter, egressRouter, transportNetwork, request, OSMLinkIds);
                completedTrips.add(trip);
            } catch (EgressPath.InvalidOriginException e) {
                LOG.warn("Skipping itinerary from {} to {}: {}", fromId, toId, e.getMessage());
            }
        }

        return completedTrips;
    }

    // with all_to_all, a FastRaptor search and egress times shared with the other pairs of the same origin and
    // destination (origin is null when the origin reaches no stop)
    private boolean shared;
    private FastRaptorOrigin sharedOrigin;
    private TIntIntMap sharedEgressTimes;

    public void setFastRaptorShared(FastRaptorOrigin origin, TIntIntMap egressTimes) {
        this.shared = true;
        this.sharedOrigin = origin;
        this.sharedEgressTimes = egressTimes;
    }

    /**
     * Access search and FastRaptorWorker search from the request's origin, keeping the paths to retainPathsToStops.
     * Null when no stop is reached by the access search.
     */
    public FastRaptorOrigin searchFastRaptorOrigin(BitSet retainPathsToStops) {
        Map<LegMode, StreetRouter> accessRouter = findAccessPaths(request);
        StreetRouter access = accessRouter.get(request.accessModes.iterator().next());
        if (access == null || retainPathsToStops.isEmpty()) return null;

        // R5 rejects arrivals at or after departure + max_trip_duration, and then fails a checkState when it steps
        // the departure back one minute and an access stop cannot be updated: drop those stops up front
        TIntIntMap accessTimes = streetTimesAtStops(access, request.maxTripDurationMinutes * FastRaptorWorker.SECONDS_PER_MINUTE);
        if (accessTimes.isEmpty()) return null;

        FastRaptorWorker worker = new FastRaptorWorker(transportNetwork.transitLayer, (AnalysisWorkerTask) request, accessTimes);
        worker.retainPaths = true;
        worker.retainPathsToStops = retainPathsToStops;
        int[][] travelTimes = worker.route();

        // keep only the best departure per stop (shortest travel time, ties to the earliest departure): with a
        // fixed egress time per stop, the fastest trip through a stop departs then, and an origin shared by many
        // destinations then holds one value per stop instead of one per stop and minute
        int nStops = transportNetwork.transitLayer.getStopCount();
        int[] travelTime = new int[nStops];
        Arrays.fill(travelTime, FastRaptorWorker.UNREACHED);
        int[] departureTime = new int[nStops];
        Path[] path = new Path[nStops];
        for (int i = 0; i < travelTimes.length; i++) {
            Path[] paths = worker.pathsPerIteration.get(i);
            int departure = worker.departureTimeForIteration[i];
            for (int stop = retainPathsToStops.nextSetBit(0); stop >= 0; stop = retainPathsToStops.nextSetBit(stop + 1)) {
                int time = travelTimes[i][stop];
                if (time == FastRaptorWorker.UNREACHED || paths[stop] == null) continue;
                if (time < travelTime[stop] || (time == travelTime[stop] && departure < departureTime[stop])) {
                    travelTime[stop] = time;
                    departureTime[stop] = departure;
                    path[stop] = paths[stop];
                }
            }
        }
        return new FastRaptorOrigin(accessRouter, accessTimes, travelTime, departureTime, path);
    }

    /** Egress times from the stops reached by the egress search to the request's destination. */
    public TIntIntMap egressTimesAtStops() {
        return egressTimesAtStops(findEgressPaths(request));
    }

    private TIntIntMap egressTimesAtStops(Map<LegMode, StreetRouter> egressRouter) {
        StreetRouter egress = egressRouter.get(request.egressModes.iterator().next());
        if (egress == null) return new TIntIntHashMap();
        return streetTimesAtStops(egress, request.maxTripDurationMinutes * FastRaptorWorker.SECONDS_PER_MINUTE);
    }

    /**
     * Adds the fastest transit trip found by R5's FastRaptorWorker over every minute of the time window, as a
     * replacement for McRAPTOR when only the shortest path is needed and there are no fares.
     * <p>
     * route() returns, per departure minute and stop, the travel time to that stop by vehicle (access included);
     * adding the egress time gives the door-to-door duration, as R5's own propagation does. Ties go to the earliest
     * departure, then to the lowest egress stop index.
     */
    private void addFastRaptorTrip(Map<String, Trip> trips, FastRaptorOrigin origin, TIntIntMap egressTimes) {
        int[] egressStops = egressTimes.keys();
        Arrays.sort(egressStops);

        int bestStop = -1, bestTotal = Integer.MAX_VALUE;
        for (int stop : egressStops) {
            if (origin.path[stop] == null) continue;
            int total = origin.travelTime[stop] + egressTimes.get(stop);
            if (total < bestTotal || (total == bestTotal && origin.departureTime[stop] < origin.departureTime[bestStop])) {
                bestStop = stop;
                bestTotal = total;
            }
        }
        if (bestStop < 0) return;

        Trip trip = new Trip(origin.path[bestStop], origin.departureTime[bestStop], origin.accessTimes,
                egressTimes.get(bestStop), bestTotal, transportNetwork);
        trip.setOD(fromId, toId, request);
        trips.put(trip.getKey(), trip);
    }

    /**
     * Complete street times below maxSeconds, matching the legs reconstructed by Trip.augment().
     * R5REgressRouter already costs edges in their physical travel direction and includes the
     * destination connection. State.reverse() would drop that connection's root cost. Use these
     * same costs before FastRaptor ranks trips, for both paired and shared-origin searches.
     */
    private TIntIntMap streetTimesAtStops(StreetRouter router, int maxSeconds) {
        TIntIntMap times = new TIntIntHashMap();
        router.getReachedStops().forEachEntry((stop, time) -> {
            if (time < maxSeconds) times.put(stop, time);
            return true;
        });
        return times;
    }


    /**
     * Finds direct paths between from and to coordinates in request and adds them to option
     */
    private void findDirectPaths(ProfileRequest request, Map<String, Trip> trips) {
        request.reverseSearch = false;
        //For direct modes
        for(LegMode mode: request.directModes) {
            StreetRouter streetRouter = new StreetRouter(transportNetwork.streetLayer);
            StreetPath streetPath;
            streetRouter.profileRequest = request;
            streetRouter.streetMode = StreetMode.valueOf(mode.toString());

            int limitSeconds = request.streetTime * 60;
            if (request.hasTransit()) {
                limitSeconds = Math.min(limitSeconds, request.getMaxTimeSeconds(mode));
            }
            streetRouter.timeLimitSeconds = limitSeconds;

            if(streetRouter.setOrigin(request.fromLat, request.fromLon)) {
                if(!streetRouter.setDestination(request.toLat, request.toLon)) {
                    LOG.warn("Trip from {} to {}. Direct mode {} to destination {} {} wasn't found.", fromId, toId, mode, request.toLat, request.toLon);
                    continue;
                }
                streetRouter.route();
                StreetRouter.State lastState = streetRouter.getState(streetRouter.getDestinationSplit());
                if (lastState == null) {
                    LOG.info("Trip from {} to {}. No direct {} path found from {} {} to {} {}.", fromId, toId, mode, request.fromLat, request.fromLon, request.toLat, request.toLon);
                    continue;
                }
                streetPath = new StreetPath(lastState, transportNetwork, false);
            } else {
                LOG.warn("Trip from {} to {}. Direct mode {} from origin {}, {} wasn't found.", fromId, toId, mode, request.fromLat, request.fromLon);
                continue;
            }

            StreetSegment streetSegment = new StreetSegment(streetPath, mode,
                    transportNetwork.streetLayer);

            LOG.info("adding direct mode {}", mode);
            EdgeStore edgeStore = null;
            if (OSMLinkIds) { edgeStore = transportNetwork.streetLayer.edgeStore; }
            Trip trip = Trip.newDirectTrip(request.fromTime, mode.toString(), streetSegment, edgeStore);
            trip.setOD(fromId, toId, request);
            // the key for a direct trip is the name of the mode
            trips.put(mode.toString(), trip);
        }
    }

    /**
     * Finds access paths from coordinate in request and adds all routers with paths to accessRouter map
     * @param request
     */
    private HashMap<LegMode, StreetRouter> findAccessPaths(ProfileRequest request) {
        request.reverseSearch = false;
        // Routes all access modes
        HashMap<LegMode, StreetRouter> accessRouter = new HashMap<>();
        for(LegMode mode: request.accessModes) {
            StreetRouter streetRouter = new StreetRouter(transportNetwork.streetLayer);
            streetRouter.profileRequest = request;
            streetRouter.streetMode = StreetMode.valueOf(mode.toString());

            //Gets correct maxCar/Bike/Walk time in seconds for access leg based on mode since it depends on the mode
            streetRouter.timeLimitSeconds = request.getMaxTimeSeconds(mode);
            streetRouter.transitStopSearch = true;
            streetRouter.quantityToMinimize = StreetRouter.State.RoutingVariable.DURATION_SECONDS;

            if(streetRouter.setOrigin(request.fromLat, request.fromLon)) {
                streetRouter.route();
                //Searching for access paths
                accessRouter.put(mode, streetRouter);
            } else {
                LOG.warn("MODE:{}, Edge near the origin coordinate {} wasn't found. Routing didn't start!", mode, fromId);
            }
        }

        return accessRouter;
    }

    /**
     * Finds all egress paths from to coordinate to end stop and adds routers to egressRouter
     * @param request
     */
    private Map<LegMode, StreetRouter> findEgressPaths(ProfileRequest request) {
        Map<LegMode, StreetRouter> egressRouter = new HashMap<>();
        //For egress
        //TODO: this must be reverse search
        request.reverseSearch = true;
        for(LegMode mode: request.egressModes) {
            StreetRouter streetRouter = new R5REgressRouter(transportNetwork.streetLayer);
            streetRouter.transitStopSearch = true;
            streetRouter.quantityToMinimize = StreetRouter.State.RoutingVariable.DURATION_SECONDS;

            //TODO: add support for bike sharing
            streetRouter.streetMode = StreetMode.valueOf(mode.toString());
            streetRouter.profileRequest = request;
            streetRouter.timeLimitSeconds = request.getMaxTimeSeconds(mode);
            if(streetRouter.setOrigin(request.toLat, request.toLon)) {
                streetRouter.route();
                TIntIntMap stops = streetRouter.getReachedStops();
                egressRouter.put(mode, streetRouter);
                LOG.info("Added {} egress stops for mode {}",stops.size(), mode);

            } else {
                LOG.warn("No permitted street connection within the time limit at destination {}, {} for mode {}. Routing didn't start!",
                        request.toLat, request.toLon, mode);
            }
        }

        return egressRouter;
    }

    /**
     * Access times given to R5's McRAPTOR router. They also make R5's target pruning safe for r5r.
     * <p>
     * R5 drops a state that arrives later than the best arrival at the destination found so far (plus
     * suboptimal_minutes), but only when request.maxFare &lt; 0 (McRaptorSuboptimalPathProfileRouter.addState, R5 v7.5).
     * Without a fare structure r5r passes maxFare = Integer.MAX_VALUE, so this pruning was off and every Monte Carlo
     * draw searched the whole network up to max_trip_duration. plan() therefore sets maxFare = -1 during route().
     * <p>
     * R5 keeps that best arrival (private field bestTimesAtTargetByAccessMode) across draws, so an early draw would
     * prune the trips of later draws and change results. route() calls accessTimes.forEach() exactly once per draw,
     * after bestStates.clear() and before any state of the draw is added, so clearing the field there limits the
     * pruning to the current draw. Pruned states can only lead to arrivals that the destination bag drops anyway, so
     * results are identical to the unpruned search.
     * <p>
     * Re-check on every R5 upgrade: the field name (a rename fails loudly in bestTimesAtTarget()); the maxFare &lt; 0
     * condition in addState (if it changes, pruning is silently off: slower, same results); and the forEach() call
     * once per draw (checked against monteCarloDraws after route()).
     */
    private static final class AccessTimes extends HashMap<LegMode, TIntIntMap> {
        TObjectIntMap<?> bestTimesAtTarget; // R5's bestTimesAtTargetByAccessMode, null when pruning is off
        int draws;

        @Override
        public void forEach(BiConsumer<? super LegMode, ? super TIntIntMap> action) {
            if (bestTimesAtTarget != null) {
                bestTimesAtTarget.clear(); // its no-entry value is Integer.MAX_VALUE: "no arrival yet"
                draws++;
            }
            super.forEach(action);
        }
    }

    private static TObjectIntMap<?> bestTimesAtTarget(McRaptorSuboptimalPathProfileRouter router) {
        try {
            Field field = McRaptorSuboptimalPathProfileRouter.class.getDeclaredField("bestTimesAtTargetByAccessMode");
            field.setAccessible(true);
            return (TObjectIntMap<?>) field.get(router);
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException("R5's McRAPTOR router no longer works as TripPlanner.AccessTimes expects", e);
        }
    }
}
