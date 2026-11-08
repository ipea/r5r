# Run a routing call on a Java background thread and print its progress

Makes `R5RCore` start the routing method in `call` on a background
thread, then polls it from R. This way the progress counter is printed
by R, and shown in any console (Java's own output only reaches
terminals), and the call can be interrupted. An interrupted job is
cancelled by `resetRoutingProperties()`, which every routing function
calls on exit. With `options(r5r.async = FALSE)` the call runs
synchronously.

## Usage

``` r
run_routing_job(r5r_network, call, progress)
```

## Arguments

- r5r_network:

  A Java reference to `org.ipea.r5r.R5RCore`.

- call:

  The call to the routing method, evaluated lazily.

- progress:

  A logical. Whether to print the progress counter.

## Value

The Java object returned by the routing method.

## See also

Other java support functions:
[`dt_to_lts_map()`](https://ipea.github.io/r5r/reference/dt_to_lts_map.md),
[`dt_to_speed_map()`](https://ipea.github.io/r5r/reference/dt_to_speed_map.md),
[`get_java_version()`](https://ipea.github.io/r5r/reference/get_java_version.md),
[`java_to_dt()`](https://ipea.github.io/r5r/reference/java_to_dt.md)
