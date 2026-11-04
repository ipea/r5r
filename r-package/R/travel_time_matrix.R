#' Calculate travel time matrix between origin destination pairs considering a
#' departure time
#'
#' Fast computation of travel time estimates between one or multiple origin
#' destination pairs. This function considers a departure time set by the user.
#' If you want to calculate travel times considering a time of arrival, have a
#' look at the [arrival_travel_time_matrix()] function.
#'
#' @template r5r_network
#' @template r5r_core
#' @template common_arguments
#' @template time_window_related_args
#' @template draws_per_minute
#' @template seed
#' @template fare_structure
#' @template max_fare
#' @template scenarios
#' @template verbose
#' @param percentiles An integer vector (max length of 5). Specifies the
#'   percentile to use when returning travel time estimates within the given
#'   time window. For example, if the 25th travel time percentile between A and
#'   B is 15 minutes, 25% of all trips taken between these points within the
#'   specified time window are shorter than 15 minutes. Defaults to 50,
#'   returning the median travel time. If a vector with length bigger than 1 is
#'   passed, the output contains an additional column for each percentile
#'   specifying the percentile travel time estimate. Due to
#'   upstream restrictions, only 5 percentiles can be specified at a time. See
#'   the R5 documentation at
#'   <https://docs.conveyal.com/analysis/methodology#accounting-for-variability>.
#'
#' @return A `data.table` with travel time estimates (in minutes) between
#'   origin and destination pairs. Pairs whose trips couldn't be completed
#'   within the maximum travel time and/or whose origin is too far from the
#'   street network are not returned in the `data.table`. If `output_dir` is
#'   not `NULL`, the function returns the path specified in that parameter, in
#'   which the `.csv` files containing the results are saved.
#'
#' @template transport_modes_section
#' @template lts_section
#' @template datetime_parsing_section
#' @template raptor_algorithm_section
#'
#' @family routing
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' # build transport network
#' data_path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path)
#'
#' # load origin/destination points
#' points <- read.csv(file.path(data_path, "poa_points_of_interest.csv"))
#'
#' departure_datetime <- as.POSIXct(
#'   "13-05-2019 14:00:00",
#'   format = "%d-%m-%Y %H:%M:%S"
#' )
#'
#' ttm <- travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   departure_datetime = departure_datetime,
#'   max_trip_duration = 60
#' )
#' head(ttm)
#'
#' # using a larger time window
#' ttm <- travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   departure_datetime = departure_datetime,
#'   time_window = 30,
#'   max_trip_duration = 60
#' )
#' head(ttm)
#'
#' # selecting different percentiles
#' ttm <- travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   departure_datetime = departure_datetime,
#'   time_window = 30,
#'   percentiles = c(25, 50, 75),
#'   max_trip_duration = 60
#' )
#' head(ttm)
#'
#' # use a fare structure and set a max fare to take monetary constraints into
#' # account
#' fare_structure <- read_fare_structure(
#'   file.path(data_path, "fares/fares_poa.zip")
#' )
#' ttm <- travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   departure_datetime = departure_datetime,
#'   fare_structure = fare_structure,
#'   max_fare = 5,
#'   max_trip_duration = 60,
#' )
#' head(ttm)
#'
#' stop_r5(r5r_network)
#'
#' @export
travel_time_matrix <- function(r5r_network,
                               origins,
                               destinations,
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
                               progress = TRUE,
                               output_dir = NULL,
                               r5r_core = deprecated()) {

  # deprecating r5r_core --------------------------------------
  if (lifecycle::is_present(r5r_core)) {

    cli::cli_warn(c(
      "!" = "The `r5r_core` argument is deprecated as of r5r v2.3.0.",
      "i" = "Please use the `r5r_network` argument instead."
    ))

    r5r_network <- r5r_core
  }

  old_options <- options(datatable.optimize = Inf)
  on.exit(options(old_options), add = TRUE)

  old_dt_threads <- data.table::getDTthreads()
  dt_threads <- ifelse(is.infinite(n_threads), 0, n_threads)
  data.table::setDTthreads(dt_threads)
  on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)

  # check inputs and set r5r options --------------------------------------

  origins <- assign_points_input(origins, "origins")
  destinations <- assign_points_input(destinations, "destinations")
  mode_list <- assign_mode(mode, mode_egress)
  departure <- assign_departure(departure_datetime, mode_list)

  # check availability of transit services on the selected date
  if (mode_list$transit_mode %like% 'TRANSIT|TRAM|SUBWAY|RAIL|BUS|FERRY|CABLE_CAR|GONDOLA|FUNICULAR') {
    check_transit_availability_on_date(r5r_network, departure_date = departure$date)
  }

  checkmate::assert_class(r5r_network, "r5r_network")
  r5r_network <- r5r_network@jcore
  on.exit(r5r_network$resetRoutingProperties(), add = TRUE)

  # in direct modes reverse origin/destination to take advantage of R5's One to Many algorithm.
  # skipped when output_dir is set: Java writes the CSVs with the swapped from_id/to_id and names
  # the files after the swapped origins, and the swap is only undone in the in-memory result
  data_path <- r5r_network$getDataPath()
  res <- NULL
  if (is.null(output_dir)) {
    res <- reverse_if_direct_mode(origins, destinations, mode_list, data_path)
  }
  if (!is.null(res)) {
    origins <- res$origins
    destinations <- res$destinations
  }


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
  set_output_dir(r5r_network, output_dir)
  set_expanded_travel_times(r5r_network, FALSE)
  set_breakdown(r5r_network, FALSE)
  r5r_network$setSearchType("DEPART_FROM")

  # SCENARIOS -------------------------------------------
  set_new_congestion(r5r_network, new_carspeeds, carspeed_scale)
  set_new_lts(r5r_network, new_lts)


  # call r5r_network method and process result -------------------------------

  travel_times <- run_routing_job(r5r_network, r5r_network$travelTimeMatrix(
    origins$id,
    origins$lat,
    origins$lon,
    destinations$id,
    destinations$lat,
    destinations$lon,
    mode_list$direct_modes,
    mode_list$transit_mode,
    mode_list$access_mode,
    mode_list$egress_mode,
    departure$date,
    departure$time,
    max_walk_time,
    max_bike_time,
    max_car_time,
    max_trip_duration
  ), progress)

  if (!verbose & progress) cat("Preparing final output...", file = stderr())

  travel_times <- java_to_dt(
    travel_times,
    ids = list(from_id = origins$id, to_id = destinations$id)
  )

  # reverse order of origins destinations back ONLY if the order had been swapped before
  if (!is.null(res)) {
    reverse_back_if_direct_mode(
      travel_times,
      origins,
      destinations,
      mode_list,
      data_path
      )
  }



  if (nrow(travel_times) > 0) {
    # replace travel-times of nonviable trips with NAs, in every travel time
    # column (one per percentile)
    for (j in grep("^travel_time_p", names(travel_times))) {
      data.table::set(
        travel_times,
        i = which(travel_times[[j]] > max_trip_duration),
        j = j,
        value = NA_integer_
      )
    }
  }

  if (!verbose & progress) cat(" DONE!\n", file = stderr())

  if (!is.null(output_dir)) return(output_dir)
  return(travel_times[])
}
