#' Java object to data.table
#'
#' @description Converts a Java object returned by r5r_network to an R `data.table`
#'
#' @param obj A Java Object reference
#' @param ids An optional named list of character vectors, e.g.
#'        `list(from_id = origins$id, to_id = destinations$id)`, holding the
#'        ids sent to Java. String columns named here are transferred as
#'        integer positions in these vectors, which is much faster than
#'        transferring one Java string per row.
#'
#' @return An R data.table
#' @family java support functions
#'
#' @keywords internal
java_to_dt <- function(obj, ids = NULL) {

  # check input
  if(class(obj)[1] != "jobjRef"){
    stop("Input must be an object of class 'jobjRef'")}

  # get column names from Java table
  columns <- obj$getColumnNames()

  # get the contents of each column in a vector, and return them in a list
  dt <- lapply(columns, function(column_name) {
    # check column data type, so we can call the appropriate Java function
    column_type <- obj$getColumnType(column_name)

    if (column_type == "String" && column_name %in% names(ids)) {
      # .jcall + .jarray so a single id is still passed as String[]
      pos <- rJava::.jcall(obj, "[I", "getStringColumnIndex", column_name,
                           rJava::.jarray(ids[[column_name]]))
      return(ids[[column_name]][pos + 1L])
    }

    if (column_type == "String") { v <- obj$getStringColumn(column_name) }
    if (column_type == "Integer") { v <- obj$getIntegerColumn(column_name) }
    if (column_type == "Long") { v <- obj$getLongColumn(column_name) }
    if (column_type == "Double") { v <- obj$getDoubleColumn(column_name) }
    if (column_type == "Boolean") { v <- obj$getBooleanColumn(column_name) }
    return(v)
  })

  # convert list of vectors to a data.table, and rename columns accordingly
  data.table::setDT(dt)
  data.table::setnames(dt, new = columns)
}

#' Run a routing call on a Java background thread and print its progress
#'
#' @description Makes `R5RCore` start the routing method in `call` on a
#'   background thread, then polls it from R. This way the progress counter is
#'   printed by R, and shown in any console (Java's own output only reaches
#'   terminals), and the call can be interrupted. An interrupted job is
#'   cancelled by `resetRoutingProperties()`, which every routing function
#'   calls on exit. With `options(r5r.async = FALSE)` the call runs
#'   synchronously.
#'
#' @param r5r_network A Java reference to `org.ipea.r5r.R5RCore`.
#' @param call The call to the routing method, evaluated lazily.
#' @param progress A logical. Whether to print the progress counter.
#'
#' @return The Java object returned by the routing method.
#' @family java support functions
#'
#' @keywords internal
run_routing_job <- function(r5r_network, call, progress) {
  if (!isTRUE(getOption("r5r.async", TRUE))) return(call)

  r5r_network$deferNextRun()
  force(call) # starts the job and returns NULL at once

  # printed to stderr, like the "Preparing final output..." message
  show <- progress && !isTRUE(getOption("knitr.in.progress"))
  if (show) on.exit(cat("\n", file = stderr()), add = TRUE)

  last <- -1L
  repeat {
    done <- rJava::.jcall(r5r_network, "Z", "waitForJob", 200L)
    if (show) {
      n <- rJava::.jcall(r5r_network, "I", "getJobProcessed")
      if (n != last) {
        total <- rJava::.jcall(r5r_network, "I", "getJobTotal")
        cat("\r", n, " out of ", total, " origins processed.", sep = "", file = stderr())
        last <- n
      }
    }
    if (done) break
  }

  return(r5r_network$getJobResult())
}

#' data.table to speedMap
#'
#' @description Converts a `data.frame` with road OSM id's and respective speeds
#'              to a Java Map<Long, Float> for use by r5r_network.
#'
#' @param dt data.frame/data.table. Table specifying the
#'        speed modifications. The table must contain columns \code{osm_id} and
#'        \code{max_speed}.
#' @return A speedMap (Java HashMap<Long, Float>)
#' @family java support functions
#' @keywords internal
dt_to_speed_map <- function(dt) {
  if (is.null(dt)){
    return (rJava::.jnew("java/util/HashMap"))
  }

  checkmate::assert_names(names(dt), must.include = c("osm_id", "max_speed", "speed_type"))
  checkmate::assert_numeric(dt$osm_id, any.missing = FALSE, all.missing = FALSE)
  checkmate::assert_numeric(dt$max_speed, any.missing = FALSE, all.missing = FALSE)
  checkmate::assert_true(length(unique(dt$speed_type)) == 1 && dt$speed_type[1] %in% c("km/h", "scale"))

  # Create new HashMap<long, float>
  map_builder <- rJava::.jnew("org.ipea.r5r.Utils.RMapBuilder")
  speed_map <- map_builder$buildSpeedMap(paste(as.character(dt$osm_id), collapse = ","),
                                        paste(as.character(dt$max_speed), collapse = ","))

  return(speed_map)
}


#' Determine the Java version installed locally
#'
#' @return The number of the Java version
#' @family java support functions
#' @keywords internal
get_java_version <- function(){
  ver <- rJava::.jcall("java.lang.System", "S", "getProperty", "java.version")
  ver <- as.numeric(gsub("\\..*", "", ver))
  return(ver)
}


#' data.table to ltsMap
#'
#' @description Converts a `data.frame` with road OSM id's and respective LTS
#'              levels a Java Map<Long, Integer> for use by r5r_network.
#'
#' @param dt data.frame/data.table. Table specifying the
#'        LTS levels. The table must contain columns \code{osm_id} and
#'        \code{lts}.
#' @return A speedMap (Java HashMap<Long, Integer>)
#' @family java support functions
#' @keywords internal
dt_to_lts_map <- function(dt) {
  checkmate::assert_names(names(dt), must.include = c("osm_id", "lts"))
  checkmate::assert_numeric(dt$osm_id, any.missing = FALSE, all.missing = FALSE)
  checkmate::assert_integer(dt$lts, any.missing = FALSE, all.missing = FALSE)

  # Create new HashMap<Long, Integer>
  map_builder <- rJava::.jnew("org.ipea.r5r.Utils.RMapBuilder")
  lts_map <- map_builder$buildLtsMap(paste(as.character(dt$osm_id), collapse = ","),
                                         paste(as.character(dt$lts), collapse = ","))

  return(lts_map)
}
