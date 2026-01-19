# Airport Traffic and Weather Analysis
Sabuhi Abbasov

![](analysis_files/figure-commonmark/visualization-1.png)

    # A tibble: 6 × 3
      departure_iata avg_wind flight_count
      <chr>             <dbl>        <int>
    1 BPX               38.5             7
    2 TFU               13.2            15
    3 SIN               12.8            13
    4 CDG                8.85           11
    5 CKG                8.79           10
    6 MEL                8.54           12

## Python

``` python
import pandas as pd
from pathlib import Path

data_path = Path("data/cleaned/flights_with_weather.csv")

py_flights = pd.read_csv(data_path)

print(f"{len(py_flights)} rows loaded.")
```

    200 rows loaded.

## R

``` r
flights_from_python <- py$py_flights
```

``` r
library(lubridate)

flights_from_python <- flights_from_python |>
  mutate(
    dep_time_clean = as_datetime(departure_estimated),
    hour_of_day = hour(dep_time_clean),
    day_of_week = wday(dep_time_clean, label = TRUE)
  )

hourly_delay <- flights_from_python |>
  group_by(hour_of_day) |>
  summarise(
    avg_delay = mean(departure_delay, na.rm = TRUE),
    flight_count = n()
  ) |>
  arrange(hour_of_day)

na.omit(hourly_delay)
```

    # A tibble: 6 × 3
      hour_of_day avg_delay flight_count
            <int>     <dbl>        <int>
    1           8      15.7           12
    2           9      19.5           50
    3          10      14.5           27
    4          11       6              5
    5          12      12.8            8
    6          13       4.5           27
