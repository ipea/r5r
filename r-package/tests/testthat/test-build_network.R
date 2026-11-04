context("build_network")

# skips tests on CRAN since they require a specific version of java
testthat::skip_on_cran()

path <- system.file("extdata/poa", package = "r5r")

# expected behavior
test_that("build_network - expected behavior", {

  testthat::expect_message( build_network(data_path = path, verbose = F, temp_dir = TRUE) )
  testthat::expect_message( build_network(data_path = path, verbose = T, temp_dir = TRUE) )

  testthat::expect_message( build_network(data_path = path, elevation="TOBLER", temp_dir = TRUE) )

  testthat::expect_is( build_network(data_path = path, temp_dir = TRUE), "r5r_network" )

  # remove files GTFS
  #  file.rename(file.path(path, "poa.zip"), file.path(path, "poa.x"))
  # testthat::expect_message( build_network(data_path = path, verbose = F) )
  #  file.rename(file.path(path, "poa.x"), file.path(path, "poa.zip"))

  # testthat::expect_message(build_network(data_path = path, version='6.4.0', verbose = F, temp_dir = TRUE))

})

# Expected errors
test_that("build_network - expected errors", {

  testthat::expect_error( build_network(data_path = NULL) )
  testthat::expect_error( build_network(data_path = 'a') )
  testthat::expect_error(build_network(data_path = path, verbose = 'a'))
  testthat::expect_error(build_network(data_path = path, temp_dir = 'a'))
  testthat::expect_error(build_network(data_path = path, elevation = 'a'))

  # No OSM data
  r5r_temp <- r5r:::tempdir_unique()
  testthat::expect_error(
    build_network(data_path = r5r_temp)
    )

  })

test_that("'overwrite' parameter works correctly", {

  testthat::expect_error(build_network(path, overwrite = 1))

  # since a network was already created, if overwrite = FALSE it should use it
  testthat::expect_message(
    r5r_network <- build_network(path, verbose = FALSE, temp_dir = TRUE),
    regexp = "Using cached network from"
  )

  # but if overwrite = TRUE, then it should create a new network anyway
  testthat::expect_message(
    r5r_network <- build_network(path, verbose = FALSE, overwrite = TRUE, temp_dir = TRUE),
    regexp = "Finished building network at"
  )

})

test_that("throws error if write access to given dir is denied", {
  # this test only works correctly with unix OSes. not sure how to change
  # permissions from inside R in windows
  skip_if_not(.Platform$OS.type == "unix")

  invisible(file.copy(path, tempdir(), recursive = TRUE))

  tmpdir <- file.path(tempdir(), "poa")

  data_files <- list.files(tmpdir, full.names = TRUE)
  files_to_remove <- data_files[grepl("network|\\.pbf\\.mapdb", data_files)]
  if (length(files_to_remove) > 0) invisible(file.remove(files_to_remove))

  Sys.chmod(tmpdir, "555")

  expect_error(build_network(tmpdir), class = "dir_permission_denied")

  Sys.chmod(tmpdir, "755")
})


# mock test
test_that("throws error if Java is not 21", {

  local_mocked_bindings(
    get_java_version = function(...) 999
  )

  expect_error( r5r:::start_r5r_java(data_path = data_path) )

})

# TO DO: create a mock test
# test_that("throws error due to large geographic extent", {
#
#   my_wrapper <- function(...) {
#     rJava::.jcall(...)
#   }
#
#   local_mocked_bindings(
#     my_wrapper = function(...) "Geographic extent of street layer"
#   )
#
#   # expect_error( r5r:::start_r5r_java(data_path = data_path) )
#
#   build_network(data_path)
#
#   )
# }

test_that("build_network - feeds with errors", {

  # create a feed with an error
  temp_net_dir <- tempfile()
  dir.create(temp_net_dir, mode = "0700")
  gtfs_dir <- file.path(temp_net_dir, "gtfs")
  dir.create(gtfs_dir, mode = "0700")

  # network with medium priority errors: empty frequencies.txt
  # should not prevent network build
  net_medium_dir <- file.path(temp_net_dir, "network_medium")
  dir.create(net_medium_dir, mode = "0700")
  src_net_path <- system.file("extdata/poa", package = "r5r")
  unzip(file.path(src_net_path, "poa_eptc.zip"), exdir = gtfs_dir)
  file.create(file.path(gtfs_dir, "frequencies.txt"))

  # turn back to GTFS
  zip(
    file.path(net_medium_dir, "gtfs.zip"),
    file.path(gtfs_dir, list.files(gtfs_dir)),
    flags = "-j" # don't record directory names
  )

  file.copy(
    file.path(src_net_path, "poa_osm.pbf"),
    file.path(net_medium_dir, "osm.pbf")
  )

  # build network
  testthat::expect_message(
    {net <- build_network(net_medium_dir, temp_dir = TRUE)},
    # current R5 (7.4) records the empty table error twice ?
    regex = "2 errors found in GTFS"
  )

  errors <- get_gtfs_errors(net)

  testthat::expect_equal(
    errors,
    # note that the expected table is dependent on R5 internals. If this test
    # starts failing, check to see if the actual errors have the same meaning as
    # the expected error and update accordingly.
    data.table::data.table(
      # current R5 (7.4) records the empty table error twice ?
      file = "frequencies",
      line = c(0,0),
      type = "EmptyTableError",
      field = NA,
      id = NA,
      priority = "MEDIUM"
    )
  )

  # network with high priority errors: missing stops
  net_high_dir <- file.path(temp_net_dir, "network_high")
  dir.create(net_high_dir, mode = "0700")

  # clean up from medium
  file.remove(file.path(gtfs_dir, "frequencies.txt"))
  trips <- read.csv(file.path(gtfs_dir, "trips.txt"))
  write.csv(
    trips[-1,],
    file.path(gtfs_dir, "trips.txt")
  )

  # turn back to GTFS
  zip(
    file.path(net_high_dir, "gtfs.zip"),
    file.path(gtfs_dir, list.files(gtfs_dir)),
    flags = "-j" # don't record directory names
  )

  file.copy(
    file.path(src_net_path, "poa_osm.pbf"),
    file.path(net_high_dir, "osm.pbf")
  )

  # build network
  testthat::expect_error(
    build_network(net_high_dir, temp_dir = TRUE),
    # current R5 (7.4) records the empty table error twice ?
    regex = "High priority GTFS errors found; network build failed."
  )

  errors <- get_gtfs_errors(net_high_dir)
  testthat::expect_equal(
    errors,
    # note that the expected table is dependent on R5 internals. If this test
    # starts failing, check to see if the actual errors have the same meaning as
    # the expected error and update accordingly.
    data.table::data.table(
      # current R5 short-circuits after high priority error so we only get one
      file = "stop_times",
      line = 2,
      type = "ReferentialIntegrityError",
      field = "trip_id",
      id = NA,
      priority = "HIGH"
    )
  )
})
