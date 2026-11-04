#' Calculate access to opportunities
#'
#' Fast computation of access to opportunities given a selected decay function.
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
#' @param opportunities_colnames A character vector. The names of the columns
#'   in the `destinations` input that tells the number of opportunities in each
#'   location. Several different column names can be passed, in which case the
#'   accessibility to each kind of opportunity will be calculated.
#' @template percentiles
#' @param decay_function A string. Which decay function to use when calculating
#'   accessibility. One of `step`, `exponential`, `fixed_exponential`, `linear`
#'   or `logistic`. Defaults to `step`, which is equivalent to a cumulative
#'   opportunities measure. See details for how each alternative works and
#'   how they relate to the `cutoffs` and `decay_value` parameters.
#' @param cutoffs A numeric vector (maximum length of 12). This parameter has
#'   different effects for each decay function: it indicates the cutoff times
#'   in minutes when calculating cumulative opportunities accessibility with
#'   the `step` function (only trips strictly shorter than the cutoff are
#'   counted), the median (or inflection point) of the decay curves in the
#'   `logistic` and `linear` functions, and the half-life in the `exponential`
#'   function. It must be `NULL` when using the `fixed_exponential` function.
#'   Values must be whole numbers between 1 and 120 minutes (R5's limit) and
#'   are sorted in ascending order.
#' @param decay_value A number. Extra parameter to be passed to the selected
#'   `decay_function`. Must be `NULL` when `decay_function` is either `step` or
#'   `exponential`.
#'
#' @return A `data.table` with accessibility estimates for all origin points.
#'   This `data.table` contains the columns `id` (origin id), `opportunity`
#'   (the type of opportunities to which accessibility was calculated),
#'   `percentile` (the travel time percentile considered in the estimate),
#'   `cutoff` (the specified cutoff values, except when `decay_function` is
#'   `fixed_exponential`, in which case the `cutoff` parameter is not used) and
#'   `accessibility` (the accessibility estimate). Origins that cannot be
#'   snapped to the street network get an accessibility of 0 (see
#'   [find_snap()]). If `output_dir` is not `NULL`, the function returns the
#'   path specified in that parameter, in which the `.csv` files containing
#'   the results are saved. With `fixed_exponential`, these files keep a
#'   `cutoff` column filled with the placeholder value `0`.
#'
#' @template decay_functions_section
#' @template transport_modes_section
#' @template lts_section
#' @template datetime_parsing_section
#' @template raptor_algorithm_section
#'
#' @family accessibility
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' data_path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path)
#' points <- read.csv(file.path(data_path, "poa_hexgrid.csv"))[1:500, ]
#'
#' departure_datetime <- as.POSIXct(
#'   "13-05-2019 14:00:00",
#'   format = "%d-%m-%Y %H:%M:%S"
#' )
#'
#' access <- accessibility(
#'   r5r_network ,
#'   origins = points,
#'   destinations = points,
#'   opportunities_colnames = "schools",
#'   mode = "WALK",
#'   departure_datetime = departure_datetime,
#'   decay_function = "step",
#'   cutoffs = 30,
#'   max_trip_duration = 30
#' )
#' head(access)
#'
#' # using a different decay function
#' access <- accessibility(
#'   r5r_network ,
#'   origins = points,
#'   destinations = points,
#'   opportunities_colnames = "schools",
#'   mode = "WALK",
#'   departure_datetime = departure_datetime,
#'   decay_function = "logistic",
#'   cutoffs = 30,
#'   decay_value = 1,
#'   max_trip_duration = 30
#' )
#' head(access)
#'
#' # using several cutoff values
#' access <- accessibility(
#'   r5r_network ,
#'   origins = points,
#'   destinations = points,
#'   opportunities_colnames = "schools",
#'   mode = "WALK",
#'   departure_datetime = departure_datetime,
#'   decay_function = "step",
#'   cutoffs = c(15, 30),
#'   max_trip_duration = 30
#' )
#' head(access)
#'
#' # calculating access to different types of opportunities
#' access <- accessibility(
#'   r5r_network ,
#'   origins = points,
#'   destinations = points,
#'   opportunities_colnames = c("schools", "healthcare"),
#'   mode = "WALK",
#'   departure_datetime = departure_datetime,
#'   decay_function = "step",
#'   cutoffs = 30,
#'   max_trip_duration = 30
#' )
#' head(access)
#'
#' stop_r5(r5r_network )
#'
#' @export
accessibility <- function(r5r_network,
                          origins,
                          destinations,
                          opportunities_colnames = "opportunities",
                          mode = "WALK",
                          mode_egress = "WALK",
                          departure_datetime = NULL,
                          time_window = 10L,
                          percentiles = 50L,
                          decay_function = "step",
                          cutoffs = NULL,
                          decay_value = NULL,
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

  checkmate::assert_class(r5r_network, "r5r_network")
  origins <- assign_points_input(origins, "origins")
  destinations <- assign_points_input(destinations, "destinations")
  opportunities <- assign_opportunities(destinations, opportunities_colnames)
  mode_list <- assign_mode(mode, mode_egress)
  departure <- assign_departure(departure_datetime, mode_list)

  # check availability of transit services on the selected date
  if (mode_list$transit_mode %like% 'TRANSIT|TRAM|SUBWAY|RAIL|BUS|FERRY|CABLE_CAR|GONDOLA|FUNICULAR') {
    check_transit_availability_on_date(r5r_network, departure_date = departure$date)
  }

  r5r_network <- r5r_network@jcore
  on.exit(r5r_network$resetRoutingProperties(), add = TRUE)

  decay_list <- assign_decay_function(decay_function, decay_value)

  # cap trip duration with cutoffs
  set_cutoffs(r5r_network, cutoffs, decay_function)
  checkmate::assert_number(max_trip_duration, lower = 1, finite = TRUE)

  if(!is.null(cutoffs)){
    if(max_trip_duration < max(cutoffs)){stop("'max_trip_duration' cannot be shorter than 'max(cutoffs)'")}

    # only the step function ignores trips longer than the cutoffs; the other
    # decay functions still weight them
    if (decay_function == "step") max_trip_duration <- max(cutoffs)
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

  # SCENARIOS -------------------------------------------
  set_new_congestion(r5r_network, new_carspeeds, carspeed_scale)
  set_new_lts(r5r_network, new_lts)


  # call r5r_network method and process results ------------------------------

  # wrap r5r_network inputs in arrays (this helps to simplify the Java code)

  from_id_arr <- rJava::.jarray(origins$id)
  from_lat_arr <- rJava::.jarray(origins$lat)
  from_lon_arr <- rJava::.jarray(origins$lon)

  to_id_arr <- rJava::.jarray(destinations$id)
  to_lat_arr <- rJava::.jarray(destinations$lat)
  to_lon_arr <- rJava::.jarray(destinations$lon)

  opportunities_names <- rJava::.jarray(opportunities_colnames)
  opportunities_values <- rJava::.jarray(opportunities, "[D")

  accessibility <- run_routing_job(r5r_network, r5r_network$accessibility(
    from_id_arr,
    from_lat_arr,
    from_lon_arr,
    to_id_arr,
    to_lat_arr,
    to_lon_arr,
    opportunities_names,
    opportunities_values,
    decay_list$fun,
    decay_list$value,
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

  accessibility <- java_to_dt(accessibility)

  if (decay_function == "fixed_exponential") accessibility[, cutoff := NULL]

  if (!verbose & progress) cat(" DONE!\n", file = stderr())

  if (!is.null(output_dir)) return(output_dir)
  return(accessibility[])
}
