package org.ipea.r5r.Process;

import com.conveyal.r5.OneOriginResult;
import com.conveyal.r5.analyst.TravelTimeComputer;
import com.conveyal.r5.analyst.cluster.RegionalTask;
import com.conveyal.r5.transit.TransportNetwork;
import org.ipea.r5r.R5.R5TravelTimeComputer;
import org.ipea.r5r.RDataFrame;
import org.ipea.r5r.RoutingProperties;

import java.text.ParseException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ForkJoinPool;

public class ParetoFrontierCalculator  extends R5DataFrameProcess {

    @Override
    protected boolean isOneToOne() {
        return false;
    }

    public ParetoFrontierCalculator(ForkJoinPool threadPool, RoutingProperties routingProperties) {
        super(threadPool, routingProperties);
    }

    @Override
    protected RDataFrame runProcess(int index) throws ParseException {
        RegionalTask request = buildRegionalTask(index);
        TravelTimeComputer computer = new R5TravelTimeComputer(request, transportNetwork, routingProperties.monteCarloSeed);

        Map<Float, OneOriginResult> travelTimeResults = new HashMap<>();

        for (float fareCutoff : this.routingProperties.fareCutoffs) {
            request.maxFare = (fareCutoff >= 0) ? Math.round(fareCutoff * 100.0f) : Integer.MAX_VALUE;
            OneOriginResult results = computer.computeTravelTimes();
            travelTimeResults.put(fareCutoff, results);
        }

        RDataFrame travelTimesTable = buildDataFrameStructure(fromIds[index], 10);
        populateDataFrame(travelTimeResults, travelTimesTable);

        if (travelTimesTable.nRow() > 0) {
            return travelTimesTable;
        } else {
            return null;
        }
    }

    @Override
    protected RDataFrame buildDataFrameStructure(String fromId, int nRows) {
        // Build return table
        RDataFrame travelTimesTable = new RDataFrame(nRows);
        travelTimesTable.addStringColumn("from_id", fromId);
        travelTimesTable.addStringColumn("to_id", "");
        travelTimesTable.addIntegerColumn("percentile", 0);
        travelTimesTable.addIntegerColumn("travel_time", 0);
        travelTimesTable.addDoubleColumn("monetary_cost", 0.0);

        return travelTimesTable;
    }

    private void populateDataFrame(Map<Float, OneOriginResult> travelTimeResults, RDataFrame travelTimesTable) {
        for (int destination = 0; destination < this.nDestinations; destination++) {
            for (int percentileIndex = 0; percentileIndex < this.routingProperties.percentiles.length; percentileIndex++) {

                boolean first = true;
                int previousTT = -1;
                for (float fare : this.routingProperties.fareCutoffs) {
                    OneOriginResult travelTimesByFare = travelTimeResults.get(fare);
                    int tt = travelTimesByFare.travelTimes.getValues()[percentileIndex][destination];

                    if (tt != previousTT & tt < maxTripDuration) {
                        if (first) {
                            // add new row to data frame
                            travelTimesTable.append();

                            // set destination id
                            travelTimesTable.set("to_id", toIds[destination]);
                            travelTimesTable.set("percentile", this.routingProperties.percentiles[percentileIndex]);
                        }
                        else {
                            travelTimesTable.appendRepeat();
                        }
                        travelTimesTable.set("monetary_cost", (double) fare);
                        travelTimesTable.set("travel_time", tt);

                        previousTT = tt;
                        first = false;
                    }
                }
            }
        }

    }

    @Override
    protected RegionalTask buildRegionalTask(int index) throws ParseException {
        RegionalTask request = super.buildRegionalTask(index);

        request.destinationPointSetKeys = this.opportunities;
        request.destinationPointSets = destinationPoints;

        return request;
    }

}
