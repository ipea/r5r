testthat::skip_on_cran()

test_that("transit egress reaches the destination with consistent costs and cutoffs", {
  cases <- list(
    list(origin = points[points$id == "89a9012aedbffff", ],
         destination = points[points$id == "89a9012997bffff", ], mode = "WALK", lts = 2L),
    list(origin = points[points$id == "89a90129c4fffff", ],
         destination = points[points$id == "89a90128b4fffff", ], mode = "WALK", lts = 2L),
    list(origin = pois[1, ], destination = points[points$id == "89a901291b7ffff", ],
         mode = "BICYCLE", lts = c(2L, 4L))
  )
  for (shortest in c(TRUE, FALSE)) for (case in cases) for (lts in case$lts) {
    bicycle <- case$mode == "BICYCLE"
    route <- function(limit) detailed_itineraries(
      r5r_network, case$origin, case$destination, mode = c("WALK", "TRANSIT"),
      mode_egress = case$mode, max_lts = lts, shortest_path = shortest, walk_speed = 3.6,
      all_to_all = bicycle, n_threads = 2L, progress = FALSE,
      departure_datetime = as.POSIXct("2019-05-13 14:00:00", tz = "America/Sao_Paulo"),
      time_window = 10L, max_walk_time = if (bicycle) Inf else 53L,
      max_trip_duration = limit
    )
    result <- route(if (bicycle) 120L else 90L)
    expect_gt(nrow(result), 0L)
    if (!nrow(result)) next
    transit_options <- unique(result$option[!result$mode %in% c("WALK", "BICYCLE", "CAR")])
    expect_gt(length(transit_options), 0L) # Direct walks must not hide missing bicycle egress.
    transit <- result[result$option %in% transit_options, ]
    last <- transit[!duplicated(transit$option, fromLast = TRUE), ]
    for (geometry in sf::st_geometry(last)) {
      endpoint <- unclass(geometry)[nrow(geometry), 1:2]
      expect_equal(unname(endpoint), c(case$destination$lon, case$destination$lat), tolerance = 1e-7)
    }
    if (!bicycle) {
      # Approximate cost check for these fixtures: forward street walk + off-street walk.
      snap <- find_snap(r5r_network, case$destination, mode = "WALK")
      linked <- isTRUE(snap$found) && is.finite(snap$distance)
      expect_true(linked)
      if (linked) for (i in seq_len(nrow(last))) {
        start <- unclass(sf::st_geometry(last)[[i]])[1L, 1:2]
        walk <- detailed_itineraries(
          r5r_network, data.frame(id = "alight", lon = start[1], lat = start[2]),
          case$destination, mode = "WALK", walk_speed = 3.6,
          departure_datetime = as.POSIXct("2019-05-13 14:00:00", tz = "America/Sao_Paulo"),
          max_trip_duration = 120L, progress = FALSE
        )
        reached <- nrow(walk) > 0L && all(is.finite(walk$total_duration))
        expect_true(reached)
        if (reached) expect_lte(abs(last$segment_duration[i] - walk$total_duration[1L] -
                                    floor(snap$distance) / 60), 0.15)
      }
    }
    totals <- data.table::as.data.table(result)[,
      .(difference = abs(sum(segment_duration + wait) - total_duration[1L]), tolerance = .N * .1),
      by = option]
    expect_true(all(totals$difference <= totals$tolerance + 1e-8))
    minimum <- min(result$total_duration)
    limit <- as.integer(floor(minimum) + 1L)
    lower <- route(limit)
    expect_gt(nrow(lower), 0L)
    if (nrow(lower)) expect_equal(min(lower$total_duration), minimum)
    expect_true(all(lower$total_duration <= limit + .05))
  }
})
