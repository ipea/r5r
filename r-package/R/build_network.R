#' Build a transport network used for routing in R5
#'
#' Builds a multimodal transport network used for routing in `R5`, combining
#' multiple data inputs present in the directory where the network should be
#' saved to. The directory must contain only one street network file (in
#' `.osm.pbf` format). It may optionally contain one or more public transport
#' GTFS feeds (in `.zip` format), when used for public transport routing, and a
#' `.tif` file describing the elevation profile of the study area. If there is
#' more than one GTFS feed in the directory, all feeds are automatically merged.
#' If there is already a `'network.dat'` file in the directory, the function
#' reads it instead (see `overwrite`).
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
#' r5r_network <- build_network(data_path)
#' @export
build_network <- function(data_path,
                          verbose = FALSE,
                          temp_dir = FALSE,
                          elevation = "TOBLER",
                          overwrite = FALSE) {

  # check inputs ------------------------------------------------------------

  checkmate::assert_directory_exists(data_path)
  checkmate::assert_logical(verbose)
  checkmate::assert_logical(temp_dir)
  checkmate::assert_character(elevation)
  checkmate::assert_logical(overwrite)

  elevation <- set_elevation(elevation)

  # expand data_path to full path, as required by rJava api call
  data_path <- path.expand(data_path)

  # check Java version installed locally and init java
  start_r5r_java(data_path = data_path, temp_dir = temp_dir, verbose = verbose)

  # check if data_path has osm.pbf, .tif gtfs data, or a network.dat file
  any_network <- length(grep("network.dat", list.files(data_path))) > 0
  any_pbf  <- length(grep(".pbf", list.files(data_path))) > 0
  any_gtfs <- length(grep(".zip", list.files(data_path))) > 0
  any_tif <- length(grep(".tif", list.files(data_path))) > 0

  # stop if there is no input data
  if (!(any_pbf | any_network)){
    cli::cli_abort("An OSM {.file .pbf} file is required in {.path {data_path}} to build a network.")
  }

  # use no elevation model if there is no raster.tif input data
  if (!(any_tif)) {
    elevation <- 'NONE'
    cli::cli_inform(c(
      i = "No raster {.file .tif} files found in {.path {data_path}}. Using elevation = {.val 'NONE'}."
    ))
  }

  # check if data_path already has a network.dat file
  dat_file <- file.path(data_path, "network.dat")

  if (checkmate::test_file_exists(dat_file) && !overwrite) {
    r5r_network <- rJava::.jnew("org.ipea.r5r.R5RCore", data_path, verbose, elevation)

    # a stale network.dat can trigger a silent internal rebuild that fails on
    # high priority GTFS errors, leaving routing properties uninitialized
    core_is_usable <- tryCatch(
      {
        r5r_network$getWalkSpeed()
        TRUE
      },
      error = function(e) FALSE
    )

    if (!core_is_usable) {
      cli::cli_abort(c(
        "x" = "Cached network at {.path {dat_file}} could not be loaded.",
        "i" = paste(
          "R5 likely attempted an internal rebuild because the cached network",
          "format is incompatible, and that rebuild failed (e.g. due to high",
          "priority GTFS errors)."
        ),
        "i" = paste(
          "Rebuild explicitly with {.code build_network(data_path, overwrite = TRUE)}",
          "to see the underlying error and a {.file gtfs_errors.csv} with details."
        )
      ))
    }

    cli::cli_inform(c(
      i = "Using cached network from {.path {dat_file}}."
    ))

  } else {
    # check if the user has permission to write to the data directory. if not,
    # R5 won't be able to create the required files and will fail with a
    # not-that-enlightening error
    error_if_no_write_permission(data_path)

    # stop r5 in case it is already running
    suppressMessages( r5r::stop_r5() )

    # clean up any files that might have been created by previous r5r usage
    # if the files do not exist 'file.remove()' will raise a warning, which is
    # suppressed here
    mapdb_files <- list.files(data_path, full.names = TRUE)
    mapdb_files <- mapdb_files[grepl("\\.mapdb", mapdb_files)]
    suppressWarnings(
      invisible(file.remove(dat_file, mapdb_files))
    )

    # build new r5r_network
    r5r_network <- rJava::.jnew("org.ipea.r5r.R5RCore", data_path, verbose, elevation, check=F)
    ex = rJava::.jgetEx(clear=TRUE)
    if (!is.null(ex)) {
      msg <- rJava::.jcall(ex, "S", "toString")
      if (grepl("Geographic extent of street layer", msg)) {
        cli::cli_abort(
          "Geographic extent of street layer exceeds limit of {.val 975,000} {.unit km^2}."
        )
      } else {
        ex$printStackTrace()
        return(NULL)
      }
    }

    # display a message if there is a PBF file but no GTFS data
    if (any_pbf && !any_gtfs) {
      cli::cli_inform(c(
        i = "No public transport data ({.file GTFS}) found in {.path {data_path}}. Graph will be built with the street network only."
      ))
    }

    errors = java_to_dt(r5r_network$gtfsErrors)
    errfile = file.path(data_path, "gtfs_errors.csv")

    # always write error file even when empty, so that if you fix errors the error file gets overwritten on rebuild
    data.table::fwrite(errors, errfile)

    if (any(errors$priority == "HIGH")) {
      cli::cli_abort(c(
        "x"="High priority GTFS errors found; network build failed.",
        "i" = "Use {.fn r5r::get_gtfs_errors} to see them, or review {.file {errfile}}."

      ))
    } else if (nrow(errors) > 0) {
        cli::cli_inform(c(
          "!" = "{nrow(errors)} errors found in GTFS.",
          "i" = "Use {.fn r5r::get_gtfs_errors} to see them, or review {.file {errfile}}."
        ))
    }

    cli::cli_inform(c(
      v = "Finished building network at {.path {data_path}}"
    ))
  }

  return(wrap_r5r_network(r5r_network))
}

error_if_no_write_permission <- function(data_path) {
  write_permission <- file.access(data_path, mode = 2)

  normalized_path <- normalizePath(data_path)

  if (write_permission == -1) {
    cli::cli_abort(
      c(
        "Permission to write to {.path {normalized_path}} denied.",
        i = paste0(
          "{.pkg r5r} needs write privilege to create the network files. ",
          "Please make sure you have this privilege in the provided directory."
        )
      ),
      class = "dir_permission_denied",
      call = rlang::caller_env()
    )
  }

  return(invisible(TRUE))
}
