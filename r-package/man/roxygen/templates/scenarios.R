#' @param new_carspeeds A `data.frame` specifying the new car speed for each OSM
#'        edge id. This table must contain columns \code{osm_id}, \code{max_speed}
#'        and \code{speed_type}. The `"speed_type"` column is of class character
#'        and it indicates whether the values in `"max_speed"` should be
#'        interpreted as percentages of original speeds (`"scale"`) or as absolute
#'        speeds (`"km/h"`). Alternatively, the `new_carspeeds` parameter can
#'        receive an `sf data.frame` with POLYGON geometry that indicates the new
#'        car speed for all the roads that fall within each polygon. In this case,
#'        the table must contain the columns \code{poly_id} with a unique id for
#'        each polygon, \code{scale} with the new speed scaling factors and
#'        \code{priority}, which is a number ranking which polygon should be
#'        considered in case of overlapping polygons. See more info in the
#'        scenarios vignette (`vignette("scenarios", package = "r5r")`).
#' @param carspeed_scale Numeric. The scaling factor applied to the car speed
#'        of road segments not specified in `new_carspeeds`. Defaults to `1`,
#'        which keeps the speeds of the unlisted roads unchanged.
#' @param new_lts A `data.frame` specifying the new LTS levels for each OSM edge
#'        id. The table must contain columns \code{osm_id} and \code{lts}.
#'        Alternatively, the `new_lts` parameter can receive an `sf data.frame`
#'        with LINESTRING geometry. R5 will then find the nearest road for each
#'        LINESTRING and update its LTS value accordingly.
