package org.ipea.r5r.Network;

import com.conveyal.analysis.datasource.DataSourceException;
import com.conveyal.gtfs.GTFSFeed;
import com.conveyal.gtfs.error.GTFSError;
import com.conveyal.gtfs.validator.PostLoadValidator;
import com.conveyal.gtfs.validator.model.Priority;
import com.conveyal.osmlib.OSM;
import com.conveyal.r5.analyst.scenario.RasterCost;
import com.conveyal.r5.kryo.KryoNetworkSerializer;
import com.conveyal.r5.streets.StreetLayer;
import com.conveyal.r5.transit.TransferFinder;
import com.conveyal.r5.transit.TransitLayer;
import com.conveyal.r5.transit.TransportNetwork;
import com.conveyal.r5.transit.GtfsTransferLoader;
import com.conveyal.r5.analyst.cluster.TransportNetworkConfig.TransferConfig;
import org.apache.commons.io.FilenameUtils;
import org.ipea.r5r.R5RCore;
import org.ipea.r5r.RDataFrame;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.zip.ZipFile;
import java.nio.file.Files;
import java.nio.file.Path;

public class NetworkBuilder {

    public boolean useNativeElevation = false;
    public String elevationCostFunction = "NONE";

    private List<String> gtfsFiles = new ArrayList<>();
    private String osmFilename;

    private OSM osmFile;
    private Stream<GTFSFeed> gtfsFeeds;
    private String tiffFile = "";

    public RDataFrame gtfsErrors = null;

    public boolean highPriorityErrors = false;

    public TransportNetwork checkAndLoadR5Network(String dataFolder) throws Exception {
        File file = new File(dataFolder, "network.dat");
        if (!file.isFile()) {
            // network.dat file does not exist. create!
            createR5Network(dataFolder);
        } else {
            // network.dat file exists
            // check version
            if (!NetworkChecker.checkR5NetworkVersion(dataFolder)) {
                // incompatible versions. try to create a new one
                // network could not be loaded, probably due to incompatible versions. create a new one
                createR5Network(dataFolder);
            }
        }
        // compatible versions, load network
        // if there were high priority errors, though, don't return network - don't even tempt someone to use it.
        return highPriorityErrors ? null : loadR5Network(dataFolder);
    }

    public TransportNetwork loadR5Network(String dataFolder) throws Exception {
        return KryoNetworkSerializer.read(new File(dataFolder, "network.dat"));
    }

    public void createR5Network(String dataFolder) {
        File dir = new File(dataFolder);

        cleanUpMapdb(dir);

        loadDirectory(dir);

        TransportNetwork tn = createNetwork();

        Map<String, String> networkConfig = buildNetworkConfig();

        try {
            // if there were high priority errors, network is unusable. Don't even serialize it as that might tempt someone
            // to use it.
            if (!highPriorityErrors) {
                KryoNetworkSerializer.write(tn, new File(dataFolder, "network.dat"));
                writeNetworkSettings(dataFolder, networkConfig);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void writeNetworkSettings(String dataFolder, Map<String, String> networkConfig) throws IOException {
        String json = "{" + networkConfig.entrySet().stream()
                .map(e -> "\""+ e.getKey() + "\":\"" + e.getValue() + "\"")
                .collect(Collectors.joining(", "))+"}";

        FileWriter fileWriter = new FileWriter(new File(dataFolder, "network_settings.json"));
        PrintWriter printWriter = new PrintWriter(fileWriter);
        printWriter.print(json);
        printWriter.close();
    }

    private Map<String, String> buildNetworkConfig() {
        Map<String, String> networkConfig = new LinkedHashMap<>();

        networkConfig.put("r5_version", R5RCore.R5_VERSION);
        networkConfig.put("r5_network_version", KryoNetworkSerializer.NETWORK_FORMAT_VERSION);
        networkConfig.put("r5r_version", R5RCore.R5R_VERSION);
        networkConfig.put("creation_date", LocalDateTime.now().toString());

        networkConfig.put("pbf_file_name", osmFilename);

        for (int i = 0; i < gtfsFiles.size(); i++) {
            networkConfig.put("gtfs_" + (i + 1), gtfsFiles.get(i));
        }

        networkConfig.put("use_elevation", String.valueOf(useNativeElevation));
        networkConfig.put("elevation_cost_function", elevationCostFunction);
        networkConfig.put("tiff_file_name", tiffFile);

        return networkConfig;
    }

    private TransportNetwork createNetwork() {
        TransportNetwork network = new TransportNetwork();

        network.scenarioId = "r5r";
        network.streetLayer = new StreetLayer();
        network.streetLayer.loadFromOsm(osmFile);
        osmFile.close();

        network.streetLayer.parentNetwork = network;
        network.streetLayer.indexStreets();

        network.transitLayer = new TransitLayer();
        // this replaces the old r5r TransitLayerWithShapes class; saving shapes now built in to r5.
        network.transitLayer.saveShapes = true;

        // Options here are OSM_ONLY (only use OSM data to find transfers, consistent with r5r versions
        // up to 2.3.0), STOP_TO_PATTERN (only use OSM data to find transfers to stops served by patterns
        // that do not have a stop with an explicit transfer from the source stop), STOP_TO_STOP (use OSM
        // to find transfers for all stop pairs that don't have an explicit GTFS transfer), and GTFS_ONLY
        // (use only transfers specified in GTFS, almost never appropriate).
        GtfsTransferLoader transferLoader = new GtfsTransferLoader(network.transitLayer, TransferConfig.OSM_ONLY);

        gtfsFeeds.forEach(gtfsFeed -> {
            network.transitLayer.loadFromGtfs(gtfsFeed, transferLoader);
            // Is there a reason we can't push this close call down into the loader method? Maybe exception handling?
            gtfsFeed.close();
        });

        transferLoader.logErrors();

        network.transitLayer.parentNetwork = network;
        network.streetLayer.associateStops(network.transitLayer);
        network.streetLayer.buildEdgeLists();

        network.rebuildTransientIndexes();

        TransferFinder transferFinder = new TransferFinder(network, transferLoader);
        transferFinder.findTransfers();
        transferFinder.findParkRideTransfer();

        // apply elevation costs if a tiff file is available
        try
        {
            if (useNativeElevation) {
                if (!tiffFile.equals("")) {
                    RasterCost elevationRaster = new RasterCost();
                    elevationRaster.dataSourceId = FilenameUtils.removeExtension(tiffFile);
                    elevationRaster.costFunction = RasterCost.CostFunction.valueOf(elevationCostFunction);

                    elevationRaster.resolve(network);
                    elevationRaster.apply(network);

                }
            }
        } catch (DataSourceException e) {
            e.printStackTrace();
            throw new RuntimeException(e);
        }

        network.scenarioId = "r5r";

        // Networks created in TransportNetworkCache are going to be used for analysis work. Pre-compute distance tables
        // from stops to street vertices, then pre-build a linked grid point set for the whole region. These linkages
        // should be serialized along with the network, which avoids building them when an analysis worker starts.
        // The linkage we create here will never be used directly, but serves as a basis for scenario linkages, making
        // analysis much faster to start up.
        network.transitLayer.buildDistanceTables(null);

        // pre-calculate transfers between transit stops
        // TODO mwbc: why is this happening again? It does not happen twice in the R5
        // TransportNetworkCache#buildNetworkFromConfig. I don't want to remove it though due to
        // https://github.com/conveyal/r5/issues/991. Maybe we should just move the entire transfer
        // finding process here?
        new TransferFinder(network, transferLoader).findTransfers();

        return network;
    }

    public void loadDirectory(File directory) {
        osmFilename = "";
        tiffFile = "";
        gtfsFiles.clear();

        for (File file : Objects.requireNonNull(directory.listFiles())) {
            String name = file.getName();

            if (name.endsWith(".pbf")) {
                osmFilename = file.getAbsolutePath();

                // Load OSM data into MapDB to pass into network builder.
                osmFile = OSM.openOrCreateFile(new File(osmFilename + ".mapdb"), osmFilename);
            }
            if (name.endsWith(".zip")) gtfsFiles.add(file.getAbsolutePath());
            if (name.endsWith(".tif") | name.endsWith(".tiff")) tiffFile = file.getAbsolutePath();
        }

        initializeGtfsErrors();

        // Supply feeds with a stream, so they do not sit open in memory while other feeds are being processed.
        gtfsFeeds = gtfsFiles.stream().map(this::readFeed);
    }

    // read a feed and store errors
    // We can't just use the R5 readOnlyTempFileFromGtfs, because then the errors get lost before
    // we have access to the object.
    private GTFSFeed readFeed (String feedFile) {
        try {
            // we use a directory to make sure that all sidecar files get deleted on exit
            File tempDir = Files.createTempDirectory("gtfs").toFile();
            File dbFile = new File(tempDir, "gtfs.db");
            File dbpFile = new File(tempDir, "gtfs.db.p");

            GTFSFeed feed = GTFSFeed.newWritableFile(dbFile);
            feed.loadFromFile(new ZipFile(feedFile), null);

            // add additional errors
            new PostLoadValidator(feed).validate();

            // parse errors
            parseGtfsErrors(feed);

            feed.close();

            // clean up
            // has to be done first, deleteOnExit deletes in reverse order and directories must be empty
            tempDir.deleteOnExit();
            dbFile.deleteOnExit();
            dbpFile.deleteOnExit();

            // re-open read only (this loses the errors, see the example in R5 BundleController.java)
            return GTFSFeed.reopenReadOnly(dbFile);
        } catch (Exception e) {
            // re-throw as unchecked
            throw new RuntimeException("Error while processing " + feedFile, e);
        }
    }

    private void initializeGtfsErrors() {
        gtfsErrors = new RDataFrame();
        gtfsErrors.addStringColumn("file", "");
        // It's a long on the Java side
        gtfsErrors.addIntegerColumn("line", -1);
        gtfsErrors.addStringColumn("type", "");
        gtfsErrors.addStringColumn("field", "");
        gtfsErrors.addStringColumn("id", "");
        gtfsErrors.addStringColumn("priority", "");
    }

    private void parseGtfsErrors(GTFSFeed feed) {
        for (GTFSError error : feed.errors) {
            gtfsErrors.append();
            gtfsErrors.set("file", error.file);
            gtfsErrors.set("line", (int) error.line);
            gtfsErrors.set("type", error.errorType);
            gtfsErrors.set("field", error.field);
            gtfsErrors.set("id", error.affectedEntityId);
            gtfsErrors.set("priority", error.getPriority().name());

            if (error.getPriority() == Priority.HIGH) {
                highPriorityErrors = true;
            }
        }
    }

    private void cleanUpMapdb(File dir) {
        // clean up older mapdb files
        File[] mapdbFiles = dir.listFiles((d, name) -> name.contains(".mapdb"));

        if (mapdbFiles != null) { for (File file:mapdbFiles) file.delete(); }
    }


}
