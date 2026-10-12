#' Check transit service availability by date
#'
#' @description
#' Counts the public transport services in the GTFS feeds of a `r5r_network`
#' that are active on given dates, and their proportion of all services. Use it
#' to pick a departure date with adequate service: public transport routing only
#' finds trips on dates when services run (per the GTFS calendars and date
#' exceptions).
#'
#' @details
#' When no date arguments are supplied, the function discovers all dates with
#' an active service referenced by a retained transit trip, including
#' frequency-based trips. This accounts for weekday calendars and date
#' exceptions, including exception-only services. A date with active service
#' does not guarantee a trip at every departure time or between every pair of
#' points.
#'
#' You can also specify the dates to check in two ways:
#' \itemize{
#'   \item Using the `dates` argument to provide a vector of specific dates.
#'   \item Using the `start_date` and `end_date` arguments to provide a continuous date range.
#' }
#' You cannot combine these methods. In all modes, `total_services` counts every
#' imported service, not only those used by trips; counts are of services, not
#' trips. If calendar bounds are invalid, automatic discovery reports the
#' affected service; explicit date queries remain available.
#'
#' @template r5r_network
#' @template r5r_core
#' @param dates A vector of specific dates to be checked. Can be character strings
#'        in "YYYY-MM-DD" format, or objects of class `Date`. This argument
#'        cannot be used with `start_date` or `end_date`. Defaults to `NULL`;
#'        when all date arguments are `NULL`, operating dates are discovered
#'        from the network.
#' @param start_date The start date for a continuous date range. Must be a single
#'        character string in "YYYY-MM-DD" format or a `Date` object. Must be used
#'        with `end_date`.
#' @param end_date The end date for a continuous date range. Must be a single
#'        character string in "YYYY-MM-DD" format or a `Date` object. Must be used
#'        with `start_date`.
#' @return A `data.table` with four columns: `date`, `total_services`,
#'         `active_services`, and `pct_active` (the proportion of active services).
#'         Automatic discovery returns dates in ascending order, or a zero-row
#'         table with these columns if no retained transit trips operate.
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#' data_path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path)
#'
#' # Discover operating dates without knowing the feed's date range
#' availability1 <- check_transit_availability(r5r_network)
#' head(availability1)
#' # plot availability over the year
#' library(ggplot2)
#' ggplot(availability1, aes(x = date, y = pct_active)) +
#'   geom_line() +
#'   geom_point() +
#'   theme_classic(base_size = 16)
#'
#' # Example 2: Check a vector of specific dates
#' # Let's check a regular weekday and a Sunday, where service may differ.
#' dates_to_check <- c("2019-05-13", "2019-05-19")
#' availability2 <- check_transit_availability(
#'   r5r_network,
#'   dates = dates_to_check
#' )
#' head(availability2)
#'
#' # Example 3: Check a continuous date range using start_date and end_date
#' availability3 <- check_transit_availability(
#'   r5r_network,
#'   start_date = "2019-01-01",
#'   end_date = "2019-12-31"
#' )
#' availability3[121:124,]
#'
#'
#' stop_r5(r5r_network)
#' @export
check_transit_availability <- function(
  r5r_network,
  dates = NULL,
  start_date = NULL,
  end_date = NULL,
  r5r_core = deprecated()
) {
  # deprecating r5r_core --------------------------------------
  if (lifecycle::is_present(r5r_core)) {
    cli::cli_warn(c(
      "!" = "The `r5r_core` argument is deprecated as of r5r v2.3.0.",
      "i" = "Please use the `r5r_network` argument instead."
    ))
    r5r_network <- r5r_core
  }

  # Check inputs
  checkmate::assert_class(r5r_network, "r5r_network")
  jcore <- r5r_network@jcore

  # Argument validation for date inputs (CONSOLIDATED)
  is_valid_dates_vector <- !is.null(dates) &&
    is.null(start_date) &&
    is.null(end_date)
  is_valid_date_range <- is.null(dates) &&
    !is.null(start_date) &&
    !is.null(end_date)
  discover_dates <- is.null(dates) && is.null(start_date) && is.null(end_date)

  if (!discover_dates && !is_valid_dates_vector && !is_valid_date_range) {
    cli::cli_abort(
      c(
        "Incorrect date arguments provided.",
        "i" = "Omit all date arguments for discovery, or use one of these methods:",
        "*" = "Use the {.arg dates} argument to provide a vector of specific dates.",
        "*" = "Use both {.arg start_date} and {.arg end_date} to provide a continuous date range.",
        "x" = "You cannot mix these methods or provide an incomplete date range."
      )
    )
  }

  # Helper function to parse and validate date inputs
  parse_date_input <- function(date_input, arg_name) {
    # Pass Date objects through directly
    if (inherits(date_input, "Date")) {
      return(date_input)
    }

    if (!is.character(date_input)) {
      cli::cli_abort(
        "{.arg {arg_name}} must be a vector of character strings or Date objects."
      )
    }

    # Use regex to strictly check for "YYYY-MM-DD" format
    is_iso_format <- grepl("^\\d{4}-\\d{2}-\\d{2}$", date_input)
    if (any(!is_iso_format)) {
      cli::cli_abort(c(
        "x" = "Invalid date format found in {.arg {arg_name}}.",
        "i" = "Please use the strict {.val 'YYYY-MM-DD'} format for all date strings."
      ))
    }

    # Use a tryCatch block to convert potential errors from as.Date() into NAs
    parsed_dates_list <- lapply(date_input, function(d) {
      tryCatch(
        {
          as.Date(d)
        },
        error = function(e) {
          # If as.Date fails, return NA instead of throwing an error
          as.Date(NA)
        }
      )
    })
    parsed_dates <- as.Date(do.call("c", parsed_dates_list))

    # Final check for NAs, which now correctly indicate logically impossible dates
    if (anyNA(parsed_dates)) {
      cli::cli_abort(c(
        "x" = "Could not parse all values in {.arg {arg_name}}.",
        "i" = "One or more dates are logically invalid (e.g., '2025-02-29')."
      ))
    }

    return(parsed_dates)
  }

  # Prepare the list of dates to check
  if (discover_dates) {
    dates_formatted <- jcore$getTransitServiceDates()
  } else if (!is.null(dates)) {
    dates_as_date <- parse_date_input(dates, "dates")
    dates_formatted <- format(dates_as_date, "%Y-%m-%d")
  } else {
    start_d <- parse_date_input(start_date, "start_date")
    end_d <- parse_date_input(end_date, "end_date")

    if (length(start_d) > 1 || length(end_d) > 1) {
      cli::cli_abort(
        "{.arg start_date} and {.arg end_date} must each be a single date."
      )
    }
    if (start_d > end_d) {
      cli::cli_abort(
        "{.arg start_date} must be before or the same as {.arg end_date}."
      )
    }

    date_sequence <- seq(from = start_d, to = end_d, by = "day")
    dates_formatted <- format(date_sequence, "%Y-%m-%d")
  }

  # Transfer only the per-date counts, rather than a service table for each date.
  availability <- rJava::.jcall(
    jcore,
    "Lorg/ipea/r5r/RDataFrame;",
    "getTransitServiceAvailability",
    rJava::.jarray(dates_formatted)
  )
  final_dt <- java_to_dt(availability)
  data.table::set(final_dt, j = "date", value = as.Date(final_dt$date))
  return(final_dt)
}
