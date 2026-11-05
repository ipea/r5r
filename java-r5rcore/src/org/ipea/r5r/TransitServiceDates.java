package org.ipea.r5r;

import com.conveyal.gtfs.model.Service;
import com.conveyal.r5.transit.TransitLayer;
import com.conveyal.r5.transit.TripPattern;
import com.conveyal.r5.transit.TripSchedule;
import java.time.DateTimeException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.BitSet;
import java.util.TreeSet;

/** Operating dates for services referenced by retained transit trips. */
public final class TransitServiceDates {
    private TransitServiceDates() {}

    public static String[] getDates(TransitLayer transit) {
        BitSet usedServices = new BitSet();
        for (TripPattern pattern : transit.tripPatterns) {
            for (TripSchedule trip : pattern.tripSchedules) {
                usedServices.set(trip.serviceCode);
            }
        }

        TreeSet<LocalDate> dates = new TreeSet<>();
        for (int code = usedServices.nextSetBit(0); code >= 0;
                code = usedServices.nextSetBit(code + 1)) {
            Service service = transit.services.get(code);
            if (service.calendar != null) {
                LocalDate start;
                LocalDate end;
                try {
                    start = gtfsDate(service.calendar.start_date);
                    end = gtfsDate(service.calendar.end_date);
                } catch (DateTimeException e) {
                    throw new IllegalArgumentException("Cannot discover operating dates for service '"
                            + service.service_id + "': invalid calendar bounds "
                            + service.calendar.start_date + " to " + service.calendar.end_date
                            + ". Specify dates explicitly or correct the GTFS calendar.", e);
                }
                for (LocalDate date = start; !date.isAfter(end); date = date.plusDays(1)) {
                    if (service.activeOn(date)) dates.add(date);
                }
            }
            // Includes exception-only services and additions outside calendar bounds.
            if (service.calendar_dates != null) {
                for (LocalDate date : service.calendar_dates.keySet()) {
                    if (date != null && service.activeOn(date)) dates.add(date);
                }
            }
        }
        return dates.stream().map(LocalDate::toString).toArray(String[]::new);
    }

    private static LocalDate gtfsDate(int date) {
        return LocalDate.parse(Integer.toString(date), DateTimeFormatter.BASIC_ISO_DATE);
    }
}
