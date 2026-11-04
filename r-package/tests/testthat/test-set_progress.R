# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

tester <- function(progress) set_progress(r5r_network@jcore, progress)

test_that("input is correct", {
  expect_error(tester("TRUE"))
  expect_error(tester(c(TRUE, TRUE)))
  expect_error(tester(NA))
})

test_that("progress argument works in routing functions", {
  assert_function <- function(f) {
    expr <- if (identical(f, travel_time_matrix)) {
      "f(r5r_network, origins=pois[1:5], destinations=pois[1:5])"
    } else if (identical(f, expanded_travel_time_matrix)) {
      "f(r5r_network, origins=pois[1:5], destinations=pois[1:5])"
    } else if (identical(f, detailed_itineraries)) {
      "f(r5r_network, origins=pois[1:5], destinations=pois[5:1])"
    } else if (identical(f, pareto_frontier)) {
      "f(
        r5r_network,
        origins=pois[1:5],
        destinations=pois[1:5],
        departure_datetime = departure_datetime,
        fare_structure = fare_structure,
        fare_cutoffs = c(0, 5, 10),
        max_trip_duration = 60
      )"
    } else if (identical(f, accessibility)) {
      "f(
        r5r_network=r5r_network,
        origins = points[1:5],
        destinations = points[1:5],
        opportunities_colnames = \"jobs\" ,
        cutoffs = 60
      )"
    } else if (identical(f, isochrone)) {
      "f(r5r_network, origins = pois[1:3], mode = \"WALK\", cutoffs = c(10, 20))"
    }

    progress_expr <- sub("\\)$", ", progress = TRUE\\)", expr)
    non_progress_expr <- sub("\\)$", ", progress = FALSE\\)", expr)

    progress_regex <- "\\d+ out of \\d+ origins processed\\."


    log_file <- file.path(r5r_network@jcore$getLogPath())
    # Clean log before test
    if (file.exists(log_file)) writeLines("", log_file)

    res <- eval(parse(text = progress_expr))
    # Wait a bit to ensure Java flushed the logs
    Sys.sleep(0.2)
    progress_messages <- readLines(log_file)
    expect_true(any(grepl(progress_regex, progress_messages)))

    # reset log again
    writeLines("", log_file)
    res <- eval(parse(text = non_progress_expr))
    # Wait a bit to ensure Java flushed the logs
    Sys.sleep(0.2)
    non_progress_messages <- readLines(log_file)
    expect_false(any(grepl(progress_regex, non_progress_messages)))
  }

  assert_function(travel_time_matrix)
  assert_function(expanded_travel_time_matrix)
  assert_function(detailed_itineraries)
  assert_function(pareto_frontier)
  assert_function(accessibility)
  assert_function(isochrone)
})
