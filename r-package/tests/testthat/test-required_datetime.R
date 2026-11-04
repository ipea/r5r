test_that("departure time is required for transit but optional for direct modes", {
  for (mode in list("TRANSIT", c("WALK", "BUS"))) {
    expect_no_warning(
      expect_error(assign_departure(NULL, assign_mode(mode, "WALK")),
                   "must pass a.*departure_datetime")
    )
  }
  for (mode in c("WALK", "BICYCLE", "CAR")) {
    expect_no_warning(result <- assign_departure(NULL, assign_mode(mode, "WALK")))
    expect_named(result, c("date", "time"))
  }
})

test_that("routing functions reject omitted and NULL transit datetimes without warning", {
  skip_on_cran()
  for (fun in list(travel_time_matrix, expanded_travel_time_matrix,
                   accessibility, detailed_itineraries, pareto_frontier)) {
    args <- list(r5r_network = r5r_network, origins = pois[1:2],
                 destinations = pois[1:2], mode = "TRANSIT", progress = FALSE)
    for (explicit_null in c(FALSE, TRUE)) {
      if (explicit_null) args["departure_datetime"] <- list(NULL)
      expect_no_warning(expect_error(do.call(fun, args), "must pass a.*departure_datetime"))
    }
  }
  for (polygon in c(TRUE, FALSE)) {
    expect_no_warning(expect_error(
      isochrone(r5r_network, origins = pois[1:2], mode = "TRANSIT",
                polygon_output = polygon, progress = FALSE),
      "must pass a.*departure_datetime"
    ))
  }
  expect_no_warning(expect_error(
    travel_time_surface(r5r_network, origins = pois[1:2], mode = "TRANSIT"),
    "must pass a.*departure_datetime"
  ))
})

test_that("arrival time is required for every mode", {
  for (mode in c("TRANSIT", "WALK", "BICYCLE", "CAR")) {
    expect_error(arrival_travel_time_matrix(mode = mode), "arrival_datetime.*required")
    expect_error(arrival_travel_time_matrix(mode = mode, arrival_datetime = NULL),
                 "arrival_datetime.*required")
  }
})
