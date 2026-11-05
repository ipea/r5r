# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

tester <- function(percentiles) {
  set_percentiles(r5r_network, percentiles)
  }

test_that("input is correct", {
  expect_error(tester("1"))
  expect_error(tester(0))
  expect_error(tester(100))
  expect_error(tester(c(1, 2, 3, 4, 5, 6)))
  expect_error(tester(c(1, 1)))
  expect_error(tester(NA))
  expect_error(tester(Inf))
})

test_that("percentiles are sorted internally", {
  ttm_sorted <- travel_time_matrix(
    r5r_network,
    origins = pois,
    destinations = pois,
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    draws_per_minute = 1,
    time_window = 30,
    max_trip_duration = 60,
    percentiles = c(25, 75)
  )
  ttm_unsorted <- travel_time_matrix(
    r5r_network,
    origins = pois,
    destinations = pois,
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    draws_per_minute = 1,
    time_window = 30,
    max_trip_duration = 60,
    percentiles = c(75, 25)
  )
  expect_identical(
    names(ttm_unsorted),
    c("from_id", "to_id", "travel_time_p25", "travel_time_p75")
  )
  expect_identical(ttm_unsorted, ttm_sorted)
})

test_that("set_percentiles argument works in travel_time_matrix()", {
  basic_expr <- call(
    "travel_time_matrix",
    r5r_network,
    origins=pois,
    destinations=pois,
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    draws_per_minute = 1,
    time_window = 30,
    max_trip_duration = 60
  )

  one_percent_expr <- many_percent_expr <- basic_expr
  one_percent_expr$percentiles <- 50
  many_percent_expr$percentiles <- c(1, 50, 99)

  one_percent <- eval(one_percent_expr)
  one_percent[, c("from_id", "to_id") := NULL]
  expect_true(ncol(one_percent) == 1)
  expect_true(names(one_percent) == "travel_time_p50")
  expect_type(one_percent$travel_time_p50, "integer")

  many_percent <- eval(many_percent_expr)
  many_percent[, c("from_id", "to_id") := NULL]
  expect_true(ncol(many_percent) == 3)
  expect_identical(
    names(many_percent),
    paste0("travel_time_p", c("01", "50", "99"))
  )
  expect_type(many_percent$travel_time_p01, "integer")
  expect_type(many_percent$travel_time_p50, "integer")
  expect_type(many_percent$travel_time_p99, "integer")

  # travel time may be NA if less than x% of the trips between a pair can be
  # completed within max_trip_duration. the lowest percentile can't have any NAs
  # though

  expect_false(any(is.na(many_percent$travel_time_p01)))
  expect_true(any(is.na(many_percent$travel_time_p50)))
  expect_true(any(is.na(many_percent$travel_time_p99)))

  many_percent[is.na(travel_time_p50), travel_time_p50 := 1000]
  many_percent[is.na(travel_time_p99), travel_time_p99 := 1000]
  expect_true(all(many_percent$travel_time_p01 <= many_percent$travel_time_p50))
  expect_true(all(many_percent$travel_time_p50 <= many_percent$travel_time_p99))
})

test_that("set_percentiles argument works in accessibility()", {
  basic_expr <- call(
    "accessibility",
    r5r_network,
    origins=points[1:30],
    destinations=points[1:30],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    opportunities_colnames = "population",
    decay_function = "step",
    cutoffs = 30,
    draws_per_minute = 1,
    time_window = 30,
    max_trip_duration = 60
  )

  one_percent_expr <- many_percent_expr <- basic_expr
  one_percent_expr$percentiles <- 50
  many_percent_expr$percentiles <- c(1, 50, 99)

  one_percent <- eval(one_percent_expr)
  expect_type(one_percent$percentile, "integer")
  expect_true(unique(one_percent$percentile) == 50)

  many_percent <- eval(many_percent_expr)
  expect_type(many_percent$percentile, "integer")
  expect_equal(unique(many_percent$percentile), c(1, 50, 99))

  many_percent <- data.table::dcast(
    many_percent,
    id ~ percentile,
    value.var = "accessibility"
  )
  data.table::setnames(
    many_percent,
    old = as.character(c(1, 50, 99)),
    new = paste0("access_", c(1, 50, 99))
  )
  expect_true(all(many_percent$access_1 >= many_percent$access_50))
  expect_true(all(many_percent$access_50 >= many_percent$access_99))
})

test_that("set_percentiles argument works in pareto_frontier()", {
  basic_expr <- call(
    "pareto_frontier",
    r5r_network,
    origins=points[1:5],
    destinations=points[1:5],
    mode = c("TRANSIT", "WALK"),
    departure_datetime = departure_datetime,
    fare_structure = fare_structure,
    fare_cutoffs = c(0, 5, 10),
    time_window = 30,
    max_trip_duration = 60
  )

  one_percent_expr <- many_percent_expr <- basic_expr
  one_percent_expr$percentiles <- 50
  many_percent_expr$percentiles <- c(1, 50, 99)

  one_percent <- eval(one_percent_expr)
  expect_type(one_percent$percentile, "integer")
  expect_true(unique(one_percent$percentile) == 50)

  many_percent <- eval(many_percent_expr)
  expect_type(many_percent$percentile, "integer")
  expect_equal(unique(many_percent$percentile), c(1, 50, 99))

  # all 0 cost trips must be identical

  zero_cost <- many_percent[monetary_cost == 0]
  zero_cost <- data.table::dcast(
    zero_cost,
    from_id + to_id ~ percentile,
    value.var = "travel_time"
  )
  data.table::setnames(
    zero_cost,
    old = as.character(c(1, 50, 99)),
    new = paste0("travel_time_", c(1, 50, 99))
  )
  expect_identical(zero_cost$travel_time_1, zero_cost$travel_time_50)
  expect_identical(zero_cost$travel_time_50, zero_cost$travel_time_99)

  # each percentile-value defines their own frontiers

  is_pareto_frontier <- function(df) {
    travel_times_decrease <- all(diff(df$travel_time) < 0)
    monetary_costs_increase <- all(diff(df$monetary_cost) > 0)
    return(travel_times_decrease && monetary_costs_increase)
  }

  many_percent <- many_percent[
    ,
    .(data = list(.SD)),
    by = .(from_id, to_id, percentile)
  ]
  many_percent[
    ,
    is_pareto_frontier := vapply(data, is_pareto_frontier, logical(1))
  ]
  expect_true(all(many_percent$is_pareto_frontier))
})
