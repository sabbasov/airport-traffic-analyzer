# Airline Performance Dashboard & Delay Prediction System

Real-time flight delay monitoring and prediction using Python, R, and machine learning.

## Setup

```bash
chmod +x setup.sh
./setup.sh setup       # Install dependencies
```

## Usage

### Fetch Data
```bash
python scripts/fetch_data.py
```

### Train Model
```r
source('model_training.R')
```

### Launch Dashboard
```r
shiny::runApp('shiny_app.R')
```

### Generate Report
```bash
quarto render analysis.qmd --to html
```

## Files

- `scripts/fetch_data.py` - Data pipeline (Aviation Stack + Open-Meteo APIs)
- `shiny_app.R` - Interactive dashboard with visualizations
- `model_training.R` - ML model training (Random Forest, RMSE: 18.3 min)
- `analysis.qmd` - Analytics report with insights
- `setup.sh` - Setup automation script
