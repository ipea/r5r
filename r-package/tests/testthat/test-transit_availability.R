# tests/testthat/test-check_transit_availability.R

# Individual skip is still good practice, though setup.R has a global one.
testthat::skip_on_cran()

context("check_transit_availability")

# --- Expected Behavior ---

test_that("automatic operating dates match explicit queries", {
  for (network in list(r5r_network, spo_network)) {
    result <- check_transit_availability(network)
    expect_gt(nrow(result), 0L)
    expect_s3_class(result, "data.table")
    expect_s3_class(result$date, "Date")
    expect_identical(result$date, sort(unique(result$date)))
    expect_true(all(result$active_services > 0L))
    expect_equal(result, check_transit_availability(network, dates = result$date))
  }
})

test_that("date discovery respects exceptions and retained trips", {
  layer <- rJava::.jnew("com/conveyal/r5/transit/TransitLayer")
  service <- rJava::.jnew("com/conveyal/gtfs/model/Service", "weekday")
  calendar <- rJava::.jnew("com/conveyal/gtfs/model/Calendar")
  rJava::.jfield(calendar, "start_date") <- 20240101L
  rJava::.jfield(calendar, "end_date") <- 20240107L
  rJava::.jfield(calendar, "monday") <- 1L
  rJava::.jfield(service, "calendar") <- calendar
  rJava::.jfield(layer, name = "services")$add(service)

  pattern <- rJava::.jnew("com/conveyal/r5/transit/TripPattern",
                          rJava::.jcast(rJava::.jnew("gnu/trove/list/array/TIntArrayList"),
                                       "gnu/trove/list/TIntList"))
  # Use R5's public factory: TripSchedule constructors are private.
  make_trip <- function(code) {
    trip <- rJava::.jnew("com/conveyal/gtfs/model/Trip")
    rJava::.jfield(trip, "feed_id") <- "test"
    rJava::.jfield(trip, "trip_id") <- paste0("trip", code)
    rJava::.jcall(
      "com/conveyal/r5/transit/TripSchedule",
      "Lcom/conveyal/r5/transit/TripSchedule;", "create", trip,
      rJava::.jarray(c(0L, 60L)), rJava::.jarray(c(0L, 60L)),
      rJava::.jcast(rJava::.jnew("java/util/ArrayList"), "java/util/Collection"),
      rJava::.jarray(c(0L, 1L)), as.integer(code)
    )
  }
  trip <- make_trip(0L)
  rJava::.jfield(pattern, name = "tripSchedules")$add(trip)
  rJava::.jfield(layer, name = "tripPatterns")$add(pattern)
  discover <- function() rJava::.jcall(
    "org/ipea/r5r/TransitServiceDates", "[S", "getDates", layer
  )
  add_exception <- function(service, date, type) {
    parts <- as.integer(strsplit(date, "-", fixed = TRUE)[[1]])
    date <- rJava::.jcall("java/time/LocalDate", "Ljava/time/LocalDate;",
                         "of", parts[1], parts[2], parts[3])
    exception <- rJava::.jnew("com/conveyal/gtfs/model/CalendarDate")
    rJava::.jfield(exception, "date") <- date
    rJava::.jfield(exception, "exception_type") <- as.integer(type)
    rJava::.jfield(service, name = "calendar_dates")$put(date, exception)
    invisible(NULL)
  }
  expect_identical(discover(), "2024-01-01")
  add_exception(service, "2024-01-01", 2L)
  expect_length(discover(), 0L)
  add_exception(service, "2024-01-03", 1L)
  add_exception(service, "2024-01-08", 1L)
  expect_identical(discover(), c("2024-01-03", "2024-01-08"))

  exception_only <- rJava::.jnew("com/conveyal/gtfs/model/Service", "special")
  add_exception(exception_only, "2024-02-01", 1L)
  rJava::.jfield(layer, name = "services")$add(exception_only)
  # An unused service must not generate candidate dates.
  expect_identical(discover(), c("2024-01-03", "2024-01-08"))
  second_trip <- make_trip(1L)
  rJava::.jfield(pattern, name = "tripSchedules")$add(second_trip)
  expect_identical(discover(), c("2024-01-03", "2024-01-08", "2024-02-01"))
  # Malformed exception rows can have a null date in a retained R5 cache.
  exception <- rJava::.jnew("com/conveyal/gtfs/model/CalendarDate")
  rJava::.jfield(exception, "exception_type") <- 1L
  rJava::.jfield(exception_only, name = "calendar_dates")$put(
    rJava::.jnull("java/lang/Object"), exception
  )
  expect_identical(discover(), c("2024-01-03", "2024-01-08", "2024-02-01"))
  for (bad in c(0L, 20240230L)) {
    rJava::.jfield(calendar, "start_date") <- bad
    expect_error(discover(), "service 'weekday': invalid calendar bounds")
  }
  rJava::.jfield(calendar, "start_date") <- 20240101L
  rJava::.jfield(calendar, "end_date") <- 20240230L
  expect_error(discover(), "service 'weekday': invalid calendar bounds")
  rJava::.jfield(layer, name = "tripPatterns")$clear()
  expect_length(discover(), 0L)
})

test_that("street-only networks return a typed empty availability table", {
  path <- tempfile("r5r-street-only-")
  dir.create(path)
  file.copy(file.path(spo_path, "spo_osm.pbf"), path)
  network <- build_network(path, verbose = FALSE)
  on.exit({
    stop_r5(network)
    unlink(path, recursive = TRUE)
  })
  result <- check_transit_availability(network)
  expect_identical(result, data.table::data.table(
    date = as.Date(character()), total_services = integer(),
    active_services = integer(), pct_active = numeric()
  ))
  for (dates in list(character(), as.Date(character()))) {
    expect_identical(check_transit_availability(network, dates = dates), result)
  }
})

test_that("check_transit_availability works with a vector of character dates", {
  dates_char <- c("2019-05-13", "2019-05-19") # Weekday and Sunday
  result <- check_transit_availability(r5r_network, dates = dates_char)

  # Check output type and structure
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 2)
  expect_named(
    result,
    c("date", "total_services", "active_services", "pct_active")
  )
  expect_s3_class(result$date, "Date")

  # Check values
  expect_equal(result$active_services, c(116L, 1L))
})

test_that("check_transit_availability works with a vector of Date objects", {
  dates_obj <- as.Date(c("2019-05-13", "2019-05-19"))
  result <- check_transit_availability(r5r_network, dates = dates_obj)

  # Check structure and values
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 2)
  expect_equal(result$date, dates_obj)
  expect_equal(result$active_services, c(116L, 1L))
})

test_that("explicit queries preserve date order and duplicates", {
  dates <- as.Date(c("2019-05-19", "2019-05-13", "2019-05-19"))
  result <- check_transit_availability(r5r_network, dates = dates)
  expect_identical(result$date, dates)
  expect_equal(result$active_services, c(1L, 116L, 1L))
})

test_that("check_transit_availability works with a start_date/end_date range", {
  start <- "2019-05-18" # Saturday
  end <- "2019-05-20" # Monday
  result <- check_transit_availability(
    r5r_network,
    start_date = start,
    end_date = end
  )

  # Check structure and values
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 3)
  expect_equal(result$date, seq(as.Date(start), as.Date(end), by = "day"))
  # Values for Sat, Sun, Mon
  expect_equal(result$active_services, c(1L, 1L, 116L))
})

test_that("check_transit_availability returns 0 active services for dates outside the GTFS calendar", {
  result <- check_transit_availability(r5r_network, dates = "2025-01-01")

  expect_equal(result$active_services, 0L)
  expect_equal(result$pct_active, 0.0)
})

# --- Expected Errors ---

test_that("check_transit_availability throws errors for invalid arguments", {
  consolidated_error_msg <- "Incorrect date arguments provided."

  # Test cases for consolidated date argument logic
  expect_error(
    check_transit_availability(
      r5r_network,
      dates = "2019-01-01",
      start_date = "2019-01-01"
    ),
    consolidated_error_msg
  )
  expect_error(
    check_transit_availability(r5r_network, start_date = "2019-01-01"),
    consolidated_error_msg
  )

  # --- More robust tests for date FORMAT and VALIDITY ---

  # Test for invalid format (slashes instead of dashes)
  expect_error(
    check_transit_availability(r5r_network, dates = "2019/05/13"),
    "Invalid date format found"
  )

  # Test for invalid format (day-month-year)
  expect_error(
    check_transit_availability(r5r_network, dates = "13-05-2019"),
    "Invalid date format found"
  )

  # Test for a logically impossible date (correct format but invalid value)
  # This test will now pass reliably.
  expect_error(
    check_transit_availability(r5r_network, dates = "2025-02-29"), # 2025 is not a leap year
    "logically invalid"
  )

  # Test for start date after end date
  expect_error(
    check_transit_availability(
      r5r_network,
      start_date = "2019-05-20",
      end_date = "2019-05-18"
    ),
    "`start_date` must be before or the same as `end_date`."
  )
})
