#' @section Routing algorithm:
#'
#' The [travel_time_matrix()], [expanded_travel_time_matrix()],
#' [arrival_travel_time_matrix()]  and [accessibility()] functions use an
#' `R5`-specific extension to the RAPTOR routing algorithm (see Conway et al.,
#' 2017). This RAPTOR extension uses a systematic sample of one departure per
#' minute over the time window set by the user in the 'time_window' parameter.
#' A detailed description of base RAPTOR can be found in Delling et al (2015).
#' However, whenever the user includes transit fares inputs to these functions,
#' they automatically switch to use an `R5`-specific extension to the McRAPTOR
#' routing algorithm. [detailed_itineraries()] also uses RAPTOR when it only
#' returns the fastest itinerary (`shortest_path = TRUE`) and no fares are
#' used.
#'
#' - Conway, M. W., Byrd, A., & van der Linden, M. (2017). Evidence-based
#' transit and land use sketch planning using interactive accessibility methods
#' on combined schedule and headway-based networks. Transportation Research
#' Record, 2653(1), 45-53. \doi{10.3141/2653-06}
#'
#' - Delling, D., Pajor, T., & Werneck, R. F. (2015). Round-based public
#' transit routing. Transportation Science, 49(3), 591-604.
#' \doi{10.1287/trsc.2014.0534}
