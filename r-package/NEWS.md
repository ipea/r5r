# r5r (development version)

**Major changes**

- [#603](https://github.com/ipea/r5r/pull/603) `detailed_itineraries()` with `shortest_path = TRUE` (the default) and no `fare_structure` now routes public transport with R5's RAPTOR algorithm (the one used by `travel_time_matrix()`) instead of McRAPTOR. The output has the same columns, but the call is much faster: on the Porto Alegre sample data (50 × 50 origin-destination pairs, public transport), about 40 times faster than r5r 2.4.0 with `all_to_all = TRUE` and `max_trip_duration = 60` (28 times with the same 2,500 pairs given row by row, since with `all_to_all = TRUE` one search per origin serves all its destinations), and 150 to 225 times faster with `max_trip_duration = 120` or `time_window = 30`. Results can differ slightly: departures are routed every minute of `time_window` instead of at random seconds, so the itinerary returned is never more than about a minute slower and often faster; walking transfers between stops are limited by `max_walk_time`; stops where the GTFS `pickup_type` or `drop_off_type` does not allow boarding or alighting are respected; on networks with elevation data, the walk from the last stop is ranked by its time in the direction of travel, as it is reported; and ties between equally fast trips may resolve to a different route. Alternative routes (`shortest_path = FALSE`) and fares still use McRAPTOR. Closed [#464](https://github.com/ipea/r5r/issues/464).

**Bug fixes**

- [#607](https://github.com/ipea/r5r/pull/607) `detailed_itineraries()` now retains the final partial street segment and the connection to the destination in transit egress legs. Backward searches associate partial distances and directional costs with the correct street endpoint. Both RAPTOR and McRAPTOR use the complete egress cost for routing, duration limits and output, including RAPTOR searches shared across destinations. Results can change, particularly for destinations on long street segments.

# r5r 2.5.0

**Major changes**

- Faster routing. In end-to-end benchmarks against r5r 2.4.0 on the Porto Alegre and São Paulo sample data, car-only `travel_time_matrix()`, `arrival_travel_time_matrix()`, `accessibility()` and `pareto_frontier()` are 2 to 4 times faster (bicycle-only 1.3 to 2.8 times; `expanded_travel_time_matrix()` 1.5 to 2.6 times), public transport routing in these functions takes about as long as in r5r 2.4.0 (from 28% slower to 1.6 times faster), and `detailed_itineraries()` with public transport and no `fare_structure` is 2 to 4 times faster. Details in the minor changes below.
- [#597](https://github.com/ipea/r5r/pull/597) New `seed` argument in `travel_time_matrix()`, `expanded_travel_time_matrix()`, `arrival_travel_time_matrix()`, `accessibility()`, `isochrone()`, `travel_time_surface()` and `pareto_frontier()`. With GTFS feeds that contain a `frequencies.txt` table, R5 draws random departure offsets for frequency-based routes, so results could change slightly between runs, and `set.seed()` had no effect on them. Setting `seed` to an integer now gives identical results across runs and regardless of `n_threads`. The default `seed = NULL` keeps the random draws. `seed` comes right after `draws_per_minute` (after `time_window` in `pareto_frontier()`), so calls that passed later arguments by position must now name them. In `expanded_travel_time_matrix()`, the trips of each departure minute are now numbered in a fixed order (by total travel time) in `draw_number`; `arrival_travel_time_matrix()` uses the same order, so for the latest departure that arrives in time it now returns the fastest trip, where it used to return an arbitrary one. With a `fare_structure` (the McRaptor algorithm, which `pareto_frontier()` always uses), `seed` also sets the departure times sampled within `time_window`, with or without frequencies. Closes [#593](https://github.com/ipea/r5r/issues/593).

**Deprecations**

- Relying on the default `departure_datetime = Sys.time()` (`arrival_datetime` in `arrival_travel_time_matrix()`) when routing on public transport is deprecated and now raises a warning, because the results then depend on when the code is run. Please set the argument explicitly: the default will be removed in a future release. See [#549](https://github.com/ipea/r5r/pull/549).

**Bug fixes**

- With the McRaptor algorithm (used when a `fare_structure` is passed, and always in `pareto_frontier()` and `detailed_itineraries()`), almost every origin was routed at the same departure times within `time_window`, because R5 seeds their random sample from the origin latitude in a way that overflows beyond about 2.15 degrees ([conveyal/r5#1026](https://github.com/conveyal/r5/issues/1026)), and `seed` did not reach this sample. Each origin now gets its own sample, which is still the same in every call (with the same `seed`), so results of these functions change slightly. Closes [#601](https://github.com/ipea/r5r/issues/601).
- With a `fare_structure`, `accessibility()`, `travel_time_matrix()` and `isochrone()` could run indefinitely, run out of memory or fail with a Java error for some combinations of `draws_per_minute` and `time_window` (e.g. 8 draws per minute in a 10-minute window, or the default 5 in a window of 150 minutes or more), because R5's McRaptor algorithm cannot sample that many departure times. These combinations now raise an informative error. Closes [#602](https://github.com/ipea/r5r/issues/602).

- `travel_time_surface()` and `isochrone()` with `polygon_output = TRUE` now use the same travel time computer as `travel_time_matrix()`. Results without `fare_structure` are unchanged. With `fare_structure`, the walk to transit stops now respects `max_walk_time`, as it already did in `travel_time_matrix()`.

- Java memory set with `options(java.parameters = "-Xmx...")` before `library(r5r)` was ignored since r5r v2.2.0, so Java always ran with its default maximum heap (a quarter of the machine's RAM, capped at about 30 GB). The memory limit and any other Java options set by the user now take effect again.
- `travel_time_matrix()`, `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` returned `from_id` and `to_id` swapped with walk-only routing, no elevation data and fewer origins than destinations (introduced in r5r 2.4.0). Closes again [#501](https://github.com/ipea/r5r/issues/501).
- [#569](https://github.com/ipea/r5r/pull/569) Fix broken source links in documentation website. Closed [#527](https://github.com/ipea/r5r/issues/527)
- Origins/destinations passed as `sf` objects that also carried `lon`/`lat` (or `x`/`y`) attribute columns were routed using those attribute columns instead of the point geometry. The geometry is now always used.
- `travel_time_matrix()`, `arrival_travel_time_matrix()` and `expanded_travel_time_matrix()` wrote CSV files with `from_id` and `to_id` swapped (and named after the destinations) when `output_dir` was used with walk-only routing, no elevation data and more origins than destinations. This is fixed, but such runs with `output_dir` may now take longer.
- `percentiles` are now sorted in ascending order internally. Unsorted values (e.g. `c(75, 25)`) used to crash inside R5 with an uninformative Java error.
- Origins/destinations with missing `lon`/`lat` coordinates now trigger a warning listing the affected ids. They used to be dropped silently.
- Origins/destinations with duplicated `id` values now raise an error in all one-to-many functions, instead of returning ambiguous duplicated rows. `detailed_itineraries()` keeps accepting repeated ids in row-paired inputs (`all_to_all = FALSE`).
- [#596](https://github.com/ipea/r5r/pull/596) `isochrone()` ignored `progress` with `polygon_output = TRUE` (the default), so the progress counter was never shown. Since `progress` defaults to `TRUE` in `isochrone()`, the counter is now shown by default. The "Using cached R5 version" message is now shown only with `verbose = TRUE` (it was shown only with `verbose = FALSE`).
- `FERRY` was missing from the list of transit modes that trigger the check for transit services on the departure date.
- `max_car_time` now caps car-only trips, as `max_walk_time` and `max_bike_time` already did for walk-only and bike-only trips. It used to apply only to car access/egress legs of transit trips.
- `accessibility()` with the `logistic`, `exponential` and `linear` decay functions ignored every trip longer than `max(cutoffs)`, although these curves still give weight to such trips, so accessibility was underestimated. `max_trip_duration` is now capped by `max(cutoffs)` only for the `step` function (the cap was introduced in r5r 2.1.0, [#348](https://github.com/ipea/r5r/issues/348)). Results of the other decay functions change and are now larger.
- `accessibility()` now accepts fractional opportunity values (e.g. population interpolated onto a grid). They used to be truncated to integers, so any value below 1 counted as 0. Missing values are treated as 0, now with a warning, and infinite values raise an error.
- `cutoffs` in `accessibility()` are now validated (whole numbers between 1 and 120, no duplicates) and sorted in ascending order. Unsorted or out-of-range values used to crash inside R5 with an uninformative Java error, and duplicated values returned duplicated rows.
- In `accessibility()`, the `decay_value` of the `linear` decay function is now required to be a whole number of minutes between 1 and 59. Fractional values used to be silently truncated by R5, and values of 60 or more crashed inside R5.
- `detailed_itineraries()` reported transfer-walk durations that differed from those used to find and rank itineraries. On networks built with elevation data this could give impossible timelines (e.g. 40 minutes to walk 119 m followed by a normal wait), itineraries longer than `max_trip_duration` and, with `shortest_path = TRUE`, an option that was not the shortest. Transfer walks now take walking distance / `walk_speed`, consistent with `travel_time_matrix()` and `expanded_travel_time_matrix()`.
- In `detailed_itineraries()`, transfer walks from or to the first stop of the transit network had a straight-line geometry and distance and no OSM or edge ids. They are now routed on the street network like all other transfers.
- CSV files written with `output_dir` did not quote text values, so any value containing a comma broke the file. This made every file written by `detailed_itineraries()` unreadable (its WKT `geometry` and its `osm_id_list` / `edge_id_list` columns always contain commas), and broke the files of any routing function when an id or route name contained a comma. Such values are now quoted following the CSV standard (RFC 4180); files without such values are unchanged.
- `detailed_itineraries()` with `output_dir` silently overwrote the file of a repeated origin-destination pair (allowed since row-paired inputs may repeat ids), and crashed with a Java error on ids containing characters not allowed in file names (e.g. `/`). It now raises an informative error in both cases.
- `detailed_itineraries()` with zero-row `origins` or `destinations` crashed inside Java. It now returns an empty result.
- [#578](https://github.com/ipea/r5r/pull/578) A routing call that failed after a scenario (`new_carspeeds`, `carspeed_scale` or `new_lts`) had been applied left that scenario, and the other routing settings of the call, active in the routing engine, so the next call silently returned scenario results. All routing functions now reset the routing settings when they exit, including on error.
- A finite `max_fare` passed without a `fare_structure` now raises an error instead of being silently ignored.
- `pareto_frontier()` failed when called without `fare_cutoffs`, because its default (`-1`) was rejected by the function's own check that cutoffs are 0 or more. Without a `fare_structure` it ran but ignored fares, so its output was not a Pareto frontier. Both `fare_structure` and `fare_cutoffs` are now required arguments, with an informative error when either is missing. Code that passed `fare_structure = NULL` (or left it out) now raises an error.
- Integer arguments (`max_walk_time`, `max_bike_time`, `max_car_time`, `max_trip_duration`, `time_window`, `percentiles`, `n_threads`, `max_rides`, `max_lts`, `draws_per_minute`, `cutoffs`, `suboptimal_minutes`, and `zoom` in `isochrone()`) now reject non-integer values instead of silently truncating them.
- Polygon-based isochrones from `isochrone()` were shifted by half a grid cell to the north-west (about 94 m at the default `zoom = 10` in Porto Alegre), because R5's travel times, computed at the centre of each Web Mercator pixel, were placed at the pixel's corner. Polygons are now in the right place.
- In polygon-based `isochrone()`, the polygon of the largest cutoff was cut short, so its size depended on the other cutoffs requested (e.g. the 30-minute transit isochrone was up to 19% smaller with `cutoffs = 30` than with `cutoffs = c(30, 60)`). It is now complete, so the largest polygons get larger (routing now runs 10 minutes past the largest cutoff).
- Line-based `isochrone()` (`polygon_output = FALSE`) assigned segments to the wrong band when `cutoffs` were not in ascending order, and crashed with duplicated `cutoffs`. `cutoffs` are now sorted and deduplicated, and must be finite, non-missing and include a value greater than 0.
- Line-based `isochrone()` now returns an `id` column with the origin id, so results for several origins can be told apart. The `id` column is now always character in both outputs (it used to keep the input type in polygon output), and the `st_centroid` warning on every line-based call is gone.
- `arrival_travel_time_matrix()` searched departures in the wrong time window for walk-, bike- or car-only trips when `max_walk_time`, `max_bike_time` or `max_car_time` was lower than `max_trip_duration`. Trips arrived well before `arrival_datetime` (e.g. with `mode = "WALK"`, `max_trip_duration = 120` and `max_walk_time = 20`, departures between 12:00 and 12:19 for an arrival at 14:00, instead of between 13:40 and 13:59).
- [#572](https://github.com/ipea/r5r/pull/572) `build_network()` now detects and aborts with an informative message when a cached `network.dat` triggers a silent internal rebuild that fails on high priority GTFS errors, instead of silently returning an unusable `r5r_network` that only fails later with an opaque `NullPointerException` on the first routing call.
- [#586](https://github.com/ipea/r5r/pull/586) With `output_dir`, the CSV files written by `travel_time_matrix()`, `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` held `2147483647` and a `[WALK]` route for trips longer than `max_trip_duration`, where the in-memory result has `NA`. These cells are now empty fields, so the files match the in-memory result.
- [#586](https://github.com/ipea/r5r/pull/586) `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` failed with walk-only routing, no elevation data and more than 5000 origins, even with 5000 or fewer destinations (R5's limit for path details). This now works.
- [#586](https://github.com/ipea/r5r/pull/586) Java errors raised while routing now reach R with their original message (e.g. R5's 5000-destination limit for path details) instead of an empty `java.lang.RuntimeException`.
- [#586](https://github.com/ipea/r5r/pull/586) `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` mixed up public transport trips departing at exactly 00:00:00 with walk-, bike- or car-only trips: the first minute returned extra rows with an empty `departure_time`. Each departure minute now has one row per draw.
- [#586](https://github.com/ipea/r5r/pull/586) `arrival_travel_time_matrix()` stopped searching earlier departures at the first minute with no trip, so pairs that could still arrive in time by leaving earlier were missing (7 of 221 pairs among the Porto Alegre points of interest). It also compared arrivals using durations rounded to 0.1 minute, which accepted trips up to 3 seconds late and could reject trips arriving on time; it now uses the exact duration.
- [#586](https://github.com/ipea/r5r/pull/586) Leg geometries of `detailed_itineraries()` repeated a vertex at every intermediate public transport stop (and in some walk legs), so `sf::st_is_valid()` returned `FALSE` under s2. Repeated consecutive vertices are now removed; shapes and `distance` are unchanged.

**Minor changes**

- r5r is now dual-licensed under `GPL (>= 3) | MIT + file LICENSE` (it was `MIT + file LICENSE`).
- r5r now requires R >= 4.1.0 (it was 3.6).
- The package repository moved from `github.com/ipeaGIT/r5r` to <https://github.com/ipea/r5r>.
- [#598](https://github.com/ipea/r5r/pull/598) Using new version of R5 v7.6. Results change slightly. On the Porto Alegre sample data, less than 1% of origin-destination pairs change, mostly with shorter travel times by public transport:
  - R5 now links transit stops and origin/destination points to the nearest street even when it lies along a long street segment. Before, such stops could be linked to a farther street, which lengthened the walk to and from transit.
  - In `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` with `breakdown = TRUE`, `transfer_time` is now the transfer walking time recorded by R5. It used to be the time left over after subtracting the other components from the total, so time spent waiting for a vehicle at the transfer stop was counted as transfer time. This waiting time is now part of `wait_time`. When two itineraries arrive at the same time, the one reported may also differ. The components still add up to `total_time`.
  - In `get_gtfs_errors()`, the `file` column names some files without the `.txt` extension (e.g. `calendar` instead of `calendar.txt`).
  - Networks built with previous versions of r5r are rebuilt automatically by `build_network()`.
- [#594](https://github.com/ipea/r5r/pull/594) `check_transit_availability()` now discovers operating dates when no date arguments are supplied, including GTFS calendar exceptions. Street-only networks and empty explicit date vectors return a typed empty availability table. Date queries transfer availability counts in one Java batch, reducing transfer overhead.
- [#596](https://github.com/ipea/r5r/pull/596) `progress` now defaults to `TRUE` in all routing and accessibility functions (it was `FALSE` everywhere except `isochrone()`). Use `progress = FALSE` to hide the counter.
- [#596](https://github.com/ipea/r5r/pull/596) The progress counter is now printed by R, so it shows in every console (RStudio, Positron, RGui and terminals). It used to be printed by Java, which only reaches terminals; it is still written to `r5r-log.log`.
- [#596](https://github.com/ipea/r5r/pull/596) Routing functions can now be interrupted with Esc / Ctrl+C. The origins being routed at that moment finish first.
- [#596](https://github.com/ipea/r5r/pull/596) The progress counter now reports every 1% of origins, plus the first and the last one. It used to report only every 1,000 origins, so runs with up to 1,000 origins showed just the first and last origin.
- Car-only and bicycle-only routing in `travel_time_matrix()`, `expanded_travel_time_matrix()`, `arrival_travel_time_matrix()`, `accessibility()` and `pareto_frontier()` is 2.5 to 4 times faster in a benchmark of this change alone (part of the overall gain in Major changes), as r5r no longer runs an unneeded search on foot. Bicycle results are unchanged. Car-only trips can no longer end with a walk not limited by `max_walk_time` (e.g. against a one-way street), so some car travel times are now longer (3% of origin-destination pairs in the Porto Alegre sample data, by 1 to 8 minutes), now consistent with `isochrone()`.
- `travel_time_matrix()`, `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` return large results faster: passing an all-to-all matrix of the Porto Alegre sample grid (1.47 million rows) from Java to R went from 0.76 to 0.13 seconds. Results are unchanged.
- `detailed_itineraries()` with public transport and no `fare_structure` is about 1.5 times faster with `max_trip_duration = 60`, 2.4 times faster with `time_window = 30`, and about 4 times faster with the defaults (`max_trip_duration = 120`, `shortest_path = TRUE`), and uses less memory. The itineraries returned are unchanged, except that with `suboptimal_minutes > 0` the `option` numbers of two itineraries with exactly the same duration and number of segments can be swapped. Routing with a `fare_structure` is unchanged.
- The deprecated `r5r_core` argument is now the last argument of every function. It used to be the second one, so positional calls such as `travel_time_matrix(r5r_network, origins, destinations)` bound `origins` to `r5r_core` and failed with a misleading deprecation warning and error.
- Documentation fixes: `carspeed_scale` defaults to `1` (not `NULL`), and the unsupported modes `BICYCLE_RENT` and `CAR_PARK` were removed from the list of transport modes.
- The documentation of `detailed_itineraries()` now lists the output columns and how itinerary options are ordered, and describes the `osm_link_ids` columns correctly (`board_stop_id` and `alight_stop_id` are feed-prefixed GTFS stop ids, not OSM ids; `edge_id_list` is also added). It also explains that `shortest_path = TRUE` picks the itinerary with the shortest travel time among all departures within `time_window` (not the earliest arrival), and that `suboptimal_minutes` requires `shortest_path = FALSE` and no `fare_structure`.
- The documentation of `detailed_itineraries()` and the time window vignette now explain how `time_window` and `suboptimal_minutes` select itineraries. Departures are simulated at random seconds (about one per minute, the same in every call from the same origin) and routed separately, and for each departure only routes arriving within `suboptimal_minutes` of the earliest arrival are kept, even if a slower route has fewer transfers. As a result, an itinerary can appear or disappear when the departure time changes by one minute. Closed [#534](https://github.com/ipea/r5r/issues/534).
- The documentation of `draws_per_minute` and `time_window` and the time window vignette now explain that, with the McRaptor algorithm (used when a `fare_structure` is passed, and always in `pareto_frontier()` and `detailed_itineraries()`), departures are sampled at random within the window instead of every minute, so `draws_per_minute` affects results even when the GTFS feeds have no `frequencies.txt` table. Closed [#282](https://github.com/ipea/r5r/issues/282).
- The documentation of `arrival_travel_time_matrix()` now describes its output correctly (one row per pair reachable in time, with the latest departure; other pairs are absent), explains that `max_trip_duration` also sets the search window, and documents `"24:MM:SS"` departure times after midnight and the whole-minute precision of walk-, bike- or car-only trips.
- The documentation of `expanded_travel_time_matrix()` now lists the output columns, explains `routes`, that the `breakdown = TRUE` time components are `0` for trips without public transport, why a pair can be `NA` in every minute and why a few trips just over `max_trip_duration` are `NA` here although `travel_time_matrix()` reports them, and no longer claims that `time_window` results use median travel times or that `breakdown = TRUE` is significantly slower.
- The documentation of `isochrone()` now describes the Web Mercator grid method, the output columns (polygon bands are cumulative, line bands are intervals), the right defaults of `mode` and `progress`, and that `max_trip_duration` is ignored (set from `max(cutoffs)`); the isochrones vignette was corrected to match.
- The documentation of the `fixed_exponential` decay function in `accessibility()` now states that its decay constant is applied to travel times in seconds, so per-minute constants must be divided by 60.
- [#571](https://github.com/ipea/r5r/pull/571) Update logging when building GTFS network with multiple feeds.
- [#568](https://github.com/ipea/r5r/pull/568) Update logging for direct trip router. Closed [#557](https://github.com/ipea/r5r/issues/557)

# r5r 2.4.0

**Major changes**

- Using new version of R5 v7.5.1. Closed [#373](https://github.com/ipea/r5r/issues/373) 
and [#970](https://github.com/conveyal/r5/issues/970)
- The `isochrone()` function has gone through major changes which substantially
improved polygon-based isochrones. The function now builds on top of a travel 
time surface that uses a regular grid of points across the network (specifically 
a grid of Web Mercator pixels) and then uses the marching squares algorithm to 
generate the isochrone polygons. See detailed in the updated vignette. Closed 
[#455](https://github.com/ipea/r5r/issues/455) and Closed [#495](https://github.com/ipea/r5r/issues/495).
- New support function `get_gtfs_errors()` to help diagnose eventual errors in
the GTFS data that prevent building the network. Closed [#431](https://github.com/ipea/r5r/issues/431) and [#541](https://github.com/ipea/r5r/issues/541).

**Minor changes**

- New support function `check_transit_availability()` that checks the number and 
proportion of public transport services from the GTFS feeds that are active on 
specified dates.
- New support function `street_network_bbox()` that efficiently extracts the 
geographic bounding box of the transport network.
- More informative messages in case of Java error in R5. Closed [#515](https://github.com/ipea/r5r/issues/515).
- When direct routing fails the log now mentions the name of the origin and 
destination points to help the user debug. Closed [#519](https://github.com/ipea/r5r/issues/519).

**Bug fixes**

- Revert back the order of origins destinations for Direct Modes. Fix implemented 
`in travel_time_matrix()`, `arrival_travel_time_matrix()` and `expanded_travel_time_matrix()`. 
Closes [#501](https://github.com/ipea/r5r/issues/501).
- Reverse search optimization is now only applicable to walking. Closes [#517](https://github.com/ipea/r5r/issues/517).
- r5r now uses walking speed from request location to snapped point on the road 
network. This was a fix upstream in R5. Closed [#373](https://github.com/ipea/r5r/issues/373) 
- Elevation data does not affect carspeeds anymore. This was a fix upstream in 
R5. Closed [#970](https://github.com/conveyal/r5/issues/970)
- Fixed a bug that was introduced in r5r {2.3.0} and which led to ignore elevation 
when building the network. Closed [#555](https://github.com/conveyal/r5/issues/555).
Elevation data is still ignored when creating scenarios of LTS, but this is a know
bug that will throw warning messages while we work a way to fix it in a future 
update.



**New contributors to r5r**

- [Egor Kotov](https://github.com/e-kotov)


# r5r 2.3.0

**Major changes**

- New function `build_network()` to replace `setup_r5()`, which is being deprecated. Idiomatically `r5r_core` is now `r5r_network`.
- New function `arrival_travel_time_matrix()` to calculate travel time matrix between origin destination pairs considering the time of arrival, instead of a depature time. Closes [#291](https://github.com/ipea/r5r/issues/291)
- We have now implemented a reverse search optimization for direct transport modes (walking and cycling) in the functions `travel_time_matrix()`, `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()`. In practice, this means that these functions are now much faster when there are multiple origins to few destinations but only when there is no elevation `.tif` file in the data path. Closes [#450](https://github.com/ipea/r5r/issues/450)
- All routing and accessibility functions in `r5r` have new parameters `new_carspeeds`, `carspeed_scale` and `new_lts` which allow one to use custom car speeds and LTS levels for cycling. These parameters provide convient and efficient ways to build different scenarios of traffic congestion, road closure and interventions in cycling infrastructure. Closes [#289](https://github.com/ipea/r5r/issues/289)

**Minor changes**

- The routable transport network built with `build_network()` and `setup_r5()` now have their own class `"r5r_network"`, making the package more consistent and safer from errors [#472](https://github.com/ipea/r5r/pull/472).
- Routing properties within r5r jar (aka little jar) are reset to default after a routing execution [#453](https://github.com/ipea/r5r/pull/453)
- Less cluttering messages in r5r dialogue. Removed logback startup messages. `Verbose=F` now completly silences java output. `Verbose=T` only reports messages up to INFO level as opposed to up to DEBUG [#456](https://github.com/ipea/r5r/pull/456).
- Removed date from r5r-log. You no longer have to delete the previous day's log! [#456](https://github.com/ipea/r5r/pull/456)
- Improved warning and error messages.
- r5r developers can now set `options(r5r.r5jar=...)` to use a local JAR instead of the R5 jar downloaded by r5r.

**Bug fixes**

- Fixed a bug where `network_settings.json` wasn't showing the right version numbers [#459](https://github.com/ipea/r5r/pull/459). Version number now dynamically updated [#456](https://github.com/ipea/r5r/pull/456).

**New co-authors**

- Alex Magnus




# r5r 2.2.0

**Major changes**

- r5r now uses the latest version of R5 V7.4. Closed [#436](https://github.com/ipea/r5r/issues/436)
- The `detailed_itineraries()` now has a new parameter `osm_link_ids`. A logical. Whether the output should include the additional columns with the OSM ids of the road segments used along the trip geometry Defaults to `FALSE`. Closes issues [#298](https://github.com/ipea/r5r/issues/298)

**Minor changes**

- r5r now throws an informative error message when the geographic extent of input data exceeds limit of 975000 km2. Closes issues #389, #405, #406, #407, #412 and #421. Thanks to PR #426 by Alex Magnus.
- removed JRI dependency in r5r little jar. This helps debugging issues in Java without the need of using R. The side effect is that r5r now creates an `r5rlog` file in the data path.

**Bug fixes**

- Fixed a bug that prevented the package to check the availability of transit services in specific days when there is no service at all.
- Fixed a bug in the isochrone function that was throwing false error message regarding cutoff being too short. Closed [#434](https://github.com/ipea/r5r/issues/434) and [#433](https://github.com/ipea/r5r/issues/433)

**New contributors**

- Alex Magnus
- Luyu Liu
- Daniel Snow
- Funding from the Department of Geography & Planning, University of Toronto via the Bousfield Visitorship.

# r5r 2.1.0

**Minor changes**

- The `isochrone()` function has a new boolean parameter `polygon_output` that allows users to choose whether the output should be a polygon- or line-based isochrone. Closed [#382](https://github.com/ipea/r5r/issues/382)
- When using public transit modes, the package now automatically detects whether there are any transit services operation on the seleced departure date. If there are no services, the package will return an error message. Closed [#326](https://github.com/ipea/r5r/issues/326)


# r5r 2.0

**Breaking changes**

- r5r uses now JDK 21 or higher (Breaking changes). Closed [#350](https://github.com/ipea/r5r/issues/350).
- r5r now uses the latest version of R5 V7.1. Closed [#350](https://github.com/ipea/r5r/issues/350)

**Major changes**

- r5r now stores R5 Jar file at user dir using `tools::R_user_dir()`
- New function `r5r_cache()` to manage the cache of the R5 Jar file.
- By using the JDK 21, this version of r5r also fixed an incompatibility with MAC ARM processors. Closed [#315](https://github.com/ipea/r5r/issues/315)

**Minor changes**

- In the `accessibility()` function, the value of `max_trip_duration` is now capped by the max value passed to the `cutoffs` parameter. Closes [#348](https://github.com/ipea/r5r/issues/348).
- Updated documentation of parameter `max_walk_time` to make it clear that in walk-only trips, whenever `max_walk_time` differs from `max_trip_duration`, the lowest value is considered. Closes [#353](https://github.com/ipea/r5r/issues/353)
- Updated documentation of parameter `max_bike_time` to make it clear that in bicycle-only trips, whenever `max_bike_time` differs from `max_trip_duration`, the lowest value is considered. Closes [#353](https://github.com/ipea/r5r/issues/353)
- Improved documentation of parameter `suboptimal_minutes` in the `detailed_itineraries()` function.
- Updated the vignette on time window to explain how this parameter behaves when used in the `detailed_itineraries()` function.

**Bug Fixes**

- Fixed bug that prevented the use the `output_dir` parameter in the `detailed_itineraries(all_to_all = TRUE)` function. Closes [#327](https://github.com/ipea/r5r/issues/327) with a contribution ([PR #354](https://github.com/ipea/r5r/pull/354)) from Luyu Liu.
- Fixed bug that prevented  `detailed_itineraries` from working with frequency-based GTFS feeds. It should ONLY work with frequency-based GTFS feeds.

**New contributors to r5r**

- [Luyu Liu](https://github.com/luyuliu)


# r5r 1.1.0

**Major changes**

- New `isochrone()`function. Closes [#123](https://github.com/ipea/r5r/issues/123), and addresses requrests in issues [#164](https://github.com/ipea/r5r/issues/164) and [#328](https://github.com/ipea/r5r/issues/328).
- New vignette about calculating / visualizing isochrones with `r5r`.
- New vignette with responses to frequently asked questions (FAQ) from `r5r` users.

**Minor changes**

- The default value of `time_window` is not set to `10` minutes in all functions to avoid weird results reported upstream in R5. Closes [#342](https://github.com/ipea/r5r/issues/342).
- Removed any mention to `percentiles` parameter in the `expanded_travel_time_matrix()` because this function does not expose this parameter to users. Closes [#343](https://github.com/ipea/r5r/issues/343).
- Updated vignette on calculating / visualizing accessibility with `r5r`.


# r5r 1.0.1

**Bug fixes**

* Updated to R5 version 6.9. This fixed a few bugs upstream, one of which often prevented users to build a network using cropped OSM data. Closes [#325](https://github.com/ipea/r5r/issues/325).



# r5r 1.0.0

**Breaking changes**

- Replaced `max_walk_dist` and `max_bike_dist` parameters with `max_walk_time` and `max_bike_time` to better align with R5 inputs. Closes [#273](https://github.com/ipea/r5r/issues/273).
- `r5r` now uses `R5`'s native elevation weighting for walking and cycling impedance functions. As a result `r5r` does not have raster or rgdal package dependencies anymore. Closes [#243](https://github.com/ipea/r5r/issues/243) and [#233](https://github.com/ipea/r5r/issues/233).
- Parameters `breakdown` and `breakdown_stat` in `travel_time_matrix()` were removed. New function `expanded_travel_time_matrix()` should be used to retrieve detailed information of travel time matrices.
- `r5r`now throws an error if users simultaneously pass more than one of the following modes `c('WALK','CAR','BICYCLE')` to the `transport_mode` parameter. This is because these modes are understood as mutually exclusive.
- Function `setup_r5()` no longer has a `version` parameter.

**New functions**

- New function `expanded_travel_time_matrix()` to calculate minute-by-minute travel times between origin destination pairs and get additional information on public transport routes, number of transfers, and total access, waiting, in-vehicle and transfer times.
- New function `pareto_frontier()` to compute of travel time and monetary cost Pareto frontier.
- New function `r5r_sitrep()` to generate an `r5r` situation report to help debug code errors
- New functions to account for monetary costs:
  - `setup_fare_structure()` to setup a fare structure to calculate the monetary costs of trips
  - `read_fare_structure()` to read a fare structure object from a file
  - `write_fare_structure()` to write a fare structure object to disk

**Major changes**

- Now using R5 latest version `6.8`.
- The `detailed_itineraries()` has been substantially improved. The new vesion is faster than  previous ones. It also includes new parameters listed below. Closes [#265](https://github.com/ipea/r5r/issues/265).
  - New `time_window` parameter
  - New `suboptimal_minutes` parameter, which extends the search space and returns a larger number of trips beyond the fastest ones;
  - Support for fare calculator and new `max_fare` parameter;
  - Routing in frequencies GFTS, including support for Monte Carlo draws
- New parameter `draws_per_minute` to `travel_time_matrix()`, `accessibility()` and `pareto_frontier()` functions. Closes [#230](https://github.com/ipea/r5r/issues/230).
- New parameter `output_dir` to all routing functions, which can be used to specify a directory in which the results should be saved as `.csv` files (one file for each origin). This parameter is particularly useful when running estimates on memory-constrained settings, because writing the results to disk prevents `R5` from storing them in memory.
- The accessibility estimates from `accessibility()` are now of returned as doubles / class `numeric`, except when using a `step` decay function. Closes [#235](https://github.com/ipea/r5r/issues/235).
- The `detailed_itineraries()` function has a new parameter `all_to_all`, which allows users to set whether they want to query routes between all origins to all destinations (`all_to_all = TRUE`) or to query routes between the 1st origin to the 1st destination, then the 2nd origin to the 2nd destination, and so on (`all_to_all = FALSE`, the default). Closes [#224](https://github.com/ipea/r5r/issues/224).



**Minor changes**

- Package documentation has been extensively updated and expanded.
- Improved documentation of the `cutoffs` parameter in `accessibility()`, clarifying the function only accepts up to 12 cutoff values. Closes [#216](https://github.com/ipea/r5r/issues/216).
- Improved documentation of the `percentiles` parameter in `accessibility()` and `travel_time_matrix()`, clarifying these function only accepts up to 5 values. Closes [#246](https://github.com/ipea/r5r/issues/246).
- r5r now downloads R5 Jar directly from Conveyal's github, making the package more stable. Closes [#226](https://github.com/ipea/r5r/issues/226).
- All functions now use `verbose = FALSE` and `progress = FALSE` by default.
- Routing functions now require users to be non-ambiguous when specifying the modes, raising errors when it cannot disambiguate them. This new behaviour replaces the old one, in which the functions could end up trying to "guess" which mode was to be used in some edge cases.
- Information on bicycle 'level of traffic stress' is now added to the output of `street_network_to_sf()`. Closes [#251](https://github.com/ipea/r5r/issues/251).
- New columns with info on population, schools and jobs in the example data sets for Sao Paulo and Porto Alegre

**Bug fixes**

- Fixed bug that `transit_network_to_sf()` generated some routes with invalid geometries. Closes [#256](https://github.com/ipea/r5r/issues/256).
- Fixed bug that prevented `setup_r5(path, overwrite = TRUE)` to work.



# r5r 0.7.1

**Minor change**

* Replaced the akima package with interp package in r5r Suggests, as requested by CRAN.

# r5r 0.7.0

**Major changes**

* From this version onwards, r5r downloads R5 JAR from github, which provides more stable connection than Ipea server. 
* The number of Monte Carlo draws to perform per time window minute when calculating travel time matrices and when estimating accessibility is now set via the `r5r.montecarlo_draws` option. Defaults to 5. This would mean 300 draws in a 60 minutes time window, for example. The user may also set a custom value using `options(r5r.montecarlo_draws = 10L)` (in which you substitute 10L by the value you want to set).

**Minor changes**

* Changed `total_time` column name to `combined_time` in `travel_time_matrix()` 
output, to avoid confusion with `travel_time` column.

# r5r 0.6.0 

**Major changes**

* Updated R5 to version 6.4. Closes [#182](https://github.com/ipea/r5r/issues/182).

* Significant performance improvements in all functions, due to a faster method
for consolidating outputs. Closes [#180](https://github.com/ipea/r5r/issues/180)

* New function `transit_network_to_sf()`, to extract the public transport network 
from R5 as simple features. Closes [#179](https://github.com/ipea/r5r/issues/179)

* New `progress` parameter in the `accessibility()`, `travel_time_matrix`, and
`detailed_itineraries()` functions, to show or hide the progress counter 
indicator. Closes [#186](https://github.com/ipea/r5r/issues/186)

* Created new support function `java_to_dt()` and removed dependency on the `jdx` package. Closes [#206](https://github.com/ipea/r5r/issues/206)

* Reduced r5r's internet dependency quite considerably. Internet is now only required to download the latest R5 jar if it hasn't been downloaded before. Closes [#197](https://github.com/ipea/r5r/issues/197).

* Added two new parameters `breakdown` and `breakdown_stat` to the `travel_time_matrix()`. This allows users to breakdown the travel time information by trip subcomponents (access time, waiting time, traveling time etc). It allows one to extract more information but it makes computation time slower. Closes [#194](https://github.com/ipea/r5r/issues/194)

**Minor changes**

* New `setup_r5()` parameter, `overwrite`, that forces the building of a new `network.dat`, even if one already exists.
* Improved documentation of parameter `departure_datetime` to clarify the parameter must be set to local time. Closes [#188](https://github.com/ipea/r5r/issues/188)
* Improved documentation regarding personalized LTS values. [Closes #190](https://github.com/ipea/r5r/issues/190).
* Improved documentation of `transit_network_to_sf()` regarding stops that are not snapped to road network. [Closes #192](https://github.com/ipea/r5r/issues/192).
* Improved documentation of `max_walking_dist` and `max_cycling_dist` parameters. [Closes #193]( https://github.com/ipea/r5r/issues/193).
* Started raising an error if the CRS of origins/destinations is not WGS 84. Closes [#201](https://github.com/ipea/r5r/issues/201).

# r5r 0.5.0

**Major changes**

* New function `accessibility()` to calculate access to opportunities. Closes [#169](https://github.com/ipea/r5r/issues/169)

* New function `find_snap()` to help users identify where in the street network the input of origin and destination points are snapped to. Closes [168](https://github.com/ipea/r5r/issues/168).

* New parameter `max_bike_dist` added to routing and accessibility functions. Closes [#174](https://github.com/ipea/r5r/issues/174)

* Implemented temporary solution for elevation. Closes [#171](https://github.com/ipea/r5r/issues/171). Now r5r can read Digital Elevation Model (DEM) data from raster files in `.tif` format to weight the
street network for walking and cycling according to the terrain's slopes. Ideally, we would like to see a solution that accounts for elevation implemented upstream in R5. For now, this is a temporary solution implemented within r5r.

**Minor changes**

* The `street_network_to_sf()` now has a more clean output when the provided GTFS covers a larger area than the street network pbf. Closes [#173](https://github.com/ipea/r5r/issues/173)

* The size of poa.zip sample GTFS data has been reduced due to CRAN policies. Closes [#172](https://github.com/ipea/r5r/issues/172).

* Progress counter Implemented. Closes [150](https://github.com/ipea/r5r/issues/150). When the `verbose` parameter is set to `FALSE`, r5r prints a progress counter and eventual `ERROR` messages. This comes with a minor penalty for computation performance. Hence we have kept `verbose` defautls to `TRUE`.

**Bug fixes**

* Fixed bug that prevented r5r from running without internet connection. Closes [#163](https://github.com/ipea/r5r/issues/163).

# r5r 0.4-0

**Major changes** 

* Updated R5 to version 6.2. Closes [#158](https://github.com/ipea/r5r/issues/158).
* Added `max_lts` parameter to `detailed_itineraries()` and `travel_time_matrix()` functions. LTS stands for Level of Traffic Stress, and allows modeling of bicycle comfort in routing analysis. Additional information can be found in [Conveyal's documentation](https://docs.conveyal.com/learn-more/traffic-stress).

**Minor changes**

* New support function `check_connection()` to check internect connection before
download files from Ipea server.

# r5r 0.3-3

**Major changes**

* New vignette to [calculate and visualize isochrones](https://ipea.github.io/r5r/articles/isochrones.html).
* New vignette to [calculate and visualize accessibility](https://ipea.github.io/r5r/articles/accessibility.html).
* Significant performance increase in `detailed_itineraries()` when 
`shortest_path = TRUE`. Closes [#153](https://github.com/ipea/r5r/issues/153).
* [Paper on the r5r package published on **Findings**](https://doi.org/10.32866/001c.21262). Closes [#108](https://github.com/ipea/r5r/issues/108).

**Minor changes**

* `travel_time_matrix()` and `detailed_itineraries()` now output more detailed
messages in the console, when `verbose = TRUE`. This shall make debugging the
package much easier.
* Improved documentation of `travel_time_matrix()`. Closes [#149](https://github.com/ipea/r5r/issues/149).
* Checks origins/destinations inputs to make sure they have and `id` column. Closes [#154](https://github.com/ipea/r5r/issues/154).

**Bug fixes**

- Fixed [introductory vignette](https://ipea.github.io/r5r/articles/r5r.html) to list only files that are included in the package installation. Closes [#111](https://github.com/ipea/r5r/issues/111).
* Fixed conflict with `{geobr}` package when downloading metadata. Closed [#137](https://github.com/ipea/r5r/issues/137).
* Fixed a bug when when parsing date and time from `departure_datetime` in `detailed_itineraries()` and `travel_time_matrix()`. Closes [#147](https://github.com/ipea/r5r/issues/147).
* Fixed a bug in `detailed_itineraries()` that caused a crash when the shape of a route in the input GTFS is broken. Closes [#145](https://github.com/ipea/r5r/issues/145)

# r5r 0.3-2

**Minor changes**

* r5r does not save the medatada file in the package directory anymore, following CRAN's policies. Closed #136.

# r5r 0.3-1

**Minor changes** 

* Allow for combination of bicycle and public transport. Closed #135.
* Added new parameter `mode_egress` to routing functions, so that users can 
explicitly set the transport mode used after egress from public transport (walk,
car or bicycle). Closed #63.
* Allow for using the r5r package off-line, provided the user has successfully ran
`setup_r5()` before.

# r5r 0.3-0

**Major changes**

* Added Conveyal's R5 repo as a git submodule. This will help improve the long term integration between r5r and R5. Closed #105.
* Internal changes to make r5r compatible with R5 latest version 6.0.1.

**Minor changes**

* Added columns with population and number of schools in sample data set of Porto Alegre to allow for accessibility examples. Closed #128.
* The `percentiles` parameter in the `travel_time_matrix` function now only accepts up to 5 cut points due to changes in R5.

# r5r 0.2-1

**Minor changes** 

* Expanded number of routes in the sample GTFS for Porto Alegre, allowing for more
complex/realistic examples.
* Fixes format of columns of the output of `travel_matrix_function` when the user 
sets `time_window` parameter. Closes #127.
* Remove repeated bus route alternatives from the output from `detailed_itineraries`
* Explicitly link destination points to street network before starting. Closes #121

# r5r 0.2-0

**Major changes** 

* Function `travel_time_matrix` now has new parameters `time_window` and
`percentiles` it now calculates travel times for multiple departure times each 
minute within a given time window. For now, the function automatically set the
number of Monte Carlo Draws to 5 times the size of `time_window`. Closes #104 
and #118

**Minor changes**

* Added a sample of frequency-based GTFS for Sao Paulo. Closed #116
* Improved documentation of routing functions adding more info on the routing 
algorithms used in R5. Closes #114

# r5r v0.1-1

**Minor changes**

* Fixed issues with time zone when setting departure times
* Fixed issues to address CRAN checks
  * Now r5r can be installed on R (>= 3.6)
  * Appropriate hyperlinks indocumentation
  * Metadata is now downloaded from https:// server

# r5r 0.1-0

* Launch of **r5r** v0.1.0 on [CRAN](https://CRAN.R-project.org/package=r5r).
* Package website https://ipea.github.io/r5r/
