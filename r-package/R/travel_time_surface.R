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
#' @inheritParams travel_time_matrix
#' @param origins Either a `POINT sf` object with WGS84 CRS, or a
#'        `data.frame` containing the columns `id`, `lon` and `lat`.
#' @param zoom Resolution of the travel time surface used to create isochrones,
#'        can be between 9 and 12. More detailed isochrones will result from
#'        larger numbers, at the expense of compute time. Specifically, a raster
#'        grid of travel times in the Web Mercator projection at this zoom level
#'        is created, and the isochrones are interpolated from this grid. For
#'        more information on how the grid cells are defined, see
#'        \href{https://docs.conveyal.com/analysis/methodology#zoom-levels}{the R5 documentation.}
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
                               departure_datetime = NULL,
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
  departure <- assign_departure(departure_datetime, mode_list)

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
