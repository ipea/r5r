package org.ipea.r5r.Planner;

import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.api.util.StreetEdgeInfo;
import com.conveyal.r5.api.util.StreetSegment;
import com.conveyal.r5.common.GeometryUtils;
import com.conveyal.r5.profile.ProfileRequest;
import com.conveyal.r5.profile.StreetMode;
import com.conveyal.r5.profile.StreetPath;
import com.conveyal.r5.streets.EdgeStore;
import com.conveyal.r5.streets.StreetRouter;
import com.conveyal.r5.streets.VertexStore;
import com.conveyal.r5.transit.TransportNetwork;
import com.conveyal.r5.transit.TripPattern;
import org.apache.commons.collections4.map.MultiKeyMap;
import org.ipea.r5r.Utils.Utils;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.CoordinateArrays;
import org.locationtech.jts.geom.LineString;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;

import static com.conveyal.r5.transit.TransitLayer.TRANSFER_DISTANCE_LIMIT_METERS;

public class TripLeg {
    private String mode;
    private boolean isTransfer = false;
    private boolean isTransit = false;

    private int legDurationSeconds;
    private int legDistance;
    private int cumulativeFare;

    private int boardStop;
    private int alightStop;

    private String boardStopId = "";
    private String alightStopId = "";

    // stop indices of transfer legs; -1 (not a stop) for access, egress and direct legs,
    // since 0 is a valid stop index
    private int fromStop = -1;
    private int toStop = -1;

    private int boardStopPosition;
    private int alightStopPosition;
    private TripPattern pattern;

    private int waitTime;
    private String route;

    private LineString geometry;
    private List<StreetEdgeInfo> streetEdges;
    private LinkedHashSet<Integer> listEdgeId = new LinkedHashSet<>();
    private LinkedHashSet<Long> listOSMId = new LinkedHashSet<>();

    public void setPatternData(TripPattern pattern, int boardStopPosition, int alightStopPosition) {
        this.pattern = pattern;
        this.boardStopPosition = boardStopPosition;
        this.alightStopPosition = alightStopPosition;
    }

    public void setODStops(int fromStop, int toStop) {
        this.fromStop = fromStop;
        this.toStop = toStop;
    }

    public String getMode() {
        return mode;
    }

    public int getLegDurationSeconds() {
        return legDurationSeconds;
    }

    public int getLegDistance() {
        return legDistance;
    }

    public int getCumulativeFare() {
        return cumulativeFare;
    }

    public int getBoardStop() {
        return boardStop;
    }

    
    public String getBoardStopId() {
        return boardStopId;
    }

    public int getAlightStop() {
        return alightStop;
    }

    public String getAlightStopId() {
        return alightStopId;
    }

    public int getWaitTime() {
        return waitTime;
    }

    public String getRoute() {
        return route;
    }

    public LinkedHashSet<Long> getListOSMId() {
        return listOSMId;
    }

    public LinkedHashSet<Integer> getListEdgeId() {
        return listEdgeId;
    }

    public LineString getGeometry() {
        // consecutive transit hops share their stop and street paths can repeat points; s2 rejects
        // repeated vertices. A line of identical points is kept as is (a 1-point LINESTRING is invalid)
        Coordinate[] coords = CoordinateArrays.removeRepeatedPoints(geometry.getCoordinates());
        return coords.length >= 2 && coords.length < geometry.getNumPoints()
                ? geometry.getFactory().createLineString(coords) : geometry;
    }

    public static TripLeg newDirectLeg(String mode, StreetSegment streetSegment, EdgeStore edgeStore) {
        TripLeg newLeg = new TripLeg();

        newLeg.mode = mode;
        newLeg.legDistance = streetSegment.distance;
        newLeg.legDurationSeconds = streetSegment.duration;
        newLeg.cumulativeFare = 0;
        newLeg.route = "";
        newLeg.geometry = streetSegment.geometry;
        newLeg.streetEdges = streetSegment.streetEdges;
        if (edgeStore != null) {
            // populate listedgeid for First/last-mile legs
            LinkedHashSet<Long> listOSMId = new LinkedHashSet<>();
            LinkedHashSet<Integer> listEdgeId = new LinkedHashSet<>();

            for (var u : newLeg.streetEdges) {
                int edgeId = u.edgeId;
                long osmId = edgeStore.getCursor(edgeId).getOSMID();

                if (osmId > 0) {
                    listOSMId.add(osmId);
                    listEdgeId.add(edgeId);
                }
            }

            newLeg.listEdgeId = listEdgeId;
            newLeg.listOSMId = listOSMId;
        }

        return newLeg;
    }

    public static TripLeg newTransferLeg(String mode, int duration, int fare, LineString geometry, StreetSegment streetSegment, EdgeStore edgeStore) {
        TripLeg newLeg = new TripLeg();

        newLeg.mode = mode;
        newLeg.isTransfer = true;
        newLeg.legDistance = (int) geometry.getLength();
        newLeg.legDurationSeconds = duration;
        newLeg.cumulativeFare = fare;
        newLeg.route = "";
        if (edgeStore != null && streetSegment != null) {
            LinkedHashSet<Long> listOSMId = new LinkedHashSet<>();
            LinkedHashSet<Integer> listEdgeId = new LinkedHashSet<>();

            for (var u : streetSegment.streetEdges) {
                int edgeId = u.edgeId;
                long osmId = edgeStore.getCursor(edgeId).getOSMID();


                if (osmId > 0) {
                    listOSMId.add(osmId);
                    listEdgeId.add(edgeId);
                }
            }

            newLeg.listEdgeId = listEdgeId;
            newLeg.listOSMId = listOSMId;
        }
        newLeg.geometry = geometry;

        return newLeg;
    }

    public static TripLeg newTransitLeg(String mode, int duration, int fare, int waitTime,
                                        int boardStop, int alightStop, String route) {
        TripLeg newLeg = new TripLeg();

        newLeg.mode = mode;
        newLeg.isTransit = true;
        newLeg.legDurationSeconds = duration;
        newLeg.cumulativeFare = fare;
        newLeg.waitTime = waitTime;
        newLeg.boardStop = boardStop;
        newLeg.alightStop = alightStop;
        newLeg.route = route;
        
        newLeg.boardStopId = "";
        newLeg.alightStopId = "";
        // newLeg.legDistance = (int) geometry.getLength();
        // newLeg.geometry = geometry;

        return newLeg;
    }

    public void augmentTransitLeg(MultiKeyMap<Integer, StreetSegment> transferPaths,
                                  TransportNetwork network, ProfileRequest request, Boolean OSMLinkIds) {
//        TripPattern pattern = network.transitLayer.tripPatterns.get(state.pattern);
//
//        int boardStopIndex = pattern.stops[state.boardStopPosition];
//        int alightStopIndex = pattern.stops[state.alightStopPosition];

        if (isTransit) {
            List<Coordinate> coords = new ArrayList<>();
            List<LineString> hops = pattern.getHopGeometries(network.transitLayer);
            for (int i = boardStopPosition; i < alightStopPosition; i++) { // hop i is from stop i to i + 1, don't
                                                                           // include last stop index
                LineString hop = hops.get(i);
                coords.addAll(Arrays.asList(hop.getCoordinates()));
            }
            geometry = GeometryUtils.geometryFactory.createLineString(coords.toArray(new Coordinate[0]));
            legDistance = Utils.getLinestringLength(geometry);
            if (OSMLinkIds) {
                this.alightStopId = network.transitLayer.stopIdForIndex.get(this.alightStop);
                this.boardStopId = network.transitLayer.stopIdForIndex.get(this.boardStop);
            }

        } else {
            // street path between stops
            if (this.fromStop >= 0 & this.toStop >= 0) {
                StreetSegment streetSegment = transferPaths.get(this.fromStop, this.toStop);

                if (streetSegment == null) {
                    boolean prevReverseSearch = request.reverseSearch;
                    request.reverseSearch = false;

                    //LOG.info("Filling middle paths");
                    StreetRouter streetRouter = new StreetRouter(network.streetLayer);
                    streetRouter.streetMode = StreetMode.WALK;
                    streetRouter.profileRequest = request;
                    //TODO: make configurable distanceLimitMeters in middle
                    streetRouter.distanceLimitMeters = TRANSFER_DISTANCE_LIMIT_METERS;

                    int stopVertexId = network.transitLayer.streetVertexForStop.get(this.fromStop);
                    streetRouter.setOrigin(stopVertexId);

                    Coordinate destStopCoord = network.transitLayer.getCoordinateForStopFixed(this.toStop);
                    streetRouter.setDestination(destStopCoord.getY() / VertexStore.FIXED_FACTOR,
                            destStopCoord.getX() / VertexStore.FIXED_FACTOR);

                    streetRouter.route();

                    StreetRouter.State lastState = streetRouter.getState(
                            destStopCoord.getY() / VertexStore.FIXED_FACTOR,
                            destStopCoord.getX() / VertexStore.FIXED_FACTOR);

                    if (lastState != null) {
                        StreetPath streetPath = new StreetPath(lastState, network, false);
                        streetSegment = new StreetSegment(streetPath, LegMode.WALK, network.streetLayer);

                        // keep the transfer duration computed by RAPTOR (distance / walk speed), which
                        // is the one used to filter and rank trips; the re-routed street path is only
                        // used for geometry, distance and edge ids
                        fillDataTransitLeg(network, OSMLinkIds, streetSegment);

                        transferPaths.put(this.fromStop, this.toStop, streetSegment);
                    }

                    request.reverseSearch = prevReverseSearch;
                } else {
                    fillDataTransitLeg(network, OSMLinkIds, streetSegment);
                }
            } else {
                this.legDistance = Utils.getLinestringLength(geometry);
            }
        }
    }

    private void fillDataTransitLeg(TransportNetwork network, Boolean OSMLinkIds, StreetSegment streetSegment) {
        this.geometry = streetSegment.geometry;
        this.streetEdges = streetSegment.streetEdges;
        if (OSMLinkIds) {
            LinkedHashSet<Long> listOSMId = new LinkedHashSet<>();
            LinkedHashSet<Integer> listEdgeId = new LinkedHashSet<>();

            for (var u : streetEdges) {
                int edgeId = u.edgeId;
                long osmId = network.streetLayer.edgeStore.getCursor(edgeId).getOSMID();

                if (osmId > 0) {
                    listOSMId.add(osmId);
                    listEdgeId.add(edgeId);
                }
            }

            this.listEdgeId = listEdgeId;
            this.listOSMId = listOSMId;
        }
        this.legDistance = Utils.getLinestringLength(geometry);
    }

    public int augmentDirectLeg() {
        this.legDistance = Utils.getLinestringLength(geometry);
        return this.legDistance;
    }
}

