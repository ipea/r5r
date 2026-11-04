# Compute travel time surfaces.

A travel time surface is a raster grid (in the Web Mercator projection)
containing travel times from a specified point.

## Usage

``` r
travel_time_surface(
  r5r_network,
  origins,
  zoom = 10,
  mode = "WALK",
  mode_egress = "WALK",
  departure_datetime = NULL,
  time_window = 10L,
  percentiles = 50L,
  max_walk_time = Inf,
  max_bike_time = Inf,
  max_car_time = Inf,
  max_trip_duration = 120L,
  walk_speed = 3.6,
  bike_speed = 12,
  max_rides = 3,
  max_lts = 2,
  fare_structure = NULL,
  max_fare = Inf,
  new_carspeeds = NULL,
  carspeed_scale = 1,
  new_lts = NULL,
  draws_per_minute = 5L,
  seed = NULL,
  n_threads = Inf,
  verbose = FALSE,
  progress = TRUE
)
```

## Arguments

- r5r_network:

  A routable transport network created with
  [`build_network()`](https://ipea.github.io/r5r/dev/reference/build_network.md).

- origins:

  Either a `POINT sf` object with WGS84 CRS, or a `data.frame`
  containing the columns `id`, `lon` and `lat`.

- zoom:

  Resolution of the travel time surface used to create isochrones, can
  be between 9 and 12. More detailed isochrones will result from larger
  numbers, at the expense of compute time. Specifically, a raster grid
  of travel times in the Web Mercator projection at this zoom level is
  created, and the isochrones are interpolated from this grid. For more
  information on how the grid cells are defined, see [the R5
  documentation.](https://docs.conveyal.com/analysis/methodology#zoom-levels)

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
  always in
  [`pareto_frontier()`](https://ipea.github.io/r5r/dev/reference/pareto_frontier.md),
  departures are instead sampled at random within the window:
  `draws_per_minute` per minute on average (one in
  [`pareto_frontier()`](https://ipea.github.io/r5r/dev/reference/pareto_frontier.md)),
  different for each origin and the same in every call from the same
  origin with the same `seed`. Defaults to 10. See
  [`vignette("time_window", package = "r5r")`](https://ipea.github.io/r5r/dev/articles/time_window.md).

- percentiles:

  An integer vector (max length of 5). Specifies the percentile to use
  when returning travel time estimates within the given time window. For
  example, if the 25th travel time percentile between A and B is 15
  minutes, 25% of all trips taken between these points within the
  specified time window are shorter than 15 minutes. Defaults to 50,
  returning the median travel time. If a vector with length bigger than
  1 is passed, the output contains an additional column for each
  percentile specifying the percentile travel time estimate. Due to
  upstream restrictions, only 5 percentiles can be specified at a time.
  See the R5 documentation at
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

- draws_per_minute:

  An integer. The number of Monte Carlo draws to perform per minute of
  `time_window`. Defaults to 5. This would mean 300 draws in a 60-minute
  time window, for example. With the default routing algorithm, this
  parameter only affects the results when the GTFS feeds contain a
  `frequencies.txt` table; otherwise, r5r still routes a departure every
  minute of `time_window`, in a deterministic way. In functions that
  accept a `fare_structure`, passing one switches to the McRaptor
  algorithm, which instead routes `time_window * draws_per_minute`
  departure times sampled at random within the window (different for
  each origin, and the same in every call from the same origin with the
  same `seed`). This parameter then affects the results with or without
  frequencies. R5's McRaptor cannot sample many departure times per
  minute over long windows, so such combinations raise an error (e.g. 8
  draws per minute in a 10-minute window, or 5 in a window of 150
  minutes or more), as does a total of exactly 200 draws.

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
  table. In functions that accept a `fare_structure`, passing one
  switches to the McRaptor algorithm, and `seed` then affects the
  results with or without frequencies.

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

## Value

A `"sf" "data.frame"` for each isochrone of each origin.

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
[`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md),
[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md),
[`arrival_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/arrival_travel_time_matrix.md)
and
[`accessibility()`](https://ipea.github.io/r5r/dev/reference/accessibility.md)
functions use an `R5`-specific extension to the RAPTOR routing algorithm
(see Conway et al., 2017). This RAPTOR extension uses a systematic
sample of one departure per minute over the time window set by the user
in the 'time_window' parameter. A detailed description of base RAPTOR
can be found in Delling et al (2015). However, whenever the user
includes transit fares inputs to these functions, they automatically
switch to use an `R5`-specific extension to the McRAPTOR routing
algorithm.
[`detailed_itineraries()`](https://ipea.github.io/r5r/dev/reference/detailed_itineraries.md)
also uses RAPTOR when it only returns the fastest itinerary
(`shortest_path = TRUE`) and no fares are used.

- Conway, M. W., Byrd, A., & van der Linden, M. (2017). Evidence-based
  transit and land use sketch planning using interactive accessibility
  methods on combined schedule and headway-based networks.
  Transportation Research Record, 2653(1), 45-53.
  [doi:10.3141/2653-06](https://doi.org/10.3141/2653-06)

- Delling, D., Pajor, T., & Werneck, R. F. (2015). Round-based public
  transit routing. Transportation Science, 49(3), 591-604.
  [doi:10.1287/trsc.2014.0534](https://doi.org/10.1287/trsc.2014.0534)

## See also

Other support functions:
[`exists_tiff()`](https://ipea.github.io/r5r/dev/reference/exists_tiff.md),
[`fileurl_from_metadata()`](https://ipea.github.io/r5r/dev/reference/fileurl_from_metadata.md),
[`get_gtfs_errors()`](https://ipea.github.io/r5r/dev/reference/get_gtfs_errors.md),
[`start_r5r_java()`](https://ipea.github.io/r5r/dev/reference/start_r5r_java.md),
[`stop_r5()`](https://ipea.github.io/r5r/dev/reference/stop_r5.md),
[`tempdir_unique()`](https://ipea.github.io/r5r/dev/reference/tempdir_unique.md),
[`validate_bad_osm_ids()`](https://ipea.github.io/r5r/dev/reference/validate_bad_osm_ids.md)
