# Setup Guide

## 1. Add Your API Key

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and add your Aviation Stack API key
# AVIATIONSTACK_API_KEY=your_actual_key_here
```

Get a free API key at: https://aviationstack.com

## 2. Run Setup

```bash
chmod +x setup.sh
./setup.sh full
```

## 3. Launch Dashboard

```bash
./setup.sh dashboard
```

That's it! The system will:
- ✅ Accumulate data (grows daily, not replaced)
- ✅ Avoid redundant API calls
- ✅ Train ML model on accumulated data
- ✅ Show interactive visualizations

## Notes

- Your `.env` file is private (in .gitignore)
- API key never exposed or committed to git
- Data accumulates in `data/cleaned/flights_with_weather.csv`
- Fetched dates tracked in `data/.historical_dates_fetched.json`

## Troubleshooting

If you get "AVIATIONSTACK_API_KEY not found":
1. Make sure `.env` file exists (not `.env.example`)
2. Make sure your API key is in the `.env` file
3. Check formatting: `AVIATIONSTACK_API_KEY=your_key` (no spaces)
