#' @param seed An integer or `NULL`. The seed of the Monte Carlo draws of the
#'   departure offsets of frequency-based transit routes and, with the McRaptor
#'   algorithm, of the departure times sampled within `time_window`. Defaults
#'   to `NULL`, in which case the draws are random and results may vary
#'   slightly between runs. With an integer, the same inputs always give the
#'   same results, regardless of `n_threads`. Results are still a Monte Carlo
#'   sample, so a different seed may give slightly different results: report
#'   the seed used and check how sensitive the results are to it. Note that
#'   `set.seed()` has no effect on these draws. With the default routing
#'   algorithm, this parameter only affects the results when the GTFS feeds
#'   contain a `frequencies.txt` table.<%= if (exists("seed_mcraptor")) " This function always uses the McRaptor algorithm, so `seed` affects the results with or without frequencies." else " In functions that accept a `fare_structure`, passing one switches to the McRaptor algorithm, and `seed` then affects the results with or without frequencies." %>
