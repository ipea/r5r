package com.conveyal.r5.streets;

import com.conveyal.r5.profile.ProfileRequest;
import com.conveyal.r5.profile.StreetMode;

/**
 * Point-origin reverse search for detailed itineraries, pending an upstream R5 correction.
 * This deliberately lives in R5's streets package to initialize its package-private queue
 * and best-state map, without reflection or replacing any upstream class. Recheck on R5 upgrades.
 * Only single-mode point-seeded egress uses this adapter; chained-mode searches are unchanged.
 * TODO: remove after R5 fixes setOrigin/State.reverse(); upstream issue link pending at
 * https://github.com/ipea/r5r/pull/607#issuecomment-6401238373.
 */
public final class R5REgressRouter extends StreetRouter {
    public R5REgressRouter(StreetLayer layer) {
        super(layer);
    }

    @Override
    public boolean setOrigin(double lat, double lon) {
        if (!profileRequest.reverseSearch) {
            throw new IllegalStateException("R5REgressRouter requires a reverse search");
        }
        // Keep R5's snapping, origin coordinates and heuristic initialization.
        if (!super.setOrigin(lat, lon)) return false;
        Split split = getOriginSplit();
        queue.clear();
        bestStatesAtEdge.clear();
        seed(split.vertex0, split.edge, split.distance0_mm, split.distanceToEdge_mm);
        seed(split.vertex1, split.edge + 1, split.distance1_mm, split.distanceToEdge_mm);
        return !queue.isEmpty();
    }

    private void seed(int vertex, int edgeId, int partialMm, int offStreetMm) {
        EdgeStore.Edge edge = streetLayer.edgeStore.getCursor(edgeId);
        // Probe a complete traversal to apply the same directional permissions, wheelchair
        // rules, bike-walking fallback and cost calculator as ordinary street traversal.
        State probe = edge.traverse(new State(edge.getToVertex(), -1, streetMode),
                streetMode, profileRequest, timeCalculator);
        if (probe == null && streetMode == StreetMode.BICYCLE
                && profileRequest.bikeTrafficStress > 0 && profileRequest.bikeTrafficStress < 4) {
            // Native point seeding ignores LTS on the snapped edge. Keep normal walk-the-bike
            // fallback when possible, but do not strand a destination where walking is forbidden.
            // Copy only to relax this partial: subsequent traversal keeps the original LTS limit.
            ProfileRequest splitRequest = profileRequest.clone();
            splitRequest.bikeTrafficStress = 4;
            probe = edge.traverse(new State(edge.getToVertex(), -1, streetMode),
                    streetMode, splitRequest, timeCalculator);
        }
        if (probe == null) return;
        State seed = new State(vertex, edgeId, probe.streetMode);
        // R5 v7.6 represents elevation/raster adjustments as an average factor per directed
        // edge. StreetRouter.partialRideSeconds also scales a whole-edge traversal time.
        // Truncate to whole seconds like native setOrigin. This preserves the averaged
        // model, not an exact clipped elevation profile or the pointset base-speed model.
        int partialSeconds = partialMm == 0 ? 0 : (int) (
                probe.getDurationSeconds() * (partialMm / (double) edge.getLengthMm()));
        int offStreetSeconds = offStreetMm / (int) (1000 * profileRequest.walkSpeed);
        seed.incrementTimeInSeconds((long) partialSeconds + offStreetSeconds);
        seed.distance = partialMm + offStreetMm;
        // Match StreetRouter.route(), which admits states strictly below the time limit.
        if (timeLimitSeconds > 0 && seed.getDurationSeconds() >= timeLimitSeconds) return;
        streetLayer.edgeStore.startTurnRestriction(seed.streetMode, true, seed);
        queue.add(seed);
        bestStatesAtEdge.put(edgeId, seed);
    }
}
