#' @param percentiles An integer vector (max length of 5, an `R5` limit). The
#'   travel time percentiles within the time window from which accessibility is
#'   calculated. They apply to travel times, not to the accessibility
#'   distribution: with 25, accessibility is calculated from the 25th
#'   percentile travel time, which may differ from the 25th percentile of
#'   accessibility. Defaults to 50 (the median travel time). With more than one
#'   value, the output gets a column identifying the percentile of each
#'   estimate. See the `R5` documentation at
#'   <https://docs.conveyal.com/analysis/methodology#accounting-for-variability>.
