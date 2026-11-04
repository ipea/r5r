#' @param origins,destinations Either a `POINT sf` object with WGS84 CRS, or a
#'   `data.frame` containing the columns `id`, `lon` and `lat`.
#' @param mode A character vector. The transport modes allowed for access,
#'   transfer and vehicle legs of the trips. Defaults to `WALK`. See details for
#'   other options.
#' @param mode_egress A character vector. The transport mode used after egress
#'   from the last public transport. It can be either `WALK`, `BICYCLE` or
#'   `CAR`. Defaults to `WALK`. Ignored when public transport is not used.
#' @param departure_datetime A POSIXct object. Only affects public transport
#'   legs; when routing with public transport, it must fall within the service
#'   period of the GTFS feeds (`calendar.txt`; see
#'   [check_transit_availability()]). Defaults to `Sys.time()`. See details for
#'   how datetimes are parsed.
#' @param max_walk_time An integer. The maximum walking time (in minutes) to
#'   access and egress the transit network, make transfers, or complete
#'   walk-only trips. Applies to each leg separately (e.g. `15` allows up to 15
#'   minutes to reach transit and another 15 after leaving it). Defaults to
#'   `Inf` (no limit besides `max_trip_duration`). In walk-only trips, the lower
#'   of `max_walk_time` and `max_trip_duration` applies.
#' @param max_bike_time An integer. The maximum cycling time (in minutes) to
#'   access and egress the transit network, make transfers, or complete
#'   bicycle-only trips. Applies to each leg separately (e.g. `15` allows up to
#'   15 minutes to reach transit and another 15 after leaving it). Defaults to
#'   `Inf` (no limit besides `max_trip_duration`). In bicycle-only trips, the
#'   lower of `max_bike_time` and `max_trip_duration` applies.
#' @param max_car_time An integer. The maximum driving time (in minutes) to
#'   access and egress the transit network, or to complete car-only trips.
#'   Applies to each leg separately (e.g. `15` allows up to 15 minutes to reach
#'   transit and another 15 after leaving it). Defaults to `Inf` (no limit
#'   besides `max_trip_duration`). In car-only trips, the lower of
#'   `max_car_time` and `max_trip_duration` applies.
#' @param max_trip_duration An integer. The maximum trip duration in minutes.
#'   Defaults to 120.
#' @param walk_speed A numeric. Average walk speed in km/h. Defaults to 3.6.
#' @param bike_speed A numeric. Average cycling speed in km/h. Defaults to 12.
#' @param max_rides An integer. The maximum number of public transport rides
#'   allowed in the same trip. Defaults to 3.
#' @param max_lts An integer between 1 and 4. The maximum level of traffic
#'   stress that cyclists will tolerate. A value of 1 means cyclists will only
#'   travel through the quietest streets, while a value of 4 indicates cyclists
#'   can travel through any road. Defaults to 2. See details.
#' @param n_threads An integer. The number of threads to use when running the
#'   router in parallel. Defaults to `Inf` (all available threads).
#' @param progress A logical. Whether to show a progress counter when running
#'   the router. Defaults to `TRUE`. Only works when `verbose` is `FALSE`.
#'   May slightly slow computation, as the counter is synchronized across
#'   threads.
#' @param output_dir Either `NULL` (the default) or a path to an existing
#'   directory. When a path is given, the function writes the results as
#'   `.csv` files to that directory and returns the path instead of the
#'   results. Useful in memory-constrained settings, as results are not
#'   loaded into RAM. Missing values (`NA`) are written as empty fields.
