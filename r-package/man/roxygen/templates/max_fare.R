#' @param max_fare A number. The maximum value that trips can cost when
#'   calculating the fastest journey between each origin and destination pair.
#'   Defaults to `Inf` (no limit). A finite value requires a `fare_structure`;
#'   an error is raised otherwise.
