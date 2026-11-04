# data.table to speedMap

Converts a `data.frame` with road OSM id's and respective speeds to a
Java Map\<Long, Float\> for use by r5r_network.

## Usage

``` r
dt_to_speed_map(dt)
```

## Arguments

- dt:

  data.frame/data.table. Table specifying the speed modifications. The
  table must contain columns `osm_id` and `max_speed`.

## Value

A speedMap (Java HashMap\<Long, Float\>)

## See also

Other java support functions:
[`dt_to_lts_map()`](https://ipea.github.io/r5r/dev/reference/dt_to_lts_map.md),
[`get_java_version()`](https://ipea.github.io/r5r/dev/reference/get_java_version.md),
[`java_to_dt()`](https://ipea.github.io/r5r/dev/reference/java_to_dt.md),
[`run_routing_job()`](https://ipea.github.io/r5r/dev/reference/run_routing_job.md)
