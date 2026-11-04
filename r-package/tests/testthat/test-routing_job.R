# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

jcore <- r5r_network@jcore

ttm_walk <- function(...) {
  travel_time_matrix(
    r5r_network,
    origins = pois,
    destinations = pois,
    mode = "WALK",
    departure_datetime = departure_datetime,
    max_trip_duration = 60,
    ...
  )
}

test_that("background job gives the same result as a synchronous call", {
  async <- ttm_walk(progress = TRUE)

  old <- options(r5r.async = FALSE)
  on.exit(options(old), add = TRUE)
  sync <- ttm_walk(progress = FALSE)

  expect_identical(async, sync)
})

test_that("job counts origins", {
  res <- travel_time_matrix(r5r_network, pois[1:5], pois[1:5], mode = "WALK",
                            departure_datetime = departure_datetime,
                            max_trip_duration = 60, progress = FALSE)
  expect_identical(jcore$getJobTotal(), 5L)
  expect_identical(jcore$getJobProcessed(), 5L)
})

test_that("an error inside the job becomes an R error", {
  on.exit(jcore$resetRoutingProperties(), add = TRUE)
  expect_error(
    run_routing_job(
      jcore,
      jcore$travelTimeMatrix(
        pois$id, pois$lat, pois$lon, pois$id, pois$lat, pois$lon,
        "WALK", "", "WALK", "WALK", "bad-date", "14:00:00",
        30L, 30L, 30L, 60L
      ),
      progress = FALSE
    ),
    "bad-date"
  )
  # the next call works
  expect_gt(nrow(ttm_walk(progress = FALSE)), 0)
})

test_that("an interrupted call cancels its job", {
  long_call <- function() {
    setTimeLimit(elapsed = 1, transient = TRUE)
    on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
    travel_time_matrix(r5r_network, points, points, mode = c("WALK", "TRANSIT"),
                       departure_datetime = departure_datetime,
                       time_window = 60, max_trip_duration = 120,
                       progress = FALSE)
  }
  res <- tryCatch(long_call(), error = function(e) e)
  if (!inherits(res, "error")) skip("routing finished before the time limit")

  expect_match(conditionMessage(res), "time limit")
  expect_lt(jcore$getJobProcessed(), jcore$getJobTotal())

  # the next call returns complete results
  old <- options(r5r.async = FALSE)
  on.exit(options(old), add = TRUE)
  expected <- ttm_walk(progress = FALSE)
  options(old)
  expect_identical(ttm_walk(progress = FALSE), expected)
})
