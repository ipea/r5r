package org.ipea.r5r.Utils;

import ch.qos.logback.classic.LoggerContext;
import com.conveyal.osmlib.OSM;
import com.conveyal.osmlib.Way;
import com.conveyal.r5.point_to_point.builder.SpeedConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.measure.UnitConverter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import static com.conveyal.r5.point_to_point.builder.SpeedUnit.MPH;
import static systems.uom.common.USCustomary.MILE_PER_HOUR;
import static tech.units.indriya.unit.Units.KILOMETRE_PER_HOUR;

/**
 * The {@code SpeedSetter} class provides a method for modifying roadspeed tags from an OSM PBF.
 * It applies maxspeed:motorcar tags based on the desired speeds given in a CSV and writes out a new PBF in an output
 * directory.
 * <p>
 * This class is designed to:
 * <ul>
 *   <li>Load a CSV mapping of OSM way IDs to speed values (either absolute speeds or percentage adjustments).</li>
 *   <li>Update OSM ways by modifying their {@code maxspeed:motorcar} tags according to the CSV, using either absolute values or percentage multipliers.</li>
 *   <li>Fallback on default highway type speeds or a user-defined default when necessary.</li>
 *   <li>Write out a new, modified OSM PBF file to the specified output directory.</li>
 * </ul>
 * <p>
 * The class supports two modes for applying speeds:
 * <ul>
 *   <li><b>ABSOLUTE:</b> Sets the specified speed as the new speed for the way.</li>
 *   <li><b>PERCENTAGE:</b> Multiplies the existing speed value by the given percentage (useful for congestion scenarios or scaling base speeds).</li>
 * </ul>
 */
public class SpeedSetter {

    private static final Logger LOG = LoggerFactory.getLogger(SpeedSetter.class);

    public enum SpeedSetterMode {
        ABSOLUTE, PERCENTAGE
    }

    private final Path outputFilePath;
    private float defaultValue = 1;
    private final OSM osmRoadNetwork;
    private final HashMap<Long, Float> speedMap;
    private SpeedSetterMode mode = SpeedSetterMode.PERCENTAGE;
    private float defaultSpeedForNoHwyTag;
    private final HashMap<String, Float> highwayDefaultSpeedMap;

    /**
     * Prepares data for manipulation does not modify any files.
     *
     * @param pbfFile      Absolute path to the pbf file
     * @param speedMap     A HashMap with key [osm_id] and value [max_speed]
     * @param outputFolder Absolute path to the output folder to save the modified PBF
     * @param verbose      If true, enables verbose logging; otherwise, logs only errors
     * @throws IOException If any of the input files or the output folder are not found or accessible
     */
    public SpeedSetter(String pbfFile, HashMap<Long, Float> speedMap, String outputFolder, boolean verbose) throws IOException {
        LoggerContext loggerContext = (LoggerContext) LoggerFactory.getILoggerFactory();
        ch.qos.logback.classic.Logger speedSetterLogger = loggerContext.getLogger("org.ipea.r5r.Utils.SpeedSetter");
        ch.qos.logback.classic.Logger osmLogger = loggerContext.getLogger("com.conveyal.osmlib");

        if (verbose) {
            Utils.setLogModeOther("INFO");
            Utils.setLogModeJar("INFO");
        } else {
            Utils.setLogModeOther("OFF");
            Utils.setLogModeJar("WARN");
        }

        // Build paths
        Path outputFolderPath = Paths.get(outputFolder);
        if (!Files.exists(outputFolderPath) || !Files.isDirectory(outputFolderPath)) {
            LOG.error("Output folder does not exist or is not a directory: {}", outputFolder);
            throw new IOException("Output folder does not exist or is not a directory: " + outputFolder);
        }

        Path pbfFilePath = Paths.get(pbfFile);
        if (!Files.exists(pbfFilePath)) {
            LOG.error("PBF file not found: {}", pbfFilePath.toAbsolutePath());
            throw new IOException("Speeds CSV not found: " + pbfFilePath.toAbsolutePath());
        }

        outputFilePath = createOutputFilePath(pbfFilePath, outputFolderPath);
        // finished building paths

        // Load OSM
        osmRoadNetwork = OSM.newWritableTempFile();
        osmRoadNetwork.readFromFile(pbfFilePath.toAbsolutePath().toString());
        LOG.info("Loaded OSM network from file {}", pbfFilePath.getFileName());

        // Load CSV into a Map
        this.speedMap = speedMap;
        LOG.info("Loaded desired road speeds from table.");

        highwayDefaultSpeedMap = createHighwayDefaultSpeedMap();
    }

    /**
     * Sets the default value to use for speed when no value is found in the CSV.
     */
    public void setDefaultValue(float defaultValue) {
        this.defaultValue = defaultValue;
    }

    /**
     * This is the method you should call from R
     */
    public void runSpeedSetter() {
        LOG.info("Setting maxspeed:motorcar tags in {} mode", mode);

        // Apply speeds to all ways
        modifyWaySpeeds();

        // Write to new PBF file
        osmRoadNetwork.writeToFile(outputFilePath.toAbsolutePath().toString());
        LOG.info("Wrote modified OSM file to: {}", outputFilePath.toAbsolutePath());
    }

    /**
     * Creates a path for the output file based on the names of the original PBF and CSV files.
     *
     * @return Path to the new output PBF file
     */
    private Path createOutputFilePath(Path pbfFilePath, Path outputFolderPath) {
        String originalPbfName = pbfFilePath.getFileName().toString();
        String newFileName = "congested-" + originalPbfName;
        return outputFolderPath.resolve(newFileName);
    }

    public void setPercentageMode(boolean modePercentage) {
        mode = modePercentage ? SpeedSetterMode.PERCENTAGE : SpeedSetterMode.ABSOLUTE;
    }

    /**
        Verify that the OSM ids are real
     */
    public String verifySpeedMap() {
        ArrayList<Long> badIds = new ArrayList<>();
        for (Long potentialWayId : speedMap.keySet()) {
            Way way = osmRoadNetwork.ways.get(potentialWayId);
            if (way == null) {
                badIds.add(potentialWayId);
            }
        }
        return badIds.toString();
    }


    private void modifyWaySpeeds() {
        for (Map.Entry<Long, Way> entry : osmRoadNetwork.ways.entrySet()) {
            long wayId = entry.getKey();
            Way way = entry.getValue();

            float speedKph;
            Float value = speedMap.getOrDefault(wayId, defaultValue);

            if (value == 1) continue;   // default value of 1 is no change, even in ABSOLUTE mode
            else if (value == 0) {      // disable road if speed is 0
                way.addOrReplaceTag("highway", "construction");
                continue;
            }

            if (mode == SpeedSetterMode.ABSOLUTE) {
                speedKph = value;
            } else {
                // PERCENTAGE mode: apply multiplier to existing maxspeed tag
                // fallback on highway type of no such tag exists
                String existingSpeed = way.getTag("maxspeed");
                if (existingSpeed == null) {
                    LOG.debug("Way id: {} has no maxspeed tag, falling back on highway defaults", wayId);
                    if (way.getTag("highway") != null) {
                        String highwayType = way.getTag("highway").toLowerCase().trim();
                        existingSpeed = String.valueOf(highwayDefaultSpeedMap.getOrDefault(highwayType, defaultSpeedForNoHwyTag));
                    } else {
                        existingSpeed = String.valueOf(defaultSpeedForNoHwyTag);
                    }
                }
                try {
                    float base = Float.parseFloat(existingSpeed);
                    speedKph = base * value;
                } catch (NumberFormatException nfe) {
                    LOG.warn("Cannot parse existing maxspeed='{}' for way {}, skipping", existingSpeed, wayId);
                    continue;
                }
            }

            way.addOrReplaceTag("maxspeed:motorcar", String.format("%1.1f kph", speedKph));
        }
    }

    private HashMap<String, Float> createHighwayDefaultSpeedMap() {
        SpeedConfig speedConfig = SpeedConfig.defaultConfig();
        HashMap<String, Float> highwaySpeedMap = new HashMap<>(speedConfig.values.size() + 1);
        if (speedConfig.units != MPH) {
            LOG.error("speedConfig is expected to be in MPH. Something has changed; skipping without generating a default highwaySpeedMap.");
            defaultSpeedForNoHwyTag = 40;
            return highwaySpeedMap;
        }
        UnitConverter unitConverter = MILE_PER_HOUR.getConverterTo(KILOMETRE_PER_HOUR);
        for (Map.Entry<String, Integer> highwaySpeed : speedConfig.values.entrySet()) {
            highwaySpeedMap.put(highwaySpeed.getKey(), unitConverter.convert(highwaySpeed.getValue()).floatValue());
        }
        defaultSpeedForNoHwyTag = (float) unitConverter.convert(speedConfig.defaultSpeed);
        return highwaySpeedMap;
    }
}
