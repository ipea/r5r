package org.ipea.r5r.Process;

import com.conveyal.r5.OneOriginResult;
import com.conveyal.r5.analyst.TravelTimeComputer;
import com.conveyal.r5.analyst.cluster.RegionalTask;
import com.conveyal.r5.analyst.decay.*;
import com.conveyal.r5.transit.TransportNetwork;
import org.ipea.r5r.R5.R5TravelTimeComputer;
import org.ipea.r5r.RDataFrame;
import org.ipea.r5r.RoutingProperties;

import java.lang.reflect.Field;
import java.text.ParseException;
import java.util.concurrent.ForkJoinPool;

public class AccessibilityEstimator extends R5DataFrameProcess {

    private DecayFunction decayFunction;

    public void setDecayFunction(String decayFunction, double decayValue) {
        decayFunction = decayFunction.toUpperCase();
        if (decayFunction.equals("STEP")) { this.decayFunction = new StepDecayFunction(); }
        if (decayFunction.equals("EXPONENTIAL")) { this.decayFunction = new ExponentialDecayFunction(); }

        if (decayFunction.equals("FIXED_EXPONENTIAL")) {
            this.decayFunction = new FixedExponentialDecayFunction();
            ((FixedExponentialDecayFunction) this.decayFunction).decayConstant = decayValue;
        }
        if (decayFunction.equals("LINEAR")) {
            this.decayFunction = new LinearDecayFunction();
            ((LinearDecayFunction) this.decayFunction).widthMinutes = (int) decayValue;
        }
        if (decayFunction.equals("LOGISTIC")) {
            this.decayFunction = new LogisticDecayFunction();
            ((LogisticDecayFunction) this.decayFunction).standardDeviationMinutes = decayValue;
        }
        this.decayFunction.prepare();
    }

    @Override
    protected boolean isOneToOne() {
        return false;
    }

    public AccessibilityEstimator(ForkJoinPool threadPool, RoutingProperties routingProperties) {
        super(threadPool, routingProperties);
    }

    @Override
    protected RDataFrame runProcess(int index) throws ParseException {
        RegionalTask request = buildRegionalTask(index);

        TravelTimeComputer computer = new R5TravelTimeComputer(request, transportNetwork, routingProperties.monteCarloSeed);
        OneOriginResult travelTimeResults = computer.computeTravelTimes();
        RDataFrame travelTimesTable = buildDataFrameStructure(fromIds[index], 10);
        populateDataFrame(travelTimeResults, travelTimesTable);

        if (travelTimesTable.nRow() > 0) {
            return travelTimesTable;
        } else {
            return null;
        }
    }

    private void populateDataFrame(OneOriginResult travelTimeResults, RDataFrame travelTimesTable) {
        // Create Field object
        Field privateField = null;
        try {
            privateField = travelTimeResults.accessibility.getClass().getDeclaredField("cumulativeOpportunities");

            // Set the accessibility as true
            privateField.setAccessible(true);

            double[][][] accessibility = (double[][][]) privateField.get(travelTimeResults.accessibility);

            int nOpportunities = this.opportunities.length;
            int nPercentiles = routingProperties.percentiles.length;
            int nCutoffs = routingProperties.cutoffs.length;

            for (int o = 0; o < nOpportunities; o++) {
                for (int p = 0; p < nPercentiles; p++) {
                    for (int c = 0; c < nCutoffs; c++) {
                        travelTimesTable.append();
                        travelTimesTable.set("opportunity", this.opportunities[o]);
                        travelTimesTable.set("percentile", routingProperties.percentiles[p]);
                        travelTimesTable.set("cutoff", routingProperties.cutoffs[c]);
                        travelTimesTable.set("accessibility", accessibility[o][p][c]);
                    }
                }
            }
        } catch (NoSuchFieldException | IllegalAccessException e) {
            e.printStackTrace();
        }
    }

    @Override
    protected RDataFrame buildDataFrameStructure(String fromId, int nRows) {
        // Build return table
        RDataFrame travelTimesTable = new RDataFrame(nRows);
        travelTimesTable.addStringColumn("id", fromId);
        travelTimesTable.addStringColumn("opportunity", "");
        travelTimesTable.addIntegerColumn("percentile", 0);
        travelTimesTable.addIntegerColumn("cutoff", 0);
        travelTimesTable.addDoubleColumn("accessibility", 0.0);

        return travelTimesTable;
    }

    @Override
    protected RegionalTask buildRegionalTask(int index) throws ParseException {
        RegionalTask request = super.buildRegionalTask(index);

        request.destinationPointSetKeys = this.opportunities;
        request.destinationPointSets = this.destinationPoints;

        request.percentiles = this.routingProperties.percentiles;
        request.recordAccessibility = true;
        request.recordTimes = false;
        request.includePathResults = false;
        request.decayFunction = this.decayFunction;

        request.cutoffsMinutes = routingProperties.cutoffs;

        return request;
    }

}
