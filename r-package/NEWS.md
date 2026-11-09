# r5r (development version)

# r5r 2.5.0

**Major changes**

- Faster routing 1. Compared with r5r 2.4.0 on the Porto Alegre and São Paulo sample data, car-only `travel_time_matrix()`, `arrival_travel_time_matrix()`, `accessibility()` and `pareto_frontier()` are 2 to 4 times faster, bicycle-only routing 1.3 to 2.8 times, and `expanded_travel_time_matrix()` 1.5 to 2.6 times. Public transport routing in these functions takes about as long as before.
- Faster routing 2. `detailed_itineraries()` with `shortest_path = TRUE` (the default) and no `fare_structure` now routes public transport with R5's RAPTOR algorithm, as `travel_time_matrix()` does, instead of McRAPTOR. It is 28 to 225 times faster on the Porto Alegre sample data, with the same output columns. See [#603](https://github.com/ipea/r5r/pull/603). Results can differ slightly:
  - departures are routed every minute of `time_window` instead of at random seconds;
  - transfer walks are limited by `max_walk_time`;
  - GTFS `pickup_type` / `drop_off_type` restrictions are respected;
  - ties between equally fast trips may resolve to a different route.
  - Alternative routes (`shortest_path = FALSE`) and fares still use McRAPTOR, and a pair that RAPTOR cannot route falls back to McRAPTOR. Closed [#464](https://github.com/ipea/r5r/issues/464).
- New `seed` argument in `travel_time_matrix()`, `expanded_travel_time_matrix()`, `arrival_travel_time_matrix()`, `accessibility()`, `isochrone()`, `travel_time_surface()` and `pareto_frontier()`. It makes the random departure offsets of frequency-based GTFS routes, and the departure times McRAPTOR samples within `time_window`, reproducible across runs and `n_threads`. The default `seed = NULL` keeps random draws. In `expanded_travel_time_matrix()` the trips of each minute are now numbered by total travel time, so `arrival_travel_time_matrix()` returns the fastest trip of the latest departure that arrives in time. Closes [#593](https://github.com/ipea/r5r/issues/593). See [#597](https://github.com/ipea/r5r/pull/597).
- Uses R5 v7.6. Less than 1% of origin-destination pairs change on the Porto Alegre sample data, mostly with shorter public transport times. See [#598](https://github.com/ipea/r5r/pull/598):
  - stops and points are linked to the nearest street even along long segments;
  - `transfer_time` (with `breakdown = TRUE`) is now R5's transfer walking time, and waiting at the transfer stop is counted in `wait_time`;
  - `get_gtfs_errors()` names some files without the `.txt` extension.
  - Networks built with earlier versions are rebuilt automatically.
- r5r requires R >= 4.1.0.

**Bug fixes**

- Java memory set with `options(java.parameters = "-Xmx...")` before `library(r5r)` was ignored since r5r 2.2.0. It takes effect again.
- With McRAPTOR (a `fare_structure`, `pareto_frontier()`, `detailed_itineraries()` with `shortest_path = FALSE`), almost every origin was routed at the same departure times within `time_window`. This was caused by an overflow in R5's random seed ([conveyal/r5#1026](https://github.com/conveyal/r5/issues/1026)). Each origin now gets its own reproducible sample, so results change slightly. Closes [#601](https://github.com/ipea/r5r/issues/601).
- `accessibility()` with the `logistic`, `exponential` and `linear` decay functions ignored trips longer than `max(cutoffs)`, which underestimated accessibility. Only the `step` function now caps `max_trip_duration` at `max(cutoffs)`.
- [#549](https://github.com/ipea/r5r/pull/549) Public transport routing now requires an explicit `departure_datetime`, since results depend on it. Without public transport, the current time is used. `arrival_travel_time_matrix()` requires `arrival_datetime` for all modes. Closed [#486](https://github.com/ipea/r5r/issues/486).
- `pareto_frontier()` now requires `fare_structure` and `fare_cutoffs`. Without `fare_cutoffs` it failed, and without `fare_structure` it ignored fares.
- Origins/destinations with duplicated `id`s raise an error in one-to-many functions. Repeated ids are still allowed in `detailed_itineraries()` with `all_to_all = FALSE`.
- A finite `max_fare` without a `fare_structure` raises an error instead of being ignored.
- `travel_time_matrix()`, `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` swapped `from_id` and `to_id` with walk-only routing and no elevation data, both in memory (fewer origins than destinations, a regression in 2.4.0, [#501](https://github.com/ipea/r5r/issues/501)) and in `output_dir` files (more origins than destinations).
- `arrival_travel_time_matrix()`:
  - for walk-, bike- or car-only trips with `max_walk_time`, `max_bike_time` or `max_car_time` below `max_trip_duration`, it searched the wrong departure window;
  - it stopped searching at the first minute without a trip, missing pairs that could still arrive in time ([#586](https://github.com/ipea/r5r/pull/586));
  - it compared arrivals using rounded durations ([#586](https://github.com/ipea/r5r/pull/586)).
- `expanded_travel_time_matrix()` and `arrival_travel_time_matrix()` mixed up transit trips departing at 00:00:00 with street-only trips, and failed with walk-only routing and more than 5000 origins ([#586](https://github.com/ipea/r5r/pull/586)).
- `detailed_itineraries()`:
  - transfer walks took a duration different from the one used for routing, giving impossible timelines on networks with elevation data; they now take distance / `walk_speed`;
  - transfer walks at the first stop had straight-line geometries;
  - leg geometries repeated vertices, so they were invalid under s2 ([#586](https://github.com/ipea/r5r/pull/586));
  - egress legs now keep the final partial street segment and the connection to the destination, with costs on the correct street endpoint ([#607](https://github.com/ipea/r5r/pull/607)). Results can change, mainly for destinations on long street segments;
  - zero-row `origins` or `destinations` return an empty result instead of crashing.
- `isochrone()`:
  - polygons were shifted half a grid cell to the north-west;
  - the polygon of the largest cutoff was cut short, so it depended on the other cutoffs; it is now complete and larger;
  - line-based output (`polygon_output = FALSE`) assigned segments to the wrong band with unsorted `cutoffs`;
  - line-based output now returns an `id` column, `id` is always character, and the `st_centroid` warning is gone.
- [#578](https://github.com/ipea/r5r/pull/578) A call that failed after applying a scenario (`new_carspeeds`, `carspeed_scale`, `new_lts`) left it active for the next call. Routing settings are now reset on exit, including on error.
- Output files (`output_dir`)
  - Text values containing commas are quoted (RFC 4180). This fixes every `detailed_itineraries()` file, whose `geometry`, `osm_id_list` and `edge_id_list` columns always contain commas.
  - Trips longer than `max_trip_duration` are empty fields, as `NA` in memory, instead of `2147483647` ([#586](https://github.com/ipea/r5r/pull/586)).
  - `detailed_itineraries()` raises an error for repeated origin-destination pairs, which overwrote each other, and for ids that are not valid file names.


**Minor changes**

- r5r is dual-licensed under `GPL (>= 3) | MIT + file LICENSE`.
- The repository moved to <https://github.com/ipea/r5r>. [#569](https://github.com/ipea/r5r/pull/569) fixes the source links on the website. Closed [#527](https://github.com/ipea/r5r/issues/527).
- `accessibility()` accepts fractional opportunities instead of truncating them to integers. Missing values count as 0 with a warning, and infinite values raise an error.
- Progress ([#596](https://github.com/ipea/r5r/pull/596)):
  - `progress` defaults to `TRUE` in all routing functions;
  - the counter is printed by R, so it shows in every console, and reports every 1% of origins;
  - `isochrone()` no longer ignores `progress`.
- [#596](https://github.com/ipea/r5r/pull/596) Routing can be interrupted with Esc / Ctrl+C. The "Using cached R5 version" message now shows only with `verbose = TRUE`.
- [#594](https://github.com/ipea/r5r/pull/594) `check_transit_availability()` finds the operating dates, including calendar exceptions, when no dates are given.
- Large matrices are passed from Java to R about 6 times faster.
- McRAPTOR itineraries in `detailed_itineraries()` are found faster and with less memory. With `suboptimal_minutes > 0`, the `option` numbers of two exactly tied itineraries can be swapped.
- Logging when building networks with several GTFS feeds ([#571](https://github.com/ipea/r5r/pull/571)) and in the direct trip router ([#568](https://github.com/ipea/r5r/pull/568), closed [#557](https://github.com/ipea/r5r/issues/557)).
- Integer arguments (`max_walk_time`, `max_bike_time`, `max_car_time`, `max_trip_duration`, `time_window`, `percentiles`, `n_threads`, `max_rides`, `max_lts`, `draws_per_minute`, `cutoffs`, `suboptimal_minutes`, and `zoom` in `isochrone()`) reject non-integer values instead of truncating them.
- `max_car_time` now caps car-only trips, not only the car legs of transit trips. Car-only trips can no longer end with a walk unbounded by `max_walk_time`, so 3% of car travel times on the Porto Alegre sample are 1 to 8 minutes longer, now consistent with `isochrone()`.
- Input combinations that R5's McRAPTOR cannot handle now raise informative errors instead of hanging, running out of memory or failing with a cryptic Java error ([#602](https://github.com/ipea/r5r/issues/602)):
  - too many departure draws for `time_window` with a `fare_structure` (e.g. 8 draws per minute in 10 minutes, or the default 5 in 150 minutes or more);
  - exactly 200 draws (e.g. `time_window = 200` in `pareto_frontier()`).
- `percentiles` and `cutoffs` are sorted, and `cutoffs` are validated (whole numbers from 1 to 120, no duplicates). They used to crash inside R5 or duplicate rows.
- The `linear` decay `decay_value` must be a whole number of minutes from 1 to 59.
- Missing `lon`/`lat` now trigger a warning listing the affected ids, instead of being dropped silently.
- Java errors reach R with their original message instead of an empty `RuntimeException` ([#586](https://github.com/ipea/r5r/pull/586)).
- [#572](https://github.com/ipea/r5r/pull/572) `build_network()` aborts with an informative message when a cached `network.dat` is rebuilt and fails on high-priority GTFS errors. Before, it returned an unusable network.
- `sf` origins/destinations that also had `lon`/`lat` (or `x`/`y`) columns were routed at those columns instead of the point geometry.



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
