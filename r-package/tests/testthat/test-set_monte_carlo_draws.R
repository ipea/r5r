# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

# only one monte carlo draw is performed per minute if the routing function is
# using the fastraptor algorithm and the gtfs feeds used to create the network
# don't include a frequencies table (poa), independently of the value set in
# draws_per_minute. the number of draws is respected when any of the feeds
# include a frequencies table (spo) and when using the mcraptor algorithm
# (i.e. when a fare_structure is set), which samples departure times.

# there's no way to actually know how many draws were performed with these
# functions, so we assume *some* draws are done and the randomization happens
# if the results of the same expression are different in two different
# evaluations

test_that("works in travel_time_matrix() - poa", {
  basic_expr <- call(
    "travel_time_matrix",
    r5r_network = r5r_network,
    origins = pois,
    destinations = pois,
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    max_trip_duration = 60,
    time_window = 30,
    percentiles = c(1, 50, 99)
  )

  small_draws_expr <- big_draws_expr <- basic_expr
  small_draws_expr$draws_per_minute <- 1
  big_draws_expr$draws_per_minute <- 5

  small_draws <- eval(small_draws_expr)
  big_draws <- eval(big_draws_expr)
  expect_identical(small_draws, big_draws)

  mcrap_basic_expr <- basic_expr
  mcrap_basic_expr$fare_structure <- fare_structure
  mcrap_basic_expr$max_fare <- 5
  mcrap_small_draws_expr <- mcrap_big_draws_expr <- mcrap_basic_expr
  mcrap_small_draws_expr$draws_per_minute <- 1
  mcrap_big_draws_expr$draws_per_minute <- 5

  mcrap_small_draws <- eval(mcrap_small_draws_expr)
  mcrap_big_draws <- eval(mcrap_big_draws_expr)
  expect_false(identical(mcrap_small_draws, mcrap_big_draws))
})

test_that("works in travel_time_matrix() - spo", {
  basic_expr <- call(
    "travel_time_matrix",
    r5r_network = spo_network,
    origins = spo_points[51:80],
    destinations = spo_points[51:80],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    max_trip_duration = 60,
    time_window = 30,
    percentiles = c(1, 50, 99)
  )

  small_draws_expr <- big_draws_expr <- basic_expr
  small_draws_expr$draws_per_minute <- 1
  big_draws_expr$draws_per_minute <- 5

  small_draws <- eval(small_draws_expr)
  big_draws <- eval(big_draws_expr)
  expect_false(identical(small_draws, big_draws))

  big_draws2 <- eval(big_draws_expr)
  expect_false(identical(big_draws, big_draws2))
})

test_that("works in accessibility() - poa", {
  basic_expr <- call(
    "accessibility",
    r5r_network = r5r_network,
    origins = points[1:30],
    destinations = points[1:30],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    opportunities_colnames = "population",
    decay_function = "step",
    cutoffs = 30,
    max_trip_duration = 60,
    time_window = 30,
    percentiles = c(1, 50, 99)
  )

  small_draws_expr <- big_draws_expr <- basic_expr
  small_draws_expr$draws_per_minute <- 1
  big_draws_expr$draws_per_minute <- 5

  small_draws <- eval(small_draws_expr)
  big_draws <- eval(big_draws_expr)
  expect_identical(small_draws, big_draws)

  mcrap_basic_expr <- basic_expr
  mcrap_basic_expr$fare_structure <- fare_structure
  mcrap_basic_expr$max_fare <- 5
  mcrap_small_draws_expr <- mcrap_big_draws_expr <- mcrap_basic_expr
  mcrap_small_draws_expr$draws_per_minute <- 1
  mcrap_big_draws_expr$draws_per_minute <- 5

  mcrap_small_draws <- eval(mcrap_small_draws_expr)
  mcrap_big_draws <- eval(mcrap_big_draws_expr)
  expect_false(identical(mcrap_small_draws, mcrap_big_draws))
})

test_that("works in accessibility() - spo", {
  basic_expr <- call(
    "accessibility",
    r5r_network = spo_network,
    origins = spo_points[51:80],
    destinations = spo_points[51:80],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    opportunities_colnames = "opportunities",
    decay_function = "step",
    cutoffs = 30,
    max_trip_duration = 60,
    time_window = 30,
    percentiles = c(1, 50, 99)
  )

  small_draws_expr <- big_draws_expr <- basic_expr
  small_draws_expr$draws_per_minute <- 1
  big_draws_expr$draws_per_minute <- 5

  small_draws <- eval(small_draws_expr)
  big_draws <- eval(big_draws_expr)
  expect_false(identical(small_draws, big_draws))

  big_draws2 <- eval(big_draws_expr)
  expect_false(identical(big_draws, big_draws2))
})

test_that("poa draws_per_minute should fail in pareto_frontier() issue #281", {
  basic_expr <- call(
    "pareto_frontier",
    r5r_network = r5r_network,
    origins = points[1:10],
    destinations = points[1:10],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    max_trip_duration = 60,
    time_window = 30,
    percentiles = c(1, 50, 99),
    fare_structure = fare_structure,
    fare_cutoffs = c(0, 5, 10)
  )

  small_draws_expr <- big_draws_expr <- basic_expr
  small_draws_expr$draws_per_minute <- 1
  big_draws_expr$draws_per_minute <- 5

  expect_error( eval(small_draws_expr) )
  expect_error( eval(big_draws_expr) )

})

test_that("spo draws_per_minute should fail in pareto_frontier() issue #281", {
  basic_expr <- call(
    "pareto_frontier",
    r5r_network = spo_network,
    origins = spo_points[51:80],
    destinations = spo_points[51:80],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    max_trip_duration = 60,
    time_window = 30,
    percentiles = c(1, 50, 99),
    fare_structure = spo_fare_struc,
    fare_cutoffs = c(0, 5, 10, 15, Inf)
  )

  small_draws_expr <- big_draws_expr <- basic_expr
  small_draws_expr$draws_per_minute <- 1
  big_draws_expr$draws_per_minute <- 5

  expect_error( eval(small_draws_expr) )
  expect_error( eval(big_draws_expr) )
})

# R5's McRaptor departure sampler never ends for some combinations (#602).
# A mock network: the check runs before the number of draws is passed to Java
test_that("infeasible draws are rejected with a fare_structure", {
  mock_network <- list(setNumberOfMonteCarloDraws = function(draws) NULL)
  tester <- function(dpm, tw, fs = list()) {
    set_monte_carlo_draws(mock_network, dpm, tw, fare_structure = fs)
  }

  # cases of #602 at time_window = 10
  expect_true(tester(5, 10))
  expect_true(tester(7, 10))
  expect_true(tester(10, 10))
  expect_error(tester(8, 10), "issues/602")
  expect_error(tester(11, 10), "issues/602")
  expect_error(tester(61, 10), "issues/602")

  # the default draws_per_minute fails with long windows
  expect_true(tester(5, 120))
  expect_error(tester(5, 150), "issues/602")
  expect_true(tester(1, 180))

  # without a fare_structure there is no limit
  expect_true(tester(61, 180, fs = NULL))

  # McRaptor rejects exactly 200 draws as an unset UI default
  expect_error(tester(5, 40), class = "r5r_200_draws")
  expect_error(
    set_monte_carlo_draws(mock_network, 1, 200, mcraptor = TRUE),
    class = "r5r_200_draws"
  )
  expect_true(set_monte_carlo_draws(mock_network, 1, 200))
})

test_that("exactly 200 McRaptor draws are rejected before routing (#602)", {
  expect_error(
    pareto_frontier(
      r5r_network,
      origins = points[1:2],
      destinations = points[1:2],
      mode = c("TRANSIT", "WALK"),
      departure_datetime = departure_datetime,
      time_window = 200,
      fare_structure = fare_structure,
      fare_cutoffs = c(0, 5)
    ),
    class = "r5r_200_draws"
  )
  expect_error(
    detailed_itineraries(
      r5r_network,
      origins = points[1:2],
      destinations = points[2:3],
      mode = c("TRANSIT", "WALK"),
      departure_datetime = departure_datetime,
      time_window = 200,
      shortest_path = FALSE
    ),
    class = "r5r_200_draws"
  )
})
