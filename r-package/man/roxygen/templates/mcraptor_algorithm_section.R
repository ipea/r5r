#' @section Routing algorithm:
#'
#' The [pareto_frontier()] function, and [detailed_itineraries()] with
#' `shortest_path = FALSE` or a `fare_structure`, use an `R5`-specific
#' extension to the McRAPTOR routing algorithm. The
#' implementation used in `detailed_itineraries()` allows the router to find
#' paths that are optimal and less than optimal in terms of travel time, with
#' some heuristics around multiple access modes, riding the same patterns, etc.
#' The specific extension to McRAPTOR to do suboptimal path routing is not
#' documented yet, but a detailed description of base McRAPTOR can be found in
#' Delling et al (2015). The implementation used in `pareto_frontier()`, on the
#' other hand, returns only the fastest trip within a given monetary cutoff,
#' ignoring slower trips that cost the same. A detailed discussion on the
#' algorithm can be found in Conway and Stewart (2019).
#'
#' - Delling, D., Pajor, T., & Werneck, R. F. (2015). Round-based public
#' transit routing. Transportation Science, 49(3), 591-604.
#' \doi{10.1287/trsc.2014.0534}
#'
#' - Conway, M. W., & Stewart, A. F. (2019). Getting Charlie off the MTA: a
#' multiobjective optimization method to account for cost constraints in public
#' transit accessibility metrics. International Journal of Geographical
#' Information Science, 33(9), 1759-1787. \doi{10.1080/13658816.2019.1605075}
