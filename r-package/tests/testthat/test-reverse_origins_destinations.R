# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

spo_points2 <- spo_points[2:3,]

npoints <- nrow(spo_points)
npoints2 <- nrow(spo_points2)




# travel_time_matrix -------------------------------------------------------------------

ttm_regular <- travel_time_matrix(
  spo_network,
  origins = spo_points2,
  destinations = spo_points,
  mode = "walk",
  max_trip_duration = 600
)

ttm_reverse <- travel_time_matrix(
  spo_network,
  origins = spo_points,
  destinations = spo_points2,
  mode = "walk",
  bike_speed = 100,
  max_trip_duration = 600
)

testthat::expect_true(length(unique(ttm_regular$from_id)) == npoints2)
testthat::expect_true(length(unique(ttm_regular$to_id)) == npoints)

testthat::expect_true(length(unique(ttm_reverse$from_id)) == npoints)
testthat::expect_true(length(unique(ttm_reverse$to_id)) == npoints2)



# arrival_travel_time_matrix -------------------------------------------------------------------

attm_regular <- arrival_travel_time_matrix(
  spo_network,
  origins = spo_points2,
  destinations = spo_points,
  mode = "walk",
  max_trip_duration = 600
)

attm_reverse <- arrival_travel_time_matrix(
  spo_network,
  origins = spo_points,
  destinations = spo_points2,
  mode = "walk",
  bike_speed = 100,
  max_trip_duration = 600
)

testthat::expect_true(length(unique(attm_regular$from_id)) == npoints2)
testthat::expect_true(length(unique(attm_regular$to_id)) == npoints)

testthat::expect_true(length(unique(attm_reverse$from_id)) == npoints)
testthat::expect_true(length(unique(attm_reverse$to_id)) == npoints2)




# expanded_travel_time_matrix -------------------------------------------------------------------

ettm_regular <- expanded_travel_time_matrix(
  spo_network,
  origins = spo_points2,
  destinations = spo_points,
  mode = "walk",
  bike_speed = 100,
  max_trip_duration = 600
)

ettm_reverse <- expanded_travel_time_matrix(
  spo_network,
  origins = spo_points,
  destinations = spo_points2,
  mode = "walk",
  bike_speed = 100,
  max_trip_duration = 600
)

testthat::expect_true(length(unique(ettm_regular$from_id)) == npoints2)
testthat::expect_true(length(unique(ettm_regular$to_id)) == npoints)

testthat::expect_true(length(unique(ettm_reverse$from_id)) == npoints)
testthat::expect_true(length(unique(ettm_reverse$to_id)) == npoints2)



# output_dir: CSVs must keep the original orientation ---------------------------------------
# the swap is undone only in the in-memory result, so it must not happen when Java writes CSVs

spo_points5 <- spo_points[1:5, ]  # 5 origins > 2 destinations would trigger the swap

check_csv_orientation <- function(fun) {
  out_dir <- tempfile("r5r_reverse_csv_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  fun(
    spo_network,
    origins = spo_points5,
    destinations = spo_points2,
    mode = "walk",
    max_trip_duration = 600,
    output_dir = out_dir
  )

  csv_files <- list.files(out_dir, pattern = "\\.csv$")
  csv <- data.table::rbindlist(lapply(
    file.path(out_dir, csv_files),
    data.table::fread,
    colClasses = list(character = c("from_id", "to_id"))
  ))

  testthat::expect_setequal(csv_files, paste0("from_", spo_points5$id, ".csv"))
  testthat::expect_setequal(unique(csv$from_id), spo_points5$id)
  testthat::expect_true(all(csv$to_id %in% spo_points2$id))
}

check_csv_orientation(travel_time_matrix)
check_csv_orientation(arrival_travel_time_matrix)
check_csv_orientation(expanded_travel_time_matrix)


test_that("walk-only runs with more than 5000 origins skip the swap and work", {
  # spo has no elevation .tif, so the walk-only origin/destination swap applies there
  big <- data.table::rbindlist(rep(list(spo_points[, .(id, lon, lat)]), 16))[1:5001][, id := as.character(.I)]
  r <- expanded_travel_time_matrix(spo_network, big, spo_points[1:3, ], mode = "WALK",
    departure_datetime = departure_datetime, max_trip_duration = 10, time_window = 1,
    n_threads = 2, progress = FALSE)
  expect_true(nrow(r) > 0)
  expect_true(all(r$from_id %in% big$id) && all(r$to_id %in% spo_points$id[1:3]))
})
