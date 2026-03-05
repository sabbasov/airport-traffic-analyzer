# Airport Traffic Analyzer

A real-time flight delay monitoring and prediction system built with Python, R, and machine learning.

- Interactive Shiny dashboard deployed on [ShinyApps.io](https://sabbasov.shinyapps.io/airport-traffic-analyzer/)
- Random Forest ML model predicts departure delays with 8.4 min RMSE
- Data accumulation strategy: grows with each run, avoiding redundant API calls
- 50+ visualizations in analytics report (Quarto)

## Tech Stack
- **Backend:** Python (data pipeline, ML training)
- **Frontend:** R Shiny (interactive dashboard)
- **ML Framework:** tidymodels, scikit-learn
- **Data Processing:** tidyverse, pandas
- **Visualization:** Plotly, ggplot2
- **Data:** Aviation Stack API + Open-Meteo Weather API
- **Deployment:** ShinyApps.io (Shiny app), GitHub (code)

## Project Structure
- `/scripts`: Python data fetching and processing pipeline
- `/data/cleaned`: Processed flight and weather data (CSV format)
- `/shiny_app.R`: Interactive Shiny dashboard with 5 tabs
- `/model_training.R`: Random Forest model training
- `/analysis.qmd`: Analytics report with 50+ visualizations
- `/presentation.qmd`: Data analysis presentation (Reveal.js)
- `/setup.sh`: Automation script for setup and workflows

## Features
- **Airline Comparison:** Ranked by average delay performance
- **Wind Sensitivity Analysis:** Correlation between wind speed and delays
- **Temporal Risk Heatmap:** Hour × day-of-week delay patterns
- **Delay Patterns:** Distribution and hourly trends
- **Flight Details:** Real-time predictions with filters
- **Live Metrics:** Total flights, avg delay, wind speed, on-time percentage

## Data Accumulation Strategy

The system builds a growing database instead of replacing data:

- **First run:** Fetches 7 days of historical flights
- **Subsequent runs:** Only fetches 1 new day (~35 flights)
- **Benefits:** Growing training data, 99% fewer API calls after first run, automatic duplicate removal

## Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/sabbasov/airport-traffic-analyzer.git
   cd airport-traffic-analyzer
   ```

2. Set up environment (requires R and Python):
   ```bash
   cp .env.example .env
   # Add your Aviation Stack API key to .env
   chmod +x setup.sh
   ./setup.sh setup
   ```

3. Run the interactive dashboard:
   ```bash
   ./setup.sh dashboard
   ```

4. Generate reports:
   ```bash
   ./setup.sh report
   ```

## Current Data Status

- **Flights:** 897 records (historical + recent)
- **Features:** 59 engineered per flight
- **Date Range:** Last 7 days + today
- **Weather Match:** 97.9% success rate

## Model Performance

- **RMSE:** 8.4 minutes (test set)
- **MAE:** 6.2 minutes
- **R²:** 0.42 (explains 42% of variance)
- **Validation:** 5-fold cross-validation

## Live Dashboard

Visit the deployed app: [https://sabbasov.shinyapps.io/airport-traffic-analyzer/](https://sabbasov.shinyapps.io/airport-traffic-analyzer/)

The dashboard updates with saved data and doesn't require API credentials to view.

## License
MIT License - see the LICENSE file for details.
