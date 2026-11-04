#' Create a transport network used for routing in R5 (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `setup_r5()` was renamed to [`build_network()`] to create a more consistent
#' API. **`setup_r5()` is being deprecated** after *r5r* v2.3.0 and will be
#' **removed in a future release**. Use [`build_network()`] instead.
#'
#' @template verbose
#' @param data_path A string pointing to the directory where data inputs are
#'        stored and where the built `network.dat` will be saved.
#' @param temp_dir A logical. Whether the `network.dat` file should be saved to
#'        a temporary directory. Defaults to `FALSE`.
#' @template elevation
#' @param overwrite A logical. Whether to overwrite an existing `network.dat`
#'        or to use a cached file. Defaults to `FALSE` (i.e. use a cached
#'        network).
#'
#' @return An `r5r_network` object, used by r5r's routing and support
#'         functions.
#'
#' @template elevation_section
#'
#' @family Build network
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' # directory with street network and gtfs files
#' data_path <- system.file("extdata/poa", package = "r5r")
#'
#' # `setup_r5()` has been deprecated, please switch to `build_network()`
#' r5r_network <- build_network(data_path)
#' @export
setup_r5 <- function(data_path,
                     verbose = FALSE,
                     temp_dir = FALSE,
                     elevation = "TOBLER",
                     overwrite = FALSE) { # nocov start

  # Deprecation warning --------------------------------------------------------
  cli::cli_warn(c(
    "!" = "{.fn setup_r5} is being deprecated in *r5r* and will be removed in a future release.",
    "i" = "Please use {.fn r5r::build_network} instead."
  ))

  # lifecycle::deprecate_soft(
  #   when = "2.3.0",
  #   what = "setup_r5()",
  #   with = "r5r::build_network()"
  #   )

  # # Optional base-R signal for tools that watch .Deprecated()
  # .Deprecated("build_network", package = "r5r")


  # Pass through to the replacement -------------------------------------------

  r5r_network <- build_network(
    data_path,
    verbose = verbose,
    temp_dir = temp_dir,
    elevation = elevation,
    overwrite = overwrite
    )

  return(r5r_network)
} # nocov end
