#' @param time_window An integer. The time window in minutes. Departures are
#'   simulated every minute from `departure_datetime` until `time_window`
#'   minutes later, and travel times are summarized over these departures using
#'   `percentiles` (the median by default). With a `fare_structure`, and always
#'   in [pareto_frontier()], departures are instead sampled at random within
#'   the window: `draws_per_minute` per minute on average (one in
#'   [pareto_frontier()]), different for each origin and the same in every call
#'   from the same origin with the same `seed`.
#'   Defaults to 10. See `vignette("time_window", package = "r5r")`.
