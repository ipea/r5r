# Detailed itineraries between origin-destination pairs

Returns detailed trip information between origin-destination pairs: the
waiting and moving time, distance, route and geometry of each trip leg.
Designed for trip planning (like Google's Directions API or
OpenTripPlanner), it takes much more time and memory than the package's
other, more analytical, routing functions.

## Usage

``` r
detailed_itineraries(
  r5r_network,
  origins,
  destinations,
  mode = "WALK",
  mode_egress = "WALK",
  departure_datetime = Sys.time(),
  time_window = 10L,
  suboptimal_minutes = 0L,
  max_walk_time = Inf,
  max_bike_time = Inf,
  max_car_time = Inf,
  max_trip_duration = 120L,
  walk_speed = 3.6,
  bike_speed = 12,
  max_rides = 3,
  max_lts = 2,
  shortest_path = TRUE,
  all_to_all = FALSE,
  fare_structure = NULL,
  max_fare = Inf,
  new_carspeeds = NULL,
  carspeed_scale = 1,
  new_lts = NULL,
  n_threads = Inf,
  verbose = FALSE,
  progress = TRUE,
  drop_geometry = FALSE,
  osm_link_ids = FALSE,
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
  Defaults to [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html). See
  details for how datetimes are parsed.

- time_window:

  An integer. The time window in minutes for which `r5r` will calculate
  multiple itineraries. Defaults to 10. Unlike other routing functions,
  results are not aggregated by percentile, so the output may contain
  trips departing after `departure_datetime` but within the window. With
  `shortest_path = TRUE` and no `fare_structure`, a trip is routed for
  each minute from `departure_datetime` until `time_window` minutes
  later, and the fastest one is returned (ties go to the earliest
  departure). Otherwise, departures are simulated at random seconds,
  about one per minute (30 to 90 seconds apart), with the same departure
  times in every call with the same origin, and each departure is routed
  separately: an itinerary may appear or disappear when
  `departure_datetime` changes by one minute, and when the same sequence
  of routes appears in several departures, only the fastest is kept. See
  [`vignette("time_window", package = "r5r")`](https://ipea.github.io/r5r/dev/articles/time_window.md).

- suboptimal_minutes:

  A number. How many minutes after the optimal arrival a non-optimal
  McRAPTOR branch may arrive and still be kept (e.g. with `10`, routes
  arriving up to 10 minutes after the fastest one are considered). It
  can only be used when `shortest_path = FALSE` and `fare_structure` is
  `NULL`. The comparison is made separately for each departure within
  `time_window` and uses arrival time only: a route beyond this margin
  is discarded even if it has fewer transfers. The default, `0`, keeps
  only routes arriving at the earliest time for each departure. Higher
  values return more itineraries, emulating people who take a slower
  route for practical reasons (e.g. mode preference, safety).

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

- shortest_path:

  A logical. Whether the function should only return the fastest
  itinerary between each origin and destination pair (the default) or
  multiple alternatives. The fastest itinerary is the one with the
  shortest travel time, measured from its own departure time, among all
  departures within `time_window`. With a large `time_window`, it may
  depart later and arrive later than other itineraries; use
  `time_window = 1` to get the itinerary with the earliest arrival for a
  given departure time. Without a `fare_structure`, public transport
  trips are then routed with R5's RAPTOR algorithm, which is much faster
  than the McRAPTOR algorithm used for alternative routes and fares (see
  the Fastest itinerary section).

- all_to_all:

  A logical. Whether to query routes between the 1st origin to the 1st
  destination, then the 2nd origin to the 2nd destination, and so on
  (`FALSE`, the default) or to query routes between all origins to all
  destinations (`TRUE`). With `shortest_path = TRUE` and no
  `fare_structure`, `all_to_all = TRUE` runs one public transport search
  per origin for all its destinations, which is much faster than listing
  the same pairs with `all_to_all = FALSE`.

- fare_structure:

  A fare structure object, following the convention set in
  [`setup_fare_structure()`](https://ipea.github.io/r5r/dev/reference/setup_fare_structure.md).
  This object describes how transit fares should be calculated. See
  [`vignette("fare_structure", package = "r5r")`](https://ipea.github.io/r5r/dev/articles/fare_structure.md)
  for its structure.

- max_fare:

  A number. The maximum value that trips can cost when calculating the
  fastest journey between each origin and destination pair. Defaults to
  `Inf` (no limit). A finite value requires a `fare_structure`; an error
  is raised otherwise.

- new_carspeeds:

  A `data.frame` specifying the new car speed for each OSM edge id. This
  table must contain columns `osm_id`, `max_speed` and `speed_type`. The
  `"speed_type"` column is of class character and it indicates whether
  the values in `"max_speed"` should be interpreted as percentages of
  original speeds (`"scale"`) or as absolute speeds (`"km/h"`).
  Alternatively, the `new_carspeeds` parameter can receive an
  `sf data.frame` with POLYGON geometry that indicates the new car speed
  for all the roads that fall within each polygon. In this case, the
  table must contain the columns `poly_id` with a unique id for each
  polygon, `scale` with the new speed scaling factors and `priority`,
  which is a number ranking which polygon should be considered in case
  of overlapping polygons. See more info in the scenarios vignette
  ([`vignette("scenarios", package = "r5r")`](https://ipea.github.io/r5r/dev/articles/scenarios.md)).

- carspeed_scale:

  Numeric. The scaling factor applied to the car speed of road segments
  not specified in `new_carspeeds`. Defaults to `1`, which keeps the
  speeds of the unlisted roads unchanged.

- new_lts:

  A `data.frame` specifying the new LTS levels for each OSM edge id. The
  table must contain columns `osm_id` and `lts`. Alternatively, the
  `new_lts` parameter can receive an `sf data.frame` with LINESTRING
  geometry. R5 will then find the nearest road for each LINESTRING and
  update its LTS value accordingly.

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

- drop_geometry:

  A logical. Whether to drop the geometry of each trip leg from the
  output. Defaults to `FALSE` (geometry kept).

- osm_link_ids:

  A logical. Whether the output should include additional columns:
  `osm_id_list` for the OSM ids of the road segments used along the trip
  geometry, `edge_id_list` for the ids of the internal street network
  edges used, and `board_stop_id` and `alight_stop_id` for the GTFS ids
  of transit boarding and alighting stops, prefixed by the feed name
  (e.g. `"poa_eptc:1649"`). `osm_id_list` and `edge_id_list` are
  character columns formatted as `"[id1, id2, ...]"`, and are `"[]"` for
  transit segments. Can only be `TRUE` when `drop_geometry` is `FALSE`.
  Defaults to `FALSE`.

  Keep in mind that `osm_id_list` will contain an id even if the route
  only uses a small stretch of the road (e.g. 5m of a 600m street
  segment). For more precision, use `edge_id_list`, which returns the
  exact internal edge segments used in the trip. You can inspect these
  edge ids and their associated properties, including OSM ids, with
  [`street_network_to_sf()`](https://ipea.github.io/r5r/dev/reference/street_network_to_sf.md).

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

When `drop_geometry` is `FALSE`, the function outputs a `LINESTRING sf`
with detailed information on the itineraries between the specified
origins and destinations. When `TRUE`, the output is a `data.table`. All
distances are in meters and travel times are in minutes. Each row is one
segment (trip leg) of one itinerary, with the columns:

- `from_id`, `from_lat`, `from_lon`, `to_id`, `to_lat`, `to_lon`: the
  origin and destination of the pair;

- `option`: the itinerary number within the pair. Options are ordered
  with direct (non-transit) trips first, then by number of segments,
  then by duration, so `option` 1 is not necessarily the fastest one.
  With `shortest_path = TRUE`, each pair has a single itinerary
  (`option` 1);

- `departure_time`: the departure time of the itinerary (`"HH:MM:SS"`);

- `total_duration`, `total_distance`: duration and distance of the whole
  itinerary;

- `segment`, `mode`, `segment_duration`, `wait`, `distance`, `route`:
  the segment number, its transport mode, its in-motion duration, the
  waiting time before it, its distance and the transit route used (empty
  for non-transit segments);

- `total_fare`, `cumulative_fare`: only when a `fare_structure` is used;

- `osm_id_list`, `edge_id_list`, `board_stop_id`, `alight_stop_id`: only
  when `osm_link_ids` is `TRUE`;

- `geometry`: only when `drop_geometry` is `FALSE`.

If `output_dir` is not `NULL`, the function returns the path specified
in that parameter, in which the `.csv` files containing the results are
saved. This function writes one file per origin-destination pair, named
`from_<origin id>_to_<destination id>.csv`, so pairs must be unique and
ids cannot contain characters that are not allowed in file names.

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

The
[`pareto_frontier()`](https://ipea.github.io/r5r/dev/reference/pareto_frontier.md)
function, and `detailed_itineraries()` with `shortest_path = FALSE` or a
`fare_structure`, use an `R5`-specific extension to the McRAPTOR routing
algorithm. The implementation used in `detailed_itineraries()` allows
the router to find paths that are optimal and less than optimal in terms
of travel time, with some heuristics around multiple access modes,
riding the same patterns, etc. The specific extension to McRAPTOR to do
suboptimal path routing is not documented yet, but a detailed
description of base McRAPTOR can be found in Delling et al (2015). The
implementation used in
[`pareto_frontier()`](https://ipea.github.io/r5r/dev/reference/pareto_frontier.md),
on the other hand, returns only the fastest trip within a given monetary
cutoff, ignoring slower trips that cost the same. A detailed discussion
on the algorithm can be found in Conway and Stewart (2019).

- Delling, D., Pajor, T., & Werneck, R. F. (2015). Round-based public
  transit routing. Transportation Science, 49(3), 591-604.
  [doi:10.1287/trsc.2014.0534](https://doi.org/10.1287/trsc.2014.0534)

- Conway, M. W., & Stewart, A. F. (2019). Getting Charlie off the MTA: a
  multiobjective optimization method to account for cost constraints in
  public transit accessibility metrics. International Journal of
  Geographical Information Science, 33(9), 1759-1787.
  [doi:10.1080/13658816.2019.1605075](https://doi.org/10.1080/13658816.2019.1605075)

## Fastest itinerary

When only the fastest itinerary is returned (`shortest_path = TRUE`) and
no `fare_structure` is used, public transport is routed with R5's RAPTOR
algorithm (Conway et al, 2017), the one used by
[`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md),
which is much faster than McRAPTOR. Compared with McRAPTOR, the results
can differ slightly: departures are routed every minute of `time_window`
instead of at random seconds, so the itinerary returned is never more
than about a minute slower and often faster; walking transfers between
stops are limited by `max_walk_time` (McRAPTOR only applies it to the
first and last legs); stops where the GTFS `pickup_type` or
`drop_off_type` does not allow boarding or alighting are respected; and
when two trips are equally fast, the route chosen may differ.

- Conway, M. W., Byrd, A., & van der Linden, M. (2017). Evidence-based
  transit and land use sketch planning using interactive accessibility
  methods on combined schedule and headway-based networks.
  Transportation Research Record, 2653(1), 45-53.
  [doi:10.3141/2653-06](https://doi.org/10.3141/2653-06)

## See also

Other routing:
[`arrival_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/arrival_travel_time_matrix.md),
[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md),
[`pareto_frontier()`](https://ipea.github.io/r5r/dev/reference/pareto_frontier.md),
[`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md)

## Examples

``` r
library(r5r)

# build transport network
data_path <- system.file("extdata/poa", package = "r5r")
r5r_network <- build_network(data_path)
#> ℹ Using cached network from
#>   /home/runner/work/_temp/Library/r5r/extdata/poa/network.dat.

# load origin/destination points
points <- read.csv(file.path(data_path, "poa_points_of_interest.csv"))

# inputs
departure_datetime <- as.POSIXct(
  "13-05-2019 14:00:00",
  format = "%d-%m-%Y %H:%M:%S"
)

det <- detailed_itineraries(
  r5r_network,
  origins = points[10,],
  destinations = points[12,],
  mode = c("WALK", "TRANSIT"),
  departure_datetime = departure_datetime,
  max_trip_duration = 60
)
head(det)
#> Simple feature collection with 5 features and 16 fields
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -51.24094 ymin: -30.05002 xmax: -51.19762 ymax: -29.99729
#> Geodetic CRS:  WGS 84
#>            from_id  from_lat  from_lon                          to_id    to_lat
#> 1 farrapos_station -29.99772 -51.19762 praia_de_belas_shopping_center -30.04995
#> 2 farrapos_station -29.99772 -51.19762 praia_de_belas_shopping_center -30.04995
#> 3 farrapos_station -29.99772 -51.19762 praia_de_belas_shopping_center -30.04995
#> 4 farrapos_station -29.99772 -51.19762 praia_de_belas_shopping_center -30.04995
#> 5 farrapos_station -29.99772 -51.19762 praia_de_belas_shopping_center -30.04995
#>      to_lon option departure_time total_duration total_distance segment mode
#> 1 -51.22875      1       14:08:00             37           9537       1 WALK
#> 2 -51.22875      1       14:08:00             37           9537       2 RAIL
#> 3 -51.22875      1       14:08:00             37           9537       3 WALK
#> 4 -51.22875      1       14:08:00             37           9537       4  BUS
#> 5 -51.22875      1       14:08:00             37           9537       5 WALK
#>   segment_duration wait distance  route                       geometry
#> 1              5.1  0.0      174        LINESTRING (-51.1981 -29.99...
#> 2              6.6  1.9     4796 LINHA1 LINESTRING (-51.19763 -29.9...
#> 3              4.0  0.0      256        LINESTRING (-51.22827 -30.0...
#> 4             10.4  4.4     4083    188 LINESTRING (-51.22926 -30.0...
#> 5              4.6  0.0      228        LINESTRING (-51.22949 -30.0...

stop_r5(r5r_network)
#> r5r_network has been successfully stopped.
```
