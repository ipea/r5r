# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

tester <- function(verbose) set_verbose(r5r_network@jcore, verbose)

test_that("input is correct", {
  expect_error(tester("TRUE"))
  expect_error(tester(c(TRUE, TRUE)))
  expect_error(tester(NA))
})

test_that("verbose argument works in routing functions", {
  assert_function <- function(f) {
    expr <- if (identical(f, travel_time_matrix)) {
      "f(r5r_network=r5r_network, origins=pois[1:5], destinations=pois[1:5])"
    } else if (identical(f, expanded_travel_time_matrix)) {
      "f(r5r_network=r5r_network, origins=pois[1:5], destinations=pois[1:5])"
    } else if (identical(f, detailed_itineraries)) {
      "f(r5r_network=r5r_network, origins=pois[1:5], destinations=pois[5:1])"
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
        r5r_network,
        origins=points[1:5],
        destinations=points[1:5],
        opportunities_colnames = \"schools\",
        cutoffs = 60
      )"
    }

    verbose_expr <- sub("\\)$", ", verbose = TRUE\\)", expr)
    non_verbose_expr <- sub("\\)$", ", verbose = FALSE, progress = FALSE\\)", expr)

    info_regex <- "\\[\\s*(INFO|ERROR|WARN)\\s*\\]"

    log_file <- file.path(r5r_network@jcore$getLogPath())
    # Clean log before test
    if (file.exists(log_file)) writeLines("", log_file)

    res <- eval(parse(text = non_verbose_expr))
    # Wait a bit to ensure Java flushed the logs
    Sys.sleep(0.2)
    non_verbose_messages <- readLines(log_file)
    expect_false(any(grepl(info_regex, non_verbose_messages)))

    # reset log again
    writeLines("", log_file)
    res <- eval(parse(text = verbose_expr))
    # Wait a bit to ensure Java flushed the logs
    Sys.sleep(0.2)
    verbose_messages <- readLines(log_file)

    expect_true(any(grepl(info_regex, verbose_messages)))
  }

  assert_function(travel_time_matrix)
  assert_function(expanded_travel_time_matrix)
  assert_function(detailed_itineraries)
  assert_function(pareto_frontier)
  assert_function(accessibility)
})
