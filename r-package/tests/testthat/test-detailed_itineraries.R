context("Detailed itineraries function")

# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

default_tester <- function(r5r_network,
                           origins = points[1:2, ],
                           destinations = points[2:1, ],
                           mode = c("WALK", "TRANSIT"),
                           departure_datetime = as.POSIXct("13-05-2019 14:00:00",
                                                           format = "%d-%m-%Y %H:%M:%S"),
                           max_walk_time = Inf,
                           max_bike_time = Inf,
                           max_trip_duration = 120L,
                           walk_speed = 3.6,
                           bike_speed = 12,
                           max_rides = 3,
                           shortest_path = TRUE,
                           n_threads = Inf,
                           verbose = FALSE,
                           drop_geometry = FALSE,
                           osm_link_ids = FALSE) {

 results <- detailed_itineraries(
   r5r_network,
   origins = origins,
   destinations = destinations,
   mode = mode,
   departure_datetime = departure_datetime,
   max_walk_time = max_walk_time,
   max_bike_time = max_bike_time,
   max_trip_duration = max_trip_duration,
   walk_speed = walk_speed,
   bike_speed = bike_speed,
   max_rides = max_rides,
   shortest_path = shortest_path,
   n_threads = n_threads,
   verbose = verbose,
   drop_geometry = drop_geometry,
   osm_link_ids = osm_link_ids
 )

 return(results)

}


# errors and warnings -----------------------------------------------------


test_that("detailed_itineraries adequately raises errors", {

  # error related to using object with wrong type as r5r_network
  expect_error(default_tester("r5r_network"))

  # error related to using wrong origins/destinations object type
  multipoint_origins      <- sf::st_cast(sf::st_as_sf(points[1:2,], coords = c("lon", "lat")), "MULTIPOINT")
  multipoint_destinations <- sf::st_cast(sf::st_as_sf(points[2:1,], coords = c("lon", "lat")), "MULTIPOINT")
  list_origins      <- list(id = c("1", "2"), lat = c(-30.02756, -30.02329), long = c(-51.22781, -51.21886))
  list_destinations <- list(id = c("2", "1"), lat = c(-30.02329, -30.02756), long = c(-51.21886, -51.22781))

  expect_error(default_tester(r5r_network, origins = multipoint_origins))
  expect_error(default_tester(r5r_network, destinations = multipoint_destinations))
  expect_error(default_tester(r5r_network, origins = list_origins))
  expect_error(default_tester(r5r_network, destinations = list_destinations))
  expect_error(default_tester(r5r_network, origins = "origins"))
  expect_error(default_tester(r5r_network, destinations = "destinations"))

  # error related to using wrong origins/destinations column types
  origins <- points[1:2, ]
  destinations <- points[2:1, ]

  origins_char_lat   <- data.frame(id = origins$id, lat = as.character(origins$lat), lon = origins$lon)
  origins_char_lon   <- data.frame(id = origins$id, lat = origins$lat, lon = as.character(origins$lon))
  destinations_char_lat   <- data.frame(id = destinations$id, lat = as.character(destinations$lat), lon = destinations$lon)
  destinations_char_lon   <- data.frame(id = destinations$id, lat = destinations$lat, lon = as.character(destinations$lon))

  expect_error(default_tester(r5r_network, origins = origins_char_lat))
  expect_error(default_tester(r5r_network, origins = origins_char_lon))
  expect_error(default_tester(r5r_network, destinations = destinations_char_lat))
  expect_error(default_tester(r5r_network, destinations = destinations_char_lon))

  # error related to 'origins' and 'destinations' with distinct number of rows
  expect_error(default_tester(r5r_network, origins = points[1:3,], destinations = points[2:1,]))
  expect_error(default_tester(r5r_network, origins = points[2:1,], destinations = points[1:3,]))

  # error related to nonexistent mode
  expect_error(default_tester(r5r_network, mode = "all"))

  # errors related to date formatting
  numeric_datetime <- as.numeric(as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"))

  expect_error(default_tester(r5r_network, departure_datetime = "13-05-2019 14:00:00"))
  expect_error(default_tester(r5r_network, departure_datetime = numeric_datetime))

  # errors related to max_walk_time
  expect_error(default_tester(r5r_network, max_walk_time = "1"))
  expect_error(default_tester(r5r_network, max_walk_time = NULL))

  # errors related to max_bike_time
  expect_error(default_tester(r5r_network, max_bike_time = "1"))
  expect_error(default_tester(r5r_network, max_bike_time = NULL))

    # error/warning related to max_street_time
  expect_error(default_tester(r5r_network, max_trip_duration = "120"))

  # error related to non-numeric walk_speed
  expect_error(default_tester(r5r_network, walk_speed = "3.6"))

  # error related to non-numeric bike_speed
  expect_error(default_tester(r5r_network, bike_speed = "12"))

  # error related to non-logical shortest_path
  expect_error(default_tester(r5r_network, shortest_path = "TRUE"))
  expect_error(default_tester(r5r_network, shortest_path = 1))
  expect_error(default_tester(r5r_network, shortest_path = NULL))

  # error related to non-logical verbose
  expect_error(default_tester(r5r_network, verbose = "TRUE"))
  expect_error(default_tester(r5r_network, verbose = 1))
  expect_error(default_tester(r5r_network, verbose = NULL))

  # error related to non-logical drop_geometry
  expect_error(default_tester(r5r_network, drop_geometry = "TRUE"))
  expect_error(default_tester(r5r_network, drop_geometry = 1))

  # error related to non-logical osm_link_ids
  expect_error(default_tester(r5r_network, osm_link_ids = "TRUE"))
  expect_error(default_tester(r5r_network, osm_link_ids = 1))
  expect_error(default_tester(r5r_network, osm_link_ids = TRUE, drop_geometry=TRUE))

  })

test_that("detailed_itineraries adequately raises warnings and messages", {

  # message related to expanding origins/destinations dataframe
  expect_message(default_tester(r5r_network, origins = points[1, ]))
  expect_message(default_tester(r5r_network, destinations = points[1, ]))

  # error/warning related to using wrong origins/destinations column types
  origins <- points[1:2, ]
  destinations <- points[2:1, ]

  origins_numeric_id <- data.frame(id = 1:2, lat = origins$lat, lon = origins$lon)
  destinations_numeric_id <- data.frame(id = 1:2, lat = destinations$lat, lon = destinations$lon)

  expect_warning(default_tester(r5r_network, origins = origins_numeric_id))
  expect_warning(default_tester(r5r_network, destinations = destinations_numeric_id))


})


# adequate behaviour ------------------------------------------------------


test_that("detailed_itineraries output is correct", {

  #  * output class ---------------------------------------------------------


  # expect results to be of class 'sf' and 'data.table', independently of the
  # class of 'origins'/'destinations', when drop_geometry = FALSE

  origins_sf <- sf::st_as_sf(
    points[1:2,],
    coords = c("lon", "lat"),
    crs = 4326
  )
  destinations_sf <- sf::st_as_sf(
    points[2:1,],
    coords = c("lon", "lat"),
    crs = 4326
  )

  result_df_input <- default_tester(r5r_network)
  result_sf_input <- default_tester(r5r_network, origins_sf, destinations_sf)

  expect_true(is(result_df_input, "sf"))
  expect_true(is(result_df_input, "data.table"))
  expect_true(is(result_sf_input, "sf"))
  expect_true(is(result_sf_input, "data.table"))

  # expect results to be of class 'data.table', but not 'sf', independently of
  # the class of 'origins'/'destinations', when drop_geometry = TRUE

  result_df_input <- default_tester(r5r_network, drop_geometry = TRUE)
  result_sf_input <- default_tester(r5r_network, origins_sf, destinations_sf, drop_geometry = TRUE)

  expect_false(is(result_df_input, "sf"))
  expect_true(is(result_df_input, "data.table"))
  expect_false(is(result_sf_input, "sf"))
  expect_true(is(result_sf_input, "data.table"))

  # bring osm ids
  result_df_input_ids <- default_tester(r5r_network,
                                        osm_link_ids = TRUE,
                                        drop_geometry = FALSE)

  expect_true(
    all(c('edge_id_list', 'board_stop_id', 'alight_stop_id') %in% names(result_df_input_ids))
    )



  # expect each column to be of right class
  expect_true(typeof(result_df_input$from_id) == "character")
  expect_true(typeof(result_df_input$from_lat) == "double")
  expect_true(typeof(result_df_input$from_lon) == "double")
  expect_true(typeof(result_df_input$to_id) == "character")
  expect_true(typeof(result_df_input$to_lat) == "double")
  expect_true(typeof(result_df_input$to_lon) == "double")
  expect_true(typeof(result_df_input$option) == "integer")
  expect_true(typeof(result_df_input$segment) == "integer")
  expect_true(typeof(result_df_input$mode) == "character")
  expect_true(typeof(result_df_input$total_duration) == "double")
  expect_true(typeof(result_df_input$segment_duration) == "double")
  expect_true(typeof(result_df_input$wait) == "double")
  expect_true(typeof(result_df_input$distance) == "integer")
  expect_true(typeof(result_df_input$route) == "character")
  expect_true(typeof(result_df_input_ids$edge_id_list) == "character")
  expect_true(typeof(result_df_input_ids$board_stop_id) == "character")
  expect_true(typeof(result_df_input_ids$alight_stop_id) == "character")


  #  * r5r options ----------------------------------------------------------


  # expect walking segments to be shorter when setting higher walk speeds
  # ps: note that if a very high speed is set then the routes change completely
  # and we lose the ability to use lower walking speeds routes as reference

  origins      <- points[1,]
  destinations <- points[3,]

  df <- default_tester(r5r_network, origins = origins, destinations = destinations, mode = "WALK", walk_speed = 4)
  duration_lower_speed <- data.table::setDT(df)$segment_duration

  df <- default_tester(r5r_network, origins = origins, destinations = destinations, mode = "WALK", walk_speed = 5)
  duration_higher_speed <- data.table::setDT(df)$segment_duration

  expect_true(duration_higher_speed < duration_lower_speed)

  # expect bike segments to be shorter when setting higher cycling speeds
  # ps: same as with walk_speeds

  df <- default_tester(r5r_network, origins = origins, destinations = destinations,
                       mode = "BICYCLE", bike_speed = 12)
  duration_lower_speed <- data.table::setDT(df)$segment_duration

  df <- default_tester(r5r_network, origins = origins, destinations = destinations,
                       mode = "BICYCLE", bike_speed = 13)
  duration_higher_speed <- data.table::setDT(df)$segment_duration

  expect_true(duration_higher_speed < duration_lower_speed)


  #  * arguments ------------------------------------------------------------


  # expect each OD pair to have only option when shortest_path == TRUE

  df <- default_tester(r5r_network, shortest_path = TRUE)
  max_n_options <- data.table::setDT(df)[, length(unique(option)), by = .(from_id, to_id)][, max(V1)]

  expect_true(max_n_options == 1)

  # # expect each OD pair to have (possibly) more than one option when shortest_path == FALSE
  #
  # df <- default_tester(r5r_network, shortest_path = FALSE)
  # max_n_options <- data.table::setDT(df)[, length(unique(option)), by = .(from_id, to_id)][, max(V1)]
  #
  # expect_true(max_n_options > 1)

  # expect all route options to have lower total duration than max_trip_duration

  max_trip_duration <- 60L
  origins <- points[1:15,]
  destinations <- points[15:1,]

  df <- default_tester(r5r_network, origins, destinations,
                       max_trip_duration = max_trip_duration, shortest_path = FALSE)

  expect_true(max(df$total_duration) <= max_trip_duration + 0.1)

  # a transfer walk through a stop with a steep stop-to-street link used to be
  # reported with an elevation-costed duration (40 min for 119 m), pushing this
  # option to 73 min under a 40-min limit
  df <- detailed_itineraries(
    r5r_network,
    origins = pois[pois$id == "gasometer_museum", ],
    destinations = pois[pois$id == "beira_rio_stadium", ],
    mode = c("WALK", "TRANSIT"),
    departure_datetime = as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"),
    time_window = 1,
    max_trip_duration = 40L,
    shortest_path = FALSE,
    drop_geometry = TRUE
  )
  expect_true(max(df$total_duration) <= 40.1)
  totals <- df[, .(legs = sum(segment_duration + wait), total = total_duration[1]), by = option]
  expect_true(all(abs(totals$legs - totals$total) <= 0.3))

  # expect an empty data.table as output when no routes are found between the pairs

  df <- default_tester(r5r_network, origins = points[10,], destinations = points[12,],
                       mode = "WALK", max_trip_duration = 30L)

  expect_true(nrow(df) == 0)

  df <- default_tester(r5r_network, origins = points[10:11,], destinations = points[12,],
                       mode = "WALK", max_trip_duration = 30L)

  expect_true(nrow(df) == 0)

})


test_that("using transit outside the gtfs dates throws an error", {
  expect_error(
    default_tester(r5r_network,
                   mode = "transit",
                   departure_datetime = as.POSIXct("13-05-2025 14:00:00",
                                                   format = "%d-%m-%Y %H:%M:%S")
    ),
    "no transit services"
  )
})

test_that("zero-row inputs return an empty result", {
  expect_equal(nrow(default_tester(r5r_network, origins = points[0, ], destinations = points[1, ])), 0)
  expect_equal(nrow(default_tester(r5r_network, origins = points[1, ], destinations = points[0, ])), 0)
})

test_that("output_dir rejects repeated pairs and ids not allowed in file names", {
  di_to_dir <- function(origins, destinations) {
    detailed_itineraries(
      r5r_network,
      origins = origins,
      destinations = destinations,
      mode = "WALK",
      departure_datetime = as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"),
      output_dir = tempdir()
    )
  }

  expect_error(di_to_dir(points[c(1, 1), ], points[c(2, 2), ]), "must be unique")

  slash_origin <- points[1, ]
  slash_origin$id <- "a/b"
  expect_error(di_to_dir(slash_origin, points[2, ]), "a/b")
})

test_that("output_dir writes CSV files that can be read back", {
  out_dir <- file.path(tempdir(), "di_csv_test")
  unlink(out_dir, recursive = TRUE)
  dir.create(out_dir)

  di <- function(output_dir = NULL) {
    detailed_itineraries(
      r5r_network,
      origins = pois[pois$id == "gasometer_museum", ],
      destinations = pois[pois$id == "beira_rio_stadium", ],
      mode = c("WALK", "TRANSIT"),
      departure_datetime = as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"),
      time_window = 1,
      shortest_path = FALSE,
      osm_link_ids = TRUE,
      output_dir = output_dir
    )
  }
  in_memory <- di()
  di(output_dir = out_dir)

  files <- list.files(out_dir, full.names = TRUE)
  expect_length(files, 1)
  from_csv <- data.table::fread(files, colClasses = list(character = c("osm_id_list", "edge_id_list", "geometry")))

  expect_equal(nrow(from_csv), nrow(in_memory))
  expect_setequal(names(from_csv), names(in_memory))
  expect_equal(sort(from_csv$edge_id_list), sort(in_memory$edge_id_list))
  expect_equal(
    sort(lengths(sf::st_as_sfc(from_csv$geometry))),
    sort(lengths(sf::st_geometry(in_memory)))
  )
})

test_that("transfer walks from stop index 0 follow the street network", {
  # poa_eptc:1000 is the stop with internal index 0; transfers from it used to
  # keep a straight line between the stops, with no edge ids
  df <- detailed_itineraries(
    r5r_network,
    origins = data.frame(id = "o", lat = -30.085368, lon = -51.221805),
    destinations = data.frame(id = "d", lat = -30.094863, lon = -51.24486),
    mode = c("WALK", "TRANSIT"),
    departure_datetime = as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"),
    time_window = 10,
    max_walk_time = 5,
    shortest_path = FALSE,
    suboptimal_minutes = 10,
    osm_link_ids = TRUE
  )
  df <- df[order(df$option, df$segment), ]
  after_stop0 <- which(df$alight_stop_id == "poa_eptc:1000") + 1
  skip_if(length(after_stop0) == 0, "no itinerary transfers at poa_eptc:1000")

  expect_true(all(df$mode[after_stop0] == "WALK"))
  expect_true(all(df$edge_id_list[after_stop0] != "[]"))
  expect_true(all(lengths(sf::st_geometry(df)[after_stop0]) / 2 > 2))
})

test_that("row-paired inputs may repeat ids, all-to-all inputs may not", {
  paired_origins <- points[c(1, 1, 2), ]
  paired_destinations <- points[c(2, 3, 3), ]

  expect_s3_class(
    detailed_itineraries(
      r5r_network,
      origins = paired_origins,
      destinations = paired_destinations,
      departure_datetime = as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"),
      all_to_all = FALSE
    ),
    "sf"
  )
  expect_error(
    detailed_itineraries(
      r5r_network,
      origins = paired_origins,
      destinations = paired_destinations,
      departure_datetime = as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"),
      all_to_all = TRUE
    ),
    regexp = "duplicated ids"
  )
})

test_that("leg geometries have no repeated consecutive vertices", {
  di <- detailed_itineraries(r5r_network, pois[1:5, ], pois[1:5, ], mode = c("WALK", "TRANSIT"),
    departure_datetime = departure_datetime, max_trip_duration = 60, all_to_all = TRUE,
    shortest_path = TRUE, n_threads = 2, progress = FALSE)
  rep_v <- vapply(sf::st_geometry(di), function(g) {
    m <- sf::st_coordinates(g)[, 1:2, drop = FALSE]
    nrow(m) > 2 && any(rowSums(abs(diff(m))) == 0)
  }, logical(1))
  expect_false(any(rep_v))
})
