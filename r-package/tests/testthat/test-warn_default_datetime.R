test_that("warns only when transit relies on the default date-time (#549)", {
  rlang::local_options(rlib_warning_verbosity = "verbose") # shown "regularly" otherwise
  expect_warning(warn_default_datetime("TRANSIT"), "deprecated")
  expect_warning(warn_default_datetime(c("walk", "bus")), "deprecated")
  expect_warning(warn_default_datetime("TRANSIT", "arrival_datetime"), "arrival_datetime")
  expect_no_warning(warn_default_datetime("WALK"))
  expect_no_warning(warn_default_datetime(c("CAR", "BICYCLE")))
})

test_that("routing functions warn before checking transit availability", {
  skip_on_cran()
  rlang::local_options(rlib_warning_verbosity = "verbose")
  # the poa GTFS has no service today, so the call then fails
  expect_warning(
    expect_error(
      travel_time_matrix(r5r_network, origins = pois, destinations = pois, mode = "TRANSIT", progress = FALSE),
      "no transit services"
    ),
    "deprecated"
  )
  expect_no_warning(
    travel_time_matrix(r5r_network, origins = pois[1:2], destinations = pois[1:2], mode = "WALK", progress = FALSE)
  )
})
