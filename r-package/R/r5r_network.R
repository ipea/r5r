#' Class to internally handle Java reference to R5RCore
#'
#' @family r5r_network
#'
#' @keywords internal
#' @importClassesFrom rJava jobjRef
setClass(
  "r5r_network",
  slots = list(jcore = "jobjRef")
)

#' Constructor for r5r_network object
#'
#' @description
#' Wraps a Java R5RCore as an r5r_network.
#'
#' @param jcore A \code{jobjRef} Java object reference to R5RCore.
#' @return \code{r5r_network}
#'
#' @family r5r_network
#'
#' @keywords internal
wrap_r5r_network <- function(jcore) { # nocov start
  if (!identical(jcore$identify(), "I am an R5R core!")) {
    stop('Provided object is not a valid reference to a java R5R core.')
  }

  # a jcore can pass identify() but still have uninitialized routing
  # properties on the Java side (see build_network()'s cache branch)
  routing_is_initialized <- tryCatch(
    {
      jcore$getWalkSpeed()
      TRUE
    },
    error = function(e) FALSE
  )

  if (!routing_is_initialized) {
    stop(
      "This r5r_network has an uninitialized routing engine (its ",
      "'routingProperties' are NULL on the Java side), so it cannot be used ",
      "for routing. This usually happens when a cached 'network.dat' was ",
      "incompatible and R5's internal rebuild attempt failed, most commonly ",
      "due to high priority GTFS errors. Rebuild explicitly with ",
      "build_network(data_path, overwrite = TRUE) to see the underlying ",
      "error and a 'gtfs_errors.csv' with details."
    )
  }

  methods::new("r5r_network", jcore = jcore)
} # nocov end
