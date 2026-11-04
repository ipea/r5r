# Calculate travel time and monetary cost Pareto frontier

Fast computation of travel time and monetary cost Pareto frontier
between origin and destination pairs.

## Usage

``` r
pareto_frontier(
  r5r_network,
  origins,
  destinations,
  mode = c("WALK", "TRANSIT"),
  mode_egress = "WALK",
  departure_datetime = NULL,
  time_window = 10L,
  seed = NULL,
  percentiles = 50L,
  max_walk_time = Inf,
  max_bike_time = Inf,
  max_car_time = Inf,
  max_trip_duration = 120L,
  fare_structure,
  fare_cutoffs,
  walk_speed = 3.6,
  bike_speed = 12,
  max_rides = 3,
  max_lts = 2,
  n_threads = Inf,
  verbose = FALSE,
  progress = TRUE,
  output_dir = NULL,
  r5r_core = deprecated()
)
```

## Arguments

- r5r_network:

  A routable transport network created with
  [`build_network()`](https://ipea.github.io/r5r/dev/reference/build_network.md).

- origins, destinations:

  Either a `POINT sf` object with WGS84 CRS, or a `data.frame`
  containing the columns `id`, `lon` and `lat`.

- mode:

  A character vector. The transport modes allowed for access, transfer
  and vehicle legs of the trips. Defaults to `WALK`. See details for
  other options.

- mode_egress:

  A character vector. The transport mode used after egress from the last
  public transport. It can be either `WALK`, `BICYCLE` or `CAR`.
  Defaults to `WALK`. Ignored when public transport is not used.

- departure_datetime:

  A POSIXct object. Only affects public transport legs; when routing
  with public transport, it must fall within the service period of the
  GTFS feeds (`calendar.txt`; see
  [`check_transit_availability()`](https://ipea.github.io/r5r/dev/reference/check_transit_availability.md)).
  Required for public transport; optional otherwise. See details for how
  datetimes are parsed.

- time_window:

  An integer. The time window in minutes. Departures are simulated every
  minute from `departure_datetime` until `time_window` minutes later,
  and travel times are summarized over these departures using
  `percentiles` (the median by default). With a `fare_structure`, and
  always in `pareto_frontier()`, departures are instead sampled at
  random within the window: `draws_per_minute` per minute on average
  (one in `pareto_frontier()`), different for each origin and the same
  in every call from the same origin with the same `seed`. Defaults
  to 10. See
  [`vignette("time_window", package = "r5r")`](https://ipea.github.io/r5r/dev/articles/time_window.md).

- seed:

  An integer or `NULL`. The seed of the Monte Carlo draws of the
  departure offsets of frequency-based transit routes and, with the
  McRaptor algorithm, of the departure times sampled within
  `time_window`. Defaults to `NULL`, in which case the draws are random
  and results may vary slightly between runs. With an integer, the same
  inputs always give the same results, regardless of `n_threads`.
  Results are still a Monte Carlo sample, so a different seed may give
  slightly different results: report the seed used and check how
  sensitive the results are to it. Note that
  [`set.seed()`](https://rdrr.io/r/base/Random.html) has no effect on
  these draws. With the default routing algorithm, this parameter only
  affects the results when the GTFS feeds contain a `frequencies.txt`
  table. This function always uses the McRaptor algorithm, so `seed`
  affects the results with or without frequencies.

- percentiles:

  An integer vector (max length of 5). Specifies the percentile to use
  when returning travel time estimates within the given time window.
  This parameter is applied to the travel time estimates only (e.g. if
  the 25th percentile is specified, and the output between A and B is 15
  minutes and 10 dollars, 25% of all trips cheaper than 10 dollars taken
  between these points are shorter than 15 minutes). Defaults to 50,
  returning the median travel time. If a vector with length bigger than
  1 is passed, the output contains an additional column that specifies
  the percentile of each travel time and monetary cost combination. Due
  to upstream restrictions, only 5 percentiles can be specified at a
  time. See the R5 documentation at
  <https://docs.conveyal.com/analysis/methodology#accounting-for-variability>.

- max_walk_time:

  An integer. The maximum walking time (in minutes) to access and egress
  the transit network, make transfers, or complete walk-only trips.
  Applies to each leg separately (e.g. `15` allows up to 15 minutes to
  reach transit and another 15 after leaving it). Defaults to `Inf` (no
  limit besides `max_trip_duration`). In walk-only trips, the lower of
  `max_walk_time` and `max_trip_duration` applies.

- max_bike_time:

  An integer. The maximum cycling time (in minutes) to access and egress
  the transit network, make transfers, or complete bicycle-only trips.
  Applies to each leg separately (e.g. `15` allows up to 15 minutes to
  reach transit and another 15 after leaving it). Defaults to `Inf` (no
  limit besides `max_trip_duration`). In bicycle-only trips, the lower
  of `max_bike_time` and `max_trip_duration` applies.

- max_car_time:

  An integer. The maximum driving time (in minutes) to access and egress
  the transit network, or to complete car-only trips. Applies to each
  leg separately (e.g. `15` allows up to 15 minutes to reach transit and
  another 15 after leaving it). Defaults to `Inf` (no limit besides
  `max_trip_duration`). In car-only trips, the lower of `max_car_time`
  and `max_trip_duration` applies.

- max_trip_duration:

  An integer. The maximum trip duration in minutes. Defaults to 120.

- fare_structure:

  A fare structure object, following the convention set in
  [`setup_fare_structure()`](https://ipea.github.io/r5r/dev/reference/setup_fare_structure.md).
  This object describes how transit fares should be calculated. See
  [`vignette("fare_structure", package = "r5r")`](https://ipea.github.io/r5r/dev/articles/fare_structure.md)
  for its structure. Required: without it there are no fares to trade
  off against travel time.

- fare_cutoffs:

  A numeric vector, required. The monetary cutoffs (each greater than or
  equal to 0) used to build the Pareto frontier. Usually these are all
  possible fares in your `fare_structure`, including sums of fares for
  trips with transfers. Coarse cutoffs merge different trips: with
  routes costing \$3 and \$4 and a single cutoff of `5`, the output
  shows the fastest trips costing up to \$5 but not which route they
  used; `c(3, 4)` separates them.

- walk_speed:

  A numeric. Average walk speed in km/h. Defaults to 3.6.

- bike_speed:

  A numeric. Average cycling speed in km/h. Defaults to 12.

- max_rides:

  An integer. The maximum number of public transport rides allowed in
  the same trip. Defaults to 3.

- max_lts:

  An integer between 1 and 4. The maximum level of traffic stress that
  cyclists will tolerate. A value of 1 means cyclists will only travel
  through the quietest streets, while a value of 4 indicates cyclists
  can travel through any road. Defaults to 2. See details.

- n_threads:

  An integer. The number of threads to use when running the router in
  parallel. Defaults to `Inf` (all available threads).

- verbose:

  A logical. Whether to show `R5` informative messages when running the
  function. Defaults to `FALSE` (`R5` error messages are still shown).
  `TRUE` shows detailed output, useful for debugging issues not caught
  by `r5r`.

- progress:

  A logical. Whether to show a progress counter when running the router.
  Defaults to `TRUE`. Only works when `verbose` is `FALSE`. May slightly
  slow computation, as the counter is synchronized across threads.

- output_dir:

  Either `NULL` (the default) or a path to an existing directory. When a
  path is given, the function writes the results as `.csv` files to that
  directory and returns the path instead of the results. Useful in
  memory-constrained settings, as results are not loaded into RAM.
  Missing values (`NA`) are written as empty fields.

- r5r_core:

  The `r5r_core` argument is deprecated as of r5r v2.3.0. Use the
  `r5r_network` argument instead.

## Value

A `data.table` with the travel time and monetary cost Pareto frontier
between the specified origins and destinations. An additional column
identifying the travel time percentile is present if more than one value
was passed to `percentiles`. Origin and destination pairs whose trips
couldn't be completed within the maximum travel time using less money
than the specified monetary cutoffs are not returned in the
`data.table`. If `output_dir` is not `NULL`, the function returns the
path specified in that parameter, in which the `.csv` files containing
the results are saved.

## Transport modes

`R5` allows for multiple combinations of transport modes. The options
include:

- **Transit modes:** `TRAM`, `SUBWAY`, `RAIL`, `BUS`, `FERRY`,
  `CABLE_CAR`, `GONDOLA`, `FUNICULAR`. The option `TRANSIT`
  automatically considers all public transport modes available.

- **Non transit modes:** `WALK`, `BICYCLE`, `CAR`.

## Level of Traffic Stress (LTS)

When cycling is enabled in `R5` (by passing the value `BICYCLE` to
either `mode` or `mode_egress`), setting `max_lts` will allow cycling
only on streets with a given level of danger/stress. Setting `max_lts`
to 1, for example, will allow cycling only on separated bicycle
infrastructure or low-traffic streets and routing will revert to walking
when traversing any links with LTS exceeding 1. Setting `max_lts` to 3
will allow cycling on links with LTS 1, 2 or 3. Routing also reverts to
walking if the street segment is tagged as non-bikable in OSM (e.g. a
staircase), independently of the specified max LTS.

The default methodology for assigning LTS values to network edges is
based on commonly tagged attributes of OSM ways. See more info about LTS
in the original documentation of R5 from Conveyal at
<https://docs.conveyal.com/learn-more/traffic-stress>. In summary:

- **LTS 1**: Tolerable for children. This includes low-speed, low-volume
  streets, as well as those with separated bicycle facilities (such as
  parking-protected lanes or cycle tracks).

- **LTS 2**: Tolerable for the mainstream adult population. This
  includes streets where cyclists have dedicated lanes and only have to
  interact with traffic at formal crossing.

- **LTS 3**: Tolerable for "enthused and confident" cyclists. This
  includes streets which may involve close proximity to moderate- or
  high-speed vehicular traffic.

- **LTS 4**: Tolerable only for "strong and fearless" cyclists. This
  includes streets where cyclists are required to mix with moderate- to
  high-speed vehicular traffic.

For advanced users, you can provide custom LTS values by adding a tag
`<key = "lts">` to the `osm.pbf` file.

## Datetime parsing

`r5r` ignores the timezone attribute of datetime objects when parsing
dates and times, using the study area's timezone instead. For example,
let's say you are running some calculations using Rio de Janeiro,
Brazil, as your study area. The datetime
`as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S")` will
be parsed as May 13th, 2019, 14:00h in Rio's local time, as expected.
But
`as.POSIXct("13-05-2019 14:00:00", format = "%d-%m-%Y %H:%M:%S", tz = "Europe/Paris")`
will also be parsed as the exact same date and time in Rio's local time,
perhaps surprisingly, ignoring the timezone attribute.

## Routing algorithm

The `pareto_frontier()` function, and
[`detailed_itineraries()`](https://ipea.github.io/r5r/dev/reference/detailed_itineraries.md)
with `shortest_path = FALSE` or a `fare_structure`, use an `R5`-specific
extension to the McRAPTOR routing algorithm. The implementation used in
[`detailed_itineraries()`](https://ipea.github.io/r5r/dev/reference/detailed_itineraries.md)
allows the router to find paths that are optimal and less than optimal
in terms of travel time, with some heuristics around multiple access
modes, riding the same patterns, etc. The specific extension to McRAPTOR
to do suboptimal path routing is not documented yet, but a detailed
description of base McRAPTOR can be found in Delling et al (2015). The
implementation used in `pareto_frontier()`, on the other hand, returns
only the fastest trip within a given monetary cutoff, ignoring slower
trips that cost the same. A detailed discussion on the algorithm can be
found in Conway and Stewart (2019).

- Delling, D., Pajor, T., & Werneck, R. F. (2015). Round-based public
  transit routing. Transportation Science, 49(3), 591-604.
  [doi:10.1287/trsc.2014.0534](https://doi.org/10.1287/trsc.2014.0534)

- Conway, M. W., & Stewart, A. F. (2019). Getting Charlie off the MTA: a
  multiobjective optimization method to account for cost constraints in
  public transit accessibility metrics. International Journal of
  Geographical Information Science, 33(9), 1759-1787.
  [doi:10.1080/13658816.2019.1605075](https://doi.org/10.1080/13658816.2019.1605075)

## See also

Other routing:
[`arrival_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/arrival_travel_time_matrix.md),
[`detailed_itineraries()`](https://ipea.github.io/r5r/dev/reference/detailed_itineraries.md),
[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md),
[`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md)

## Examples

``` r
library(r5r)

# build transport network
data_path <- system.file("extdata/poa", package = "r5r")
r5r_network <- build_network(data_path = data_path)
#> ℹ Using cached network from
#>   /home/runner/work/_temp/Library/r5r/extdata/poa/network.dat.

# load origin/destination points
points <- read.csv(file.path(data_path, "poa_hexgrid.csv"))[1:5,]

# load fare structure object
fare_structure_path <- system.file(
  "extdata/poa/fares/fares_poa.zip",
  package = "r5r"
)
fare_structure <- read_fare_structure(fare_structure_path)

departure_datetime <- as.POSIXct(
  "13-05-2019 14:00:00",
  format = "%d-%m-%Y %H:%M:%S"
)

pf <- pareto_frontier(
  r5r_network,
  origins = points,
  destinations = points,
  mode = c("WALK", "TRANSIT"),
  departure_datetime = departure_datetime,
  fare_structure = fare_structure,
  fare_cutoffs = c(4.5, 4.8, 9, 9.3, 9.6)
)
#> Loading required namespace: testthat
head(pf)
#>            from_id           to_id percentile travel_time monetary_cost
#>             <char>          <char>      <int>       <int>         <num>
#> 1: 89a901291abffff 89a901291abffff         50           2           4.5
#> 2: 89a901291abffff 89a9012a3cfffff         50          72           9.0
#> 3: 89a901291abffff 89a901295b7ffff         50          61           4.5
#> 4: 89a901291abffff 89a901295b7ffff         50          55           4.8
#> 5: 89a901291abffff 89a901295b7ffff         50          45           9.0
#> 6: 89a901291abffff 89a901284a3ffff         50          59           4.8

stop_r5(r5r_network)
#> r5r_network has been successfully stopped.
```
