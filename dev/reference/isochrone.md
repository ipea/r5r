# Estimate isochrones from a given location

Fast computation of isochrones from a given location. The function can
return either polygon-based or line-based isochrones. Polygon-based
isochrones are generated from a travel time surface: travel times from
each origin to the centres of a regular grid of Web Mercator pixels (see
`zoom`), from which the isochrone polygons are interpolated with the
marching squares algorithm. Line-based isochrones are based on travel
times from each origin to the centroids of all segments in the transport
network.

## Usage

``` r
isochrone(
  r5r_network,
  origins,
  mode = "transit",
  mode_egress = "walk",
  cutoffs = c(0, 15, 30),
  zoom = 10,
  departure_datetime = NULL,
  polygon_output = TRUE,
  time_window = 10L,
  max_walk_time = Inf,
  max_bike_time = Inf,
  max_car_time = Inf,
  max_trip_duration = 120L,
  walk_speed = 3.6,
  bike_speed = 12,
  max_rides = 3,
  max_lts = 2,
  draws_per_minute = 5L,
  seed = NULL,
  percentiles = NULL,
  n_threads = Inf,
  verbose = FALSE,
  progress = TRUE,
  sample_size = deprecated(),
  r5r_core = deprecated()
)
```

## Arguments

- r5r_network:

  A routable transport network created with
  [`build_network()`](https://ipea.github.io/r5r/dev/reference/build_network.md).

- origins:

  Either a `POINT sf` object with WGS84 CRS, or a `data.frame`
  containing the columns `id`, `lon` and `lat`.

- mode:

  A character vector. The transport modes allowed for access, transfer
  and vehicle legs of the trips. Defaults to `TRANSIT`. See details for
  other options.

- mode_egress:

  A character vector. The transport mode used after egress from the last
  public transport. It can be either `WALK`, `BICYCLE` or `CAR`.
  Defaults to `WALK`. Ignored when public transport is not used.

- cutoffs:

  A numeric vector. The travel times, in minutes, that delimit the
  isochrones. Defaults to `c(0, 15, 30)`. Values are sorted and
  duplicates are removed; at least one value must be greater than 0.

- zoom:

  A number between 9 and 12. The Web Mercator zoom level of the travel
  time grid from which polygon isochrones are interpolated (only used
  when `polygon_output = TRUE`). Higher values give more detailed
  isochrones but take longer to compute. Defaults to 10 (cells of about
  153 meters at the Equator). For how grid cells are defined, see [the
  R5
  documentation.](https://docs.conveyal.com/analysis/methodology#zoom-levels)

- departure_datetime:

  A POSIXct object. Only affects public transport legs; when routing
  with public transport, it must fall within the service period of the
  GTFS feeds (`calendar.txt`; see
  [`check_transit_availability()`](https://ipea.github.io/r5r/dev/reference/check_transit_availability.md)).
  Required for public transport; optional otherwise. See details for how
  datetimes are parsed.

- polygon_output:

  A Logical. If `TRUE`, the function outputs polygon-based isochrones
  (the default) based on travel times from each origin to a regular grid
  of points (see parameter `zoom`). If `FALSE`, the function outputs
  line-based isochrones based on travel times from each origin to the
  centroids of all segments in the transport network.

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

  Ignored. The maximum trip duration is set internally from
  `max(cutoffs)`.

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

- percentiles:

  An integer vector (max length of 5). The travel time percentiles
  within `time_window` used to build the isochrones, one set of polygons
  per percentile. Defaults to 50 (the median travel time). Only used
  when `polygon_output = TRUE`; must be `NULL` for line-based
  isochrones.

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

- sample_size:

  deprecated, no longer has any effect.

- r5r_core:

  The `r5r_core` argument is deprecated as of r5r v2.3.0. Use the
  `r5r_network` argument instead.

## Value

A `"sf" "data.frame"`. With `polygon_output = TRUE`, one `POLYGON` or
`MULTIPOLYGON` per origin, percentile and cutoff, with columns `id`
(origin id), `isochrone` (cutoff in minutes), `percentile` (a string
such as `"p50"`) and `polygons`. Each polygon covers the whole area
reached from 0 up to its cutoff, so polygons of larger cutoffs contain
those of smaller ones. With `polygon_output = FALSE`, one `LINESTRING`
per street segment reached, with columns `id` (origin id), `edge_index`,
`osm_id`, `isochrone` (the smallest cutoff at or above the segment's
travel time, i.e. bands are intervals), `travel_time_p50` and
`geometry`.

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

## Examples

``` r
options(java.parameters = "-Xmx2G")
library(r5r)
library(ggplot2)

# build transport network
data_path <- system.file("extdata/poa", package = "r5r")
r5r_network <- build_network(data_path = data_path)
#> ℹ Using cached network from
#>   /home/runner/work/_temp/Library/r5r/extdata/poa/network.dat.

# load origin/point of interest
points <- read.csv(file.path(data_path, "poa_points_of_interest.csv"))
origin <- points[2,]

departure_datetime <- as.POSIXct(
 "13-05-2019 14:00:00",
 format = "%d-%m-%Y %H:%M:%S"
)

# estimate polygon-based isochrone from origin
iso_poly <- isochrone(
  r5r_network,
  origins = origin,
  mode = "walk",
  polygon_output = TRUE,
  departure_datetime = departure_datetime,
  cutoffs = seq(0, 120, 30)
  )

head(iso_poly)
#> Simple feature collection with 4 features and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -51.25603 ymin: -30.0783 xmax: -51.16081 ymax: -29.99003
#> Geodetic CRS:  WGS 84
#>                    id isochrone percentile                       polygons
#> 1 bus_central_station       120        p50 POLYGON ((-51.21071 -30.076...
#> 2 bus_central_station        90        p50 POLYGON ((-51.2114 -30.0637...
#> 3 bus_central_station        60        p50 POLYGON ((-51.21071 -30.048...
#> 4 bus_central_station        30        p50 POLYGON ((-51.21346 -30.035...


# estimate line-based isochrone from origin
iso_lines <- isochrone(
  r5r_network,
  origins = origin,
  mode = "walk",
  polygon_output = FALSE,
  departure_datetime = departure_datetime,
  cutoffs = seq(0, 100, 25)
  )

head(iso_lines)
#> Simple feature collection with 6 features and 14 fields
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -51.18467 ymin: -30.05426 xmax: -51.17266 ymax: -30.02355
#> Geodetic CRS:  WGS 84
#>                    id edge_index   osm_id isochrone travel_time_p50 from_vertex
#> 1 bus_central_station        644 27238056       100             100         443
#> 2 bus_central_station        645 27238056       100             100         444
#> 3 bus_central_station       1048 27370379       100             100         717
#> 4 bus_central_station       1049 27370379       100             100         718
#> 5 bus_central_station       1058 27370382       100             100         722
#> 6 bus_central_station       1059 27370382       100             100         723
#>   to_vertex street_class  length walk   car car_speed bicycle bicycle_lts
#> 1       444     TERTIARY  78.580 TRUE  TRUE    39.996    TRUE           2
#> 2       443     TERTIARY  78.580 TRUE FALSE    39.996   FALSE           2
#> 3       718        OTHER 242.560 TRUE  TRUE    40.248    TRUE           4
#> 4       717        OTHER 242.560 TRUE  TRUE    40.248    TRUE           4
#> 5       723        OTHER  85.916 TRUE  TRUE    40.248    TRUE           2
#> 6       722        OTHER  85.916 TRUE  TRUE    40.248    TRUE           2
#>                         geometry
#> 1 LINESTRING (-51.17282 -30.0...
#> 2 LINESTRING (-51.17266 -30.0...
#> 3 LINESTRING (-51.18231 -30.0...
#> 4 LINESTRING (-51.18467 -30.0...
#> 5 LINESTRING (-51.18424 -30.0...
#> 6 LINESTRING (-51.1839 -30.05...


# plot colors
colors <- c('#ffe0a5','#ffcb69','#ffa600','#ff7c43','#f95d6a',
            '#d45087','#a05195','#665191','#2f4b7c','#003f5c')

# polygons
ggplot() +
  geom_sf(data=iso_poly, aes(fill=factor(isochrone))) +
  scale_fill_manual(values = colors) +
  theme_minimal()


# lines
ggplot() +
  geom_sf(data=iso_lines, aes(color=factor(isochrone))) +
  scale_color_manual(values = colors) +
  theme_minimal()


stop_r5(r5r_network)
#> r5r_network has been successfully stopped.
```
