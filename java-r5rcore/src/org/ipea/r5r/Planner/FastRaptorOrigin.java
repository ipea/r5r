package org.ipea.r5r.Planner;

import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.streets.StreetRouter;
import com.conveyal.r5.transit.path.Path;
import gnu.trove.map.TIntIntMap;

import java.util.Map;

/**
 * Result of one FastRaptorWorker search from an origin over every minute of the time window, reduced to the best
 * departure at each retained stop: shortest travel time (ties to the earliest departure), its departure time and
 * path, plus the access search they start from. Read-only once built, so it can serve every destination of the
 * origin from several threads (#464).
 */
public class FastRaptorOrigin {
    final Map<LegMode, StreetRouter> accessRouter;
    final TIntIntMap accessTimes;
    final int[] travelTime;    // seconds from departure to arrival at the stop, by vehicle; UNREACHED if not reached
    final int[] departureTime; // clock time of the departure with that travel time
    final Path[] path;

    FastRaptorOrigin(Map<LegMode, StreetRouter> accessRouter, TIntIntMap accessTimes, int[] travelTime,
                     int[] departureTime, Path[] path) {
        this.accessRouter = accessRouter;
        this.accessTimes = accessTimes;
        this.travelTime = travelTime;
        this.departureTime = departureTime;
        this.path = path;
    }
}
