#' Expand origin-destination pairs
#'
#' This function is used in [detailed_itineraries()] to update the `origins` and
#' `destinations` datasets.
#'
#' @param origins Passed by [detailed_itineraries()].
#' @param destinations Passed by [detailed_itineraries()].
#' @param all_to_all Passed by [detailed_itineraries()].
#'
#' @keywords internal
expand_od_pairs <- function(origins, destinations, all_to_all) {
  checkmate::assert_logical(all_to_all, len = 1, any.missing = FALSE)

  n_origs <- nrow(origins)
  n_dests <- nrow(destinations)

  if (all_to_all || n_origs == 1 || n_dests == 1) {
    origins <- origins[rep(seq_len(n_origs), each = n_dests), ]
    destinations <- destinations[rep(seq_len(n_dests), times = n_origs), ]

    if (!all_to_all && (n_origs > 1 || n_dests > 1)) {
      if (n_origs == 1) {
        message("'origins' was expanded to match the number of destinations.")
      } else {
        message("'destinations' was expanded to match the number of origins.")
      }
    }
  } else if (n_origs != n_dests) {
    stop(
      "When 'all_to_all' is FALSE, 'origins' and 'destinations' must either ",
      "have the same number of rows or one of them must have only one row."
    )
  }

  result <- list(origins = origins, destinations = destinations)
  return(result)
}
