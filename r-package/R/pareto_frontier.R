#' Calculate travel time and monetary cost Pareto frontier
#'
#' Fast computation of travel time and monetary cost Pareto frontier between
#' origin and destination pairs.
#'
#' @template r5r_network
#' @template r5r_core
#' @template common_arguments
#' @template time_window_related_args
#' @param fare_structure A fare structure object, following the convention
#'   set in [setup_fare_structure()]. This object describes how transit fares
#'   should be calculated. See `vignette("fare_structure", package = "r5r")`
#'   for its structure. Required: without it there are no fares to trade off
#'   against travel time.
#' @template verbose
#' @templateVar seed_mcraptor TRUE
#' @template seed
#' @param percentiles An integer vector (max length of 5). Specifies the
#'   percentile to use when returning travel time estimates within the given
#'   time window. This parameter is applied to the travel time
#'   estimates only (e.g. if the 25th percentile is specified, and the output
#'   between A and B is 15 minutes and 10 dollars, 25% of all trips cheaper
#'   than 10 dollars taken between these points are shorter than 15 minutes).
#'   Defaults to 50, returning the median travel time. If a vector with length
#'   bigger than 1 is passed, the output contains an additional column that
#'   specifies the percentile of each travel time and monetary cost
#'   combination. Due to upstream restrictions, only 5 percentiles can be
#'   specified at a time. See the R5 documentation at
#'   <https://docs.conveyal.com/analysis/methodology#accounting-for-variability>.
#' @param fare_cutoffs A numeric vector, required. The monetary cutoffs (each
#'   greater than or equal to 0) used to build the Pareto frontier. Usually these
#'   are all possible fares in your `fare_structure`, including sums of fares for trips
#'   with transfers. Coarse cutoffs merge different trips: with routes costing
#'   $3 and $4 and a single cutoff of `5`, the output shows the fastest trips
#'   costing up to $5 but not which route they used; `c(3, 4)` separates
#'   them.
#'
#' @return A `data.table` with the travel time and monetary cost Pareto frontier
#'   between the specified origins and destinations. An additional column
#'   identifying the travel time percentile is present if more than one value
#'   was passed to `percentiles`. Origin and destination pairs whose trips
#'   couldn't be completed within the maximum travel time using less money than
#'   the specified monetary cutoffs are not returned in the `data.table`. If
#'   `output_dir` is not `NULL`, the function returns the path specified in
#'   that parameter, in which the `.csv` files containing the results are
#'   saved.
#'
#' @template transport_modes_section
#' @template lts_section
#' @template datetime_parsing_section
#' @template mcraptor_algorithm_section
#'
#' @family routing
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' # build transport network
#' data_path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path = data_path)
#'
#' # load origin/destination points
#' points <- read.csv(file.path(data_path, "poa_hexgrid.csv"))[1:5,]
#'
#' # load fare structure object
#' fare_structure_path <- system.file(
#'   "extdata/poa/fares/fares_poa.zip",
#'   package = "r5r"
#' )
#' fare_structure <- read_fare_structure(fare_structure_path)
#'
#' departure_datetime <- as.POSIXct(
#'   "13-05-2019 14:00:00",
#'   format = "%d-%m-%Y %H:%M:%S"
#' )
#'
#' pf <- pareto_frontier(
#'   r5r_network,
#'   origins = points,
#'   destinations = points,
#'   mode = c("WALK", "TRANSIT"),
#'   departure_datetime = departure_datetime,
#'   fare_structure = fare_structure,
#'   fare_cutoffs = c(4.5, 4.8, 9, 9.3, 9.6)
#' )
#' head(pf)
#'
#' stop_r5(r5r_network)
#' @export
pareto_frontier <- function(r5r_network,
                            origins,
                            destinations,
                            mode = c("WALK", "TRANSIT"),
                            mode_egress = "WALK",
                            departure_datetime = NULL,
                            time_window = 10L,
                            seed = NULL,
                            percentiles = 50L,
                            max_walk_time = Inf,
                            max_bike_time = Inf,
                            max_car_time = Inf,
                            max_trip_duration = 120L,
                            fare_structure,
                            fare_cutoffs,
                            walk_speed = 3.6,
                            bike_speed = 12,
                            max_rides = 3,
                            max_lts = 2,
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

  if (missing(fare_structure) || is.null(fare_structure)) {
    cli::cli_abort(c(
      "{.arg fare_structure} is required.",
      "i" = "Create one with {.fn setup_fare_structure} or {.fn read_fare_structure}."
    ))
  }
  if (missing(fare_cutoffs)) {
    cli::cli_abort(c(
      "{.arg fare_cutoffs} is required.",
      "i" = "Pass the monetary cutoffs of the frontier, e.g. the fares of your {.arg fare_structure}."
    ))
  }

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
  set_monte_carlo_draws(
    r5r_network,
    1,
    time_window,
    mcraptor = mode_list$transit_mode != ""
  )
  set_monte_carlo_seed(r5r_network, seed)
  set_speed(r5r_network, walk_speed, "walk")
  set_speed(r5r_network, bike_speed, "bike")
  set_max_rides(r5r_network, max_rides)
  set_max_lts(r5r_network, max_lts)
  set_n_threads(r5r_network, n_threads)
  set_verbose(r5r_network, verbose)
  set_progress(r5r_network, progress)
  set_fare_structure(r5r_network, fare_structure)
  set_output_dir(r5r_network, output_dir)
  set_fare_cutoffs(r5r_network, fare_cutoffs)

  # call r5r_network method and process result -------------------------------

  frontier <- run_routing_job(r5r_network, r5r_network$paretoFrontier(
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

  frontier <- java_to_dt(frontier)

  if (nrow(frontier) > 0) {
    # replace travel-times of nonviable trips with NAs
    frontier[travel_time > max_trip_duration, travel_time := NA_integer_]
  }

  if (!verbose & progress) cat(" DONE!\n", file = stderr())

  if (!is.null(output_dir)) return(output_dir)
  return(frontier[])
}
