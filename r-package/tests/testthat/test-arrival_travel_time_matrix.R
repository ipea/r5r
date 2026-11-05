context("Arrival travel time matrix function")

# skips tests on CRAN since they require a specific version of java
testthat::skip_on_cran()

# create testing function

default_tester <- function(r5r_network,
                           origins = points[1:10,],
                           destinations = points[1:10,],
                           mode = "TRANSIT",
                           arrival_datetime = as.POSIXct("13-05-2019 14:00:00",
                                                           format = "%d-%m-%Y %H:%M:%S"),
                           breakdown = FALSE,
                           max_walk_time = Inf,
                           max_bike_time = Inf,
                           max_trip_duration = 120L,
                           walk_speed = 3.6,
                           bike_speed = 12,
                           max_rides = 3,
                           n_threads = Inf,
                           verbose = FALSE,
                           progress=TRUE) {

  results <- arrival_travel_time_matrix(
    r5r_network,
    origins = origins,
    destinations = destinations,
    mode = mode,
    arrival_datetime = arrival_datetime,
    breakdown = breakdown,
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


# errors and warnings -----------------------------------------------------


test_that("adequately raises errors", {

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

  expect_error(default_tester(r5r_network, arrival_datetime = "13-05-2019 14:00:00"))
  expect_error(default_tester(r5r_network, arrival_datetime = numeric_datetime))


  # error with breakdown
  expect_error(default_tester(r5r_network, breakdown ='test'))

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
  expect_true(typeof(result_df_input$total_time) == "double")


  #  * r5r options ----------------------------------------------------------

  result_sf_input <- default_tester(r5r_network, origins_sf, destinations_sf,
                                    verbose = FALSE, progress=TRUE)


  #  * arguments ------------------------------------------------------------


  # expect all travel times to be lower than max_trip_duration

  origins <- destinations <- points[1:10,]
  max_trip_duration <- 60L

  df <- default_tester(r5r_network, origins, destinations, max_trip_duration = max_trip_duration)
  max_duration <- data.table::setDT(df)[, max(total_time, na.rm=T)]

  expect_true(max_duration <= max_trip_duration)



  # expect number of columns to be larger when breakdown = TRUE
  df2 <- default_tester(r5r_network, breakdown =TRUE)
  df3 <- default_tester(r5r_network, breakdown =FALSE)
  expect_true(ncol(df2) > ncol(df3))

  expect_true(typeof(df2$routes) == "character")
  expect_true(typeof(df2$access_time ) == "double")

  # # expect Empty data.table for trips walking and cycling and by car
  #
  # origins <- destinations <- points[1:10,]
  #
  # df <- default_tester(r5r_network, origins = origins, destinations = destinations,
  #                      mode = "WALK")
  # expect_true(nrow(df) == 0)
  #
  # df <- default_tester(r5r_network, origins = origins, destinations = destinations,
  #                      mode = "BICYCLE")
  # expect_true(nrow(df) == 0)
  #
  # df <- default_tester(r5r_network, origins = origins, destinations = destinations,
  #                      mode = "CAR")
  # expect_true(nrow(df) == 0)


})


test_that("using transit outside the gtfs dates throws an error", {
  expect_error(
    default_tester(r5r_network,
                   mode='transit',
                   arrival_datetime = as.POSIXct("13-05-2025 14:00:00",
                                                 format = "%d-%m-%Y %H:%M:%S")
    ),
    "no transit services"
  )
})

test_that("search window follows max_walk_time in walk-only trips", {
  # max_trip_duration is lowered to max_walk_time, so departures must be
  # searched in the 20 minutes before the arrival time
  df <- default_tester(r5r_network, mode = "WALK", max_trip_duration = 120L,
                       max_walk_time = 20)
  expect_true(nrow(df) > 0)
  expect_true(all(df$departure_time >= "13:40:00"))
})

test_that("arrival finds every pair that an earlier departure reaches in time", {
  a <- arrival_travel_time_matrix(r5r_network, pois, pois, mode = c("WALK", "TRANSIT"),
    arrival_datetime = departure_datetime, max_trip_duration = 60, n_threads = 2, progress = FALSE)
  e <- expanded_travel_time_matrix(r5r_network, pois, pois, mode = c("WALK", "TRANSIT"),
    departure_datetime = departure_datetime - 3600, max_trip_duration = 60, time_window = 60,
    n_threads = 2, progress = FALSE)[!is.na(total_time)]
  e[, arr := as.numeric(as.difftime(departure_time, format = "%H:%M:%S", units = "secs")) + total_time * 60]
  # 30 s margin: expanded's total_time is a sum of parts rounded to 0.1 min
  strict <- unique(e[arr <= 14 * 3600 - 30, .(from_id, to_id)])
  expect_equal(nrow(data.table::fsetdiff(strict, unique(a[, .(from_id, to_id)]))), 0)
})
