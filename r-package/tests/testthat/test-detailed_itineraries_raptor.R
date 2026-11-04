context("Detailed itineraries function: shortest path with RAPTOR")

# with shortest_path = TRUE and no fare_structure, detailed_itineraries() routes
# public transport with R5's RAPTOR (FastRaptorWorker) instead of McRAPTOR (#464)

# if running manually, please run the following line first:
# source("tests/testthat/setup.R")

testthat::skip_on_cran()

raptor_tester <- function(origins = pois[1:5, ],
                          destinations = pois[1:5, ],
                          mode = c("WALK", "TRANSIT"),
                          departure_datetime = as.POSIXct("13-05-2019 14:00:00",
                                                          format = "%d-%m-%Y %H:%M:%S"),
                          time_window = 10L,
                          max_trip_duration = 60L,
                          all_to_all = TRUE,
                          shortest_path = TRUE,
                          ...) {
  detailed_itineraries(
    r5r_network,
    origins = origins,
    destinations = destinations,
    mode = mode,
    departure_datetime = departure_datetime,
    time_window = time_window,
    max_trip_duration = max_trip_duration,
    all_to_all = all_to_all,
    shortest_path = shortest_path,
    progress = FALSE,
    ...
  )
}

# one row per pair, the fastest option: total duration, departure time, routes
pair_summary <- function(x) {
  x <- data.table::as.data.table(sf::st_drop_geometry(x))
  x <- x[, .(total_duration = total_duration[1],
             departure_time = departure_time[1],
             routes = paste(route[route != ""], collapse = "|")),
         by = .(from_id, to_id, option)]
  data.table::setorder(x, from_id, to_id, total_duration, departure_time)
  x[, .SD[1], by = .(from_id, to_id)][, option := NULL][]
}

column_classes <- function(x) lapply(sf::st_drop_geometry(x), class)

test_that("the routing flags never outlive a call", {
  expect_error(raptor_tester(mode = "BAD"))
  expect_false(r5r_network@jcore$getFastRaptor())

  invisible(raptor_tester(origins = pois[1, ], destinations = pois[2, ]))
  expect_false(r5r_network@jcore$getFastRaptor())
})

test_that("has the same columns as McRAPTOR itineraries", {
  raptor <- raptor_tester()
  mcraptor <- raptor_tester(shortest_path = FALSE)

  expect_identical(names(raptor), names(mcraptor))
  expect_identical(column_classes(raptor), column_classes(mcraptor))
  expect_true(all(raptor$option == 1L))
  expect_false(any(sf::st_is_empty(raptor)))
  expect_setequal(unique(paste(raptor$from_id, raptor$to_id)),
                  unique(paste(mcraptor$from_id, mcraptor$to_id)))

  ids <- raptor_tester(osm_link_ids = TRUE)
  transit <- ids[ids$route != "", ]
  expect_true(nrow(transit) > 0)
  expect_true(all(transit$board_stop_id != "" & transit$alight_stop_id != ""))
})

test_that("segment durations and waits add up to the total duration", {
  raptor <- data.table::as.data.table(sf::st_drop_geometry(raptor_tester()))
  check <- raptor[, .(diff = abs(sum(segment_duration + wait) - total_duration[1]), n = .N),
                  by = .(from_id, to_id)]
  expect_true(all(check$diff <= 0.05 * check$n + 1e-9))
  expect_true(all(raptor$total_duration <= 60))
})

test_that("is never slower than McRAPTOR departing at the same time", {
  # McRAPTOR departs at random seconds: routed from the same departure time, the
  # fastest RAPTOR trip cannot be slower (both include the 1-minute boarding slack)
  mcraptor <- pair_summary(raptor_tester(shortest_path = FALSE))
  mcraptor <- mcraptor[routes != ""][1:min(.N, 6)]
  expect_true(nrow(mcraptor) > 0)

  for (i in seq_len(nrow(mcraptor))) {
    dep <- as.POSIXct(paste("2019-05-13", mcraptor$departure_time[i]))
    raptor <- pair_summary(raptor_tester(origins = pois[id == mcraptor$from_id[i]],
                                         destinations = pois[id == mcraptor$to_id[i]],
                                         departure_datetime = dep, time_window = 1L))
    expect_lte(raptor$total_duration, mcraptor$total_duration[i] + 0.1)
  }
})

test_that("the time window keeps the fastest of its one-minute departures", {
  # the hexgrid pair has an egress downhill: ranked by the backward egress search
  # times, the 14:09 departure (37.1 min) lost to a slower one at 14:05 (39.4 min)
  od <- list(origins = rbind(pois[1:3, .(id, lat, lon)], points[id == "89a90128253ffff", .(id, lat, lon)]),
             destinations = rbind(pois[4:6, .(id, lat, lon)], points[id == "89a9012803bffff", .(id, lat, lon)]),
             all_to_all = FALSE)
  window <- pair_summary(do.call(raptor_tester, c(od, list(time_window = 10L))))

  minutes <- data.table::rbindlist(lapply(0:9, function(k) {
    pair_summary(do.call(raptor_tester, c(od, list(time_window = 1L,
                                                   departure_datetime = departure_datetime + 60 * k))))
  }))
  data.table::setorder(minutes, from_id, to_id, total_duration, departure_time)
  best <- minutes[, .SD[1], by = .(from_id, to_id)]

  data.table::setkey(window, from_id, to_id)
  data.table::setkey(best, from_id, to_id)
  expect_equal(window$total_duration, best$total_duration)
  expect_equal(window$departure_time, best$departure_time)
  expect_true(all(grepl("^14:0[0-9]:00$", window$departure_time)))
  expect_true("89a90128253ffff" %in% window$from_id)
})

test_that("one search per origin (all_to_all) gives the same trips as one per pair", {
  o <- pois[1:5, ]
  d <- pois[6:10, ]
  per_origin <- raptor_tester(origins = o, destinations = d, all_to_all = TRUE)
  per_pair <- raptor_tester(origins = o[rep(seq_len(.N), each = nrow(d))],
                            destinations = d[rep(seq_len(.N), times = nrow(o))],
                            all_to_all = FALSE)
  expect_true(any(per_origin$route != ""))
  expect_equal(per_origin, per_pair)
})

test_that("results do not depend on runs or threads", {
  run1 <- raptor_tester()
  run2 <- raptor_tester()
  single <- raptor_tester(n_threads = 1)
  expect_equal(run1, run2)
  expect_equal(run1, single)
})

test_that("pairs RAPTOR cannot route fall back to McRAPTOR", {
  # a JVM property makes every RAPTOR itinerary fail
  tester <- function(all_to_all) {
    raptor_tester(destinations = pois[6:10, ], all_to_all = all_to_all)
  }
  expected <- list(tester(TRUE), tester(FALSE))
  rJava::.jcall("java/lang/System", "S", "setProperty", "r5r.failFastRaptor", "true")
  withr::defer(rJava::.jcall("java/lang/System", "S", "clearProperty", "r5r.failFastRaptor"))

  for (i in 1:2) {
    fallback <- tester(i == 1)
    expect_setequal(unique(paste(fallback$from_id, fallback$to_id)),
                    unique(paste(expected[[i]]$from_id, expected[[i]]$to_id)))
    expect_true(any(fallback$route != ""))
    expect_true(all(fallback$option == 1L))
  }
})

test_that("access longer than max_trip_duration does not break routing", {
  # R5 fails a checkState when an access stop is reached after max_trip_duration
  # and the time window has more than one minute
  expect_no_error(
    raptor_tester(origins = pois[1:3, ], destinations = pois[4:6, ], all_to_all = FALSE,
                  max_walk_time = 60L, max_trip_duration = 30L, time_window = 5L)
  )
})
