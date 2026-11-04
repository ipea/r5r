#' Calculate travel time matrix between origin destination pairs considering a
#' time of arrival
#'
#' Computes travel times between origin-destination pairs for a given arrival
#' time: for each pair, the trip with the latest departure that arrives by
#' `arrival_datetime`. Departures are searched minute by minute between
#' `arrival_datetime - max_trip_duration` and `arrival_datetime`, so
#' `max_trip_duration` also sets the search window. For a departure time, use
#' [travel_time_matrix()]. This function wraps [expanded_travel_time_matrix()],
#' so its output has more columns than that of [travel_time_matrix()], and it
#' can be very memory intensive with a long `max_trip_duration`.
#' `destinations` can have at most 5000 rows, a limit of R5 for detailed path
#' information; split larger sets into chunks.
#'
#' @inheritParams expanded_travel_time_matrix
#' @param arrival_datetime A POSIXct object, required for all modes. The time by which trips must
#'   arrive. When routing with public transport, services must run on the date
#'   of `arrival_datetime - max_trip_duration` (see
#'   [check_transit_availability()]). See details for
#'   how datetimes are parsed.
#'
#' @return A `data.table` with one row per origin-destination pair that can be
#'   reached by `arrival_datetime`, describing the trip with the latest
#'   departure that still arrives in time: its `departure_time`, the `routes`
#'   used and its `total_time` (in minutes), plus the columns added by
#'   `breakdown = TRUE` (see [expanded_travel_time_matrix()]). Pairs that
#'   cannot be reached in time are absent from the output. When the search
#'   window crosses midnight, departure times after midnight are reported as
#'   `"24:MM:SS"`, and only the public transport services of the departure
#'   day are considered. Trips made only by walking, cycling or driving have
#'   travel times in whole minutes, so they can arrive up to 59 seconds after
#'   `arrival_datetime`. If `output_dir` is not `NULL`, the function
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
#' r5r_network <- build_network(data_path )
#'
#' # load origin/destination points
#' points <- read.csv(file.path(data_path, "poa_points_of_interest.csv"))
#'
#' arrival_datetime <- as.POSIXct(
#'   "13-05-2019 14:00:00",
#'   format = "%d-%m-%Y %H:%M:%S"
#' )
#'
#' # by default only returns the total time between each pair in each minute of
#' # the specified time window
#' arrival_ttm <- arrival_travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   arrival_datetime = arrival_datetime,
#'   max_trip_duration = 60
#' )
#'
#' head(arrival_ttm)
#'
#' # when breakdown = TRUE the output contains much more information
#' arrival_ttm2 <- arrival_travel_time_matrix(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   arrival_datetime = arrival_datetime,
#'   max_trip_duration = 60,
#'   breakdown = TRUE
#' )
#'
#' head(arrival_ttm2)
#'
#' stop_r5(r5r_network)
#' @export
arrival_travel_time_matrix <- function(r5r_network,
                                       origins,
                                       destinations,
                                       mode = "WALK",
                                       mode_egress = "WALK",
                                       arrival_datetime,
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

  if (missing(arrival_datetime) || is.null(arrival_datetime)) {
    cli::cli_abort(
      "{.arg arrival_datetime} is required. Supply a POSIXct value specifying when trips must arrive. For trips that do not depend on time, use {.fun travel_time_matrix}."
    )
  }

  old_options <- options(datatable.optimize = Inf)
  on.exit(options(old_options), add = TRUE)
  checkmate::assert_number(n_threads, lower = 1)
  old_dt_threads <- data.table::getDTthreads()
  dt_threads <- ifelse(is.infinite(n_threads), 0, n_threads)
  data.table::setDTthreads(dt_threads)
  on.exit(data.table::setDTthreads(old_dt_threads), add = TRUE)

  # check inputs and set r5r options --------------------------------------

  checkmate::assert_class(r5r_network, "r5r_network")

  origins <- assign_points_input(origins, "origins")
  destinations <- assign_points_input(destinations, "destinations")
  mode_list <- assign_mode(mode, mode_egress)

  # set before the departure datetime, which depends on the final max_trip_duration
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

  # calculate departure datetime
  departure_datetime <- arrival_datetime - as.difftime(max_trip_duration, units = "mins")
  departure <- assign_departure(departure_datetime, mode_list)

  # check availability of transit services on the selected date
  if (mode_list$transit_mode %like% 'TRANSIT|TRAM|SUBWAY|RAIL|BUS|FERRY|CABLE_CAR|GONDOLA|FUNICULAR') {
    check_transit_availability_on_date(r5r_network, departure_date = departure$date)
  }

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


  set_time_window(r5r_network, max_trip_duration)
  set_monte_carlo_draws(r5r_network, draws_per_minute, max_trip_duration)
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
  r5r_network$setSearchType("ARRIVE_BY")
  set_breakdown(r5r_network, breakdown)
  set_fare_structure(r5r_network, NULL)

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
