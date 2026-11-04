#' @section Level of Traffic Stress (LTS):
#'
#' When cycling is enabled in `R5` (by passing the value `BICYCLE` to either
#' `mode` or `mode_egress`), setting `max_lts` will allow cycling only on
#' streets with a given level of danger/stress. Setting `max_lts` to 1, for
#' example, will allow cycling only on separated bicycle infrastructure or
#' low-traffic streets and routing will revert to walking when traversing any
#' links with LTS exceeding 1. Setting `max_lts` to 3 will allow cycling on
#' links with LTS 1, 2 or 3. Routing also reverts to walking if the street
#' segment is tagged as non-bikable in OSM (e.g. a staircase), independently of
#' the specified max LTS.
#'
#' The default methodology for assigning LTS values to network edges is based
#' on commonly tagged attributes of OSM ways. See more info about LTS in the
#' original documentation of R5 from Conveyal at
#' <https://docs.conveyal.com/learn-more/traffic-stress>. In summary:
#'
#' - **LTS 1**: Tolerable for children. This includes low-speed, low-volume
#' streets, as well as those with separated bicycle facilities (such as
#' parking-protected lanes or cycle tracks).
#' - **LTS 2**: Tolerable for the mainstream adult population. This includes
#' streets where cyclists have dedicated lanes and only have to interact with
#' traffic at formal crossing.
#' - **LTS 3**: Tolerable for "enthused and confident" cyclists. This includes
#' streets which may involve close proximity to moderate- or high-speed
#' vehicular traffic.
#' - **LTS 4**: Tolerable only for "strong and fearless" cyclists. This
#' includes streets where cyclists are required to mix with moderate- to
#' high-speed vehicular traffic.
#'
#' For advanced users, you can provide custom LTS values by adding a tag `<key
#' = "lts">` to the `osm.pbf` file.
