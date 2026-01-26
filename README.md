# Airline Performance Dashboard & Delay Prediction System

Real-time flight delay monitoring and prediction using Python, R, and machine learning.

## Setup (Important: Add Your API Key First!)

**1. Copy the example environment file:**
```bash
cp .env.example .env
```

**2. Add your Aviation Stack API key to `.env`:**
```bash
# Edit .env and replace with your actual key
AVIATIONSTACK_API_KEY=your_api_key_here
```

Get a free API key at [aviationstack.com](https://aviationstack.com)

**3. Install and run:**
```bash
chmod +x setup.sh
./setup.sh full        # Complete setup (dependencies + data + model + report)
./setup.sh dashboard   # Launch dashboard
```

## Key Features

🔄 **Incremental Data Accumulation** - Data grows with each run, avoiding redundant API calls  
📊 **Interactive Dashboard** - Real-time filtering, predictions, and visualizations  
🤖 **ML Model** - Random Forest regressor predicts delays (RMSE: 8.4 min)  
📈 **Analytics Report** - 50+ visualizations of patterns and insights  
⚡ **Automated Pipeline** - One command sets up everything  
🔐 **Secure** - API key stored locally in .env (not in git)

## Usage

### Automated Setup
```bash
./setup.sh setup       # Install Python + R packages
./setup.sh data        # Fetch flights + weather data (accumulates)
./setup.sh model       # Train ML model on all data
./setup.sh dashboard   # Launch interactive dashboard
./setup.sh report      # Generate analytics report
./setup.sh full        # All of the above
```

### Manual Workflow
```bash
# Fetch and process data
python scripts/fetch_data.py

# Train the model
Rscript -e "source('model_training.R')"

# Launch dashboard (interactive)
Rscript -e "shiny::runApp('shiny_app.R')"

# Generate report
quarto render analysis.qmd --to html
```

## Data Accumulation Strategy

The system **builds a growing database** instead of replacing data each time:

- **First run**: Fetches 7 days of historical flights → 897 flights
- **Second run**: Only fetches 1 new day → 932 flights total
- **Subsequent runs**: Adds ~35 new flights daily with 1 API call

**Benefits**:
- ✅ Growing training data = Better ML models
- ✅ 99% fewer API calls after first run
- ✅ Duplicates automatically removed
- ✅ Dashboard shows increasingly rich insights

See [DATA_ACCUMULATION_GUIDE.md](DATA_ACCUMULATION_GUIDE.md) for details.

## Files

| File | Purpose |
|------|---------|
| `scripts/fetch_data.py` | Data pipeline (Aviation Stack + Open-Meteo APIs) |
| `shiny_app.R` | Interactive Shiny dashboard with 5 tabs |
| `model_training.R` | Random Forest model (RMSE: 8.4 min) |
| `analysis.qmd` | Analytics report (50+ visualizations) |
| `presentation.qmd` | Data analysis presentation (Reveal.js) |
| `setup.sh` | Automation script |
| `pyproject.toml` | Python package config |

## Current Data Status

- **Flights**: 897 records (100 live + 797 historical)
- **Features**: 59 per flight (time, weather, airline, airports)
- **Date range**: Last 7 days + today
- **Weather match**: 97.9% success rate

## Model Performance

- **RMSE**: 8.4 minutes (test set)
- **MAE**: 6.2 minutes
- **R²**: 0.42 (explains 42% of variance)
- **Features**: 20+ engineered variables
- **Validation**: 5-fold cross-validation
