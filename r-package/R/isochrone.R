#' Estimate isochrones from a given location
#'
#' @description Fast computation of isochrones from a given location. The
#' function can return either polygon-based or line-based isochrones.
#' Polygon-based isochrones are generated from a travel time surface: travel
#' times from each origin to the centres of a regular grid of Web Mercator
#' pixels (see `zoom`), from which the isochrone polygons are interpolated with
#' the marching squares algorithm. Line-based isochrones are based on
#' travel times from each origin to the centroids of all segments in the
#' transport network.
#'
#' @template r5r_network
#' @template r5r_core
#' @inheritParams travel_time_matrix
#' @param origins Either a `POINT sf` object with WGS84 CRS, or a
#'        `data.frame` containing the columns `id`, `lon` and `lat`.
#' @param cutoffs A numeric vector. The travel times, in minutes, that delimit
#'        the isochrones. Defaults to `c(0, 15, 30)`. Values are sorted and
#'        duplicates are removed; at least one value must be greater than 0.
#' @param zoom A number between 9 and 12. The Web Mercator zoom level of the
#'        travel time grid from which polygon isochrones are interpolated
#'        (only used when `polygon_output = TRUE`). Higher values give more
#'        detailed isochrones but take longer to compute. Defaults to 10
#'        (cells of about 153 meters at the Equator). For how grid cells are
#'        defined, see
#'        \href{https://docs.conveyal.com/analysis/methodology#zoom-levels}{the R5 documentation.}
#' @param mode A character vector. The transport modes allowed for access,
#'        transfer and vehicle legs of the trips. Defaults to `TRANSIT`. See
#'        details for other options.
#' @param polygon_output A Logical. If `TRUE`, the function outputs
#'        polygon-based isochrones (the default) based on travel times from each
#'        origin to a regular grid of points (see parameter `zoom`). If `FALSE`,
#'        the function outputs
#'        line-based isochrones based on travel times from each origin to the
#'        centroids of all segments in the transport network.
#' @param max_trip_duration Ignored. The maximum trip duration is set
#'        internally from `max(cutoffs)`.
#' @param percentiles An integer vector (max length of 5). The travel time
#'        percentiles within `time_window` used to build the isochrones, one
#'        set of polygons per percentile. Defaults to 50 (the median travel
#'        time). Only used when `polygon_output = TRUE`; must be `NULL` for
#'        line-based isochrones.
#' @template draws_per_minute
#' @template seed
#' @param progress A logical. Whether to show a progress counter when running
#'        the router. Defaults to `TRUE`. Only works when `verbose` is
#'        `FALSE`. May slightly slow computation, as the counter is
#'        synchronized across threads.
#' @template verbose
#' @param sample_size deprecated, no longer has any effect.
#'
#' @return A `"sf" "data.frame"`. With `polygon_output = TRUE`, one `POLYGON`
#'         or `MULTIPOLYGON` per origin, percentile and cutoff, with columns
#'         `id` (origin id), `isochrone` (cutoff in minutes), `percentile` (a
#'         string such as `"p50"`) and `polygons`. Each polygon covers the whole
#'         area reached from 0 up to its cutoff, so polygons of larger cutoffs
#'         contain those of smaller ones. With `polygon_output = FALSE`, one
#'         `LINESTRING` per street segment reached, with columns `id` (origin
#'         id), `edge_index`, `osm_id`, `isochrone` (the smallest cutoff at or
#'         above the segment's travel time, i.e. bands are intervals),
#'         `travel_time_p50` and `geometry`.
#'
#' @template transport_modes_section
#' @template lts_section
#' @template datetime_parsing_section
#' @template raptor_algorithm_section
#'
#' @family Isochrone
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' options(java.parameters = "-Xmx2G")
#' library(r5r)
#' library(ggplot2)
#'
#' # build transport network
#' data_path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path = data_path)
#'
#' # load origin/point of interest
#' points <- read.csv(file.path(data_path, "poa_points_of_interest.csv"))
#' origin <- points[2,]
#'
#' departure_datetime <- as.POSIXct(
#'  "13-05-2019 14:00:00",
#'  format = "%d-%m-%Y %H:%M:%S"
#' )
#'
#' # estimate polygon-based isochrone from origin
#' iso_poly <- isochrone(
#'   r5r_network,
#'   origins = origin,
#'   mode = "walk",
#'   polygon_output = TRUE,
#'   departure_datetime = departure_datetime,
#'   cutoffs = seq(0, 120, 30)
#'   )
#'
#' head(iso_poly)
#'
#'
#' # estimate line-based isochrone from origin
#' iso_lines <- isochrone(
#'   r5r_network,
#'   origins = origin,
#'   mode = "walk",
#'   polygon_output = FALSE,
#'   departure_datetime = departure_datetime,
#'   cutoffs = seq(0, 100, 25)
#'   )
#'
#' head(iso_lines)
#'
#'
#' # plot colors
#' colors <- c('#ffe0a5','#ffcb69','#ffa600','#ff7c43','#f95d6a',
#'             '#d45087','#a05195','#665191','#2f4b7c','#003f5c')
#'
#' # polygons
#' ggplot() +
#'   geom_sf(data=iso_poly, aes(fill=factor(isochrone))) +
#'   scale_fill_manual(values = colors) +
#'   theme_minimal()
#'
#' # lines
#' ggplot() +
#'   geom_sf(data=iso_lines, aes(color=factor(isochrone))) +
#'   scale_color_manual(values = colors) +
#'   theme_minimal()
#'
#' stop_r5(r5r_network)
#'
#' @export
isochrone <- function(r5r_network,
                      origins,
                      mode = "transit",
                      mode_egress = "walk",
                      cutoffs = c(0, 15, 30),
                      zoom = 10,
                      departure_datetime = NULL,
                      polygon_output = TRUE,
                      time_window = 10L,
                      max_walk_time = Inf,
                      max_bike_time = Inf,
                      max_car_time = Inf,
                      max_trip_duration = 120L,
                      walk_speed = 3.6,
                      bike_speed = 12,
                      max_rides = 3,
                      max_lts = 2,
                      draws_per_minute = 5L,
                      seed = NULL,
                      # TODO this is unused for line-based isos
                      percentiles = NULL,
                      n_threads = Inf,
                      verbose = FALSE,
                      progress = TRUE,
                      # no longer used
                      sample_size = deprecated(),
                      r5r_core = deprecated()
                      ){


  # deprecating r5r_core --------------------------------------
  if (lifecycle::is_present(r5r_core)) {

    cli::cli_warn(c(
      "!" = "The `r5r_core` argument is deprecated as of r5r v2.3.0.",
      "i" = "Please use the `r5r_network` argument instead."
    ))

    r5r_network <- r5r_core
  }

  if (missing(departure_datetime)) warn_default_datetime(mode)

  # sample size no longer used
  if (lifecycle::is_present(sample_size)) {
    cli::cli_warn(c(
      "!" = "The `sample_size` argument is no longer used and has no effect."
    ))
  }

# check inputs ------------------------------------------------------------
  checkmate::assert_class(r5r_network, "r5r_network")

  # check cutoffs
  checkmate::assert_numeric(cutoffs, lower = 0, finite = TRUE, any.missing = FALSE, min.len = 1)
  checkmate::assert_logical(polygon_output)

  # max cutoff is used as max_trip_duration
  max_trip_duration = as.integer(max(cutoffs))

  # sort cutoffs, remove duplicates and include 0
  cutoffs <- sort(unique(c(0, cutoffs)))
  if (length(cutoffs) < 2) cli::cli_abort("{.arg cutoffs} must contain at least one value greater than 0.")

  ## whether polygon- or line-based isochrones
  if (isTRUE(polygon_output)) {
    if (checkmate::test_null(percentiles)) {
      percentiles = 50L
    }

    # R5 only supports grids between zoom 9 and 12
    checkmate::assert_numeric(zoom, lower=9, upper=12, len=1)

    # create the travel time surfaces
    surfaces = travel_time_surface(r5r_network = r5r_network,
                              origins = origins,
                              mode = mode,
                              mode_egress = mode_egress,
                              departure_datetime = departure_datetime,
                              time_window = time_window,
                              percentiles = percentiles,
                              max_walk_time = max_walk_time,
                              max_bike_time = max_bike_time,
                              max_car_time = max_car_time,
                              # route past max(cutoffs) so the outer band is interpolated like the inner ones
                              max_trip_duration = max_trip_duration + 10L,
                              walk_speed = walk_speed,
                              bike_speed = bike_speed,
                              max_rides = max_rides,
                              max_lts = max_lts,
                              draws_per_minute = draws_per_minute,
                              seed = seed,
                              n_threads = n_threads,
                              verbose = verbose,
                              progress = progress,
                              zoom = zoom
    )

    # convert surfaces to isochrones
    # this uses a few named functions to traverse down the nested list
    # (percentiles inside origins)
    isos <- purrr::list_rbind(purrr::map2(surfaces, as.character(origins$id), percentiles_to_isodt, cutoffs))
    isos <- isos[, c("id", "isochrone", "percentile", "polygons")]
    return(sf::st_as_sf(isos, sf_column_name="polygons"))
  }

  if(isFALSE(polygon_output)){

    if (!checkmate::test_null(percentiles)) {
      cli::cli_abort("Percentiles not supported for line-based isochrones")
    }

    network_e <- r5r::street_network_to_sf(r5r_network)$edges

    destinations <- sf::st_centroid(sf::st_set_agr(network_e, "constant"))
    }

  # rename id col
  names(destinations)[1] <- 'id'
  destinations$id <- as.character(destinations$id)


    # estimate travel time matrix
    ttm <- travel_time_matrix(r5r_network = r5r_network,
                              origins = origins,
                              destinations = destinations,
                              mode = mode,
                              mode_egress = mode_egress,
                              departure_datetime = departure_datetime,
                              time_window = time_window,
                              # percentiles = percentiles,
                              max_walk_time = max_walk_time,
                              max_bike_time = max_bike_time,
                              max_car_time = max_car_time,
                              max_trip_duration = max_trip_duration,
                              walk_speed = walk_speed,
                              bike_speed = bike_speed,
                              max_rides = max_rides,
                              max_lts = max_lts,
                              draws_per_minute = draws_per_minute,
                              seed = seed,
                              n_threads = n_threads,
                              verbose = verbose,
                              progress = progress
                              )

    # ignore travel times equal to 0
    ttm <- ttm[travel_time_p50>0, ]

    # aggregate travel-times
    # ttm[, isochrone_interval := cut(x=travel_time_p50, breaks=cutoffs)]
    ttm[, isochrone := cut(x=travel_time_p50, breaks=cutoffs, labels=F)]
    ttm[, isochrone := cutoffs[cutoffs>0][isochrone]]


    # line-based isochrones
      prep_iso_lines <- function(orig){ # orig = '89a90128107ffff'

        temp_ttm <- subset(ttm, from_id == orig)

        # join ttm results to destinations
        temp_iso <- subset(network_e, edge_index %in% temp_ttm$to_id)
        data.table::setDT(temp_iso)[, edge_index := as.character(edge_index)]
        temp_iso[temp_ttm, on=c('edge_index' ='to_id'), c('travel_time_p50', 'isochrone') := list(i.travel_time_p50, i.isochrone)]
       # temp_iso <- sf::st_as_sf(temp_iso)

      temp_iso <- temp_iso[order(-isochrone, -travel_time_p50)]
      temp_iso[, id := as.character(orig)]
      data.table::setcolorder(temp_iso, c('id', 'edge_index', 'osm_id', 'isochrone', 'travel_time_p50'))
      # plot(temp_iso)
      return(temp_iso)
    }


    # get the isocrhone from each origin
    iso_list <- lapply(X = unique(origins$id), FUN = prep_iso_lines)

    # put output together
    iso <- data.table::rbindlist(iso_list)
    iso <- sf::st_sf(iso)
    iso <- subset(iso, isochrone < Inf)

    # remove data.table from class
    class(iso) <- c("sf", "data.frame")
    return(iso)
  }


# Helper function to handle multiple percentiles
percentiles_to_isodt <- function (surfaceList, origin_id, cutoffs) {
  iso <- purrr::imap(surfaceList, percentile_to_isodt, cutoffs)
  iso <- purrr::list_rbind(iso)
  iso$id <- origin_id
  return(iso)
}

percentile_to_isodt <- function(surface, percentile, cutoffs) {
  iso <- surface_isochrone(surface, cutoffs)
  iso$percentile <- percentile
  return(iso)
}
