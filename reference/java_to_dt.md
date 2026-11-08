# Java object to data.table

Converts a Java object returned by r5r_network to an R `data.table`

## Usage

``` r
java_to_dt(obj, ids = NULL)
```

## Arguments

- obj:

  A Java Object reference

- ids:

  An optional named list of character vectors, e.g.
  `list(from_id = origins$id, to_id = destinations$id)`, holding the ids
  sent to Java. String columns named here are transferred as integer
  positions in these vectors, which is much faster than transferring one
  Java string per row.

## Value

An R data.table

## See also

Other java support functions:
[`dt_to_lts_map()`](https://ipea.github.io/r5r/reference/dt_to_lts_map.md),
[`dt_to_speed_map()`](https://ipea.github.io/r5r/reference/dt_to_speed_map.md),
[`get_java_version()`](https://ipea.github.io/r5r/reference/get_java_version.md),
[`run_routing_job()`](https://ipea.github.io/r5r/reference/run_routing_job.md)
