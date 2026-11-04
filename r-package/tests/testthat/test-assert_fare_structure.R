path <- system.file("extdata/poa/fares/fares_poa.zip", package = "r5r")
struc <- read_fare_structure(path)

copied_element <- function(element) {
  results <- struc
  results[[element]] <- data.table::copy(struc[[element]])
  results
}

test_that("basic structure is right", {
  expect_error(assert_fare_structure("a"))

  struc_copy <- struc
  struc_copy$max_discounted_transfers <- NULL
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$fare_cap2 <- struc$fare_cap
  expect_error(assert_fare_structure(struc_copy))

  names(struc_copy) <- gsub("fare_cap2", "fare_cap", names(struc_copy))
  expect_error(assert_fare_structure(struc_copy))
})

test_that("max_discounted_transfers is right", {
  struc_copy <- struc
  struc_copy$max_discounted_transfers <- "1"
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$max_discounted_transfers <- -1
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$max_discounted_transfers <- NA
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$max_discounted_transfers <- c(2, 2)
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$max_discounted_transfers <- Inf
  expect_true(assert_fare_structure(struc_copy))
})

test_that("transfer_time_allowance is right", {
  struc_copy <- struc
  struc_copy$transfer_time_allowance <- "1"
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$transfer_time_allowance <- -1
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$transfer_time_allowance <- NA
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$transfer_time_allowance <- c(2, 2)
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$transfer_time_allowance <- Inf
  expect_true(assert_fare_structure(struc_copy))
})

test_that("fare_cap is right", {
  struc_copy <- struc
  struc_copy$fare_cap <- "1"
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$fare_cap <- -1
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$fare_cap <- NA
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$fare_cap <- c(2, 2)
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$fare_cap <- Inf
  expect_true(assert_fare_structure(struc_copy))
})

test_that("fares_per_type is right", {
  struc_copy <- struc
  struc_copy$fares_per_type <- "1"
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[, type := as.factor(type)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[1, type := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_type[1, type := "RAIL"]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[
    ,
    unlimited_transfers := as.factor(unlimited_transfers)
  ]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[1, unlimited_transfers := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[
    ,
    allow_same_route_transfer := as.factor(allow_same_route_transfer)
  ]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[1, allow_same_route_transfer := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[, use_route_fare := as.factor(use_route_fare)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[1, use_route_fare := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[, fare := as.factor(fare)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_type")
  struc_copy$fares_per_type[1, fare := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_type[1, fare := -1]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_type[1, fare := Inf]
  expect_error(assert_fare_structure(struc_copy))
})

test_that("fares_per_transfer is right", {
  struc_copy <- struc
  struc_copy$fares_per_transfer <- "1"
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- struc
  struc_copy$fares_per_transfer <- data.table::data.table(NULL)
  expect_true(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_transfer")
  struc_copy$fares_per_transfer[, first_leg := as.factor(first_leg)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_transfer")
  struc_copy$fares_per_transfer[1, first_leg := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_transfer[1, first_leg := "oie"]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_transfer")
  struc_copy$fares_per_transfer[, second_leg := as.factor(second_leg)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_transfer")
  struc_copy$fares_per_transfer[1, second_leg := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_transfer[1, second_leg := "oie"]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_transfer")
  struc_copy$fares_per_transfer[, fare := as.factor(fare)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_transfer")
  struc_copy$fares_per_transfer[1, fare := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_transfer[1, fare := -1]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_transfer[1, fare := Inf]
  expect_error(assert_fare_structure(struc_copy))
})

test_that("fares_per_route is right", {
  struc_copy <- struc
  struc_copy$fares_per_route <- "1"
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, agency_id := as.factor(agency_id)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, agency_id := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, agency_name := as.factor(agency_name)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, agency_name := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, route_id := as.factor(route_id)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, route_id := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, route_short_name := as.factor(route_short_name)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, route_short_name := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, route_long_name := as.factor(route_long_name)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, route_long_name := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, mode := as.factor(mode)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, mode := NA]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, route_fare := as.factor(route_fare)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, route_fare := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_route[1, route_fare := -1]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_route[1, route_fare := Inf]
  expect_error(assert_fare_structure(struc_copy))

  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[, fare_type := as.factor(fare_type)]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy <- copied_element("fares_per_route")
  struc_copy$fares_per_route[1, fare_type := NA]
  expect_error(assert_fare_structure(struc_copy))
  struc_copy$fares_per_route[1, fare_type := "oie"]
  expect_error(assert_fare_structure(struc_copy))
})
