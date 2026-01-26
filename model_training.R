library(tidyverse)
library(tidymodels)
library(vip)

flights_data <- read_csv("data/cleaned/flights_with_weather.csv", show_col_types = FALSE)

flights_data <- flights_data |>
  mutate(
    departure_estimated = as_datetime(departure_estimated),
    hour_of_day = hour(departure_estimated),
    day_of_week = wday(departure_estimated),
    date = date(departure_estimated)
  ) |>
  filter(!is.na(airline_name), !is.na(departure_iata), !is.na(departure_delay)) |>
  filter(departure_delay > -100, departure_delay < 500) |>
  select(
    departure_delay,
    airline_name,
    departure_iata,
    arrival_iata,
    hour_of_day,
    day_of_week,
    wind_speed_10m
  )

set.seed(42)
data_split <- initial_split(flights_data, prop = 0.8)
train_data <- training(data_split)
test_data <- testing(data_split)
test_data_original <- test_data

recipe_spec <- recipe(departure_delay ~ ., data = train_data) |>
  step_dummy(all_nominal_predictors(), one_hot = TRUE) |>
  step_normalize(all_numeric_predictors()) |>
  step_impute_mean(wind_speed_10m)

model_spec_rf <- rand_forest(
  mtry = tune(),
  min_n = tune(),
  trees = 500
) |>
  set_engine("ranger", importance = "impurity") |>
  set_mode("regression")

model_spec_lm <- linear_reg() |>
  set_engine("lm")

workflow_rf <- workflow() |>
  add_recipe(recipe_spec) |>
  add_model(model_spec_rf)

workflow_lm <- workflow() |>
  add_recipe(recipe_spec) |>
  add_model(model_spec_lm)

set.seed(42)
folds <- vfold_cv(train_data, v = 5)

print("Training linear regression model...")
fit_lm <- fit(workflow_lm, data = train_data)
pred_lm <- predict(fit_lm, test_data) |>
  bind_cols(test_data |> select(departure_delay))

rmse_lm <- sqrt(mean((pred_lm$.pred - pred_lm$departure_delay)^2, na.rm = TRUE))
mae_lm <- mean(abs(pred_lm$.pred - pred_lm$departure_delay), na.rm = TRUE)
ss_res <- sum((pred_lm$.pred - pred_lm$departure_delay)^2, na.rm = TRUE)
ss_tot <- sum((pred_lm$departure_delay - mean(pred_lm$departure_delay, na.rm = TRUE))^2, na.rm = TRUE)
r2_lm <- if (ss_tot > 0) 1 - (ss_res / ss_tot) else NA

cat("Linear Regression Model Performance:\n")
cat("RMSE:", round(rmse_lm, 2), "minutes\n")
cat("MAE:", round(mae_lm, 2), "minutes\n")
cat("R² Score:", round(r2_lm, 4), "\n\n")

print("Training random forest model with hyperparameter tuning...")
tune_results <- tune_grid(
  workflow_rf,
  resamples = folds,
  grid = 10,
  metrics = metric_set(rmse, mae),
  control = control_grid(save_pred = TRUE, verbose = TRUE)
)

best_params <- select_best(tune_results, metric = "rmse")
workflow_rf_final <- finalize_workflow(workflow_rf, best_params)
fit_rf <- fit(workflow_rf_final, data = train_data)

pred_rf <- predict(fit_rf, test_data) |>
  bind_cols(test_data |> select(departure_delay))

rmse_rf <- sqrt(mean((pred_rf$.pred - pred_rf$departure_delay)^2, na.rm = TRUE))
mae_rf <- mean(abs(pred_rf$.pred - pred_rf$departure_delay), na.rm = TRUE)
ss_res_rf <- sum((pred_rf$.pred - pred_rf$departure_delay)^2, na.rm = TRUE)
ss_tot_rf <- sum((pred_rf$departure_delay - mean(pred_rf$departure_delay, na.rm = TRUE))^2, na.rm = TRUE)
r2_rf <- if (ss_tot_rf > 0) 1 - (ss_res_rf / ss_tot_rf) else NA

cat("\nRandom Forest Model Performance:\n")
cat("RMSE:", round(rmse_rf, 2), "minutes\n")
cat("MAE:", round(mae_rf, 2), "minutes\n")
cat("R² Score:", round(r2_rf, 4), "\n\n")

if (!is.na(rmse_rf) && !is.na(rmse_lm) && rmse_rf < rmse_lm) {
  final_model <- fit_rf
  final_rmse <- rmse_rf
  model_type <- "Random Forest"
} else {
  final_model <- fit_lm
  final_rmse <- rmse_lm
  model_type <- "Linear Regression"
}

cat("===== FINAL MODEL SELECTION =====\n")
cat("Best Model:", model_type, "\n")
cat("Final RMSE:", round(final_rmse, 2), "minutes\n")
cat("==================================\n\n")

feature_importance <- final_model |>
  extract_fit_parsnip() |>
  vip(num_features = 10)

print(feature_importance)

prediction_df <- bind_rows(
  pred_rf |> mutate(model = "Random Forest"),
  pred_lm |> mutate(model = "Linear Regression")
)

residuals_by_airline <- prediction_df |>
  filter(model == model_type) |>
  bind_cols(test_data_original |> select(airline_name)) |>
  mutate(residual = .pred - departure_delay) |>
  group_by(airline_name) |>
  summarise(
    mean_residual = mean(residual, na.rm = TRUE),
    std_residual = sd(residual, na.rm = TRUE),
    sample_size = n(),
    .groups = "drop"
  ) |>
  arrange(abs(mean_residual))

cat("\nPrediction Errors by Airline:\n")
print(residuals_by_airline |> slice_head(n = 10))

residuals_by_hour <- prediction_df |>
  filter(model == model_type) |>
  bind_cols(test_data_original |> select(hour_of_day)) |>
  mutate(residual = .pred - departure_delay) |>
  group_by(hour_of_day) |>
  summarise(
    mean_residual = mean(residual, na.rm = TRUE),
    rmse_hourly = sqrt(mean(residual^2, na.rm = TRUE)),
    sample_size = n(),
    .groups = "drop"
  ) |>
  arrange(hour_of_day)

cat("\nPrediction Errors by Hour of Day:\n")
print(residuals_by_hour)

summary_stats <- tibble(
  metric = c("Total Training Samples", "Total Test Samples", "Number of Airlines", "Average Delay (minutes)"),
  value = c(
    nrow(train_data),
    nrow(test_data),
    n_distinct(flights_data$airline_name),
    round(mean(flights_data$departure_delay, na.rm = TRUE), 2)
  )
)

cat("\n===== MODEL SUMMARY =====\n")
print(summary_stats)

saveRDS(final_model, "model_training.rds")
cat("\nModel saved to model_training.rds\n")
