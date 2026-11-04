context("Pareto frontier function")

# skips tests on CRAN since they require a specific version of java
testthat::skip_on_cran()

# create testing function

default_tester <- function(r5r_network,
                           origins = points[1:10,],
                           destinations = points[1:10,],
                           mode = "TRANSIT",
                           departure_datetime = as.POSIXct("13-05-2019 14:00:00",
                                                           format = "%d-%m-%Y %H:%M:%S"),
                           time_window = 1L,
                           percentiles = 50,
                           fare_structure = poa_fare_structure,
                           fare_cutoffs = 0L,
                           max_walk_time = Inf,
                           max_bike_time = Inf,
                           max_trip_duration = 120L,
                           walk_speed = 3.6,
                           bike_speed = 12,
                           max_rides = 3,
                           n_threads = Inf,
                           verbose = FALSE,
                           progress=TRUE) {

  results <- pareto_frontier(
    r5r_network,
    origins = origins,
    destinations = destinations,
    mode = mode,
    departure_datetime = departure_datetime,
    time_window = time_window,
    percentiles = percentiles,
    fare_structure = fare_structure,
    fare_cutoffs = fare_cutoffs,
    max_walk_time = max_walk_time,
    max_bike_time = max_bike_time,
    max_trip_duration = max_trip_duration,
    walk_speed = walk_speed,
    bike_speed = bike_speed,
    max_rides = max_rides,
    n_threads = n_threads,
    verbose = verbose
  )

  return(results)

}

# load fare calculator object
fare_structure_path <- system.file("extdata/poa/fares/fares_poa.zip",
                                    package = "r5r")
poa_fare_structure <- r5r::read_fare_structure(fare_structure_path)

# errors and warnings -----------------------------------------------------


test_that("adequately raises errors", {

  # errors related to missing fare_structure / fare_cutoffs
  dep <- as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S")
  expect_error(
    pareto_frontier(r5r_network, points[1:2, ], points[1:2, ], departure_datetime = dep, fare_cutoffs = 0),
    "fare_structure"
  )
  expect_error(default_tester(r5r_network, fare_structure = NULL), "fare_structure")
  expect_error(
    pareto_frontier(r5r_network, points[1:2, ], points[1:2, ], departure_datetime = dep,
                    fare_structure = poa_fare_structure),
    "fare_cutoffs"
  )
  expect_error(default_tester(r5r_network, fare_cutoffs = -1))

  # error related to using object with wrong type as r5r_network
  expect_error(default_tester("r5r_network"))

  # error related to using wrong origins/destinations object type
  multipoint_origins      <- sf::st_cast(sf::st_as_sf(points[1:2,], coords = c("lon", "lat")), "MULTIPOINT")
  multipoint_destinations <- multipoint_origins
  list_origins      <- list(id = c("1", "2"), lat = c(-30.02756, -30.02329), long = c(-51.22781, -51.21886))
  list_destinations <- list_origins

  expect_error(default_tester(r5r_network, origins = multipoint_origins))
  expect_error(default_tester(r5r_network, destinations = multipoint_destinations))
  expect_error(default_tester(r5r_network, origins = list_origins))
  expect_error(default_tester(r5r_network, destinations = list_destinations))
  expect_error(default_tester(r5r_network, origins = "origins"))
  expect_error(default_tester(r5r_network, destinations = "destinations"))

  # error/warning related to using wrong origins/destinations column types
  origins <- destinations <- points[1:2, ]

  origins_char_lat   <- data.frame(id = origins$id, lat = as.character(origins$lat), lon = origins$lon)
  origins_char_lon   <- data.frame(id = origins$id, lat = origins$lat, lon = as.character(origins$lon))
  destinations_char_lat   <- data.frame(id = destinations$id, lat = as.character(destinations$lat), lon = destinations$lon)
  destinations_char_lon   <- data.frame(id = destinations$id, lat = destinations$lat, lon = as.character(destinations$lon))

  expect_error(default_tester(r5r_network, origins = origins_char_lat))
  expect_error(default_tester(r5r_network, origins = origins_char_lon))
  expect_error(default_tester(r5r_network, destinations = destinations_char_lat))
  expect_error(default_tester(r5r_network, destinations = destinations_char_lon))

  # error related to nonexistent mode
  expect_error(default_tester(r5r_network, mode = "pogoball"))

  # errors related to date formatting
  numeric_datetime <- as.numeric(as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S"))

  expect_error(default_tester(r5r_network, departure_datetime = "13-05-2019 14:00:00"))
  expect_error(default_tester(r5r_network, numeric_datetime))

  # errors related to max_walk_time
  expect_error(default_tester(r5r_network, max_walk_time = "1000"))
  expect_error(default_tester(r5r_network, max_walk_time = NULL))

  # errors related to max_bike_time
  expect_error(default_tester(r5r_network, max_bike_time = "1000"))
  expect_error(default_tester(r5r_network, max_bike_time = NULL))

  # error/warning related to max_street_time
  expect_error(default_tester(r5r_network, max_trip_duration = "120"))

  # error related to non-numeric walk_speed
  expect_error(default_tester(r5r_network, walk_speed = "3.6"))

  # error related to non-numeric bike_speed
  expect_error(default_tester(r5r_network, bike_speed = "12"))

  # error related to too many or invalid percentiles
  expect_error(default_tester(r5r_network, percentiles = .3))
  expect_error(default_tester(r5r_network, percentiles = 1:6))

})

test_that("adequately raises warnings - needs java", {

  # error/warning related to using wrong origins/destinations column types
  origins <- destinations <- points[1:2, ]

  origins_numeric_id <- data.frame(id = 1:2, lat = origins$lat, lon = origins$lon)
  destinations_numeric_id <- data.frame(id = 1:2, lat = destinations$lat, lon = destinations$lon)

  expect_warning(default_tester(r5r_network, origins = origins_numeric_id))
  expect_warning(default_tester(r5r_network, destinations = destinations_numeric_id))


})


# adequate behaviour ------------------------------------------------------


test_that("output is correct", {

  #  * output class ---------------------------------------------------------


  # expect results to be of class 'data.table', independently of the class of
  # 'origins'/'destinations'

  origins_sf <- destinations_sf <- sf::st_as_sf(
    points[1:10, ],
    coords = c("lon", "lat"),
    crs = 4326
  )

  result_df_input <- default_tester(r5r_network)
  result_sf_input <- default_tester(r5r_network, origins_sf, destinations_sf)

  expect_true(is(result_df_input, "data.table"))
  expect_true(is(result_sf_input, "data.table"))

  # expect each column to be of right class

  expect_true(typeof(result_df_input$from_id) == "character")
  expect_true(typeof(result_df_input$to_id) == "character")
  expect_true(typeof(result_df_input$travel_time ) == "integer")


  #  * r5r options ----------------------------------------------------------

  result_sf_input <- default_tester(r5r_network, origins_sf, destinations_sf,
                                    verbose = FALSE, progress=TRUE)


  #  * arguments ------------------------------------------------------------


  # expect all travel times to be lower than max_trip_duration

  origins <- destinations <- points[1:10,]

  max_trip_duration <- 60L

  df <- default_tester(r5r_network, origins, destinations, max_trip_duration = max_trip_duration)
  max_duration <- data.table::setDT(df)[, max(travel_time)]

  expect_true(max_duration <= max_trip_duration)

  # expect number of rows to be lower than or equal to nrow(origins) * nrow(destinations)

  max_trip_duration <- 300L

  df <- default_tester(r5r_network, origins, destinations, max_trip_duration = max_trip_duration)
  n_rows <- nrow(df)

  expect_true(n_rows <= nrow(origins) * nrow(destinations))

})


test_that("using transit outside the gtfs dates throws an error", {
  expect_error(
    default_tester(r5r_network,
           mode='transit',
           departure_datetime = as.POSIXct("13-05-2025 14:00:00",
                                           format = "%d-%m-%Y %H:%M:%S")
    )
  )
})
