package org.ipea.r5r;

import com.conveyal.analysis.components.WorkerComponents;
import com.conveyal.gtfs.model.Service;
import com.conveyal.r5.OneOriginResult;
import com.conveyal.r5.analyst.Grid;
import com.conveyal.r5.analyst.cluster.PathResult;
import com.conveyal.r5.analyst.decay.*;
import com.conveyal.r5.api.util.SearchType;
import com.conveyal.r5.analyst.scenario.RoadCongestion;
import com.conveyal.r5.transit.TransportNetwork;
import com.fasterxml.jackson.core.JsonProcessingException;

import org.apache.commons.io.FilenameUtils;
import org.ipea.r5r.Fares.FareStructure;
import org.ipea.r5r.Fares.FareStructureBuilder;
import org.ipea.r5r.Fares.RuleBasedInRoutingFareCalculator;
import org.ipea.r5r.Modifications.R5RFileStorage;
import org.ipea.r5r.Network.NetworkBuilder;
import org.ipea.r5r.Process.*;
import org.ipea.r5r.Scenario.R5RShapefileLts;
import org.ipea.r5r.Scenario.RoadCongestionOSM;
import org.ipea.r5r.Scenario.SetLtsOsm;
import org.ipea.r5r.Utils.Utils;
import org.slf4j.LoggerFactory;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.ParseException;
import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ForkJoinPool;

import org.locationtech.jts.geom.Envelope;


public class R5RCore {

    public static final String R5_VERSION = System.getProperty("R5_VER", "7+, ERROR getting exact version");

    public static final String R5R_VERSION = System.getProperty("R5R_VER", "2+, ERROR getting exact version");

    private int numberOfThreads;
    private ForkJoinPool r5rThreadPool;

    private final RoutingProperties routingProperties;

    private final String dataPath;

    public final RDataFrame gtfsErrors;

    public double getWalkSpeed() {
        return this.routingProperties.walkSpeed;
    }

    public void setWalkSpeed(double walkSpeed) {
        this.routingProperties.walkSpeed = walkSpeed;
    }

    public double getBikeSpeed() {
        return this.routingProperties.bikeSpeed;
    }

    public void setBikeSpeed(double bikeSpeed) {
        this.routingProperties.bikeSpeed = bikeSpeed;
    }

    public int getMaxLevelTrafficStress() {
        return this.routingProperties.maxLevelTrafficStress;
    }

    public void setMaxLevelTrafficStress(int maxLevelTrafficStress) {
        this.routingProperties.maxLevelTrafficStress = maxLevelTrafficStress;
    }

    public int getSuboptimalMinutes() {
        return this.routingProperties.suboptimalMinutes;
    }

    public void setSuboptimalMinutes(int suboptimalMinutes) {
        this.routingProperties.suboptimalMinutes = Math.max(suboptimalMinutes, 0);
    }

    public int getTimeWindowSize() {
        return this.routingProperties.timeWindowSize;
    }

    public void setTimeWindowSize(int timeWindowSize) {
        this.routingProperties.timeWindowSize = timeWindowSize;
    }

    public int getNumberOfMonteCarloDraws() {
        return this.routingProperties.numberOfMonteCarloDraws;
    }

    public void setNumberOfMonteCarloDraws(int numberOfMonteCarloDraws) {
        this.routingProperties.numberOfMonteCarloDraws = numberOfMonteCarloDraws;
    }

    public void setPercentiles(int[] percentiles) {
        this.routingProperties.percentiles = percentiles;
    }

    public void setPercentiles(int percentile) {
        this.routingProperties.percentiles = new int[1];
        this.routingProperties.percentiles[0] = percentile;
    }

    public void setCutoffs(int[] cutoffs) {
        this.routingProperties.cutoffs = cutoffs;
    }

    public void setCutoffs(int cutoff) {
        this.routingProperties.cutoffs = new int[1];
        this.routingProperties.cutoffs[0] = cutoff;
    }

    public void setTravelAllowance(boolean active) {
        ParetoItineraryPlanner.travelAllowanceActive = active;
    }

    public int getMaxRides() {
        return this.routingProperties.maxRides;
    }

    public void setMaxRides(int maxRides) {
        this.routingProperties.maxRides = maxRides;
    }

    public void setExpandedTravelTimes(boolean expandedTravelTimes) {
        this.routingProperties.expandedTravelTimes = expandedTravelTimes;
    }

    public void setSearchType(String searchType) {
        this.routingProperties.searchType = SearchType.valueOf(searchType);
    }

    public void setTravelTimesBreakdown(boolean detailedTravelTimes) {
        this.routingProperties.travelTimesBreakdown = detailedTravelTimes;
    }

    public boolean getTravelTimesBreakdown() {
        return this.routingProperties.travelTimesBreakdown;
    }

    public void setTravelTimesBreakdownStat(String stat) {
        stat = stat.toUpperCase();
        if (stat.equals("MIN") | stat.equals("MINIMUM")) {
            this.routingProperties.travelTimesBreakdownStat = PathResult.Stat.MINIMUM;
        }
        if (stat.equals("MEAN") | stat.equals("AVG") | stat.equals("AVERAGE")) {
            this.routingProperties.travelTimesBreakdownStat = PathResult.Stat.MEAN;
        }
    }

    public void setMaxFare(float maxFare) {
        this.routingProperties.maxFare = (maxFare >= 0) ? maxFare : Integer.MAX_VALUE;
    }

    public void setFareCutoffs(float maxFare) {
        this.routingProperties.maxFare = maxFare;
        this.routingProperties.fareCutoffs = new float[]{maxFare};
    }

    public void setFareCutoffs(float[] maxFare) {
        this.routingProperties.maxFare = maxFare[0];
        this.routingProperties.fareCutoffs = maxFare;
    }

    public void setFareCalculator(String fareCalculatorSettingsJson) {
        this.routingProperties.setFareCalculatorJson(fareCalculatorSettingsJson);
    }

    public void dropFareCalculator() {
        this.routingProperties.fareCalculator = null;
        this.routingProperties.maxFare = -1.0f;
        this.routingProperties.fareCutoffs = new float[]{-1.0f};
    }

    public String getTravelTimesBreakdownStat() {
        return this.routingProperties.travelTimesBreakdownStat.toString();
    }

    public int getNumberOfThreads() {
        return this.numberOfThreads;
    }

    // called from R before every routing call: reuse the pool when the number of threads is unchanged
    public void setNumberOfThreads(int numberOfThreads) {
        if (r5rThreadPool != null && r5rThreadPool != ForkJoinPool.commonPool()
                && r5rThreadPool.getParallelism() == numberOfThreads) return;
        shutdownThreadPool();
        this.numberOfThreads = numberOfThreads;
        r5rThreadPool = new ForkJoinPool(numberOfThreads);
    }

    public void setNumberOfThreadsToMax() {
        shutdownThreadPool();
        r5rThreadPool = ForkJoinPool.commonPool();
        numberOfThreads = ForkJoinPool.commonPool().getParallelism();
    }

    // the common pool cannot be shut down; routing calls are sequential, so the old pool is idle here
    private void shutdownThreadPool() {
        if (r5rThreadPool != null && r5rThreadPool != ForkJoinPool.commonPool()) r5rThreadPool.shutdown();
    }

    public void silentMode() {
        Utils.setLogModeOther("OFF");
        Utils.setLogModeJar("WARN");
    }

    public void verboseMode() {
        Utils.setLogModeOther("INFO");
        Utils.setLogModeJar("INFO");
    }

    public void setProgress(boolean progress) {
        Utils.setlogProgress(progress);
    }

    public void setBenchmark(boolean benchmark) {
        Utils.benchmark = benchmark;
    }

    public void setCsvOutput(String csvFolder) {
        if (!csvFolder.equals("")) {
            Utils.saveOutputToCsv = true;
            Utils.outputCsvFolder = csvFolder;
        } else {
            Utils.saveOutputToCsv = false;
            Utils.outputCsvFolder = "";
        }
    }

    public String getOutputCsvFolder () {
        return Utils.outputCsvFolder;
    }

    public String getLogPath() { return System.getProperty("LOG_PATH"); }

    public void setDetailedItinerariesV2(boolean v2) {
        Utils.detailedItinerariesV2 = v2;
    }

    public String getDataPath() { return dataPath; }

    private static final org.slf4j.Logger LOG = LoggerFactory.getLogger(R5RCore.class);

    public R5RCore(String dataFolder, boolean verbose, String nativeElevationFunction) throws Exception {
        if (verbose) {
            verboseMode();
        } else {
            silentMode();
        }

        setNumberOfThreadsToMax();

        WorkerComponents.fileStorage = new R5RFileStorage(null);

        nativeElevationFunction = nativeElevationFunction.toUpperCase();

        NetworkBuilder builder = new NetworkBuilder();

        builder.useNativeElevation = !nativeElevationFunction.equals("NONE");
        builder.elevationCostFunction = nativeElevationFunction;

        dataPath = dataFolder;
        Path path = Paths.get(dataFolder).toAbsolutePath().normalize();
        // network will be null if there were high priority errors
        TransportNetwork network = builder.checkAndLoadR5Network(path.toString());
        this.routingProperties = network == null ? null : new RoutingProperties(network);
        this.gtfsErrors = builder.gtfsErrors;
    }

    // ---------------------------------------------------------------------------------------------------
    //                                      MAIN R5R FUNCTIONS
    // ---------------------------------------------------------------------------------------------------

    // ----------------------------------  DETAILED ITINERARIES  -----------------------------------------

    public RDataFrame detailedItineraries(String fromId, double fromLat, double fromLon, String toId, double toLat, double toLon,
                                                                   String directModes, String transitModes, String accessModes, String egressModes,
                                                                   String date, String departureTime, int maxWalkTime, int maxBikeTime,  int maxCarTime, int maxTripDuration,
                                                                   boolean dropItineraryGeometry, boolean shortestPath, boolean osm_link_ids) throws ParseException, ExecutionException, InterruptedException {

        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};
        String[] toIds = {toId};
        double[] toLats = {toLat};
        double[] toLons = {toLon};

        return detailedItineraries(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes,
                date, departureTime, maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration,
                dropItineraryGeometry, shortestPath, osm_link_ids);

    }

    public RDataFrame detailedItineraries(String[] fromIds, double[] fromLats, double[] fromLons,
                                                                            String[] toIds, double[] toLats, double[] toLons,
                                                                            String directModes, String transitModes, String accessModes, String egressModes,
                                                                            String date, String departureTime, int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration,
                                                                            boolean dropItineraryGeometry, boolean shortestPath, boolean osmLinkIds) throws ExecutionException, InterruptedException {
        if (Utils.detailedItinerariesV2) {
            // call regular detailed itineraries, based on PointToPointQuery
            FastDetailedItineraryPlanner detailedItineraryPlanner = new FastDetailedItineraryPlanner(this.r5rThreadPool, this.routingProperties);
            detailedItineraryPlanner.setOrigins(fromIds, fromLats, fromLons);
            detailedItineraryPlanner.setDestinations(toIds, toLats, toLons);
            detailedItineraryPlanner.setModes(directModes, accessModes, transitModes, egressModes);
            detailedItineraryPlanner.setDepartureDateTime(date, departureTime);
            detailedItineraryPlanner.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);
            if (shortestPath) detailedItineraryPlanner.shortestPathOnly();
            if (dropItineraryGeometry) { detailedItineraryPlanner.dropItineraryGeometry(); }
            if (osmLinkIds) detailedItineraryPlanner.OSMLinkIds();

            RDataFrame out = detailedItineraryPlanner.run();
            this.routingProperties.reset();
            return out;
        } else {
            // call regular detailed itineraries, based on PointToPointQuery
            DetailedItineraryPlanner detailedItineraryPlanner = new DetailedItineraryPlanner(this.r5rThreadPool, this.routingProperties);
            detailedItineraryPlanner.setOrigins(fromIds, fromLats, fromLons);
            detailedItineraryPlanner.setDestinations(toIds, toLats, toLons);
            detailedItineraryPlanner.setModes(directModes, accessModes, transitModes, egressModes);
            detailedItineraryPlanner.setDepartureDateTime(date, departureTime);
            detailedItineraryPlanner.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);
            if (dropItineraryGeometry) { detailedItineraryPlanner.dropItineraryGeometry(); }

            RDataFrame out = detailedItineraryPlanner.run();
            this.routingProperties.reset();
            return out;
        }
    }





    // ----------------------------------  TRAVEL TIME MATRIX  -----------------------------------------

    public RDataFrame travelTimeMatrix(String fromId, double fromLat, double fromLon,
                                                                           String[] toIds, double[] toLats, double[] toLons,
                                                                           String directModes, String transitModes, String accessModes, String egressModes,
                                                                           String date, String departureTime,
                                                                           int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};

        return travelTimeMatrix(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes, date, departureTime, maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame travelTimeMatrix(String[] fromIds, double[] fromLats, double[] fromLons,
                                                                           String toId, double toLat, double toLon,
                                                                           String directModes, String transitModes, String accessModes, String egressModes,
                                                                           String date, String departureTime,
                                                                           int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] toIds = {toId};
        double[] toLats = {toLat};
        double[] toLons = {toLon};

        return travelTimeMatrix(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes, date, departureTime, maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame travelTimeMatrix(String fromId, double fromLat, double fromLon,
                                                                           String toId, double toLat, double toLon,
                                                                           String directModes, String transitModes, String accessModes, String egressModes,
                                                                           String date, String departureTime,
                                                                           int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};

        String[] toIds = {toId};
        double[] toLats = {toLat};
        double[] toLons = {toLon};

        return travelTimeMatrix(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes, date, departureTime, maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame travelTimeMatrix(String[] fromIds, double[] fromLats, double[] fromLons,
                                                                           String[] toIds, double[] toLats, double[] toLons,
                                                                           String directModes, String transitModes, String accessModes, String egressModes,
                                                                           String date, String departureTime,
                                                                           int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        TravelTimeMatrixComputer travelTimeMatrixComputer = new TravelTimeMatrixComputer(this.r5rThreadPool, this.routingProperties);
        travelTimeMatrixComputer.setOrigins(fromIds, fromLats, fromLons);
        travelTimeMatrixComputer.setDestinations(toIds, toLats, toLons);
        travelTimeMatrixComputer.setModes(directModes, accessModes, transitModes, egressModes);
        travelTimeMatrixComputer.setDepartureDateTime(date, departureTime);
        travelTimeMatrixComputer.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

        RDataFrame out = travelTimeMatrixComputer.run();
        this.routingProperties.reset();
        return out;
    }

    // ----------------------------------  PARETO FRONTIERS  -----------------------------------------

    public RDataFrame paretoFrontier(String fromId, double fromLat, double fromLon,
                                       String[] toIds, double[] toLats, double[] toLons,
                                       String directModes, String transitModes, String accessModes, String egressModes,
                                       String date, String departureTime,
                                       int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};

        return paretoFrontier(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes, date, departureTime,
                maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame paretoFrontier(String[] fromIds, double[] fromLats, double[] fromLons,
                                       String toId, double toLat, double toLon,
                                       String directModes, String transitModes, String accessModes, String egressModes,
                                       String date, String departureTime,
                                       int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] toIds = {toId};
        double[] toLats = {toLat};
        double[] toLons = {toLon};

        return paretoFrontier(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes, date, departureTime,
                maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame paretoFrontier(String fromId, double fromLat, double fromLon,
                                       String toId, double toLat, double toLon,
                                       String directModes, String transitModes, String accessModes, String egressModes,
                                       String date, String departureTime,
                                       int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};

        String[] toIds = {toId};
        double[] toLats = {toLat};
        double[] toLons = {toLon};

        return paretoFrontier(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes, date, departureTime,
                maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame paretoFrontier(String[] fromIds, double[] fromLats, double[] fromLons,
                                       String[] toIds, double[] toLats, double[] toLons,
                                       String directModes, String transitModes, String accessModes, String egressModes,
                                       String date, String departureTime,
                                       int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        ParetoFrontierCalculator paretoFrontierCalculator = new ParetoFrontierCalculator(this.r5rThreadPool, this.routingProperties);
        paretoFrontierCalculator.setOrigins(fromIds, fromLats, fromLons);
        paretoFrontierCalculator.setDestinations(toIds, toLats, toLons);
        paretoFrontierCalculator.setModes(directModes, accessModes, transitModes, egressModes);
        paretoFrontierCalculator.setDepartureDateTime(date, departureTime);
        paretoFrontierCalculator.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

        RDataFrame out = paretoFrontierCalculator.run();
        this.routingProperties.reset();
        return out;
    }

    /**
     * This functions returns the Pareto frontier as raw R5 JSON (for visualization with Fareto)
     * @throws JsonProcessingException 
     */
    public String faretoJson(String fromId, double fromLat, double fromLon,
                                String toId, double toLat, double toLon,
                                String directModes, String transitModes, String accessModes, String egressModes,
                                String date, String departureTime,
                                int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException, JsonProcessingException {
        FaretoDebug calculator = new FaretoDebug(r5rThreadPool, routingProperties);
        calculator.setOrigins(new String[] {fromId}, new double[] {fromLat}, new double[] {fromLon});
        calculator.setDestinations(new String[] {toId}, new double[] {toLat}, new double[] {toLon});
        calculator.setModes(directModes, accessModes, transitModes, egressModes);
        calculator.setDepartureDateTime(date, departureTime);
        calculator.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

        calculator.run();
        this.routingProperties.reset();

        // we use the conveyal objectmapper, because it is already configured to properly serialize pareto returns
        // notably, it can handle GeoJson and names the properties the way fareto expects (camelCase rather than snake_case)
        return com.conveyal.analysis.util.JsonUtil.objectMapper.writeValueAsString(calculator.pathResults);
    }

    // --------------------------------------  ACCESSIBILITY  ----------------------------------------------

    public RDataFrame accessibility(String[] fromIds, double[] fromLats, double[] fromLons,
                                    String[] toIds, double[] toLats, double[] toLons,
                                    String[] opportunities, double[][] opportunityCounts,
                                    String decayFunction, double decayValue,
                                    String directModes, String transitModes, String accessModes, String egressModes,
                                    String date, String departureTime,
                                    int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration)
            throws ExecutionException, InterruptedException {

        AccessibilityEstimator accessibilityEstimator = new AccessibilityEstimator(this.r5rThreadPool, this.routingProperties);
        accessibilityEstimator.setOrigins(fromIds, fromLats, fromLons);
        accessibilityEstimator.setDestinations(toIds, toLats, toLons, opportunities, opportunityCounts);
        accessibilityEstimator.setDecayFunction(decayFunction, decayValue);
        accessibilityEstimator.setModes(directModes, accessModes, transitModes, egressModes);
        accessibilityEstimator.setDepartureDateTime(date, departureTime);
        accessibilityEstimator.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

        RDataFrame out = accessibilityEstimator.run();
        routingProperties.reset();
        return out;
    }

    // Test decay functions used to calculate accessibility
    public double[] testDecay(String decayFunctionName, double decayValue) {
        DecayFunction decayFunction = null;
        decayFunctionName = decayFunctionName.toUpperCase();
        if (decayFunctionName.equals("STEP")) { decayFunction = new StepDecayFunction(); }
        if (decayFunctionName.equals("EXPONENTIAL")) { decayFunction = new ExponentialDecayFunction(); }

        if (decayFunctionName.equals("FIXED_EXPONENTIAL")) {
            decayFunction = new FixedExponentialDecayFunction();
            ((FixedExponentialDecayFunction) decayFunction).decayConstant = decayValue;
        }
        if (decayFunctionName.equals("LINEAR")) {
            decayFunction = new LinearDecayFunction();
            ((LinearDecayFunction) decayFunction).widthMinutes = (int) decayValue;
        }
        if (decayFunctionName.equals("LOGISTIC")) {
            decayFunction = new LogisticDecayFunction();
            ((LogisticDecayFunction) decayFunction).standardDeviationMinutes = decayValue;
        }

        if (decayFunction != null) {
            decayFunction.prepare();
            double[] decay = new double [3600];
            for (int i = 0; i < 3600; i++) {
                decay[i] = decayFunction.computeWeight(1800, i+1);
            }
            return decay;

        } else {
            return null;
        }

    }

    // ----------------------------------  FIND SNAP POINTS  -----------------------------------------
    public RDataFrame findSnapPoints(String fromId, double fromLat, double fromLon, double radius, String mode) throws ExecutionException, InterruptedException {
        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};

        return findSnapPoints(fromIds, fromLats, fromLons, radius, mode);
    }

    public RDataFrame findSnapPoints(String[] fromId, double[] fromLat, double[] fromLon, double radius, String mode) throws ExecutionException, InterruptedException {
        SnapFinder snapFinder = new SnapFinder(r5rThreadPool, routingProperties.getTransportNetworkBase());
        snapFinder.setOrigins(fromId, fromLat, fromLon);
        snapFinder.setRadius(radius);
        snapFinder.setMode(mode);
        return snapFinder.run();
    }

    public RDataFrame getGrid(int resolution) {
        return getGrid(resolution, true);
    }

    public RDataFrame getGrid(int resolution, boolean dropGeometry) {
        Grid gridPointSet = new Grid(resolution, routingProperties.getTransportNetworkBase().getEnvelope());

        RDataFrame gridTable = new RDataFrame(gridPointSet.featureCount());
        gridTable.addStringColumn("id", "");
        gridTable.addDoubleColumn("lat", 0.0);
        gridTable.addDoubleColumn("lon", 0.0);
        if (!dropGeometry) { gridTable.addStringColumn("geometry", ""); }

        for (int index = 0; index < gridPointSet.featureCount(); index++) {
            int x = index % gridPointSet.extents.width;
            int y = index / gridPointSet.extents.width;

            gridTable.append();
            gridTable.set("id", String.valueOf(index));
            gridTable.set("lat", Grid.pixelToCenterLat(y + gridPointSet.extents.north, resolution));
            gridTable.set("lon", Grid.pixelToCenterLon(x + gridPointSet.extents.west, resolution));

            if (!dropGeometry) {
                gridTable.set("geometry", Grid.getPixelGeometry(x + gridPointSet.extents.west, y + gridPointSet.extents.north, gridPointSet.extents).toString());
            }
        }

        return gridTable;
    }

    // ------------------------------ SCENARIOS ----------------------------------------

    // Discards the scenario network and restores the default routing properties.
    // Called from R on exit of every routing function, so that nothing set for a
    // call that fails (in R or in Java) leaks into the next call.
    public void resetRoutingProperties() {
        this.routingProperties.reset();
        setCsvOutput("");
    }

    public String applyCongestionPolygon(String filePath, String scalingAttribute, String priorityAttribute, String nameAttribute, float defaultScaling){
        Path fileJPath = Paths.get(filePath).toAbsolutePath().normalize();

        RoadCongestion congestion = new RoadCongestion();
        congestion.polygonLayer = fileJPath.toString();
        congestion.scalingAttribute = scalingAttribute;
        congestion.priorityAttribute = priorityAttribute;
        congestion.nameAttribute = nameAttribute;
        congestion.defaultScaling = defaultScaling;

        congestion.resolve(routingProperties.getTransportNetworkForScenario());
        congestion.apply(routingProperties.getTransportNetworkForScenario());
        return congestion.errors.toString();
    }

    public String applyLtsPolygon(String filePath){
        Path fileJPath = Paths.get(filePath).toAbsolutePath().normalize();

        R5RShapefileLts lts = new R5RShapefileLts();
        lts.dataSourceId = FilenameUtils.removeExtension(fileJPath.toString());

        lts.resolve(routingProperties.getTransportNetworkForScenario());
        lts.apply(routingProperties.getTransportNetworkForScenario());
        return lts.errors.toString();
    }

    public String applyCongestionOsm(HashMap<Long, Float> speedMap, float defaultScaling, boolean absoluteMode){
        RoadCongestionOSM congestion = new RoadCongestionOSM();
        congestion.speedMap = speedMap;
        congestion.defaultScaling = defaultScaling;
        congestion.absoluteMode = absoluteMode;

        congestion.resolve(routingProperties.getTransportNetworkForScenario());
        congestion.apply(routingProperties.getTransportNetworkForScenario());
        return congestion.errors.toString();
    }

    public String applyLtsOsm(HashMap<Long, Integer> ltsMap){
        SetLtsOsm lts = new SetLtsOsm();
        lts.ltsMap = ltsMap;

        lts.resolve(routingProperties.getTransportNetworkForScenario());
        lts.apply(routingProperties.getTransportNetworkForScenario());
        return lts.errors.toString();
    }

    // ------------------------------ STREET AND TRANSIT NETWORKS ----------------------------------------

    public List<RDataFrame> getStreetNetwork() {
        // Convert R5's road network to Simple Features objects
        StreetNetwork streetNetwork = new StreetNetwork(routingProperties.getTransportNetwork());

        // Return a list of dataframes
        List<RDataFrame> transportNetworkList = new ArrayList<>();
        transportNetworkList.add(streetNetwork.verticesTable);
        transportNetworkList.add(streetNetwork.edgesTable);

        return transportNetworkList;
    }

    public List<RDataFrame> getTransitNetwork() {
        // Convert R5's transit network to Simple Features objects
        TransitNetwork transitNetwork = new TransitNetwork(routingProperties.getTransportNetworkBase());

        // Return a list of dataframes
        List<RDataFrame> transportNetworkList = new ArrayList<>();
        transportNetworkList.add(transitNetwork.routesTable);
        transportNetworkList.add(transitNetwork.stopsTable);

        return transportNetworkList;
    }


    // ------------------------------- FARE CALCULATOR ----------------------------------------

    public FareStructure buildFareStructure(float baseFare, String type) {
        FareStructureBuilder builder = new FareStructureBuilder(routingProperties.getTransportNetworkBase());

        type = type.toUpperCase();
        return builder.build(baseFare, type);
    }

    public String getFareStructure() {
        String json = "";

        if (this.routingProperties.fareCalculator != null) {
            json = ((RuleBasedInRoutingFareCalculator) this.routingProperties.fareCalculator).getFareStructure().toJson();
        }

        return json;
    }


    // ------------------------------- PARETO ITINERARIES ----------------------------------------

    public RDataFrame paretoItineraries(String fromId, double fromLat, double fromLon,
                                     String toId, double toLat, double toLon,
                                     String directModes, String transitModes, String accessModes, String egressModes,
                                     String date, String departureTime,
                                     int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        String[] fromIds = {fromId};
        double[] fromLats = {fromLat};
        double[] fromLons = {fromLon};

        String[] toIds = {toId};
        double[] toLats = {toLat};
        double[] toLons = {toLon};

        return paretoItineraries(fromIds, fromLats, fromLons, toIds, toLats, toLons,
                directModes, transitModes, accessModes, egressModes,
                date, departureTime, maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

    }

    public RDataFrame paretoItineraries(String[] fromIds, double[] fromLats, double[] fromLons,
                                     String[] toIds, double[] toLats, double[] toLons,
                                     String directModes, String transitModes, String accessModes, String egressModes,
                                     String date, String departureTime,
                                     int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration) throws ExecutionException, InterruptedException {

        ParetoItineraryPlanner paretoFrontierCalculator = new ParetoItineraryPlanner(this.r5rThreadPool, this.routingProperties);
        paretoFrontierCalculator.setOrigins(fromIds, fromLats, fromLons);
        paretoFrontierCalculator.setDestinations(toIds, toLats, toLons);
        paretoFrontierCalculator.setModes(directModes, accessModes, transitModes, egressModes);
        paretoFrontierCalculator.setDepartureDateTime(date, departureTime);
        paretoFrontierCalculator.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

        RDataFrame out = paretoFrontierCalculator.run();
        this.routingProperties.reset();
        return out;
    }

    // -------------------------------- GRIDDED ISOCHRONES ------------------------------------------
    public RegularGridResult[] travelTimeSurfaces (String fromIds, double fromLats, double fromLons,
                    String directModes, String transitModes, String accessModes, String egressModes,
                    String date, String departureTime,
                    int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration, int zoom)
                    throws ExecutionException, InterruptedException {
        return travelTimeSurfaces(new String[] { fromIds }, new double[] { fromLats }, new double[] { fromLons },
                    directModes, transitModes, accessModes, egressModes,
                    date, departureTime,
                   maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration, zoom);
    }

    public RegularGridResult[] travelTimeSurfaces (String[] fromIds, double[] fromLats, double[] fromLons,
                    String directModes, String transitModes, String accessModes, String egressModes,
                    String date, String departureTime,
                    int maxWalkTime, int maxBikeTime, int maxCarTime, int maxTripDuration, int zoom)
                    throws ExecutionException, InterruptedException {
        RegularGridProcess regularGridProcess = new RegularGridProcess(this.r5rThreadPool, this.routingProperties, zoom);
        regularGridProcess.setOrigins(fromIds, fromLats, fromLons);
        regularGridProcess.setModes(directModes, accessModes, transitModes, egressModes);
        regularGridProcess.setDepartureDateTime(date, departureTime);
        regularGridProcess.setTripDuration(maxWalkTime, maxBikeTime, maxCarTime, maxTripDuration);

        RegularGridResult[] out = regularGridProcess.run();
        this.routingProperties.reset();
        return out;
    }

    // --------------------------------  UTILITY FUNCTIONS  -----------------------------------------

    /** Operating dates for services referenced by retained trips. */
    public String[] getTransitServiceDates() {
        return TransitServiceDates.getDates(routingProperties.getTransportNetworkBase().transitLayer);
    }

    /** Summarize calendars in one transfer, preserving explicit date order and duplicates. */
    public RDataFrame getTransitServiceAvailability(String[] dates) {
        RDataFrame table = new RDataFrame();
        table.addStringColumn("date", "");
        table.addIntegerColumn("total_services", 0);
        table.addIntegerColumn("active_services", 0);
        table.addDoubleColumn("pct_active", 0.0);
        var services = routingProperties.getTransportNetworkBase().transitLayer.services;
        for (String dateString : dates) {
            LocalDate date = LocalDate.parse(dateString);
            int active = 0;
            for (Service service : services) {
                if (service.activeOn(date)) active++;
            }
            table.append();
            table.set("date", dateString);
            table.set("total_services", services.size());
            table.set("active_services", active);
            table.set("pct_active", services.isEmpty() ? 0.0 : (double) active / services.size());
        }
        return table;
    }

    // Returns list of public transport services active on a given date.
    public RDataFrame getTransitServicesByDate(String date) {
        RDataFrame servicesTable = new RDataFrame();
        servicesTable.addStringColumn("service_id", "");
        servicesTable.addStringColumn("start_date", "");
        servicesTable.addStringColumn("end_date", "");
        servicesTable.addBooleanColumn("active_on_date", false);

        for (Service service : routingProperties.getTransportNetworkBase().transitLayer.services) {
            servicesTable.append();
            servicesTable.set("service_id", service.service_id);

            if (service.calendar != null) {
                servicesTable.set("start_date", String.valueOf(service.calendar.start_date));
                servicesTable.set("end_date", String.valueOf(service.calendar.end_date));
            }

            servicesTable.set("active_on_date", service.activeOn(LocalDate.parse(date)));
        }

        return servicesTable;
    }

    public boolean hasFrequencies() {
        return routingProperties.getTransportNetworkBase().transitLayer.hasFrequencies;
    }

    public void abort() {
        LOG.error("process aborted");
    }

    /** Used to ensure user has passed a jobjRef to an R5R core in R. */
    public String identify(){
        return "I am an R5R core!";
    }

   /** Get the geographic envelope (bounding box) of the transport network's street layer as a primitive array. @return A double array with the coordinates in the order: [minX, maxX, minY, maxY]. */
    public double[] getNetworkEnvelopeAsArray() {
        Envelope envelope = this.routingProperties.getTransportNetworkBase().getEnvelope();
        return new double[]{
            envelope.getMinX(),
            envelope.getMaxX(),
            envelope.getMinY(),
            envelope.getMaxY()
        };
    }
}
