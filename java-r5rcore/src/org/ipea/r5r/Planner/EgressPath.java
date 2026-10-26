package org.ipea.r5r.Planner;

import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.api.util.NonTransitMode;
import com.conveyal.r5.api.util.StreetEdgeInfo;
import com.conveyal.r5.api.util.StreetSegment;
import com.conveyal.r5.common.GeometryUtils;
import com.conveyal.r5.streets.EdgeStore;
import com.conveyal.r5.streets.Split;
import com.conveyal.r5.streets.StreetRouter;
import com.conveyal.r5.streets.VertexStore;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.LineString;

import java.util.ArrayList;
import java.util.List;

/** Reconstructs a single-mode egress, including its point-seeded terminal connection. */
public final class EgressPath {
    private EgressPath() {}

    /** Only this invalid-chain condition is recoverable by omitting one itinerary. */
    public static final class InvalidOriginException extends IllegalArgumentException {
        private InvalidOriginException() {
            super("Egress path must descend from this router's point origin");
        }
    }

    public static StreetSegment build(StreetRouter router, StreetRouter.State state,
                                      LegMode mode, double destinationLat, double destinationLon) {
        StreetSegment segment = new StreetSegment();
        segment.mode = mode;
        // These are the complete costs already supplied to RAPTOR or McRAPTOR. State.reverse() in
        // R5 v7.6 drops the root's partial-edge/off-street costs, so do not use it here.
        segment.duration = state.getLegDurationSeconds();
        segment.distance = state.distance;
        segment.streetEdges = new ArrayList<>();
        List<Coordinate> coordinates = new ArrayList<>();
        StreetRouter.State root = state;
        while (root.backState != null) {
            EdgeStore.Edge edge = router.streetLayer.edgeStore.getCursor(root.backEdge);
            LineString geometry = edge.getGeometry();
            append(coordinates, geometry.getCoordinates());
            addEdge(segment, edge, geometry, edge.getLengthMm(), root);
            root = root.backState;
        }
        Split split = router.getOriginSplit();
        if (split == null || !((root.backEdge == split.edge && root.vertex == split.vertex0)
                || (root.backEdge == split.edge + 1 && root.vertex == split.vertex1))) {
            throw new InvalidOriginException();
        }
        EdgeStore.Edge edge = router.streetLayer.edgeStore.getCursor(split.edge);
        Coordinate[] full = edge.getGeometry().getCoordinates();
        List<Coordinate> partial = new ArrayList<>();
        // A self-loop has the same vertex at both ends; only the directed seed edge
        // distinguishes which part of the street leads to the snapped destination.
        boolean fromVertex0 = root.backEdge == split.edge;
        if (fromVertex0) {
            for (int i = 0; i <= split.seg; i++) partial.add(full[i]);
        } else {
            for (int i = full.length - 1; i > split.seg; i--) partial.add(full[i]);
        }
        partial.add(new Coordinate(split.fixedLon / VertexStore.FIXED_FACTOR,
                split.fixedLat / VertexStore.FIXED_FACTOR));
        LineString partialGeometry = line(partial);
        append(coordinates, partialGeometry.getCoordinates());
        int partialMm = fromVertex0 ? split.distance0_mm : split.distance1_mm;
        if (partialMm > 0) {
            edge.seek(root.backEdge);
            addEdge(segment, edge, partialGeometry, partialMm, root);
        }
        append(coordinates, new Coordinate[]{new Coordinate(destinationLon, destinationLat)});
        segment.geometry = line(coordinates);
        return segment;
    }

    private static void addEdge(StreetSegment segment, EdgeStore.Edge edge, LineString geometry,
                                int distanceMm, StreetRouter.State state) {
        StreetEdgeInfo info = new StreetEdgeInfo();
        info.edgeId = edge.getEdgeIndex();
        info.geometry = geometry;
        info.distance = distanceMm;
        info.mode = NonTransitMode.valueOf(state.streetMode.toString());
        segment.streetEdges.add(info);
    }

    private static void append(List<Coordinate> coordinates, Coordinate[] next) {
        for (Coordinate coordinate : next) {
            if (coordinates.isEmpty() || !coordinates.get(coordinates.size() - 1).equals2D(coordinate)) {
                coordinates.add(coordinate);
            }
        }
    }

    private static LineString line(List<Coordinate> coordinates) {
        if (coordinates.size() == 1) coordinates.add(coordinates.get(0).copy());
        return GeometryUtils.geometryFactory.createLineString(coordinates.toArray(new Coordinate[0]));
    }
}
