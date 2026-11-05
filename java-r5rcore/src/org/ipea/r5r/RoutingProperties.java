package org.ipea.r5r;

import com.conveyal.r5.analyst.cluster.PathResult;
import com.conveyal.r5.analyst.fare.*;
import com.conveyal.r5.analyst.scenario.Scenario;
import com.conveyal.r5.api.util.SearchType;
import com.conveyal.r5.transit.TransitLayer;
import com.conveyal.r5.transit.TransportNetwork;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.core.JsonProcessingException;
import org.ipea.r5r.Fares.RuleBasedInRoutingFareCalculator;
import org.ipea.r5r.Process.R5Process;
import org.ipea.r5r.Scenario.DummyScenario;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.ipea.r5r.JsonUtil.OBJECT_MAPPER;


public class RoutingProperties {
    private static final Logger LOG = LoggerFactory.getLogger(RoutingProperties.class);

    public static final float DEFAULT_WALK_SPEED = 1.0f;
    public static final float DEFAULT_BIKE_SPEED = 3.3f;
    public static final int DEFAULT_MAX_RIDES = 3;
    public static final int DEFAULT_MAX_LEVEL_TRAFFIC_STRESS = 2;
    public static final int DEFAULT_SUBOPTIMAL_MINUTES = 0;
    public static final int DEFAULT_TIME_WINDOW_SIZE = 10;
    public static final int DEFAULT_NUMBER_OF_MONTE_CARLO_DRAWS = 50;
    public static final float DEFAULT_MAX_FARE = -1.0f;
    public static final int[] DEFAULT_PERCENTILES = {50};
    public static final int[] DEFAULT_CUTOFFS = {30};
    public static final float[] DEFAULT_FARE_CUTOFFS = {-1.0f};
    public double walkSpeed = DEFAULT_WALK_SPEED;
    public double bikeSpeed = DEFAULT_BIKE_SPEED;
    public int maxRides = DEFAULT_MAX_RIDES; // max 8 number of rides in public transport trips
    public int maxLevelTrafficStress = DEFAULT_MAX_LEVEL_TRAFFIC_STRESS;
    public int suboptimalMinutes = DEFAULT_SUBOPTIMAL_MINUTES; // Suboptimal minutes in point-to-point queries
    public int timeWindowSize = DEFAULT_TIME_WINDOW_SIZE; // minutes
    public int numberOfMonteCarloDraws = DEFAULT_NUMBER_OF_MONTE_CARLO_DRAWS; //
    public Integer monteCarloSeed = null; // null: R5's unseeded frequency offsets
    public int[] percentiles = DEFAULT_PERCENTILES;
    public int[] cutoffs = DEFAULT_CUTOFFS;
    public boolean travelTimesBreakdown = false;
    public boolean expandedTravelTimes = false;
    public boolean fastRaptor = false; // detailed_itineraries(), shortest path without fares: FastRaptorWorker, not McRAPTOR
    public boolean fastRaptorPerOrigin = false; // all_to_all: one FastRaptor search per origin, shared by its pairs
    public PathResult.Stat travelTimesBreakdownStat = PathResult.Stat.MEAN;

    public float maxFare = DEFAULT_MAX_FARE;
    public float[] fareCutoffs = DEFAULT_FARE_CUTOFFS;
    public InRoutingFareCalculator fareCalculator = null;
    public TransitLayer transitLayer;
    public SearchType searchType = SearchType.DEPART_FROM;
    private final TransportNetwork transportNetworkBase;
    private TransportNetwork transportNetworkWorking;
    private final Scenario dummyScenario = new DummyScenario();
    boolean scenarioApplied = false;

    public void setFareCalculatorJson(String fareCalculatorJson) {
        // first, check to see if this is a built-in R5 fare calculator JSON representation
        try {
            ObjectNode node = OBJECT_MAPPER.readValue(fareCalculatorJson, ObjectNode.class);
            // https://stackoverflow.com/questions/26190851
            if (node.has("type")) {
                this.fareCalculator = OBJECT_MAPPER.readValue(fareCalculatorJson, InRoutingFareCalculator.class);
            } else {
                this.fareCalculator = new RuleBasedInRoutingFareCalculator(transitLayer, fareCalculatorJson);
            }
        } catch (JsonProcessingException e) {
            throw new RuntimeException(e);
        }

    }

    public RoutingProperties(TransportNetwork network) {
        transportNetworkBase = network;
        transportNetworkWorking = null;
        transitLayer = network.transitLayer;
    }

    public void reset() {
        walkSpeed = DEFAULT_WALK_SPEED;
        bikeSpeed = DEFAULT_BIKE_SPEED;

        maxRides = DEFAULT_MAX_RIDES;
        maxLevelTrafficStress = DEFAULT_MAX_LEVEL_TRAFFIC_STRESS;
        suboptimalMinutes = DEFAULT_SUBOPTIMAL_MINUTES;
        timeWindowSize = DEFAULT_TIME_WINDOW_SIZE;
        numberOfMonteCarloDraws = DEFAULT_NUMBER_OF_MONTE_CARLO_DRAWS;
        monteCarloSeed = null;

        travelTimesBreakdown = false;
        travelTimesBreakdownStat = PathResult.Stat.MEAN;
        expandedTravelTimes = false;
        fastRaptor = false;
        fastRaptorPerOrigin = false;

        percentiles = DEFAULT_PERCENTILES;
        cutoffs = DEFAULT_CUTOFFS;
        fareCutoffs = DEFAULT_FARE_CUTOFFS;

        maxFare = DEFAULT_MAX_FARE;
        fareCalculator = null;
        searchType = SearchType.DEPART_FROM;
        transportNetworkWorking = null;
        scenarioApplied = false;
        // do not reset transitLayer
    }

    public TransportNetwork getTransportNetworkForScenario() {
        scenarioApplied = true;
        if (transportNetworkWorking == null) transportNetworkWorking = transportNetworkBase.scenarioCopy(dummyScenario);
        return transportNetworkWorking;
    }

    public TransportNetwork getTransportNetworkBase(){ return transportNetworkBase; }

    public TransportNetwork getTransportNetwork(){
        if (scenarioApplied){
            LOG.warn("A scenario has been applied. Unfortunately elevation data will be lost from the network. See issue #555.");
            return transportNetworkWorking;
        } else return transportNetworkBase;
    }
}
