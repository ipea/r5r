#' @param draws_per_minute An integer. The number of Monte Carlo draws to
#'   perform per minute of `time_window`. Defaults to 5. This would mean 300
#'   draws in a 60-minute time window, for example. With the default routing
#'   algorithm, this parameter only affects the results when the GTFS feeds
#'   contain a `frequencies.txt` table; otherwise, r5r still routes a departure
#'   every minute of `time_window`, in a deterministic way. In functions that
#'   accept a `fare_structure`, passing one switches to the McRaptor algorithm,
#'   which instead routes `time_window * draws_per_minute` departure times
#'   sampled at random within the window (different for each origin, and the
#'   same in every call from the same origin with the same `seed`). This
#'   parameter then affects the results with or without frequencies. R5's
#'   McRaptor cannot sample many departure times per minute over long windows,
#'   so such combinations raise an error (e.g. 8 draws per minute in a
#'   10-minute window, or 5 in a window of 150 minutes or more), as does a
#'   total of exactly 200 draws.
