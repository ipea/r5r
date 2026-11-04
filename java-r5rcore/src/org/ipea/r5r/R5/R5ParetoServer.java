package org.ipea.r5r.R5;

import com.conveyal.r5.SoftwareVersion;
import com.conveyal.r5.analyst.cluster.RegionalTask;
import com.conveyal.r5.analyst.fare.BostonInRoutingFareCalculator;
import com.conveyal.r5.analyst.fare.TransferAllowance;
import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.common.GeometryUtils;
import com.conveyal.r5.profile.*;
import com.conveyal.r5.streets.StreetRouter;
import com.conveyal.r5.streets.VertexStore;
import com.conveyal.r5.transit.RouteInfo;
import com.conveyal.r5.transit.TransportNetwork;
import com.conveyal.r5.transit.TripPattern;
import gnu.trove.iterator.TIntObjectIterator;
import gnu.trove.map.TIntIntMap;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.CoordinateArrays;
import org.locationtech.jts.geom.LineString;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.IntFunction;


public class R5ParetoServer {
    private final RegionalTask profileRequest;
    public TransportNetwork transportNetwork;

    private static final Logger LOG = LoggerFactory.getLogger(R5ParetoServer.class);

    public R5ParetoServer (RegionalTask request, TransportNetwork transportNetwork) {
        this.profileRequest = request;
        this.transportNetwork = transportNetwork;
    }

    public R5ParetoServer.ParetoReturn handle () {
        // now perform routing - always using McRaptor
        LOG.info("Performing walk search for access (other access modes not supported)");
        Map<LegMode, TIntIntMap> accessTimes = accessEgressSearch(profileRequest.fromLat, profileRequest.fromLon, profileRequest);

        LOG.info("Performing walk search for egress (other access modes not supported)");
        Map<LegMode, TIntIntMap> egressTimes = accessEgressSearch(profileRequest.toLat, profileRequest.toLon, profileRequest);

        LOG.info("Performing multiobjective transit routing");
        long startTime = System.currentTimeMillis();
//        profileRequest.maxTripDurationMinutes = 120; // hack
        IntFunction<DominatingList> listSupplier = (departureTime) -> new FareDominatingList(
                profileRequest.inRoutingFareCalculator,
                profileRequest.maxFare,
                // while I appreciate the use of symbolic constants, I certainly hope the number of seconds per
                // minute does not change
                // in fact, we have been moving in the opposite direction with leap-second smearing
                departureTime + profileRequest.maxTripDurationMinutes * FastRaptorWorker.SECONDS_PER_MINUTE);

        McRaptorSuboptimalPathProfileRouter mcRaptor;

        if (profileRequest.inRoutingFareCalculator == null) {
            mcRaptor = new McRaptorSuboptimalPathProfileRouter(
                    transportNetwork,
                    profileRequest,
                    accessTimes,
                    egressTimes,
                    (t)->new SuboptimalDominatingList(profileRequest.suboptimalMinutes),
                    null,
                    true); // no collator - route will return states at destination
        } else {
            mcRaptor = new McRaptorSuboptimalPathProfileRouter(
                    transportNetwork,
                    profileRequest,
                    accessTimes,
                    egressTimes,
                    listSupplier,
                    null,
                    true); // no collator - route will return states at destination
        }

        try {
            mcRaptor.route();
        } catch (NullPointerException e) {
            LOG.error("exception in routing");
            e.printStackTrace();
        }
        long totalTime = System.currentTimeMillis() - startTime;

        List<R5ParetoServer.ParetoTrip> trips = new ArrayList<>();

        for (TIntObjectIterator<Collection<McRaptorSuboptimalPathProfileRouter.McRaptorState>> it =
             mcRaptor.finalStatesByDepartureTime.iterator(); it.hasNext();) {
            it.advance();

            int departureTime = it.key();

            for (McRaptorSuboptimalPathProfileRouter.McRaptorState state : it.value()) {
                trips.add(new R5ParetoServer.ParetoTrip(state, departureTime, transportNetwork));
            }
        }

        ParetoReturn ret = null;
        try {
            ProfileRequest newReq = (ProfileRequest) profileRequest.clone();
            // don't serialize the whole R5R fare calculator. HACK fareto requires something here
            // so we just return a BostonInRoutingFareCalculator.
            newReq.inRoutingFareCalculator = new BostonInRoutingFareCalculator();
            ret = new ParetoReturn(trips, totalTime, newReq);
        } catch (NullPointerException e){
            LOG.error("exception in building return");
            e.printStackTrace();
        }
        return ret;
    }

    private Map<LegMode, TIntIntMap> accessEgressSearch (double fromLat, double fromLon, ProfileRequest profileRequest) {
        LOG.info("Performing walk search for access (other access modes not supported)");
        StreetRouter sr = new StreetRouter(transportNetwork.streetLayer);
        sr.profileRequest = profileRequest;
        sr.timeLimitSeconds = profileRequest.maxWalkTime * 60; // 20 * 60; // hardwired at 20 mins
        sr.quantityToMinimize = StreetRouter.State.RoutingVariable.DURATION_SECONDS;

        if (!sr.setOrigin(fromLat, fromLon)) {
            LOG.error("Origin or destination not found");
        }

        sr.route();

        TIntIntMap accessTimes = sr.getReachedStops(); // map from stop ID to access time

        if (accessTimes.size() == 0) LOG.error("No transit near origin!");

        Map<LegMode, TIntIntMap> ret = new HashMap<>();
        ret.put(LegMode.WALK, accessTimes);
        return ret;
    }

    /**
     * Many happy returns - class to encapsulate return value.
     */
    public static final class ParetoReturn {
        public final Collection<R5ParetoServer.ParetoTrip> trips;
        public final long computeTimeMillis;
        /** save backend version in JSON output - useful for JSON that's being pushed to fareto-examples */
        public SoftwareVersion backendVersion = SoftwareVersion.instance;
        public String generationTime = LocalDateTime.now().format(DateTimeFormatter.ISO_DATE_TIME);
        public ProfileRequest request;

        public ParetoReturn(Collection<R5ParetoServer.ParetoTrip> trips, long computeTimeMillis, ProfileRequest request) {
            this.trips = trips;
            this.computeTimeMillis = computeTimeMillis;
            this.request = request;
        }
    }

    public static final class ParetoTrip {
        public final int durationSeconds;
        public final int departureTime;
        public final int fare;
        public final List<R5ParetoServer.ParetoLeg> legs;

        public ParetoTrip (McRaptorSuboptimalPathProfileRouter.McRaptorState state, int departureTime, TransportNetwork network) {
            this.departureTime = departureTime;
            this.durationSeconds = state.time - departureTime;
            this.fare = state.fare.cumulativeFarePaid;

            legs = new ArrayList<>();

            try
            {
                loadTransitLegs(state, network);
            } catch (Exception e) {
                LOG.error("error loading legs");
                e.printStackTrace();
            }

            Collections.reverse(legs);
        }

        private void loadTransitLegs(McRaptorSuboptimalPathProfileRouter.McRaptorState state, TransportNetwork network) {
            while (state != null) {
                if (state.stop != -1 && (state.pattern != -1 || state.back != null)) {
                    if (state.pattern == -1) {
                        int destStopIndex = state.stop;
                        int originStopIndex = state.back.stop;

                        Coordinate originStopCoord = network.transitLayer.getCoordinateForStopFixed(originStopIndex);
                        Coordinate destStopCoord = network.transitLayer.getCoordinateForStopFixed(destStopIndex);

                        int originTime = state.back.time;
                        int destTime = state.time;

                        LineString geom = GeometryUtils.geometryFactory.createLineString(new Coordinate[] {
                                new Coordinate(originStopCoord.getX() / VertexStore.FIXED_FACTOR, originStopCoord.getY() / VertexStore.FIXED_FACTOR),
                                new Coordinate(destStopCoord.getX() / VertexStore.FIXED_FACTOR, destStopCoord.getY() / VertexStore.FIXED_FACTOR),
                        });

                        legs.add(new ParetoTransferLeg(
                                originStopCoord.getY() / VertexStore.FIXED_FACTOR,
                                originStopCoord.getX() / VertexStore.FIXED_FACTOR,
                                destStopCoord.getY() / VertexStore.FIXED_FACTOR,
                                destStopCoord.getX() / VertexStore.FIXED_FACTOR,
                                geom,
                                originTime,
                                destTime,
                                network.transitLayer.stopIdForIndex.get(originStopIndex),
                                network.transitLayer.stopNames.get(originStopIndex),
                                network.transitLayer.stopIdForIndex.get(destStopIndex),
                                network.transitLayer.stopNames.get(destStopIndex),
                                state.fare.cumulativeFarePaid,
                                state.fare.transferAllowance
                        ));

                    } else {
                        TripPattern pattern = network.transitLayer.tripPatterns.get(state.pattern);

                        int boardStopIndex = pattern.stops[state.boardStopPosition];
                        int alightStopIndex = pattern.stops[state.alightStopPosition];

                        Coordinate boardStopCoord = network.transitLayer.getCoordinateForStopFixed(boardStopIndex);
                        Coordinate alightStopCoord = network.transitLayer.getCoordinateForStopFixed(alightStopIndex);

                        if (boardStopCoord == null) boardStopCoord = new Coordinate(0.0, 0.0);
                        if (alightStopCoord == null) alightStopCoord = new Coordinate(0.0, 0.0);

                        List<Coordinate> coords = new ArrayList<>();
                        List<LineString> hops = pattern.getHopGeometries(network.transitLayer);
                        for (int i = state.boardStopPosition; i < state.alightStopPosition; i++) { // hop i is from stop i to i + 1, don't include last stop index
                            LineString hop = hops.get(i);
                            coords.addAll(Arrays.asList(hop.getCoordinates()));
                        }
                        // consecutive hops share their stop; s2 rejects repeated vertices (as in TripLeg.getGeometry())
                        Coordinate[] hopCoords = coords.toArray(new Coordinate[0]);
                        Coordinate[] uniqueCoords = CoordinateArrays.removeRepeatedPoints(hopCoords);
                        LineString shape = GeometryUtils.geometryFactory.createLineString(uniqueCoords.length >= 2 ? uniqueCoords : hopCoords);

                        legs.add(new ParetoTransitLeg(network.transitLayer.routes.get(pattern.routeIndex),
                                network.transitLayer.stopIdForIndex.get(boardStopIndex), network.transitLayer.stopNames.get(boardStopIndex),
                                network.transitLayer.stopIdForIndex.get(alightStopIndex), network.transitLayer.stopNames.get(alightStopIndex),
                                state.boardTime, state.time, state.fare.cumulativeFarePaid,
                                boardStopCoord.getY() / VertexStore.FIXED_FACTOR,
                                boardStopCoord.getX() / VertexStore.FIXED_FACTOR,
                                alightStopCoord.getY() / VertexStore.FIXED_FACTOR,
                                alightStopCoord.getX() / VertexStore.FIXED_FACTOR, shape, state.fare.transferAllowance));
                    }


                }
                state = state.back;
            }
        }

    }

    public static final class ParetoTransitLeg extends R5ParetoServer.ParetoLeg {
        public final RouteInfo route;

        public ParetoTransitLeg(RouteInfo route, String boardStopId, String boardStopName, String alightStopId, String alightStopName,
                                int boardTime, int alightTime, int cumulativeFare, double boardStopLat, double boardStopLon,
                                double alightStopLat, double alightStopLon, LineString geom, TransferAllowance transferAllowance) {
            super(boardStopLat, boardStopLon, alightStopLat, alightStopLon, geom, boardTime, alightTime,
                    boardStopId, boardStopName, alightStopId, alightStopName, cumulativeFare, transferAllowance);
            this.route = route;
        }

        @Override public String getType() {
            return "transit";
        }
    }

    public static final class ParetoTransferLeg extends R5ParetoServer.ParetoLeg {
        public ParetoTransferLeg(double originLat, double originLon, double destLat,
                                 double destLon, LineString geom, int originTime, int destTime,
                                 String originStopId, String originStopName, String destStopId, String destStopName,
                                 int cumulativeFare, TransferAllowance transferAllowance) {
            super(originLat, originLon, destLat, destLon, geom, originTime, destTime,
                    originStopId, originStopName, destStopId, destStopName, cumulativeFare,
                    transferAllowance);
        }

        @Override public String getType() {
            return "transfer";
        }
    }

    public static abstract class ParetoLeg {
        public final double originLat;
        public final double originLon;
        public final double destLat;
        public final double destLon;
        public final LineString geom;
        public final int originTime;
        public final int destTime;
        public final String originStopId;
        public final String originStopName;
        public final String destStopId;
        public final String destStopName;
        public final int cumulativeFare;
        public final TransferAllowance transferAllowance;

        protected ParetoLeg(double originLat, double originLon, double destLat, double destLon,
                            LineString geom, int originTime, int destTime, String originStopId,
                            String originStopName, String destStopId, String destStopName, int cumulativeFare,
                            TransferAllowance transferAllowance) {
            this.originLat = originLat;
            this.originLon = originLon;
            this.destLat = destLat;
            this.destLon = destLon;
            this.geom = geom;
            this.originTime = originTime;
            this.destTime = destTime;
            this.originStopId = originStopId;
            this.originStopName = originStopName;
            this.destStopId = destStopId;
            this.destStopName = destStopName;
            this.cumulativeFare = cumulativeFare;
            this.transferAllowance = transferAllowance;
        }

        public abstract String getType();
    }
}
