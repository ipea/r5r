# Convert a travel time surface to an isochrone.
surface_isochrone <- function (travel_time_surface, cutoffs) {
  checkmate::check_class(travel_time_surface, "travel_time_surface")

  nonzero_cutoffs = cutoffs[cutoffs>0]

  # get the iso, in web mercator pixel space
  bands = isoband::isobands(
    # R5 computes travel times at pixel centres, hence the 0.5 offset
    travel_time_surface@west + seq_len(travel_time_surface@width) - 0.5,
    travel_time_surface@north + seq_len(travel_time_surface@height) - 0.5,
    travel_time_surface@matrix,
    rep(0, length(nonzero_cutoffs)), # bands should all start at 0 minutes
    nonzero_cutoffs
  )

  # convert back to lat lon
  bands <- purrr::map(bands, function (b) {
    b$x <- webmercator_pixel_to_lon(b$x, travel_time_surface@zoom)
    b$y <- webmercator_pixel_to_lat(b$y, travel_time_surface@zoom)
    return(b)
  })
  class(bands) <- c("isobands", "iso")

  iso <- data.table::data.table(sf::st_sf(
    isochrone = nonzero_cutoffs,
    polygons = sf::st_make_valid(sf::st_sfc(isoband::iso_to_sfg(bands), crs=4326))
  ))

  iso <- iso[ order(-isochrone), ]
  return(iso)
}