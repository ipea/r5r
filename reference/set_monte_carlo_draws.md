# Set number of Monte Carlo draws

Sets the number of Monte Carlo draws to be used by R5.

## Usage

``` r
set_monte_carlo_draws(
  r5r_network,
  draws_per_minute,
  time_window,
  fare_structure = NULL,
  mcraptor = !is.null(fare_structure)
)
```

## Arguments

- r5r_network:

  A routable transport network created with
  [`build_network()`](https://ipea.github.io/r5r/reference/build_network.md).

- draws_per_minute:

  A number.

- time_window:

  A number.

- fare_structure:

  A fare structure or `NULL`. When set, R5 uses the McRaptor algorithm,
  and combinations of `draws_per_minute` and `time_window` that its
  departure-time sampler cannot handle are rejected.

- mcraptor:

  A logical. Whether the routing uses the McRaptor algorithm. Defaults
  to `TRUE` when a `fare_structure` is set.

## Value

Invisibly returns `TRUE`.

## See also

Other setting functions:
[`reverse_back_if_direct_mode()`](https://ipea.github.io/r5r/reference/reverse_back_if_direct_mode.md),
[`reverse_if_direct_mode()`](https://ipea.github.io/r5r/reference/reverse_if_direct_mode.md),
[`set_breakdown()`](https://ipea.github.io/r5r/reference/set_breakdown.md),
[`set_cutoffs()`](https://ipea.github.io/r5r/reference/set_cutoffs.md),
[`set_elevation()`](https://ipea.github.io/r5r/reference/set_elevation.md),
[`set_expanded_travel_times()`](https://ipea.github.io/r5r/reference/set_expanded_travel_times.md),
[`set_fare_cutoffs()`](https://ipea.github.io/r5r/reference/set_fare_cutoffs.md),
[`set_fare_structure()`](https://ipea.github.io/r5r/reference/set_fare_structure.md),
[`set_max_fare()`](https://ipea.github.io/r5r/reference/set_max_fare.md),
[`set_max_lts()`](https://ipea.github.io/r5r/reference/set_max_lts.md),
[`set_max_rides()`](https://ipea.github.io/r5r/reference/set_max_rides.md),
[`set_monte_carlo_seed()`](https://ipea.github.io/r5r/reference/set_monte_carlo_seed.md),
[`set_n_threads()`](https://ipea.github.io/r5r/reference/set_n_threads.md),
[`set_new_congestion()`](https://ipea.github.io/r5r/reference/set_new_congestion.md),
[`set_new_lts()`](https://ipea.github.io/r5r/reference/set_new_lts.md),
[`set_output_dir()`](https://ipea.github.io/r5r/reference/set_output_dir.md),
[`set_percentiles()`](https://ipea.github.io/r5r/reference/set_percentiles.md),
[`set_progress()`](https://ipea.github.io/r5r/reference/set_progress.md),
[`set_speed()`](https://ipea.github.io/r5r/reference/set_speed.md),
[`set_suboptimal_minutes()`](https://ipea.github.io/r5r/reference/set_suboptimal_minutes.md),
[`set_time_window()`](https://ipea.github.io/r5r/reference/set_time_window.md),
[`set_verbose()`](https://ipea.github.io/r5r/reference/set_verbose.md)
