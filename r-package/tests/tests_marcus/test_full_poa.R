# test R5
options(java.parameters = "-Xmx16G")
# source('./R/fun/setup.R')
# source("./R/fun/selecionar_data_gtfs.R")


# devtools::install_github("ipea/r5r", subdir = "r-package")
# library(r5r)
devtools::load_all(".")
library(data.table)

# get folders
# folders_graphs <- list.dirs("../../otp/graphs")
# folders_graphs <- folders_graphs[-1]
# folders_graphs <- folders_graphs[-1]
# folders_graphs <- folders_graphs[folders_graphs %like% paste0(munis_df_2019[modo == "todos"]$abrev_muni, collapse = "|")]
# folders_graphs <- folders_graphs[folders_graphs %like% "2019"]

folder_graphs <- "../../poa_data/"
folder_points <- "../../poa_data/"
folder_year <- "2019"
folder_muni <- "poa"


# selecionar_data_gtfs("poa", 2019)

# r5 setup - bho ---------------------------------------
setup <- setup_r5(data_path = folder_graphs, verbose = FALSE)

# points
points_file <- paste0(folder_points, "points_", folder_muni, "_09_", folder_year, ".csv")
points <- fread(points_file)
colnames(points) <- c("id", "lon", "lat")



# poa: 128.531 sec elapsed - 10 threads
# poa: 224.594 sec elapsed -  4 threads
tictoc::tic(folder_muni)
df_n <- travel_time_matrix(setup,
                           origin = points,
                           destination = points,
                           time_window = 120,
                           percentiles = c(5, 25, 50, 75, 95),
                           breakdown = FALSE,
                           max_walk_dist = 1000,
                           max_trip_duration = 120,
                           departure_datetime = as.POSIXct("2019-06-19 07:00:00"),
                           mode = c("WALK", "TRANSIT"),
                           n_threads = 4,
                           verbose = FALSE,
                           progress = TRUE)
tictoc::toc()

setup$setCsvOutput(here::here("tests_marcus/data"))
# ttmatrix bho - 222.32 secs
tictoc::tic(folder_muni)
df_b <- travel_time_matrix(setup,
                           origin = points,
                           destination = points,
                           time_window = 120,
                           percentiles = c(5, 25, 50, 75, 95),
                           breakdown = TRUE,
                           max_walk_dist = 1000,
                           max_trip_duration = 120,
                           departure_datetime = as.POSIXct("2019-06-19 07:00:00"),
                           mode = c("WALK", "TRANSIT"),
                           n_threads = 4,
                           verbose = FALSE,
                           progress = TRUE)
tictoc::toc()


