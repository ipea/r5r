package org.ipea.r5r.Process;

import org.ipea.r5r.RDataFrame;
import org.ipea.r5r.RoutingProperties;
import org.ipea.r5r.Utils.Utils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ForkJoinPool;

import static java.lang.Math.max;

public abstract class R5DataFrameProcess extends R5Process<RDataFrame, RDataFrame> {

    public R5DataFrameProcess(ForkJoinPool threadPool, RoutingProperties routingProperties) {
        super(threadPool, routingProperties);
    }

    private static final Logger LOG = LoggerFactory.getLogger(R5DataFrameProcess.class);

    protected abstract boolean isOneToOne();

    @Override
    protected RDataFrame mergeResults (List<RDataFrame> processResults) {
        LOG.info("Consolidating results...");

        int nRows;
        nRows = processResults.stream()
                .mapToInt(RDataFrame::nRow)
                .sum();

        RDataFrame mergedDataFrame = buildDataFrameStructure("", nRows);
        if (Utils.benchmark) {
            mergedDataFrame.addLongColumn("execution_time", 0L);
        }

        mergedDataFrame.getDataFrame().keySet().stream().parallel().forEach(
                key -> {
                    ArrayList<Object> destinationArray = mergedDataFrame.getDataFrame().get(key);
                    processResults.forEach(
                            dataFrame -> {
                                ArrayList<Object> originArray = dataFrame.getDataFrame().get(key);
                                destinationArray.addAll(originArray);

                                originArray.clear();
                            });
                }
        );
        mergedDataFrame.updateRowCount();

        LOG.info(" DONE!");

        return mergedDataFrame;
    }

    protected abstract RDataFrame buildDataFrameStructure(String fromId, int nRows);

    // we override this here so we can handle benchmarking and saving output to CSV
    @Override
    protected RDataFrame tryRunProcess(int index) {
        if (cancelled) return null;
        RDataFrame results = null;
        try {
            long start = System.currentTimeMillis();
            results = runProcess(index);
            long duration = max(System.currentTimeMillis() - start, 0L);

            if (results != null & Utils.benchmark) {
                results.addLongColumn("execution_time", duration);
            }

            if (Utils.saveOutputToCsv & results != null) {
                String filename = getCsvFilename(index);
                results.saveToCsv(filename);
                results.clear();
            }

            int nProcessed = totalProcessed.getAndIncrement();
            if (isProgressStep(nProcessed)) {
                LOG.info("{} out of {} origins processed.", nProcessed, nOrigins);
            }
        } catch (Exception e) {
            e.printStackTrace();
            // re-throw as unchecked so we get an error on the R side
            throw new RuntimeException(e);
        }

        return Utils.saveOutputToCsv ? null : results;
    }

    private String getCsvFilename(int index) {
        String filename;
        if (this.isOneToOne()) {
            // one-to-one functions, such as detailed itineraries
            // save one file per origin-destination pair
            filename = Utils.outputCsvFolder + "/from_" + fromIds[index] + "_to_" + toIds[index] +  ".csv";
        } else {
            // one-to-many functions, such as travel time matrix
            // save one file per origin
            filename = Utils.outputCsvFolder + "/from_" + fromIds[index] +  ".csv";
        }
        return filename;
    }
}
