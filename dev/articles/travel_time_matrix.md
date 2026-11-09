# Travel time matrices

Abstract

This vignette shows how to use the travel_time_matrix() and
expanded_travel_time_matrix() functions in r5r.

## 1. Introduction

Many transport planning and modeling tasks need travel time estimates
between origins and destinations. `R5` computes realistic door-to-door
travel times in multimodal networks very fast, and `r5r` offers three
functions for it:

- [`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md)
- [`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md)
- [`arrival_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/arrival_travel_time_matrix.md)

This vignette shows, with a reproducible example, how they work and how
they differ.

## 2. Build routable transport network with `build_network()`

We use the Porto Alegre (Brazil) sample data included in `r5r`.

``` r

# increase Java memory
old_options <- options(java.parameters = "-Xmx2G")

# load libraries
library(r5r)
library(data.table)
library(ggplot2)

# build a routable transport network with r5r
data_path <- system.file("extdata/poa", package = "r5r")
r5r_network <- build_network(data_path)

# routing inputs
mode <- c('walk', 'transit')
max_trip_duration <- 60 # minutes

# departure time
departure_datetime <- as.POSIXct("13-05-2019 14:00:00", 
                                 format = "%d-%m-%Y %H:%M:%S")

# load origin/destination points
points <- fread(file.path(data_path, "poa_points_of_interest.csv"))
```

## 3. The `travel_time_matrix()` function

[`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md)
quickly computes travel times between all origin/destination pairs for a
departure time and transport mode. Other parameters include:

- `max_trip_duration`: maximum trip duration
- `max_rides`: maximum number of public transport rides
- `max_walk_time` and `max_bike_time`: maximum walking or cycling time
  to and from public transport
- `walk_speed` and `bike_speed`: average walking or cycling speed (km/h)
- `max_fare`: maximum monetary cost in public transport. [See this
  vignette](https://ipea.github.io/r5r/articles/fare_structure.html).

``` r

# estimate travel time matrix
ttm <- travel_time_matrix(
  r5r_network,   
  origins = points,
  destinations = points,    
  mode = mode,
  max_trip_duration = max_trip_duration,
  departure_datetime = departure_datetime
  )

head(ttm, n = 10)
#>           from_id                     to_id travel_time_p50
#>            <char>                    <char>           <int>
#>  1: public_market             public_market               0
#>  2: public_market       bus_central_station              14
#>  3: public_market          gasometer_museum              12
#>  4: public_market       santa_casa_hospital              15
#>  5: public_market                  townhall               3
#>  6: public_market           piratini_palace              17
#>  7: public_market    metropolitan_cathedral              17
#>  8: public_market          farroupilha_park              18
#>  9: public_market moinhos_de_vento_hospital              20
#> 10: public_market          farrapos_station              21
```

Travel times can vary significantly across the day with public transport
service levels. The `time_window` and `percentiles` parameters handle
this efficiently: R⁵ computes travel times for departures every minute
within `time_window` and returns the selected percentiles ([time window
vignette](https://ipea.github.io/r5r/articles/time_window.html)).

## 4. The `expanded_travel_time_matrix()` function

[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md)
returns more than the total travel time: by default, it also lists the
public transport routes taken between each origin/destination pair. With
`breakdown = TRUE`, it adds each trip’s number of public transport rides
and its access, waiting, in-vehicle, transfer and egress times, which
can be slower for large data sets.

*A general call to expanded_travel_time_matrix()*

``` r

ettm <- expanded_travel_time_matrix(
  r5r_network,   
  origins = points,
  destinations = points,    
  mode = mode,
  max_trip_duration = max_trip_duration,
  departure_datetime = departure_datetime
  )

head(ettm, n = 10)
#>           from_id         to_id departure_time draw_number routes total_time
#>            <char>        <char>         <char>       <int> <char>      <num>
#>  1: public_market public_market       14:00:00           1 [WALK]          0
#>  2: public_market public_market       14:01:00           1 [WALK]          0
#>  3: public_market public_market       14:02:00           1 [WALK]          0
#>  4: public_market public_market       14:03:00           1 [WALK]          0
#>  5: public_market public_market       14:04:00           1 [WALK]          0
#>  6: public_market public_market       14:05:00           1 [WALK]          0
#>  7: public_market public_market       14:06:00           1 [WALK]          0
#>  8: public_market public_market       14:07:00           1 [WALK]          0
#>  9: public_market public_market       14:08:00           1 [WALK]          0
#> 10: public_market public_market       14:09:00           1 [WALK]          0
```

*Calling expanded_travel_time_matrix() with `breakdown = TRUE`*

``` r

ettm2 <- expanded_travel_time_matrix(
  r5r_network,   
  origins = points,
  destinations = points,    
  mode = mode,
  max_trip_duration = max_trip_duration,
  departure_datetime = departure_datetime,
  breakdown = TRUE
  )

head(ettm2, n = 10)
#>           from_id         to_id departure_time draw_number access_time
#>            <char>        <char>         <char>       <int>       <num>
#>  1: public_market public_market       14:00:00           1           0
#>  2: public_market public_market       14:01:00           1           0
#>  3: public_market public_market       14:02:00           1           0
#>  4: public_market public_market       14:03:00           1           0
#>  5: public_market public_market       14:04:00           1           0
#>  6: public_market public_market       14:05:00           1           0
#>  7: public_market public_market       14:06:00           1           0
#>  8: public_market public_market       14:07:00           1           0
#>  9: public_market public_market       14:08:00           1           0
#> 10: public_market public_market       14:09:00           1           0
#>     wait_time ride_time transfer_time egress_time routes n_rides total_time
#>         <num>     <num>         <num>       <num> <char>   <int>      <num>
#>  1:         0         0             0           0 [WALK]       0          0
#>  2:         0         0             0           0 [WALK]       0          0
#>  3:         0         0             0           0 [WALK]       0          0
#>  4:         0         0             0           0 [WALK]       0          0
#>  5:         0         0             0           0 [WALK]       0          0
#>  6:         0         0             0           0 [WALK]       0          0
#>  7:         0         0             0           0 [WALK]       0          0
#>  8:         0         0             0           0 [WALK]       0          0
#>  9:         0         0             0           0 [WALK]       0          0
#> 10:         0         0             0           0 [WALK]       0          0
```

Over its `time_window` (10 minutes by default),
[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md)
returns the fastest route departing at each minute. This can be very
memory intensive for large data sets and time windows.

``` r

ettm_window <- expanded_travel_time_matrix(
  r5r_network,   
  origins = points,
  destinations = points,    
  mode = mode,
  max_trip_duration = max_trip_duration,
  departure_datetime = departure_datetime,
  breakdown = TRUE,
  time_window = 10
  )

ettm_window[15:25,]
#>           from_id               to_id departure_time draw_number access_time
#>            <char>              <char>         <char>       <int>       <num>
#>  1: public_market bus_central_station       14:04:00           1         1.5
#>  2: public_market bus_central_station       14:05:00           1         4.8
#>  3: public_market bus_central_station       14:06:00           1         4.1
#>  4: public_market bus_central_station       14:07:00           1         4.4
#>  5: public_market bus_central_station       14:08:00           1         2.3
#>  6: public_market bus_central_station       14:09:00           1         2.3
#>  7: public_market    gasometer_museum       14:00:00           1         2.9
#>  8: public_market    gasometer_museum       14:01:00           1         6.0
#>  9: public_market    gasometer_museum       14:02:00           1         6.0
#> 10: public_market    gasometer_museum       14:03:00           1         3.5
#> 11: public_market    gasometer_museum       14:04:00           1         3.5
#>     wait_time ride_time transfer_time egress_time routes n_rides total_time
#>         <num>     <num>         <num>       <num> <char>   <int>      <num>
#>  1:       1.5       3.5             0         6.7    525       1       13.2
#>  2:       1.2       1.6             0         6.2 LINHA1       1       13.8
#>  3:       1.9       2.0             0         6.7    495       1       14.7
#>  4:       1.6       2.0             0         6.7    493       1       14.7
#>  5:       4.7       1.1             0         7.4    D72       1       15.5
#>  6:       3.7       1.1             0         7.4    D72       1       14.5
#>  7:       1.1       4.5             0         1.8   2821       1       10.3
#>  8:       3.0       4.3             0         1.8    346       1       15.1
#>  9:       2.0       4.3             0         1.8    346       1       14.1
#> 10:       3.5       4.9             0         1.8    244       1       13.7
#> 11:       2.5       4.9             0         1.8    244       1       12.7
```

## 5. The `arrival_travel_time_matrix()` function

[`travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/travel_time_matrix.md)
and
[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md)
take a **departure** time. To route by **arrival** time, use
[`arrival_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/arrival_travel_time_matrix.md):
given the latest acceptable arrival time and a maximum trip duration, it
returns the travel time of the trip with the latest departure that still
arrives in time.

This models trips where arriving by a set time matters, such as getting
to work or school by 9 a.m.: people usually take the latest departure
that gets them there on time, not the fastest trip that leaves them
waiting at the destination.

As in
[`expanded_travel_time_matrix()`](https://ipea.github.io/r5r/dev/reference/expanded_travel_time_matrix.md),
the output has additional columns (and `breakdown = TRUE` is available).

*A general call to arrival_travel_time_matrix()*

``` r


arrival_datetime <- as.POSIXct(
 "13-05-2019 14:00:00",
 format = "%d-%m-%Y %H:%M:%S"
)

arrival_ttm <- arrival_travel_time_matrix(
  r5r_network,
  origins = points,
  destinations = points,
  mode = c("WALK", "TRANSIT"),
  arrival_datetime = arrival_datetime,
  max_trip_duration = 60
)

head(arrival_ttm, n = 10)
#>           from_id                     to_id departure_time draw_number  routes
#>            <char>                    <char>         <char>       <int>  <char>
#>  1: public_market             public_market       13:59:00           1  [WALK]
#>  2: public_market       bus_central_station       13:45:00           1  LINHA1
#>  3: public_market          gasometer_museum       13:45:00           1    2441
#>  4: public_market       santa_casa_hospital       13:44:00           1  [WALK]
#>  5: public_market                  townhall       13:56:00           1  [WALK]
#>  6: public_market           piratini_palace       13:42:00           1  [WALK]
#>  7: public_market    metropolitan_cathedral       13:42:00           1  [WALK]
#>  8: public_market          farroupilha_park       13:40:00           1     R41
#>  9: public_market moinhos_de_vento_hospital       13:36:00           1 731|637
#> 10: public_market          farrapos_station       13:36:00           1     731
#>     total_time
#>          <num>
#>  1:        0.0
#>  2:       13.8
#>  3:       11.7
#>  4:       15.4
#>  5:        3.6
#>  6:       17.4
#>  7:       18.0
#>  8:       16.5
#>  9:       20.3
#> 10:       21.4
```

#### Cleaning up after usage

Stop the network and run Java’s garbage collector to free the memory it
used:

``` r

r5r::stop_r5(r5r_network)
rJava::.jgc(R.gc = TRUE)
options(old_options)
```

If you have any suggestions or want to report an error, please visit
[the package GitHub page](https://github.com/ipea/r5r).

### References
