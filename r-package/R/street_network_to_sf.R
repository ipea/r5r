#' Extract OpenStreetMap network in sf format
#'
#' Extracts the OpenStreetMap network in `sf` format from a routable transport
#' network built with [build_network()].
#'
#' @template r5r_network
#' @template r5r_core
#'
#' @return A list with two components of a street network in sf format: vertices
#'         (POINT) and edges (LINESTRING).
#'
#' @family network functions
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' # build transport network
#' path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(path)
#'
#' # extract street network from r5r_network
#' street_net <- street_network_to_sf(r5r_network)
#'
#' stop_r5(r5r_network)
#' @export
street_network_to_sf <- function(r5r_network,
                                 r5r_core = deprecated()) {

  # deprecating r5r_core --------------------------------------
  if (lifecycle::is_present(r5r_core)) {

    cli::cli_warn(c(
      "!" = "The `r5r_core` argument is deprecated as of r5r v2.3.0.",
      "i" = "Please use the `r5r_network` argument instead."
    ))

    r5r_network <- r5r_core
  }

  # check input
  checkmate::assert_class(r5r_network, "r5r_network")

  # Get street network from R5R network
  network <- r5r_network@jcore$getStreetNetwork()

  # Convert vertices to SF (point)
  vertices_df <- java_to_dt(network$get(0L))
  vertices_sf <- sfheaders::sf_point(vertices_df, x='lon', y='lat', keep = TRUE)
  sf::st_crs(vertices_sf) <- 4326 # WGS 84

  # Convert edges to SF (linestring)
  edges_df <- java_to_dt(network$get(1L))
  edges_df[, geometry := sf::st_as_sfc(geometry)]
  edges_sf <- sf::st_sf(edges_df, crs = 4326) # WGS 84

  # gather in a list
  street_network <- list(vertices = vertices_sf, edges = edges_sf)

  return(street_network)
}
