#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PYTHON_ENV=".venv"
PYTHON_VERSION="3.12"

echo "========================================"
echo "Airline Performance Dashboard Setup"
echo "========================================"
echo ""

create_python_env() {
  if [ ! -d "$PYTHON_ENV" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$PYTHON_ENV"
    echo "✓ Virtual environment created"
  else
    echo "✓ Virtual environment already exists"
  fi
  
  source "$PYTHON_ENV/bin/activate"
  echo "✓ Virtual environment activated"
  
  echo ""
  echo "Installing Python dependencies..."
  pip install --upgrade pip setuptools wheel
  pip install -e .
  echo "✓ Python packages installed"
}

setup_r_packages() {
  echo ""
  echo "Installing R packages..."
  Rscript install_r_packages.R
  echo "✓ R packages installed"
}

fetch_data() {
  echo ""
  echo "Fetching flight and weather data..."
  source "$PYTHON_ENV/bin/activate"
  python scripts/fetch_data.py
  echo "✓ Data fetched and processed"
}

train_model() {
  echo ""
  echo "Training machine learning model..."
  Rscript -e "source('model_training.R')"
  echo "✓ Model trained successfully"
}

launch_dashboard() {
  echo ""
  echo "Launching interactive dashboard..."
  echo "Dashboard will open at http://localhost:3838"
  echo ""
  Rscript -e "shiny::runApp('shiny_app.R')"
}

generate_report() {
  echo ""
  echo "Generating analytics report..."
  quarto render analysis.qmd --to html
  echo "✓ Report generated: analysis.html"
}

show_help() {
  cat << EOF
Usage: ./setup.sh [command]

Commands:
  setup           Install all dependencies (Python + R)
  data            Fetch flight and weather data
  model           Train ML model
  dashboard       Launch interactive Shiny dashboard
  report          Generate analytics report
  full            Complete setup (setup + data + model + report)
  
Examples:
  ./setup.sh setup      # Install all dependencies
  ./setup.sh data       # Fetch fresh data from API
  ./setup.sh model      # Train ML model
  ./setup.sh dashboard  # Launch dashboard (interactive)
  ./setup.sh report     # Generate HTML report
  ./setup.sh full       # Complete workflow

EOF
}

case "${1:-setup}" in
  setup)
    create_python_env
    setup_r_packages
    echo ""
    echo "✓ Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Fetch data:        ./setup.sh data"
    echo "  2. Train model:       ./setup.sh model"
    echo "  3. Launch dashboard:  ./setup.sh dashboard"
    echo "  4. Generate report:   ./setup.sh report"
    ;;
  data)
    fetch_data
    ;;
  model)
    train_model
    ;;
  dashboard)
    launch_dashboard
    ;;
  report)
    generate_report
    ;;
  full)
    create_python_env
    setup_r_packages
    fetch_data
    train_model
    generate_report
    echo ""
    echo "✓ Full setup complete!"
    echo ""
    echo "To launch the dashboard, run:"
    echo "  ./setup.sh dashboard"
    ;;
  help|-h|--help)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac

echo ""
