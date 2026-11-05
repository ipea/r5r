#' Manage cached files from the r5r package
#'
#' @param list_files Logical. Whether to print a message with the address of r5r
#'        JAR files cached locally. Defaults to `TRUE`.
#' @param delete_file String. The file name (basename) of a JAR file cached
#'        locally that should be deleted. Defaults to `NULL`, so that no
#'        file is deleted. If `delete_file = "all"`, then all cached files are
#'        deleted.
#'
#' @return A message indicating which files exist and/or which ones have been
#'         deleted from local cache directory.
#' @export
#' @family Cache data
#' @examplesIf identical(tolower(Sys.getenv("NOT_CRAN")), "true")
#' # download r5 JAR
#' r5r::download_r5()
#'
#' # list all files cached
#' r5r_cache(list_files = TRUE)
#'
#' # delete r5 JAR
#' r5r_cache(delete_file = 'r5-v7.0')
#'
r5r_cache <- function(list_files = TRUE,
                      delete_file = NULL){

  # check inputs
  checkmate::assert_logical(list_files)
  checkmate::assert_character(delete_file, null.ok = TRUE)

  # find / create local dir
  if (!dir.exists(r5r_env$cache_dir)) { dir.create(r5r_env$cache_dir, recursive=TRUE) }

  # list cached files
  files <- list.files(dirname(r5r_env$cache_dir), full.names = TRUE, recursive = TRUE)

  # if wants to delete file
  # delete_file = "r5-v7.0-all.jar"
  if (!is.null(delete_file)) {

    # IF file does not exist, print message
    if (!any(grepl(delete_file, files)) & delete_file != "all") {
      message(paste0("The file '", delete_file, "' is not cached."))
    }

    # IF file exists, delete file
    if (any(grepl(delete_file, files))) {
      f <- files[grepl(delete_file, files)]
      unlink(f, recursive = TRUE, force = TRUE)
      message(paste0("The file '", delete_file, "' has been removed."))
    }

    # Delete ALL file
    if (delete_file=='all') {

      # delete any files from censobr, current and old data releases
      dir_above <- dirname(r5r_env$cache_dir)
      unlink(dir_above, recursive = TRUE, force = TRUE)
      message(paste0("All files have been removed."))

    }
  }

  # list cached files
  files <- list.files(r5r_env$cache_dir, full.names = TRUE)

  # print file names
  if(isTRUE(list_files)){
    message('Files currently cached:')
    message(paste0(files, collapse = '\n'))
  }
}
