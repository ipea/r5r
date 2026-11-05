#' Stop running r5r network
#'
#' @description Stops the given `r5r_network` objects, or all `r5r_network`
#' objects in the calling environment if none is supplied.
#'
#' @param ... \code{r5r_network} objects currently running. By default, if no
#'            r5r network is supplied all running networks are stopped.
#' @return No return value, called for side effects.
#'
#' @family support functions
#'
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' library(r5r)
#'
#' path <- system.file("extdata/poa", package = "r5r")
#'
#' r5r_network <- build_network(path)
#'
#' stop_r5(r5r_network)
#' @export
stop_r5 <- function(...) {

  supplied_cores <- list(...)

  # find all running r5r networks in the parent frame

  current_objects <- mget(ls(envir = parent.frame()), envir = parent.frame())

  classes_list <- lapply(current_objects, class)

  running_cores <- current_objects[which(classes_list == "r5r_network")]

  # if no networks have been supplied, remove all running networks
  # else, remove matches between running and supplied networks

  if (length(supplied_cores) == 0) {

    rm(list = names(running_cores), envir = parent.frame())

    message("All r5r networks have been successfully stopped.")

  } else {

    matches_supplied <- running_cores[running_cores %in% supplied_cores]

    # if a match has been found, stop it
    # else, a non r5r core object has been supplied, which raises a warning

    if (length(matches_supplied) >= 1) {

      rm(list = names(matches_supplied), envir = parent.frame())

      message(paste0(paste(names(matches_supplied), collapse = ", "),
                     " has been successfully stopped."))

    } else {

      unknown_object <- current_objects[current_objects %in% supplied_cores]

      warning(paste0(paste(names(unknown_object), collapse = ", "),
                     " is not a r5r core object."))

    }

  }

  rJava::.jgc()

}
