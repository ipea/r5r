package org.ipea.r5r.Planner;

import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.api.util.StreetSegment;
import com.conveyal.r5.common.GeometryUtils;
import com.conveyal.r5.profile.McRaptorSuboptimalPathProfileRouter;
import com.conveyal.r5.profile.ProfileRequest;
import com.conveyal.r5.profile.StreetMode;
import com.conveyal.r5.profile.StreetPath;
import com.conveyal.r5.streets.EdgeStore;
import com.conveyal.r5.streets.StreetRouter;
import com.conveyal.r5.streets.VertexStore;
import com.conveyal.r5.transit.RouteInfo;
import com.conveyal.r5.transit.TransitLayer;
import com.conveyal.r5.transit.TransportNetwork;
import com.conveyal.r5.transit.TripPattern;
import com.conveyal.r5.transit.TripSchedule;
import com.conveyal.r5.transit.path.Path;
import com.conveyal.r5.transit.path.StopSequence;
import gnu.trove.list.TIntList;
import gnu.trove.map.TIntIntMap;
import org.apache.commons.collections4.map.MultiKeyMap;
import org.ipea.r5r.Utils.Utils;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.LineString;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.function.Predicate;
import java.util.stream.Collectors;

public class Trip {
    private static final Logger LOG = LoggerFactory.getLogger(Trip.class);

    private boolean isDirect = false;

    public int directFirst() { return isDirect ? 0 : 1; }

    // origin-destination
    private String fromId;
    private double fromLat;
    private double fromLon;

    private String toId;
    private double toLat;
    private double toLon;

    public String getFromId() {
        return fromId;
    }

    public double getFromLat() {
        return fromLat;
    }

    public double getFromLon() {
        return fromLon;
    }

    public String getToId() {
        return toId;
    }

    public double getToLat() {
        return toLat;
    }

    public double getToLon() {
        return toLon;
    }

    public int getDepartureTime() {
        return departureTime;
    }

    public int getTotalDurationSeconds() {
        return totalDurationSeconds;
    }

    public int getTotalDistance() {
        return totalDistance;
    }

    public int getTotalFare() {
        return totalFare;
    }

    public List<TripLeg> getLegs() {
        return legs;
    }

    public int getNumberOfLegs() { return legs.size(); }

    public void setOD(String fromId, String toId, ProfileRequest request) {
        this.fromId = fromId;
        this.fromLat = request.fromLat;
        this.fromLon = request.fromLon;

        this.toId = toId;
        this.toLat = request.toLat;
        this.toLon = request.toLon;
    }

    private int departureTime;
    private int totalDurationSeconds;
    private int totalDistance;
    private int totalFare;
    private String key;

    private final List<TripLeg> legs;

    public String getKey() {
        return key;
    }

    public void buildKey() {
        if (isDirect) {
            this.key = legs.iterator().next().getMode();
        } else {
            this.key = legs.stream().map(TripLeg::getRoute).
                    filter(Predicate.not(String::isEmpty)).
                    collect(Collectors.joining("|"));
        }
    }

    public Trip() {
        legs = new ArrayList<>();
    }

    public void addLeg(TripLeg leg) {
        legs.add(leg);
    }

    public static Trip newDirectTrip(int departureTime, String mode, StreetSegment streetSegment, EdgeStore edgeStore) {
        Trip trip = new Trip();
        trip.isDirect = true;
        trip.departureTime = departureTime;
        trip.totalDurationSeconds = streetSegment.duration;
        trip.totalDistance = streetSegment.distance;
        trip.totalFare = 0;

        trip.addLeg(TripLeg.newDirectLeg(mode, streetSegment, edgeStore));

        return trip;
    }

    public Trip(McRaptorSuboptimalPathProfileRouter.McRaptorState state,
                int departureTime, TransportNetwork network, ProfileRequest request) {
        this.departureTime = departureTime;
        this.totalDurationSeconds = state.time - departureTime;
        this.totalFare = state.fare != null ? state.fare.cumulativeFarePaid : 0;

        legs = new ArrayList<>();

        try {
            loadTransitLegs(state, network, request);
            Collections.reverse(legs);
            buildKey();
        } catch (Exception e) {
            LOG.error("error loading legs");
            e.printStackTrace();
        }
    }

    public void augment(Map<LegMode, StreetRouter> accessRouter, Map<LegMode, StreetRouter> egressRouter,
                        TransportNetwork network, ProfileRequest request, boolean OSMLinkIds) {

        Map<Integer, StreetSegment> accessPaths = new HashMap<>();
        Map<Integer, StreetSegment> egressPaths = new HashMap<>();
        MultiKeyMap<Integer, StreetSegment> transferPaths = new MultiKeyMap<>();

        if (!isDirect) {
            int tripDuration = 0;
            int tripDistance = 0;

            // add access and egress legs
            addAccessPath(accessRouter, accessPaths, network, request, OSMLinkIds);
            addEgressPath(egressRouter, egressPaths, network, request, OSMLinkIds);

            for (TripLeg leg : legs) {
                leg.augmentTransitLeg(transferPaths, network, request, OSMLinkIds);
                tripDuration += (leg.getLegDurationSeconds() + leg.getWaitTime());
                tripDistance += leg.getLegDistance();
            }

            this.totalDistance = tripDistance;
            this.totalDurationSeconds = tripDuration;
        } else {
            int tripDistance = 0;

            for (TripLeg leg : legs) {
                tripDistance += leg.augmentDirectLeg();
            }

            this.totalDistance = tripDistance;
        }
    }

    private void loadTransitLegs(McRaptorSuboptimalPathProfileRouter.McRaptorState state,
                                 TransportNetwork network, ProfileRequest request) {
        while (state != null) {
            if (state.stop != -1 && (state.pattern != -1 || state.back != null)) {
                if (state.pattern == -1) {

                    int originTime = state.back.time;
                    int destTime = state.time;
                    int fare = state.fare != null ? state.fare.cumulativeFarePaid : 0;

                    legs.add(newStopTransferLeg(network, state.back.stop, state.stop, destTime - originTime, fare));

                } else {
                    TripPattern pattern = network.transitLayer.tripPatterns.get(state.pattern);

                    int boardStopIndex = pattern.stops[state.boardStopPosition];
                    int alightStopIndex = pattern.stops[state.alightStopPosition];

                    RouteInfo route = network.transitLayer.routes.get(pattern.routeIndex);
                    String mode = TransitLayer.getTransitModes(route.route_type).toString();

                    int duration = state.time - state.boardTime;
                    int wait = state.boardTime - state.back.time;

                    int fare = state.fare != null ? state.fare.cumulativeFarePaid : 0;
                    TripLeg leg = TripLeg.newTransitLeg(mode, duration,
                            fare, wait, boardStopIndex, alightStopIndex, route.route_id);

                    leg.setPatternData(pattern, state.boardStopPosition, state.alightStopPosition);

                    legs.add(leg);
                }

            }
            state = state.back;
        }
    }

    // walk between two stops; augment() replaces the straight line with the street path
    private static TripLeg newStopTransferLeg(TransportNetwork network, int originStopIndex, int destStopIndex,
                                              int duration, int fare) {
        LineString geom = GeometryUtils.geometryFactory.createLineString(new Coordinate[0]);

        Coordinate originStopCoord = network.transitLayer.getCoordinateForStopFixed(originStopIndex);
        Coordinate destStopCoord = network.transitLayer.getCoordinateForStopFixed(destStopIndex);

        if (originStopIndex != destStopIndex & originStopCoord != null & destStopCoord != null) {
            geom = GeometryUtils.geometryFactory.createLineString(new Coordinate[]{
                    new Coordinate(originStopCoord.getX() / VertexStore.FIXED_FACTOR, originStopCoord.getY() / VertexStore.FIXED_FACTOR),
                    new Coordinate(destStopCoord.getX() / VertexStore.FIXED_FACTOR, destStopCoord.getY() / VertexStore.FIXED_FACTOR),
            });
        }

        TripLeg leg = TripLeg.newTransferLeg(StreetMode.WALK.toString(), duration, fare, geom, null, null);
        leg.setODStops(originStopIndex, destStopIndex);
        return leg;
    }

    /**
     * Transit trip from a path retained by R5's FastRaptorWorker (#464). The path holds stop indices, board clock
     * times, ride times and the transfer walk before each ride, but no waits or pattern positions: waits follow from
     * the clock times, and positions are matched against the pattern's schedules (a pattern can visit a stop twice).
     *
     * @param accessTimes  access seconds per stop given to the worker
     * @param egressSeconds egress seconds from the last alight stop
     * @param expectedTotal the worker's travel time to the last alight stop plus egressSeconds
     */
    public Trip(Path path, int departureTime, TIntIntMap accessTimes, int egressSeconds, int expectedTotal,
                TransportNetwork network) {
        this.departureTime = departureTime;
        this.totalFare = 0;
        legs = new ArrayList<>();

        TIntList patterns = path.patternSequence.patterns;
        StopSequence stops = path.patternSequence.stopSequence;
        if (patterns.isEmpty() || !accessTimes.containsKey(stops.boardStops.get(0))) {
            throw new IllegalStateException("FastRaptor path does not start at an access stop");
        }

        int ready = departureTime + accessTimes.get(stops.boardStops.get(0)); // clock time at the next board stop
        for (int k = 0; k < patterns.size(); k++) {
            int boardStop = stops.boardStops.get(k);
            int alightStop = stops.alightStops.get(k);
            int boardTime = path.boardTimes.get(k);
            int rideTime = stops.rideTimesSeconds.get(k);

            if (k > 0) {
                int transferTime = stops.transferTimesSeconds.get(k);
                int previousAlightStop = stops.alightStops.get(k - 1);
                // a transfer within the same stop (GTFS transfers.txt, not loaded by r5r) has no leg of its own:
                // its time is then counted in the wait
                if (previousAlightStop != boardStop) {
                    legs.add(newStopTransferLeg(network, previousAlightStop, boardStop, transferTime, 0));
                    ready += transferTime;
                }
            }

            int wait = boardTime - ready;
            if (wait < 0) throw new IllegalStateException("FastRaptor path boards before reaching the stop");

            TripPattern pattern = network.transitLayer.tripPatterns.get(patterns.get(k));
            int[] positions = stopPositions(pattern, boardStop, alightStop, boardTime, rideTime);
            RouteInfo route = network.transitLayer.routes.get(pattern.routeIndex);
            String mode = TransitLayer.getTransitModes(route.route_type).toString();

            TripLeg leg = TripLeg.newTransitLeg(mode, rideTime, 0, wait, boardStop, alightStop, route.route_id);
            leg.setPatternData(pattern, positions[0], positions[1]);
            legs.add(leg);

            ready = boardTime + rideTime;
        }

        this.totalDurationSeconds = ready - departureTime + egressSeconds;
        if (totalDurationSeconds != expectedTotal) {
            throw new IllegalStateException("FastRaptor path duration does not match its travel time");
        }
        buildKey();
    }

    /**
     * Board and alight positions of a ride in a pattern: the pair whose scheduled times match the ride, or, when no
     * schedule matches, the shortest span from the board stop to a later alight stop.
     */
    private static int[] stopPositions(TripPattern pattern, int boardStop, int alightStop, int boardTime, int rideTime) {
        int[] best = null;
        for (int p = 0; p < pattern.stops.length; p++) {
            if (pattern.stops[p] != boardStop) continue;
            for (int q = p + 1; q < pattern.stops.length; q++) {
                if (pattern.stops[q] != alightStop) continue;
                for (TripSchedule schedule : pattern.tripSchedules) {
                    if (schedule.departures[p] == boardTime && schedule.arrivals[q] == boardTime + rideTime) {
                        return new int[]{p, q};
                    }
                }
                if (best == null || q - p < best[1] - best[0]) best = new int[]{p, q};
            }
        }
        if (best == null) throw new IllegalStateException("FastRaptor ride stops are not in its pattern");
        LOG.warn("No schedule of pattern {} matches the ride from stop {} at {}; using the shortest span",
                pattern.originalId, boardStop, boardTime);
        return best;
    }

    private void addAccessPath(Map<LegMode, StreetRouter> accessRouter, Map<Integer, StreetSegment> accessPaths,
                               TransportNetwork network, ProfileRequest request, boolean OSMLinkIds) {
        TripLeg leg = legs.get(0);

        int startStopIndex = leg.getBoardStop();
        int startVertexStopIndex = network.transitLayer.streetVertexForStop.get(startStopIndex);

        //LOG.info("Filling response access paths:");
        //TODO: update this so that each stopIndex and mode pair is changed to streetpath only once
        LegMode accessMode = request.accessModes.iterator().next();
        if (accessMode != null) {

            StreetSegment streetSegment = accessPaths.get(startVertexStopIndex);
            EdgeStore edgeStore = null;
            if (OSMLinkIds){
                edgeStore = network.streetLayer.edgeStore;
            }
            if (streetSegment == null) {
                StreetRouter streetRouter = accessRouter.get(accessMode);
                //FIXME: Must we really update this on every streetrouter?
                streetRouter.profileRequest.reverseSearch = false;
                StreetRouter.State streetState = streetRouter.getStateAtVertex(startVertexStopIndex);
                if (streetState != null) {
                    StreetPath streetPath;

                    streetPath = new StreetPath(streetState, network, false);

                    streetSegment = new StreetSegment(streetPath, accessMode, network.streetLayer);

                    TripLeg accessLeg = TripLeg.newTransferLeg(accessMode.toString(),
                            streetSegment.duration, 0, streetSegment.geometry, streetSegment, edgeStore);

                    legs.add(0, accessLeg);

                    accessPaths.put(startVertexStopIndex, streetSegment);
                } else {
                    LOG.warn("Access: Last state not found for mode:{} stop:{}({})", accessMode, startVertexStopIndex, startStopIndex);
                }
            } else {
                TripLeg accessLeg = TripLeg.newTransferLeg(accessMode.toString(),
                        streetSegment.duration, 0, streetSegment.geometry, streetSegment, edgeStore);
                legs.add(0, accessLeg);

                accessPaths.put(startVertexStopIndex, streetSegment);
            }
        } else {
            LOG.warn("Mode is not in stopModeAccessMap for start stop:{}({})", startVertexStopIndex, startStopIndex);
        }
    }

    private void addEgressPath(Map<LegMode, StreetRouter> egressRouter, Map<Integer, StreetSegment> egressPaths,
                               TransportNetwork network, ProfileRequest request, boolean OSMLinkIds) {
        TripLeg leg = legs.get(legs.size() - 1);

        int cumulativeFare = leg.getCumulativeFare();
        int endStopIndex = leg.getAlightStop(); // currentTransitPath.alightStops[currentTransitPath.length-1];
        int endVertexStopIndex = network.transitLayer.streetVertexForStop.get(endStopIndex);

        //LOG.info("Filling response EGRESS paths:");
        LegMode egressMode = request.egressModes.iterator().next();
        if (egressMode != null) {
            //Here egressRouter needs to have this egress mode since stopModeEgressMap is filled from egressRouter
            StreetSegment streetSegment = egressPaths.get(endVertexStopIndex);
            EdgeStore edgeStore = null;
            if (OSMLinkIds){
                edgeStore = network.streetLayer.edgeStore;
            }

            if (streetSegment == null) {
                StreetRouter streetRouter = egressRouter.get(egressMode);
                //FIXME: Must we really update this on every streetrouter?
                streetRouter.profileRequest.reverseSearch = true;
                StreetRouter.State streetState = streetRouter.getStateAtVertex(endVertexStopIndex);
                if (streetState != null) {
                    streetSegment = EgressPath.build(streetRouter, streetState, egressMode,
                            request.toLat, request.toLon);

                    TripLeg egressLeg = TripLeg.newTransferLeg(egressMode.toString(),
                            streetSegment.duration, cumulativeFare, streetSegment.geometry, streetSegment, edgeStore);
                    legs.add(egressLeg);
                } else {
                    LOG.warn("EGRESS: Last state not found for mode:{} stop:{}({})", egressMode, endVertexStopIndex, endStopIndex);
                }
            } else {
                TripLeg egressLeg = TripLeg.newTransferLeg(egressMode.toString(),
                        streetSegment.duration, cumulativeFare, streetSegment.geometry, streetSegment, edgeStore);
                legs.add(egressLeg);
                egressPaths.put(endVertexStopIndex, streetSegment);
            }

        } else {
            LOG.warn("Mode is not in stopModeEgressMap for END stop:{}({})", endVertexStopIndex, endStopIndex);
        }
    }
}

