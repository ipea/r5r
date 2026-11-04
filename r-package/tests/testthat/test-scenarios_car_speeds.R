


# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

# TODO
# test if setting max_speed to 0 closes the road

# data.frame with new speed info
edge_speeds <- read.csv(file.path(data_path, "poa_osm_congestion.csv"))

# sf with congestion polygons
congestion_poly <- readRDS(file.path(data_path, "poa_poly_congestion.rds"))
congestion_poly$scale <- c(0.2, 0.5)

# get origin and destination points in a single road
network <- r5r::street_network_to_sf(r5r_network)

point_orig <- network$vertices |>
  dplyr::filter(index == 18050 ) |> # 7772
  sfheaders::sf_to_df() |>
  dplyr::select(id=sfg_id, lon=x, lat=y)

point_dest <- network$vertices |>
  dplyr::filter(index == 16844 )  |> #8128
  sfheaders::sf_to_df() |>
  dplyr::select(id=sfg_id, lon=x, lat=y)

point_orig$id <- as.character(point_orig$id)
point_dest$id <- as.character(point_dest$id)

meta_fun <- function(
    fun = r5r::travel_time_matrix,
    new_carspeeds= NULL,
    carspeed_scale = 1,
    point_origg = point_orig,
    point_destt = point_dest){

      fun(
        r5r_network = r5r_network,
        origins = point_origg,
        destinations = point_destt,
        mode = 'car',
        departure_datetime = Sys.time(),
        max_trip_duration = 60,
        new_carspeeds = new_carspeeds,
        carspeed_scale = carspeed_scale
      )
  }



# car speeds with osm ids -------------------------------------------------------------------
test_that("success in increasing travel times with osm ids", {

  # calculate travel times / access *before* changing road speeds
  ttm_pre <- meta_fun(r5r::travel_time_matrix)
  expanded_ttm_pre <- meta_fun(r5r::expanded_travel_time_matrix)
  det_pre <- meta_fun(r5r::detailed_itineraries)
  arrival_ttm_pre <- r5r::arrival_travel_time_matrix(
    r5r_network = r5r_network,
    origins = point_orig,
    destinations = point_dest,
    mode = 'car',
    arrival_datetime = Sys.time(),
    max_trip_duration = 60
    )
  # to do: r5r::accessibility
  # plot(det_pre['total_duration'])
  # mapview::mapview(network$edges) + network$vertices + det_pre
  # mapview::mapview(network$edges) + det_pre

  # changing CARSPEED_SCALE without changing new_carspeeds
  ttm_pos <- meta_fun(r5r::travel_time_matrix, carspeed_scale = 0.1)
  expanded_ttm_pos <- meta_fun(r5r::expanded_travel_time_matrix, carspeed_scale = 0.1)
  det_pos <- meta_fun(r5r::detailed_itineraries, carspeed_scale = 0.5)
  arrival_ttm_pos <- r5r::arrival_travel_time_matrix(
    r5r_network = r5r_network,
    origins = point_orig,
    destinations = point_dest,
    mode = 'car',
    arrival_datetime = Sys.time(),
    max_trip_duration = 60,
    carspeed_scale = 0.1
  )


  #  mapview::mapview(det_pre) + det_pos

  # checking for longer travel times
  testthat::expect_true(ttm_pos$travel_time_p50 > ttm_pre$travel_time_p50)
  testthat::expect_true(all(expanded_ttm_pos$total_time > expanded_ttm_pre$total_time))
  testthat::expect_true(arrival_ttm_pos$total_time > arrival_ttm_pre$total_time)
  testthat::expect_true(det_pos$total_duration > det_pre$total_duration)
  # testthat::expect_true(det_pos$total_distance == det_pre$total_distance)

  # setting NEW_CARSPEEDS without changing carspeed_scale
  fast_carspeeds <- data.frame(osm_id = c(450002312, 390862071), max_speed = 1.5, speed_type = "scale")
  ttm_3 <- meta_fun(r5r::travel_time_matrix, new_carspeeds = fast_carspeeds)
  testthat::expect_true(ttm_3$travel_time_p50 < ttm_pre$travel_time_p50)

  # test closing road with speed = 0"
  closed_road <- data.frame(osm_id = 450002312, max_speed = 0, speed_type = "scale")
  det_closed <- meta_fun(r5r::detailed_itineraries, new_carspeeds = closed_road)
  testthat::expect_true(det_closed$total_duration > det_pre$total_duration)
  # mapview::mapview(det_closed) + det_pre

})



# car speeds with polygons -------------------------------------------------------------------
test_that("success in increasing travel times with polygons", {

  # calculate travel times / access *before* changing road speeds
  ttm_pre <- meta_fun(r5r::travel_time_matrix,
                      point_origg = pois[1], point_destt = pois[12])
  expanded_ttm_pre <- meta_fun(r5r::expanded_travel_time_matrix,
                               point_origg = pois[1], point_destt = pois[12])
  det_pre <- meta_fun(r5r::detailed_itineraries,
                      point_origg = pois[1], point_destt = pois[12])
  arrival_ttm_pre <- r5r::arrival_travel_time_matrix(
    r5r_network = r5r_network,
    origins = pois[1],
    destinations = pois[12],
    mode = 'car',
    arrival_datetime = Sys.time(),
    max_trip_duration = 60
  )
  # to do: r5r::accessibility
  # plot(det_pre['total_duration'])
  # mapview::mapview(network$edges) + network$vertices + det

  # changing CARSPEED_SCALE without changing new_carspeeds
  ttm_pos <- meta_fun(r5r::travel_time_matrix, new_carspeeds = congestion_poly,
                      point_origg = pois[1], point_destt = pois[12])
  expanded_ttm_pos <- meta_fun(r5r::expanded_travel_time_matrix, new_carspeeds = congestion_poly,
                               point_origg = pois[1], point_destt = pois[12])
  det_pos <- meta_fun(r5r::detailed_itineraries, new_carspeeds = congestion_poly,
                      point_origg = pois[1], point_destt = pois[12])
  arrival_ttm_pos <- r5r::arrival_travel_time_matrix(
    r5r_network = r5r_network,
    origins = pois[1],
    destinations = pois[12],
    mode = 'car',
    arrival_datetime = Sys.time(),
    max_trip_duration = 60,
    new_carspeeds = congestion_poly
  )


  #  mapview::mapview(det_pre) + det_pos

  # checking for longer travel times
  testthat::expect_true(ttm_pos$travel_time_p50 > ttm_pre$travel_time_p50)
  testthat::expect_true(all(expanded_ttm_pos$total_time > expanded_ttm_pre$total_time))
  testthat::expect_true(arrival_ttm_pos$total_time > arrival_ttm_pre$total_time)
  testthat::expect_true(det_pos$total_duration > det_pre$total_duration)
  # testthat::expect_true(det_pos$total_distance == det_pre$total_distance)

  # setting carspeed_scale without changing NEW_CARSPEEDS
  ttm_3 <- meta_fun(r5r::travel_time_matrix, carspeed_scale =  1.3)
  testthat::expect_true(ttm_3$travel_time_p50 < ttm_pre$travel_time_p50)
})

# errors in congestion polygon -------------------------------------------------------------------
test_that("errors in congestion polygon", {

  # wrong col names
  wrong_congestion_poly1 <- congestion_poly
  names(wrong_congestion_poly1) <- c("poly_id", "speed", "priority", "geometry")
  testthat::expect_error(meta_fun(new_carspeeds = wrong_congestion_poly1))

  # missing col
  wrong_congestion_poly2 <- congestion_poly
  wrong_congestion_poly2$poly_id <- NULL
  testthat::expect_error(meta_fun(new_carspeeds = wrong_congestion_poly2))

  # # Wrong geometry type
  # wrong_congestion_poly3 <- congestion_poly
  # wrong_congestion_poly3 <- sf::st_cast(wrong_congestion_poly3, to = 'MULTIPOINT')
  # testthat::expect_error(meta_fun(new_carspeeds = wrong_congestion_poly3))

  # Wrong projection
  wrong_congestion_poly4 <- sf::st_transform(congestion_poly, 3857)
  testthat::expect_error(meta_fun(new_carspeeds = wrong_congestion_poly4))

  })


test_that("errors due to incorrect input types", {

  testthat::expect_error(meta_fun(new_carspeeds = 'banana'))
  testthat::expect_error(meta_fun(carspeed_scale = 'banana'))

})


test_that("errors error in the new_carspeeds column names", {

  mock_data <- data.frame(osm_id = '27184648', max_speed = 10, speed_type="banana")
  testthat::expect_error(meta_fun(new_carspeeds =  mock_data))

  mock_data <- data.frame(my_osm_id = '9999', max_speed = 9999, speed_type="km/h")
  testthat::expect_error(meta_fun(new_carspeeds =  mock_data))

  testthat::expect_error(meta_fun(carspeed_scale = Inf))
  testthat::expect_error(meta_fun(carspeed_scale = -1))

})


test_that("message for missing OSM ids", {

  mock_data <- data.frame(osm_id = 45698769, max_speed = 100, speed_type="km/h")
  log_file <- file.path(r5r_network@jcore$getLogPath())
  expect_true(file.exists(log_file), info = paste("Log file not found at", log_file))

  meta_fun(new_carspeeds = mock_data)
  log <- readLines(log_file, warn = FALSE)
  expect_true(
    any(grepl("45698769", log, fixed = TRUE)),
    info = "Did not find warning for a bad OSM Id in log"
  )
})


test_that("a failed scenario call does not leak into the next call", {
  plain_car <- function(...) {
    travel_time_matrix(
      r5r_network,
      origins = points[1:20, ],
      destinations = points[1:20, ],
      mode = "CAR",
      departure_datetime = departure_datetime,
      ...
    )
  }

  baseline <- plain_car()

  # carspeed_scale is applied before new_lts fails validation (lts not integer)
  bad_lts <- data.frame(osm_id = 27184648, lts = 1.5)
  expect_error(suppressWarnings(suppressMessages(
    plain_car(carspeed_scale = 0.3, new_lts = bad_lts)
  )))

  expect_identical(plain_car(), baseline)
})
