package org.ipea.r5r.Utils;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.LoggerContext;
import com.conveyal.r5.api.util.LegMode;
import com.conveyal.r5.api.util.TransitModes;
import com.conveyal.r5.common.GeometryUtils;
import org.ipea.r5r.Process.R5DataFrameProcess;
import org.ipea.r5r.Process.R5Process;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.LineString;
import org.slf4j.LoggerFactory;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.EnumSet;

public class Utils {

    static public volatile Level logLevel = Level.INFO;
    static public boolean benchmark = false;
    static public boolean progress = true;

    static public boolean detailedItinerariesV2 = true;

    static public boolean saveOutputToCsv = false;
    static public String outputCsvFolder = "";

    public synchronized static Level getLogLevel() { return logLevel; }
    public synchronized static void setLogLevel(Level l) { logLevel = l; }

    public static EnumSet<LegMode> setLegModes(String modes) {
        EnumSet<LegMode> legModes = EnumSet.noneOf(LegMode.class);

        String[] modesArray = modes.split(";");
        if (!modes.equals("") & modesArray.length > 0) {
            for (String mode : modesArray) {
                legModes.add(LegMode.valueOf(mode));
            }
        }

        return legModes;
    }

    public static EnumSet<TransitModes> setTransitModes(String modes) {
        EnumSet<TransitModes> transitModes = EnumSet.noneOf(TransitModes.class);

        String[] modesArray = modes.split(";");
        if (!modes.equals("") & modesArray.length > 0) {
            for (String mode : modesArray) {
                transitModes.add(TransitModes.valueOf(mode));
            }
        }

        return transitModes;
    }

    public static int getSecondsFromMidnight(String departureTime) throws ParseException {
        DateFormat dateFormat = new SimpleDateFormat("HH:mm:ss");
        Date reference = dateFormat.parse("00:00:00");
        Date date = dateFormat.parse(departureTime);
        return (int) ((date.getTime() - reference.getTime()) / 1000L);
    }

    public static String getTimeFromSeconds(int secondsFromMidnight) {
        int sec = secondsFromMidnight % 60;
        int min = (secondsFromMidnight / 60)%60;
        int hours = (secondsFromMidnight/60)/60;

        String strSec=(sec<10)?"0"+ sec :Integer.toString(sec);
        String strMin=(min<10)?"0"+ min :Integer.toString(min);
        String strHours=(hours<10)?"0"+ hours :Integer.toString(hours);

        return (strHours + ":" + strMin + ":" + strSec);
    }

    public static void setlogProgress(boolean progress){
        Utils.progress = progress;

        LoggerContext loggerContext = (LoggerContext) LoggerFactory.getILoggerFactory();
        Logger logger = loggerContext.getLogger(R5DataFrameProcess.class);

        // Choose smallest # Level as that is the most verbose.

        Level progressLevel = progress ? Level.INFO : Level.WARN;
        Level levelToSet = Utils.getLogLevel().toInt() < progressLevel.toInt() ? Utils.getLogLevel() : progressLevel;
        logger.setLevel(levelToSet);
        // RegularGridProcess (travel time surfaces) logs progress through R5Process
        loggerContext.getLogger(R5Process.class).setLevel(levelToSet);
    }

    public static void setLogModeOther(String level) {
        Utils.setLogLevel(Level.valueOf(level));
        String[] loggerNames = {
                "com.conveyal",
                "org.ipea.r5r",
                "graphql.GraphQL",
                "org.mongodb.driver.connection",
                "org.eclipse.jetty",
                "org.eclipse.jetty",
                "org.hsqldb.persist.Logger",
        };

        LoggerContext loggerContext = (LoggerContext) LoggerFactory.getILoggerFactory();
        for (String name : loggerNames) {
            Logger logger = loggerContext.getLogger(name);
            logger.setLevel(Utils.getLogLevel());
        }
    }

    public static void setLogModeJar(String level) {
        LoggerContext loggerContext = (LoggerContext) LoggerFactory.getILoggerFactory();
        Logger logger = loggerContext.getLogger("org.ipea.r5r");
        logger.setLevel(Level.valueOf(level));
    }

    public static int getLinestringLength(LineString geometry) {
        Coordinate previousCoordinate = null;
        double accDistance = 0;

        for (Coordinate coordinate : geometry.getCoordinates()) {
            if (previousCoordinate != null) {
                accDistance += GeometryUtils.distance(previousCoordinate.y, previousCoordinate.x, coordinate.y, coordinate.x);
            }

            previousCoordinate = coordinate;
        }

        return (int) Math.round(accDistance);
    }

    public static double roundTo1Place(double value) {
        return Math.round(value * 10.0) / 10.0;
    }

}
