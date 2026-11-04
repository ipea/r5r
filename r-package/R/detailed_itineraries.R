#' Detailed itineraries between origin-destination pairs
#'
#' Returns detailed trip information between origin-destination pairs: the
#' waiting and moving time, distance, route and geometry of each trip leg.
#' Designed for trip planning (like Google's Directions API or
#' OpenTripPlanner), it takes much more time and memory than the package's
#' other, more analytical, routing functions.
#'
#' @template r5r_network
#' @template r5r_core
#' @template common_arguments
#' @template scenarios
#' @template verbose
#' @template fare_structure
#' @template max_fare
#' @param time_window An integer. The time window in minutes for which `r5r`
#'   will calculate multiple itineraries. Defaults to 10. Unlike other routing
#'   functions, results are not aggregated by percentile, so the output may
#'   contain trips departing after `departure_datetime` but within the window.
#'   With `shortest_path = TRUE` and no `fare_structure`, a trip is routed for
#'   each minute from `departure_datetime` until `time_window` minutes later,
#'   and the fastest one is returned (ties go to the earliest departure).
#'   Otherwise, departures are simulated at random seconds, about one per
#'   minute (30 to 90 seconds apart), with the same departure times in every
#'   call with the same origin, and each departure is routed separately: an
#'   itinerary may appear or disappear when `departure_datetime` changes by one
#'   minute, and when the same sequence of routes appears in several
#'   departures, only the fastest is kept. See
#'   `vignette("time_window", package = "r5r")`.
#' @param suboptimal_minutes A number. How many minutes after the optimal
#'   arrival a non-optimal McRAPTOR branch may arrive and still be kept (e.g.
#'   with `10`, routes arriving up to 10 minutes after the fastest one are
#'   considered). It can only be used when `shortest_path = FALSE` and 
#'   `fare_structure` is `NULL`. The comparison is made separately for each 
#'   departure within `time_window` and uses arrival time only: a route beyond 
#'   this margin is discarded even if it has fewer transfers. The default, `0`, 
#'   keeps only routes arriving at the earliest time for each departure. Higher 
#'   values return more itineraries, emulating people who take a slower route for
#'   practical reasons (e.g. mode preference, safety).
#' @param shortest_path A logical. Whether the function should only return the
#'   fastest itinerary between each origin and destination pair (the default)
#'   or multiple alternatives. The fastest itinerary is the one with the
#'   shortest travel time, measured from its own departure time, among all
#'   departures within `time_window`. With a large `time_window`, it may depart
#'   later and arrive later than other itineraries; use `time_window = 1` to
#'   get the itinerary with the earliest arrival for a given departure time.
#'   Without a `fare_structure`, public transport trips are then routed with
#'   R5's RAPTOR algorithm, which is much faster than the McRAPTOR algorithm
#'   used for alternative routes and fares (see the Fastest itinerary section).
#' @param all_to_all A logical. Whether to query routes between the 1st origin
#'   to the 1st destination, then the 2nd origin to the 2nd destination, and so
#'   on (`FALSE`, the default) or to query routes between all origins to all
#'   destinations (`TRUE`). With `shortest_path = TRUE` and no `fare_structure`,
#'   `all_to_all = TRUE` runs one public transport search per origin for all
#'   its destinations, which is much faster than listing the same pairs with
#'   `all_to_all = FALSE`.
#' @param drop_geometry A logical. Whether to drop the geometry of each trip
#'   leg from the output. Defaults to `FALSE` (geometry kept).
#' @param osm_link_ids A logical. Whether the output should include additional
#'   columns: `osm_id_list` for the OSM ids of the road segments used along the
#'   trip geometry, `edge_id_list` for the ids of the internal street network
#'   edges used, and `board_stop_id` and `alight_stop_id` for the GTFS ids of
#'   transit boarding and alighting stops, prefixed by the feed name (e.g.
#'   `"poa_eptc:1649"`). `osm_id_list` and `edge_id_list` are character
#'   columns formatted as `"[id1, id2, ...]"`, and are `"[]"` for transit
#'   segments. Can only be `TRUE` when `drop_geometry` is `FALSE`. Defaults to
#'   `FALSE`.
#'
#'   Keep in mind that `osm_id_list` will contain an id even if the route only
#'   uses a small stretch of the road (e.g. 5m of a 600m street segment). For
#'   more precision, use `edge_id_list`, which returns the exact internal edge
#'   segments used in the trip. You can inspect these edge ids and their
#'   associated properties, including OSM ids, with
#'   [street_network_to_sf()].
#'
#' @template transport_modes_section
#' @template lts_section
#' @template datetime_parsing_section
#' @template mcraptor_algorithm_section
#'
#' @section Fastest itinerary:
#'
#' When only the fastest itinerary is returned (`shortest_path = TRUE`) and no
#' `fare_structure` is used, public transport is routed with R5's RAPTOR
#' algorithm (Conway et al, 2017), the one used by [travel_time_matrix()],
#' which is much faster than McRAPTOR. Compared with McRAPTOR, the results can
#' differ slightly: departures are routed every minute of `time_window`
#' instead of at random seconds, so the itinerary returned is never more than
#' about a minute slower and often faster; walking transfers between stops are
#' limited by `max_walk_time` (McRAPTOR only applies it to the first and last
#' legs); stops where the GTFS `pickup_type` or `drop_off_type` does not allow
#' boarding or alighting are respected; and when two trips are equally fast,
#' the route chosen may differ.
#'
#' - Conway, M. W., Byrd, A., & van der Linden, M. (2017). Evidence-based
#' transit and land use sketch planning using interactive accessibility methods
#' on combined schedule and headway-based networks. Transportation Research
#' Record, 2653(1), 45-53. \doi{10.3141/2653-06}
#'
#' @return When `drop_geometry` is `FALSE`, the function outputs a `LINESTRING
#'   sf` with detailed information on the itineraries between the specified
#'   origins and destinations. When `TRUE`, the output is a `data.table`. All
#'   distances are in meters and travel times are in minutes. Each row is one
#'   segment (trip leg) of one itinerary, with the columns:
#'   - `from_id`, `from_lat`, `from_lon`, `to_id`, `to_lat`, `to_lon`: the
#'     origin and destination of the pair;
#'   - `option`: the itinerary number within the pair. Options are ordered
#'     with direct (non-transit) trips first, then by number of segments, then
#'     by duration, so `option` 1 is not necessarily the fastest one. With
#'     `shortest_path = TRUE`, each pair has a single itinerary (`option` 1);
#'   - `departure_time`: the departure time of the itinerary (`"HH:MM:SS"`);
#'   - `total_duration`, `total_distance`: duration and distance of the whole
#'     itinerary;
#'   - `segment`, `mode`, `segment_duration`, `wait`, `distance`, `route`: the
#'     segment number, its transport mode, its in-motion duration, the waiting
#'     time before it, its distance and the transit route used (empty for
#'     non-transit segments);
#'   - `total_fare`, `cumulative_fare`: only when a `fare_structure` is used;
#'   - `osm_id_list`, `edge_id_list`, `board_stop_id`, `alight_stop_id`: only
#'     when `osm_link_ids` is `TRUE`;
#'   - `geometry`: only when `drop_geometry` is `FALSE`.
#'
#'   If `output_dir` is not `NULL`, the function returns the path specified in
#'   that parameter, in which the `.csv` files containing the results are
#'   saved. This function writes one file per origin-destination pair, named
#'   `from_<origin id>_to_<destination id>.csv`, so pairs must be unique and
#'   ids cannot contain characters that are not allowed in file names.
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
#' # inputs
#' departure_datetime <- as.POSIXct(
#'   "13-05-2019 14:00:00",
#'   format = "%d-%m-%Y %H:%M:%S"
#' )
#'
#' det <- detailed_itineraries(
#'   r5r_network,
#'   origins = points[10,],
#'   destinations = points[12,],
#'   mode = c("WALK", "TRANSIT"),
#'   departure_datetime = departure_datetime,
#'   max_trip_duration = 60
#' )
#' head(det)
#'
#' stop_r5(r5r_network)
#' @export
detailed_itineraries <- function(r5r_network,
                                 origins,
                                 destinations,
                                 mode = "WALK",
                                 mode_egress = "WALK",
                                 departure_datetime = NULL,
                                 time_window = 10L,
                                 suboptimal_minutes = 0L,
                                 max_walk_time = Inf,
                                 max_bike_time = Inf,
                                 max_car_time = Inf,
                                 max_trip_duration = 120L,
                                 walk_speed = 3.6,
                                 bike_speed = 12,
                                 max_rides = 3,
                                 max_lts = 2,
                                 shortest_path = TRUE,
                                 all_to_all = FALSE,
                                 fare_structure = NULL,
                                 max_fare = Inf,
                                 new_carspeeds = NULL,
                                 carspeed_scale = 1,
                                 new_lts = NULL,
                                 n_threads = Inf,
                                 verbose = FALSE,
                                 progress = TRUE,
                                 drop_geometry = FALSE,
                                 osm_link_ids = FALSE,
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

  # row-paired inputs (all_to_all = FALSE) may legitimately repeat an id
  origins <- assign_points_input(origins, "origins", unique_ids = all_to_all)
  destinations <- assign_points_input(destinations, "destinations", unique_ids = all_to_all)
  od_list <- expand_od_pairs(origins, destinations, all_to_all)
  origins <- od_list$origins
  destinations <- od_list$destinations

  # with output_dir, each pair is written to a file named after its ids
  if (!is.null(output_dir)) {
    if (anyDuplicated(data.table::data.table(origins$id, destinations$id)) > 0) {
      cli::cli_abort(
        "With {.arg output_dir}, origin-destination pairs must be unique, because each pair is written to a file named {.file from_<id>_to_<id>.csv}."
      )
    }
    bad_ids <- unique(grep('[/\\\\:*?"<>|]', c(origins$id, destinations$id), value = TRUE))
    if (length(bad_ids) > 0) {
      cli::cli_abort(c(
        "With {.arg output_dir}, ids cannot contain characters that are not allowed in file names ({.code / \\ : * ? \" < > |}).",
        "x" = "Invalid id{?s}: {.val {bad_ids}}."
      ))
    }
  }

  mode_list <- assign_mode(mode, mode_egress)
  departure <- assign_departure(departure_datetime, mode_list)

  # check availability of transit services on the selected date
  if (mode_list$transit_mode %like% 'TRANSIT|TRAM|SUBWAY|RAIL|BUS|FERRY|CABLE_CAR|GONDOLA|FUNICULAR') {
    check_transit_availability_on_date(r5r_network, departure_date = departure$date)
  }

  r5r_network <- r5r_network@jcore
  on.exit(r5r_network$resetRoutingProperties(), add = TRUE)

  # detailed itineraries via public transport cannot be computed on frequencies-based GTFS
  if (mode_list$transit_mode != "" & r5r_network$hasFrequencies()) {
    stop(
      "Assertion on 'r5r_network' failed: None of the GTFS feeds used to create ",
      "the transit network can contain a 'frequencies' table. Try using ",
      "gtfstools::frequencies_to_stop_times() to create a suitable feed."
    )
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
  shortest_path <- assign_shortest_path(shortest_path)
  drop_geometry <- assign_drop_geometry(drop_geometry)
  osm_link_ids <- assign_osm_link_ids(osm_link_ids, drop_geometry)

  set_time_window(r5r_network, time_window)
  set_monte_carlo_draws(
    r5r_network,
    1,
    time_window,
    mcraptor = mode_list$transit_mode != "" &&
      !(shortest_path && is.null(fare_structure))
  )
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
  set_suboptimal_minutes(
    r5r_network,
    suboptimal_minutes,
    fare_structure,
    shortest_path
  )

  # SCENARIOS -------------------------------------------
  set_new_congestion(r5r_network, new_carspeeds, carspeed_scale)
  set_new_lts(r5r_network, new_lts)

  # the fastest trip without fares is routed with R5's RAPTOR instead of
  # McRAPTOR; with all_to_all, one search per origin serves all its
  # destinations. Both flags are reset on exit with the other properties
  if (shortest_path && is.null(fare_structure)) {
    r5r_network$setFastRaptor(TRUE)
    r5r_network$setFastRaptorPerOrigin(all_to_all)
  }

  # call r5r_network method and process result -------------------------------

  path_options <- run_routing_job(r5r_network, r5r_network$detailedItineraries(
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
    max_trip_duration,
    drop_geometry,
    shortest_path,
    osm_link_ids
  ), progress)

  if (!is.null(output_dir)) return(output_dir)

  path_options <- java_to_dt(path_options)

  if (!drop_geometry) {
    if (nrow(path_options) > 0) {
      path_options[, geometry := sf::st_as_sfc(geometry)]
    } else {
      path_options[, geometry := sf::st_sfc(sf::st_linestring(), crs = 4326)[0]]
    }

    path_options <- sf::st_sf(path_options, crs = 4326)
  }

  return(path_options)
}
