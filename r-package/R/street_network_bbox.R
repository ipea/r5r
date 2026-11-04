#' Extract the geographic bounding box of the transport network
#'
#' Extracts the geographic bounding box of the street network layer from a
#' routable transport network built with [build_network()]. It is a fast and
#' memory-efficient alternative to `sf::st_bbox(street_network_to_sf(r5r_net))`.
#'
#' @template r5r_network
#' @template r5r_core
#' @param output A character string specifying the desired output format. One of
#'   `"polygon"` (the default), `"bbox"`, or `"vector"`.
#'
#' @return By default (`output = "polygon"`), an `sf` object with a single `POLYGON`
#'   geometry. If `output = "bbox"`, an `sf` `bbox` object. If `output = "vector"`,
#'   a named numeric vector with `xmin`, `ymin`, `xmax`, `ymax` coordinates.
#'   All outputs use the WGS84 coordinate reference system (EPSG: 4326).
#'
#' @family network functions
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#' library(sf)
#'
#' data_path <- system.file("extdata/poa", package = "r5r")
#' r5r_network <- build_network(data_path)
#'
#' # Get the network's bounding box as an sf polygon (default)
#' poly <- street_network_bbox(r5r_network, output = "polygon")
#' plot(poly)
#'
#' # Get an sf bbox object (order is xmin, ymin, xmax, ymax)
#' box <- street_network_bbox(r5r_network , output = "bbox")
#' box
#'
#' # Get a simple named vector (order now also xmin, ymin, xmax, ymax)
#' vec <- street_network_bbox(r5r_network , output = "vector")
#' vec
#'
#' stop_r5(r5r_network)
#' @export
street_network_bbox <- function(
  r5r_network,
  output = c("polygon", "bbox", "vector"),
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

  # --- Input validation ---
  checkmate::assert_class(r5r_network, "r5r_network")
  output <- match.arg(output)

  # --- Call the optimized Java method ---
  coords_vec <- rJava::.jcall(
    r5r_network@jcore,
    "[D", # Signature for "returns an array of doubles"
    "getNetworkEnvelopeAsArray"
  )

  # --- Assign names based on the documented order from the Java method ---
  names(coords_vec) <- c("xmin", "xmax", "ymin", "ymax")

  # --- Reorder to match sf::st_bbox standard ---
  coords_vec <- coords_vec[c("xmin", "ymin", "xmax", "ymax")]

  # --- Format the output as requested ---
  if (output == "vector") {
    return(coords_vec)
  }

  bbox <- sf::st_bbox(coords_vec, crs = 4326) # WGS 84

  if (output == "bbox") {
    return(bbox)
  }

  if (output == "polygon") {
    return(sf::st_as_sfc(bbox))
  }
}
