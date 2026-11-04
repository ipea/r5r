package org.ipea.r5r.Process;

import java.text.ParseException;
import java.util.List;
import java.util.concurrent.ForkJoinPool;

import org.ipea.r5r.R5.R5TravelTimeComputer;
import org.ipea.r5r.RegularGridResult;
import org.ipea.r5r.RoutingProperties;
import org.locationtech.jts.geom.Envelope;

import com.conveyal.r5.OneOriginResult;
import com.conveyal.r5.analyst.TravelTimeComputer;
import com.conveyal.r5.analyst.WebMercatorExtents;
import com.conveyal.r5.analyst.cluster.TravelTimeSurfaceTask;

/**
 * This class produces regular grids of travel times, used in isochrones, using the Conveyal
 * WebMercatorGridPointSet (the same as is used in the Conveyal UI). By returning travel times
 * as a raster, isochrone generation is more computationally efficient (because the very efficient
 * marching squares algorithm can be used). Resulting isochrones are more accurate as well, because
 * the marching squares algorithm uses information both about what cells are unreachable as well as
 * what cells are reachable. This way the isochrone cannot include any unreachable area (except perhaps
 * a small amount due to interpolation between grid cells), whereas the concave-hull algorithm used
 * previously uses a heuristic to identify unreachable areas.
 */
public class RegularGridProcess extends R5Process<RegularGridResult, RegularGridResult[]> {
    public final WebMercatorExtents extents;

    public RegularGridProcess(ForkJoinPool threadPool, RoutingProperties routingProperties, int zoom) {
        super(threadPool, routingProperties);
        
        // Calculate the extents of the transport network and request a pointset that size.
        // this will be fast after the first call as R5 transparently caches these pointsets.
        Envelope env = routingProperties.getTransportNetwork().getEnvelope();
        extents = WebMercatorExtents.forWgsEnvelope(env, zoom);
    }

    @Override
    public RegularGridResult runProcess(int index) {
        TravelTimeSurfaceTask request = new TravelTimeSurfaceTask();

        try {
            initalizeRequest(index, request);
        } catch (ParseException e) {
            // rethrow as unchecked
            throw new RuntimeException(e);
        }
    
        request.makeTauiSite = false;
        request.percentiles = routingProperties.percentiles;
        request.zoom = extents.zoom;
        request.west = extents.west;
        request.width = extents.width;
        request.north = extents.north;
        request.height = extents.height;

        TravelTimeComputer computer = new R5TravelTimeComputer(request, transportNetwork, routingProperties.monteCarloSeed);
        OneOriginResult result = computer.computeTravelTimes();

        return new RegularGridResult(result.travelTimes, request);
    }

    @Override
    protected RegularGridResult[] mergeResults(List<RegularGridResult> processResults) {
        return processResults.toArray(new RegularGridResult[0]);
    }

    // no destination pointsets for travel time surfaces
    @Override
    protected void buildDestinationPointSet() {}
}
