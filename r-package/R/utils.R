#' Get most recent JAR file url from metadata
#'
#' Returns the most recent JAR file url from metadata, depending on the version.
#'
#' @param version A string. The version of R5 to be downloaded. When `NULL`, it
#'        defaults to the latest version.
#'
#' @return A url a string.
#'
#' @family support functions
#'
#' @keywords internal
fileurl_from_metadata <- function(version = NULL) { # nocov start

  # R5 version
  if(is.null(version)) {version = r5r_env$r5_jar_version}

  checkmate::assert_string(version)

  metadata <- system.file("extdata/metadata_r5r.csv", package = "r5r")
  metadata <- data.table::fread(metadata)

  # check for invalid 'version' input

  if (!(version %in% metadata$version)) {
    stop(
      "Error: Invalid value to argument 'version'. ",
      "Please use one of the following: ",
      paste(unique(metadata$version), collapse = "; ")
    )
  }

  # check which jar file to download based on the 'version' parameter

  env <- environment()
  metadata <- metadata[version == get("version", envir = env)]
  metadata <- metadata[release_date == max(release_date)]
  url <- metadata$download_path
  return(url)

} # nocov end


check_transit_availability_on_date <- function(r5r_network,
                                               departure_date){ # nocov start

  # check services Available on the departure date
  services <- check_transit_availability(r5r_network, dates = departure_date)
  services_available <- services$pct_active

  if (services_available == 0 | is.na(services_available)) {
    cli::cli_abort("There are no transit services available on the selected
                   departure date: {.val {departure_date}}. Please ensure there
                   is a GTFS in your data path & that the departure date falls
                   within the GTFS calendar."
                   )
    }


  if (services_available < 0.2) {
    cli::cli_alert_warning("Less than 20% of the transit services in the GTFS are running
                   on the selected departure date.")
  }
} # nocov end


#' Initialize Java and Check Version
#'
#' Sets up Java logging for r5r and ensures Java SE Development Kit 21 is installed.
#'
#' @param data_path A character string. The directory where the log file should be saved.
#' @param temp_dir A logical. Whether the jar file should be saved in a temporary
#'   directory. Defaults to `FALSE`.
#' @param verbose A logical. Whether to show informative messages. Defaults to `FALSE`.
#'
#' @return No return value. The function will stop execution with an error if Java 21 is not found.
#'
#' @details
#' This function initializes the Java Virtual Machine (JVM) with a log path for r5r, and checks that
#' the installed Java version is 21. If not, it stops with an informative error message and download links.
#'
#' @family support functions
#'
#' @keywords internal
start_r5r_java <- function(data_path,
                           temp_dir = FALSE,
                           verbose = FALSE) { # nocov start

  log_filename <- "r5r-log.log"
  log_path <- paste0("-DLOG_PATH=", file.path(data_path, log_filename))

  r5_version <- paste0("-DR5_VER=", r5r_env$r5_jar_version)
  r5r_version <- paste0("-DR5R_VER=", utils::packageVersion("r5r"))

  # passing `parameters` replaces .jinit()'s default, so keep the user's options(java.parameters)
  rJava::.jinit(parameters = c(getOption("java.parameters"), log_path, r5_version, r5r_version))

  ver <- get_java_version()

  if (ver != 21) {
    # Helper that turns plain text into a clickable hyperlink (works in
    # RStudio ≥ 2023.12 and other terminals that support OSC-8 links)
    link <- cli::style_hyperlink

    cli::cli_abort(c(
      "This package requires {.val Java-SE Development Kit 21}.",
      "i" = "Please install JDK 21 from one of the sources below:",
      "*" = link("rJavaEnv",       "https://www.ekotov.pro/rJavaEnv"),
      "*" = link("Eclipse Temurin","https://adoptium.net/temurin"),
      "*" = link("Amazon Corretto","https://aws.amazon.com/corretto"),
      "*" = link("OpenJDK",        "https://jdk.java.net/java-se-ri/21"),
      "*" = link("Oracle",         "https://docs.oracle.com/en/java/javase/21/install/index.html")
    ))
  }

  # if (ver != 21) {
  #   cli::cli_abort(c(
  #     "This package requires {.val Java SE Development Kit 21}.",
  #     "i" = "Please install JDK 21 from one of the sources below:",
  #     "*" = "{.pkg rJavaEnv}: <https://www.ekotov.pro/rJavaEnv>",
  #     "*" = "Eclipse Temurin: <https://adoptium.net/temurin>",
  #     "*" = "Amazon Corretto: <https://aws.amazon.com/corretto>",
  #     "*" = "OpenJDK: <https://jdk.java.net/java-se-ri/21>",
  #     "*" = "Oracle: <https://docs.oracle.com/en/java/javase/21/install/index.html>"
  #   ))
  # }

  # r5r jar
  r5r_jar <- system.file("jar/r5r.jar", package = "r5r")
  rJava::.jaddClassPath(path = r5r_jar)

  # r5r jar
  # check if the most recent JAR release is stored already.
  fileurl <- fileurl_from_metadata( r5r_env$r5_jar_version )
  filename <- basename(fileurl)

  if (is.null(getOption("r5r.r5jar"))) {
    jar_file <- data.table::fifelse(
      temp_dir,
      file.path(tempdir(), filename),
      file.path( r5r_env$cache_dir, filename)
    )

    # If there isn't a complete JAR already, download it
    if (checkmate::test_file_exists(jar_file) && file.info(jar_file)$size >= r5r_env$r5_jar_size) {
      if (verbose) message("Using cached R5 version from ", jar_file)
    } else {
      check  <- download_r5(temp_dir = temp_dir, quiet = !verbose)
      if (is.null(check)) { return(invisible(NULL)) }
    }
  } else {
    jar_file <- getOption("r5r.r5jar")
    if (checkmate::test_file_exists(jar_file)) {
      message("Overriding default R5 with option r5r.r5jar, using ", jar_file)
    } else {
      stop(paste0("Cannot find r5 jar \"", jar_file, "\", specified in options(r5r.r5jar)"))
    }
  }

  # R5 jar
  rJava::.jaddClassPath(path = jar_file)
} # nocov end


#' Return a temporary directory path that is unique with every call
#'
#' This is different from the built in tempdir() in that it does not return the same directory within a given runtime. Always returns a unique directory
#'
#' @return Path. Returns the path of the created temporary directory
#'
#' @family support functions
#'
#' @keywords internal
tempdir_unique <- function(){ # nocov start
  output_dir <- tempfile("r5rtemp_")
  if (!dir.create(output_dir)) {
    stop("Failed to create temporary directory.")
  }
  return(output_dir)
} # nocov end


#' Check if there is an elevation data file in `.tif` format in a given data path
#'
#' @param data_path A string pointing to a directory.
#' @return `TRUE` if there is a `.tif` file, `FALSE` otherwise
#'
#' @family support functions
#'
#' @keywords internal
exists_tiff <- function(data_path){ # nocov start

  all_files <- list.files(data_path)
  check <- ifelse(any(data.table::like(all_files, '.tif')), TRUE, FALSE)

  return(check)
} # nocov end


#' Validate OSM IDs returned from Java backend and print warnings
#'
#' Parses a Java-style array string (e.g., \code{"[id1, id2]"}), extracts OSM IDs,
#' and prints a pretty warning if any invalid IDs are found.
#'
#' If no invalid IDs are found (i.e., input is \code{"[]"}), prints nothing.
#'
#' @param bad_ids_string Character. A string formatted as a Java array (e.g., \code{"[id1, id2]"}).
#'
#' @return Warning if necessary.
#'
#' @family support functions
#' @keywords internal
validate_bad_osm_ids <- function(bad_ids_string) {
  # Remove brackets and trim whitespace
  ids <- gsub("^\\[|\\]$", "", bad_ids_string)
  ids <- trimws(ids)

  # Handle empty case: after removing brackets, should be empty string
  if (nchar(ids) > 0) {
    # Optionally, split into vector for pretty printing
    ids_vec <- unlist(strsplit(ids, ",\\s*"))
    cli::cli_alert_warning("Found invalid osm IDs in congestion data: {paste(ids_vec, collapse = ', ')}")
  }
}


#' Save speeds polygon to .geojson temporary file
#'
#' Support function that checks the input of speeds polygon passed to
#' `build_custom_network()` and saves it to a `.geojson` temporary file.
#'
#' @param new_speeds_poly An sf polygon
#'
#' @family Support functions
#'
#' @return The path to a `.geojson` saved as a temporary file.
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#'
#' # read polygons with new speeds
#' congestion_poly <- readRDS(
#'   system.file("extdata/poa/poa_poly_congestion.rds", package = "r5r")
#'   )
#'
#' geojson_path <- r5r:::congestion_poly2geojson(
#'   new_speeds_poly = congestion_poly
#'   )
#'
#' @keywords internal
congestion_poly2geojson <- function(new_speeds_poly){

  # check input class
  checkmate::assert_class(new_speeds_poly, "sf")

  # check input colnames
  checkmate::assert_names(
    x = names(new_speeds_poly),
    must.include = c("poly_id", "scale", "priority", "geometry")
  )

  # Check column types and check input geometry
  checkmate::assert_character(new_speeds_poly$poly_id, any.missing = FALSE)
  checkmate::assert_numeric(new_speeds_poly$scale, any.missing = FALSE)
  checkmate::assert_integer(new_speeds_poly$priority, any.missing = FALSE)
  checkmate::assert_subset(
    x = unique(as.character(sf::st_geometry_type(new_speeds_poly))),
    choices = c("POLYGON", "MULTIPOLYGON"),
    empty.ok = FALSE
  )

  # check input spatial projection
  if (sf::st_crs(new_speeds_poly) != sf::st_crs(4326)) {
    stop(
      "The CRS of parameter `new_speeds` must be WGS 84 (EPSG 4326). ",
      "Please use either sf::set_crs() to set it or ",
      "sf::st_transform() to reproject it."
    )
  }

  # save polygons to temp file
  file_path <- tempfile(
    pattern = 'r5r_congestion_poly',
    fileext = ".geojson"
  )

  sf::st_write(new_speeds_poly, file_path, quiet = TRUE)

  if (file.exists(file_path)) { return(file_path)}
}


#' Save LTS lines to shapefile temporary file
#'
#' Support function that checks the input of LTS lines passed to
#' and saves it to a `.shp` temporary file.
#'
#' @param new_lts_lines An sf LINESTRING or MULTILINESTRING
#'
#' @family Support functions
#'
#' @return The path to a `.shp` saved as a temporary file.
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#'
#' # read lines with new speeds
#' new_lts_lines <- readRDS(
#'   system.file("extdata/poa/poa_ls_lts.rds", package = "r5r")
#'   )
#'
#' shp_path <- r5r:::lts_lines2shp(
#'   new_lts_lines = new_lts_lines
#'   )
#'
#' @keywords internal
lts_lines2shp <- function(new_lts_lines){

  # check input class
  checkmate::assert_class(new_lts_lines, "sf")

  # check input colnames
  checkmate::assert_names(
    x = names(new_lts_lines),
    must.include = c("line_id", "lts", "priority", "geometry")
  )

  # Check column types and check input geometry
  checkmate::assert_character(new_lts_lines$line_id, any.missing = FALSE)
  checkmate::assert_integer(new_lts_lines$lts, any.missing = FALSE, lower = 1, upper = 4)
  checkmate::assert_integer(new_lts_lines$priority, any.missing = FALSE)
  checkmate::assert_subset(
    x = unique(as.character(sf::st_geometry_type(new_lts_lines))),
    choices = c("LINESTRING"),
    empty.ok = FALSE
  )

  # check input spatial projection
  if (sf::st_crs(new_lts_lines) != sf::st_crs(4326)) {
    stop(
      "The CRS of parameter `new_lts_lines` must be WGS 84 (EPSG 4326). ",
      "Please use either sf::set_crs() to set it or ",
      "sf::st_transform() to reproject it."
    )
  }

  # save lines to temp file
  file_path <- tempfile(
    pattern = 'r5r_lts_lines',
    fileext = ".shp"
  )

  sf::st_write(new_lts_lines, file_path, quiet = TRUE)

  if (file.exists(file_path)) { return(file_path)}
}


#' Warn about the deprecated `Sys.time()` default of the departure/arrival time
#'
#' Relying on the default `Sys.time()` with public transport gives results that
#' depend on when the code is run (#549). The default will be removed in a
#' future release.
#'
#' @param mode The `mode` passed to the routing function.
#' @param arg The name of the date-time argument.
#'
#' @return Invisibly returns `NULL`.
#'
#' @keywords internal
warn_default_datetime <- function(mode, arg = "departure_datetime") {
  if (any(grepl("TRANSIT|TRAM|SUBWAY|RAIL|BUS|FERRY|CABLE_CAR|GONDOLA|FUNICULAR", toupper(mode)))) {
    cli::cli_warn(
      c(
        "!" = "Relying on the default {.code {arg} = Sys.time()} for public transport routing is deprecated as of r5r v2.5.0.",
        "i" = "Results depend on the departure time. Please set {.arg {arg}} explicitly: the default will be removed in a future release."
      ),
      .frequency = "regularly",
      .frequency_id = "r5r_default_datetime"
    )
  }
  invisible(NULL)
}
