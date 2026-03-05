# ShinyApps.io deployment version
# Wrapper that handles relative paths correctly for ShinyApps.io

library(shiny)
library(tidyverse)
library(plotly)
library(lubridate)
library(DT)
library(shinyjs)
library(tidymodels)

# Get the directory where this app is running
app_dir <- getwd()

# Load model and data with correct paths
trained_model <- readRDS(file.path(app_dir, "model_training.rds"))
flights_data <- read_csv(file.path(app_dir, "data", "flights_with_weather.csv"), show_col_types = FALSE)

flights_data <- flights_data |>
  mutate(
    departure_estimated = as_datetime(departure_estimated),
    hour_of_day = hour(departure_estimated),
    day_of_week = wday(departure_estimated, label = TRUE),
    date = date(departure_estimated),
    departure_delay_capped = pmin(departure_delay, 300),
    departure_delay = as.numeric(departure_delay),
    departure_delay = case_when(
      departure_delay > 300 ~ NA_real_,
      TRUE ~ departure_delay
    )
  ) |>
  filter(!is.na(airline_name), !is.na(flight_number), flight_number != "")

airlines <- sort(unique(flights_data$airline_name))

# Include the rest of shiny_app.R (UI and Server)
source(file.path(app_dir, "shiny_app.R"), local = TRUE)
