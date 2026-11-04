#' Calculate minute-by-minute travel times between origin destination pairs
#'
#' Detailed computation of travel time estimates between one or multiple origin
#' destination pairs. Results show the travel time of the fastest route
#' alternative departing each minute within a specified time window. This
#' function can be very memory intensive for large data sets and time
#' windows. `destinations` can have at most 5000 rows, a limit of R5 for
#' detailed path information; split larger sets into chunks.
#'
#' @template r5r_network
#' @template r5r_core
#' @template common_arguments
#' @param time_window An integer. The time window in minutes for which `r5r`
#'   will calculate multiple travel time matrices departing each minute.
#'   Defaults to 10 minutes. The output has one row per departure minute (and
#'   per Monte Carlo draw, see `draws_per_minute`). See
#'   `vignette("time_window", package = "r5r")`.
#' @template draws_per_minute
#' @template seed
#' @template scenarios
#' @template verbose
#' @param breakdown A logical. Whether to include detailed information about
#'   each trip in the output. If `FALSE` (the default), the output lists the
#'   total time between each origin-destination pair and the routes used to
#'   complete the trip for each minute of the specified time window. If `TRUE`,
#'   the output also includes the access, waiting, in-vehicle, transfer and
#'   egress time of each trip, and its number of public transport rides. For
#'   trips made only by walking, cycling or driving (`routes` equal to
#'   `[WALK]`, `[BICYCLE]` or `[CAR]`), these components are all `0` and
#'   `total_time` holds the whole trip.
#'
#' @return A `data.table` with travel time estimates (in minutes) and the
#'   routes used in each trip between origin and destination pairs, for each
#'   minute of the specified time window. Each set of origin, destination and
#'   departure minute can appear up to N times, where N is the number of Monte
#'   Carlo draws set by `draws_per_minute` (this only applies when the GTFS
#'   feeds include a frequencies table; otherwise a single draw is
#'   performed). A pair is completely absent from the final output if no trips
#'   could be completed in
#'   any of the minutes of the time window. If for a single pair trips could be
#'   completed in some of the minutes of the time window, but not for all of
#'   them, the minutes in which trips couldn't be completed will have `NA`
#'   travel time and routes used. A pair may also appear with `NA` in every
#'   minute, when its only trips are slightly longer than `max_trip_duration`
#'   (e.g. walk-only trips, whose time to walk between the point and the
#'   street network is added after the limit is applied).
#'
#'   The output has the columns `from_id`, `to_id`, `departure_time`,
#'   `draw_number`, `routes` and `total_time`, plus `access_time`,
#'   `wait_time`, `ride_time`, `transfer_time`, `egress_time` and `n_rides`
#'   when `breakdown = TRUE`. `routes` lists the public transport routes used,
#'   separated by `|`, or the street mode (e.g. `[WALK]`) for trips that do
#'   not use public transport. `draw_number` only labels the draws of a
#'   departure minute; their order is arbitrary.
#'
#'   Travel times are reported with a precision of 0.1 minute, and trips
#'   longer than `max_trip_duration` get `NA`. `travel_time_matrix()` rounds
#'   travel times down to whole minutes, so it can report trips that are up to
#'   0.9 minute over `max_trip_duration` which are `NA` here. With walk-,
#'   bike- or car-only `mode`, travel times are whole minutes.
#'
#'   If `output_dir` is not `NULL`, the function
#'   returns the path specified in that parameter, in which the `.csv` files
#'   containing the results are saved.
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
#' # by default only returns the total time between each pair in each minute of
#' # the specified time window
#' ettm <- expanded_travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   time_window = 20,
#'   departure_datetime = departure_datetime,
#'   max_trip_duration = 60
#' )
#' head(ettm)
#'
#' # when breakdown = TRUE the output contains much more information
#' ettm <- expanded_travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   time_window = 20,
#'   departure_datetime = departure_datetime,
#'   max_trip_duration = 60,
#'   breakdown = TRUE
#' )
#' head(ettm)
#'
#' stop_r5(r5r_network)
#' @export
expanded_travel_time_matrix <- function(r5r_network,
                                        origins,
                                        destinations,
                                        mode = "WALK",
                                        mode_egress = "WALK",
                                        departure_datetime = NULL,
                                        time_window = 10L,
                                        breakdown = FALSE,
                                        max_walk_time = Inf,
                                        max_bike_time = Inf,
                                        max_car_time = Inf,
                                        max_trip_duration = 120L,
                                        walk_speed = 3.6,
                                        bike_speed = 12,
                                        max_rides = 3,
                                        max_lts = 2,
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

  if (missing(departure_datetime)) warn_default_datetime(mode)

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
  # also skipped for more than 5000 origins: they would become destinations, above R5's limit
  data_path <- r5r_network$getDataPath()
  res <- NULL
  if (is.null(output_dir) && nrow(origins) <= 5000) {
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
  set_monte_carlo_draws(r5r_network, draws_per_minute, time_window)
  set_monte_carlo_seed(r5r_network, seed)
  set_speed(r5r_network, walk_speed, "walk")
  set_speed(r5r_network, bike_speed, "bike")
  set_max_rides(r5r_network, max_rides)
  set_max_lts(r5r_network, max_lts)
  set_n_threads(r5r_network, n_threads)
  set_verbose(r5r_network, verbose)
  set_progress(r5r_network, progress)
  set_output_dir(r5r_network, output_dir)
  set_expanded_travel_times(r5r_network, TRUE)
  set_breakdown(r5r_network, breakdown)
  set_fare_structure(r5r_network, NULL)
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

  # replace travel-times of non-viable trips with NAs
  # if breakdown is TRUE, there are more columns in the output

  if (nrow(travel_times) > 0) {
    if (breakdown) {
      travel_times[
        total_time > max_trip_duration,
        `:=`(
          access_time = NA_integer_,
          wait_time = NA_integer_,
          ride_time = NA_integer_,
          transfer_time = NA_integer_,
          egress_time = NA_integer_,
          routes = NA_character_,
          n_rides = NA_integer_,
          total_time = NA_integer_
        )
      ]
    } else {
      travel_times[
        total_time > max_trip_duration,
        `:=`(routes = NA_character_, total_time = NA_integer_)
      ]
    }
  }

  if (!verbose & progress) cat(" DONE!\n", file = stderr())

  if (!is.null(output_dir)) return(output_dir)
  return(travel_times[])
}
