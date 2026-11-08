# data.table to ltsMap

Converts a `data.frame` with road OSM id's and respective LTS levels a
Java Map\<Long, Integer\> for use by r5r_network.

## Usage

``` r
dt_to_lts_map(dt)
```

## Arguments

- dt:

  data.frame/data.table. Table specifying the LTS levels. The table must
  contain columns `osm_id` and `lts`.

## Value

A speedMap (Java HashMap\<Long, Integer\>)

## See also

Other java support functions:
[`dt_to_speed_map()`](https://ipea.github.io/r5r/reference/dt_to_speed_map.md),
[`get_java_version()`](https://ipea.github.io/r5r/reference/get_java_version.md),
[`java_to_dt()`](https://ipea.github.io/r5r/reference/java_to_dt.md),
[`run_routing_job()`](https://ipea.github.io/r5r/reference/run_routing_job.md)
