#' Find snapped locations of input points on street network
#'
#' Finds the snapped location of points on `R5` network. Snapping is an
#' important step of the routing process, which is when the origins and
#' destinations specified by the user are actually positioned on the network
#' created by `R5`. The snapping process in `R5` is composed of two rounds.
#' First, it tries to snap the points within a radius of 300 meters from
#' themselves. If the first round is unsuccessful, then `R5` expands the search
#' to the radius specified (by default 1.6km). If yet again it is unsuccessful,
#' then the unsnapped points won't be used during the routing process. The
#' snapped location of each point depends on the transport mode set by the user,
#' because some network edges are not available to specific modes (e.g. a
#' pedestrian-only street cannot be used to snap car trips).
#'
#' @template r5r_network
#' @template r5r_core
#' @param points Either a `POINT sf` object with WGS84 CRS, or a `data.frame`
#'        containing the columns `id`, `lon` and `lat`.
#' @param radius Numeric. The maximum radius in meters within which to snap.
#'        Defaults to 1600m.
#' @param mode A string. Which mode to consider when trying to snap the points
#'        to the network. Defaults to `WALK`, also allows `BICYCLE` and `CAR`.
#'
#' @return A `data.table` with the original points, their respective
#' snapped coordinates on the street network and the Euclidean distance (in
#' meters) between the original points and their snapped location. Points that
#' could not be snapped show `NA` coordinates and `found = FALSE`.
#'
#' @family network functions
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path = path)
#' points <- read.csv(file.path(path, "poa_hexgrid.csv"))
#'
#' snap_df <- find_snap(
#'   r5r_network,
#'   points = points,
#'   radius = 2000,
#'   mode = "WALK"
#'   )
#'
#' stop_r5(r5r_network)
#' @export
find_snap <- function(r5r_network,
                      points,
                      radius = 1600,
                      mode = "WALK",
                      r5r_core = deprecated()){

  # deprecating r5r_core --------------------------------------
  if (lifecycle::is_present(r5r_core)) {

    cli::cli_warn(c(
      "!" = "The `r5r_core` argument is deprecated as of r5r v2.3.0.",
      "i" = "Please use the `r5r_network` argument instead."
    ))

    r5r_network <- r5r_core
  }

  checkmate::assert_class(r5r_network, "r5r_network")
  r5r_network <- r5r_network@jcore

  checkmate::assert_numeric(radius, lower = 0, finite = TRUE, max.len = 1)
  mode_options <- c("WALK", "BICYCLE", "CAR")
  checkmate::assert(
    checkmate::check_string(mode),
    checkmate::check_names(mode, subset.of = mode_options),
    combine = "and"
  )

  points <- assign_points_input(points, "points")

  snap_df <- r5r_network$findSnapPoints(points$id,
                                     points$lat,
                                     points$lon,
                                     radius,
                                     mode)
  snap_df <- java_to_dt(snap_df)

  snap_df[found == FALSE, `:=`(snap_lat = NA, snap_lon = NA, distance = NA)]

  return(snap_df)
}



