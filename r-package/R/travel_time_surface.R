setClass("travel_time_surface", slots=list(
  matrix="matrix",
  zoom="integer",
  north="integer",
  west="integer",
  height="integer",
  width="integer"
))

#' Compute travel time surfaces.
#'
#' @description A travel time surface is a raster grid (in the Web Mercator projection)
#' containing travel times from a specified point.
#'
#' @template r5r_network
#' @param origins Either a `POINT sf` object with WGS84 CRS, or a
#'        `data.frame` containing the columns `id`, `lon` and `lat`.
#' @param zoom Resolution of the travel time surface used to create isochrones,
#'        can be between 9 and 12. More detailed isochrones will result from
#'        larger numbers, at the expense of compute time. Specifically, a raster
#'        grid of travel times in the Web Mercator projection at this zoom level
#'        is created, and the isochrones are interpolated from this grid. For
#'        more information on how the grid cells are defined, see
#'        \href{https://docs.conveyal.com/analysis/methodology#zoom-levels}{the R5 documentation.}
#' @param mode A character vector. The transport modes allowed for access,
#'        transfer and vehicle legs of the trips. Defaults to `WALK`. See
#'        details for other options.
#' @param mode_egress A character vector. The transport mode used after egress
#'        from the last public transport. It can be either `WALK`, `BICYCLE` or
#'        `CAR`. Defaults to `WALK`. Ignored when public transport is not used.
#' @param departure_datetime A POSIXct object. Only affects public transport
#'        legs; when routing with public transport, it must fall within the
#'        service period of the GTFS feeds (`calendar.txt`; see
#'        [check_transit_availability()]). Defaults to `Sys.time()`. See
#'        details for how datetimes are parsed.
#' @param time_window An integer. The time window in minutes for which `r5r`
#'        will calculate multiple travel time matrices departing each minute
#'        (or, with a `fare_structure`, at departure times sampled at random
#'        within the window; see `draws_per_minute`). Defaults to 10 minutes.
#'        The function returns the result based on median travel times. See
#'        `vignette("time_window", package = "r5r")`.
#' @param max_walk_time An integer. The maximum walking time (in minutes) to
#'        access and egress the transit network, or to make transfers within the
#'        network. Defaults to no restrictions, as long as `max_trip_duration`
#'        is respected. The max time is considered separately for each leg (e.g.
#'        if you set `max_walk_time` to 15, you could potentially walk up to 15
#'        minutes to reach transit, and up to _another_ 15 minutes to reach the
#'        destination after leaving transit). Defaults to `Inf`, no limit.
#' @param max_bike_time An integer. The maximum cycling time (in minutes) to
#'        access and egress the transit network. Defaults to no restrictions, as
#'        long as `max_trip_duration` is respected. The max time is considered
#'        separately for each leg (e.g. if you set `max_bike_time` to 15 minutes,
#'        you could potentially cycle up to 15 minutes to reach transit, and up
#'        to _another_ 15 minutes to reach the destination after leaving
#'        transit). Defaults to `Inf`, no limit.
#' @param max_car_time An integer. The maximum driving time (in minutes) to
#'        access and egress the transit network, or to complete car-only
#'        trips. Defaults to no restrictions, as long as `max_trip_duration`
#'        is respected. The max time is considered
#'        separately for each leg (e.g. if you set `max_car_time` to 15 minutes,
#'        you could potentially drive up to 15 minutes to reach transit, and up
#'        to _another_ 15 minutes to reach the destination after leaving transit).
#'        Defaults to `Inf`, no limit. In car-only trips, whenever
#'        `max_car_time` differs from `max_trip_duration`, the lowest value is
#'        considered.
#' @param max_trip_duration An integer. The maximum trip duration in minutes.
#'        Defaults to 120 minutes (2 hours).
#' @param walk_speed A numeric. Average walk speed in km/h. Defaults to 3.6 km/h.
#' @param bike_speed A numeric. Average cycling speed in km/h. Defaults to 12 km/h.
#' @param max_rides An integer. The maximum number of public transport rides
#'        allowed in the same trip. Defaults to 3.
#' @param max_lts An integer between 1 and 4. The maximum level of traffic
#'        stress that cyclists will tolerate. A value of 1 means cyclists will
#'        only travel through the quietest streets, while a value of 4 indicates
#'        cyclists can travel through any road. Defaults to 2. See details.
#'
#' @template draws_per_minute
#' @template seed
#' @param n_threads An integer. The number of threads to use when running the
#'        router in parallel. Defaults to use all available threads (`Inf`).
#' @param progress A logical. Whether to show a progress counter when running
#'        the router. Defaults to `TRUE`. Only works when `verbose` is set to
#'        `FALSE`, so the progress counter does not interfere with `R5`'s output
#'        messages. Setting `progress` to `TRUE` may impose a small penalty for
#'        computation efficiency, because the progress counter must be
#'        synchronized among all active threads.
#' @template fare_structure
#' @template max_fare
#' @template scenarios
#' @template verbose
#' @template percentiles
#'
#' @return A `"sf" "data.frame"` for each isochrone of each origin.
#'
#' @template transport_modes_section
#' @template lts_section
#' @template datetime_parsing_section
#' @template raptor_algorithm_section
#'
#'
#' @family support functions
#'
#' @keywords internal
travel_time_surface <- function(r5r_network,
                               origins,
                               zoom = 10,
                               mode = "WALK",
                               mode_egress = "WALK",
                               departure_datetime = Sys.time(),
                               time_window = 10L,
                               percentiles = 50L,
                               max_walk_time = Inf,
                               max_bike_time = Inf,
                               max_car_time = Inf,
                               max_trip_duration = 120L,
                               walk_speed = 3.6,
                               bike_speed = 12,
                               max_rides = 3,
                               max_lts = 2,
                               fare_structure = NULL,
                               max_fare = Inf,
                               new_carspeeds = NULL,
                               carspeed_scale = 1,
                               new_lts = NULL,
                               draws_per_minute = 5L,
                               seed = NULL,
                               n_threads = Inf,
                               verbose = FALSE,
                               progress = TRUE
                      ) {
  # check inputs ------------------------------------------------------------
  checkmate::assert_class(r5r_network, "r5r_network")
  # R5 only supports grids between zoom 9 and 12
  checkmate::assert_int(zoom, lower = 9, upper = 12)
  r5r_network <- r5r_network@jcore
  on.exit(r5r_network$resetRoutingProperties(), add = TRUE)

  origins <- assign_points_input(origins, "origins")
  mode_list <- assign_mode(mode, mode_egress)
  departure <- assign_departure(departure_datetime)

  max_walk_time <- assign_max_street_time(
    max_walk_time,
    walk_speed,
    max_trip_duration,
    "walk"
  )
  max_bike_time <- assign_max_street_time(
    max_bike_time,
    bike_speed,
    max_trip_duration,
    "bike"
  )
  max_car_time <- assign_max_street_time(
    max_car_time,
    NULL, # no car speed argument to validate
    max_trip_duration,
    "car"
  )
  max_trip_duration <- assign_max_trip_duration(
    max_trip_duration,
    mode_list,
    max_walk_time,
    max_bike_time,
    max_car_time
  )

  set_time_window(r5r_network, time_window)
  set_percentiles(r5r_network, percentiles)
  set_monte_carlo_draws(r5r_network, draws_per_minute, time_window, fare_structure)
  set_monte_carlo_seed(r5r_network, seed)
  set_speed(r5r_network, walk_speed, "walk")
  set_speed(r5r_network, bike_speed, "bike")
  set_max_rides(r5r_network, max_rides)
  set_max_lts(r5r_network, max_lts)
  set_n_threads(r5r_network, n_threads)
  set_verbose(r5r_network, verbose)
  set_progress(r5r_network, progress)
  set_fare_structure(r5r_network, fare_structure)
  set_max_fare(r5r_network, max_fare, fare_structure)
  set_expanded_travel_times(r5r_network, FALSE)
  set_breakdown(r5r_network, FALSE)
  r5r_network$setSearchType("DEPART_FROM")

  # SCENARIOS -------------------------------------------
  set_new_congestion(r5r_network, new_carspeeds, carspeed_scale)
  set_new_lts(r5r_network, new_lts)

  surfaces <- run_routing_job(r5r_network, r5r_network$travelTimeSurfaces(
    origins$id, origins$lat, origins$lon,
    mode_list$direct_modes,
    mode_list$transit_mode,
    mode_list$access_mode,
    mode_list$egress_mode,
    departure$date,
    departure$time,
    max_walk_time,
    max_bike_time,
    max_car_time,
    max_trip_duration,
    as.integer(zoom)
  ), progress)

  # convert from java objects to R travel_time_surface class
  return(lapply(rJava::.jevalArray(surfaces), process_surfaces))
}

# process each percentile of a travel time surface
process_surfaces <- function (sfaces) {
  result = list()

  for (i in seq_along(sfaces$percentiles)) {
    # R has issues with nonconsecutive ints being used as list indices, so use strings
    result[[paste0("p", sfaces$percentiles[i])]] = process_surface(
      sfaces$values[i,],
      sfaces$zoom,
      sfaces$west,
      sfaces$north,
      sfaces$width,
      sfaces$height
      )
  }

  return(result)
}

# process a single surface into an R object
process_surface <- function (sface, zoom, west, north, width, height) {
  methods::new("travel_time_surface",
    matrix=matrix(as.double(sface), height, width, byrow = TRUE),
    zoom = zoom,
    width = width,
    height = height,
    north = north,
    west = west
  )
}
