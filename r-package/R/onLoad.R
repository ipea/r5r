# initial message about ram memory
.onAttach <- function(lib, pkg) { # nocov start
  msg <- cli::format_inline(
    "Please make sure you have already allocated some memory to Java by running
    {.code options(java.parameters = '-Xmx2G')} *before* loading library(r5r)

    You should replace {.val 2G} by the amount of memory you'll need.
    Currently, Java memory is set to {.val {getOption('java.parameters')}}."
  )

  packageStartupMessage(msg)
  } # nocov end

# package global variables
r5r_env <- new.env(parent = emptyenv())

.onLoad <- function(lib, pkg) { # nocov start

  # JAR version
  r5r_env$r5_jar_version <- "7.6.0" # "7.5.1"
  r5r_env$r5_jar_size <- 65103995 #  64437969

  # create dir to store R5 Jar
  cache_d <- paste0('r5r/r5_jar_v', r5r_env$r5_jar_version)
  r5r_env$cache_dir <- tools::R_user_dir(cache_d, which = 'cache')
  if (!dir.exists(r5r_env$cache_dir)) dir.create(r5r_env$cache_dir, recursive = TRUE)
  # gsub("\\\\", "/", r5r_env$cache_dir)

  ## delete any JAR files from old releases
  dir_above <- dirname(r5r_env$cache_dir)
  all_cache <- list.files(dir_above, pattern = 'r5',full.names = TRUE)
  old_cache <- all_cache[!grepl(r5r_env$r5_jar_version, all_cache)]
  if(length(old_cache)>0){ unlink(old_cache, recursive = TRUE) }

} # nocov end
