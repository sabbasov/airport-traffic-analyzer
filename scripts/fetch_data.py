import requests
import json
import time
import os
from pathlib import Path
import pandas as pd
import openmeteo_requests
import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
CLEANED_DIR = DATA_DIR / "cleaned"
DATA_DIR.mkdir(exist_ok=True)
CLEANED_DIR.mkdir(parents=True, exist_ok=True)

# Get API key from environment variable
API_KEY = os.getenv("AVIATIONSTACK_API_KEY")
if not API_KEY:
    raise ValueError(
        "AVIATIONSTACK_API_KEY not found in environment variables. "
        "Please create a .env file with your API key: AVIATIONSTACK_API_KEY=your_key"
    )
BASE_URL = "https://api.aviationstack.com/v1"

# Enable/Disable API fetching globally
FETCH_FROM_API = False
# Enable API fetching for historical flights with real delay data for ML training
FETCH_HISTORICAL_FLIGHTS = True

ENDPOINTS = {
    "flights": "flights",
    "airports": "airports",
    "airlines": "airlines",
    "cities": "cities",
    "countries": "countries",
}

# Track which dates have been fetched to avoid re-fetching historical data
HISTORICAL_DATES_FILE = DATA_DIR / ".historical_dates_fetched.json"

def load_fetched_dates():
    """Load list of dates already fetched"""
    if HISTORICAL_DATES_FILE.exists():
        with open(HISTORICAL_DATES_FILE) as f:
            return set(json.load(f))
    return set()

def save_fetched_dates(dates):
    """Save list of dates fetched"""
    with open(HISTORICAL_DATES_FILE, "w") as f:
        json.dump(sorted(list(dates)), f)

def fetch_or_load(endpoint_name, paginate=False):
    endpoint_path = ENDPOINTS[endpoint_name]
    cache_file = DATA_DIR / f"{endpoint_name}.json"

    if FETCH_FROM_API:
        all_data = []
        offset = 0
        limit = 100
        
        while True:
            params = {"access_key": API_KEY, "offset": offset, "limit": limit}
            response = requests.get(f"{BASE_URL}/{endpoint_path}", params=params, timeout=(5, 15))
            response.raise_for_status()
            res_json = response.json()
            
            batch = res_json.get("data", [])
            all_data.extend(batch)
            
            if not paginate:
                break
                
            pagination = res_json.get("pagination", {})
            total = pagination.get("total", 0)
            print(f"  > Progress: {len(all_data)} / {total}")
            
            if len(all_data) >= total or not batch:
                break
            
            offset += limit
            time.sleep(1)

        data = {"data": all_data}
        with open(cache_file, "w") as f:
            json.dump(data, f, indent=2)
    else:
        with open(cache_file) as f:
            data = json.load(f)
    return data

airports_data = fetch_or_load("airports", paginate=True)

# Turn ON API fetching for live flights data
FETCH_FROM_API = True
flights_data = fetch_or_load("flights")
# Turn OFF API fetching after flights
FETCH_FROM_API = False

cities_data = fetch_or_load("cities")
countries_data = fetch_or_load("countries")

# Fetch historical flights with real delays for ML training - INCREMENTAL
if FETCH_HISTORICAL_FLIGHTS:
    print("Fetching historical flights data for ML training...")
    historical_flights = []
    
    fetched_dates = load_fetched_dates()
    print(f"  > Previously fetched {len(fetched_dates)} dates")
    
    # Fetch last 7 days of historical data for training (aviationstack provides 3 months)
    # Only fetch dates not already in the system
    for days_back in range(1, 8):
        flight_date = (datetime.date.today() - datetime.timedelta(days=days_back)).strftime('%Y-%m-%d')
        
        # Skip if already fetched
        if flight_date in fetched_dates:
            print(f"  > Skipping {flight_date} (already fetched)")
            continue
        
        params = {
            "access_key": API_KEY,
            "flight_date": flight_date,
            "limit": 100,
            "offset": 0
        }
        
        print(f"  > Fetching flights for {flight_date}...")
        
        try:
            response = requests.get(f"{BASE_URL}/flights", params=params, timeout=(5, 15))
            response.raise_for_status()
            res_json = response.json()
            batch = res_json.get("data", [])
            
            if batch:
                historical_flights.extend(batch)
                fetched_dates.add(flight_date)
                print(f"    ✓ Got {len(batch)} flights")
            else:
                fetched_dates.add(flight_date)
                print(f"    - No flights for this date")
            
            time.sleep(1)  # Rate limiting
        except Exception as e:
            print(f"  ! Error fetching {flight_date}: {e}")
    
    # Save updated list of fetched dates
    save_fetched_dates(fetched_dates)
    
    if historical_flights:
        flights_data["data"].extend(historical_flights)
        print(f"  ✓ Total flights collected: {len(flights_data['data'])}")
    else:
        print(f"  - No new historical flights to fetch")


airports_df = pd.DataFrame(airports_data["data"])
airports_df = airports_df.drop_duplicates(subset=["iata_code"])
airports_df = airports_df.dropna(subset=["latitude", "longitude"])
airports_df = airports_df[airports_df["latitude"] != 0]
airports_lookup = airports_df.set_index("iata_code")[["latitude", "longitude"]]

flights = pd.json_normalize(flights_data["data"], sep='_')

# Extract actual delay times from API response (real delays for completed/landed flights)
flights["departure_delay"] = pd.to_numeric(flights.get("departure_delay", 0), errors='coerce').fillna(0)
flights["arrival_delay"] = pd.to_numeric(flights.get("arrival_delay", 0), errors='coerce').fillna(0)

flights["departure_estimated"] = pd.to_datetime(flights["departure_estimated"], utc=True)
flights["flight_date_str"] = pd.to_datetime(flights["flight_date"]).dt.strftime('%Y-%m-%d')

flights = flights.merge(airports_lookup, left_on="departure_iata", right_index=True, how="left")

weather_tasks = flights.dropna(subset=["latitude", "longitude", "flight_date_str"])
unique_locations = weather_tasks.drop_duplicates(subset=["departure_iata", "flight_date_str"])

# Load existing data if it exists to append to it
output_file = CLEANED_DIR / "flights_with_weather.csv"
existing_flights = None
if output_file.exists():
    print(f"Loading existing flights data ({output_file})...")
    existing_flights = pd.read_csv(output_file)
    print(f"  > Loaded {len(existing_flights)} existing flights")

if not unique_locations.empty:
    openmeteo = openmeteo_requests.Client()
    
    today = datetime.date.today()
    
    weather_list = []
    
    for i, row in unique_locations.iterrows():
        flight_date = pd.to_datetime(row["flight_date_str"]).date()
        
        if flight_date < today:
            url = "https://archive-api.open-meteo.com/v1/archive"
        else:
            url = "https://api.open-meteo.com/v1/forecast"

        params = {
            "latitude": row["latitude"],
            "longitude": row["longitude"],
            "start_date": row["flight_date_str"],
            "end_date": row["flight_date_str"],
            "hourly": ["wind_speed_10m"],
            "timezone": "UTC"
        }

        try:
            responses = openmeteo.weather_api(url, params=params)
            response = responses[0]
            
            hourly = response.Hourly()
            times = pd.date_range(
                start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
                end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
                freq=pd.Timedelta(seconds=hourly.Interval()),
                inclusive="left"
            )
            
            weather_list.append(pd.DataFrame({
                "weather_time": times,
                "wind_speed_10m": hourly.Variables(0).ValuesAsNumpy(),
                "departure_iata": row["departure_iata"]
            }))
        except Exception as e:
            print(f"Could not get weather for {row['departure_iata']} on {row['flight_date_str']}: {e}")

    if weather_list:
        weather_bank = pd.concat(weather_list).sort_values("weather_time")

    flights = flights.sort_values("departure_estimated")
    final_df = pd.merge_asof(
        flights,
        weather_bank,
        left_on="departure_estimated",
        right_on="weather_time",
        by="departure_iata",
        direction="nearest"
    )

    # Append to existing data instead of replacing
    if existing_flights is not None:
        # Remove duplicates by flight ID, keeping the new data
        final_df_combined = pd.concat([existing_flights, final_df], ignore_index=True)
        # Drop duplicates based on flight identifier columns
        final_df_combined = final_df_combined.drop_duplicates(
            subset=['flight_iata', 'departure_iata', 'departure_estimated'],
            keep='last'  # Keep newer data in case of conflicts
        )
        final_df = final_df_combined
        print(f"  ✓ Appended new flights to existing dataset")
    
    success_rate = final_df["wind_speed_10m"].notna().mean() * 100
    final_df.to_csv(output_file, index=False)
    print(f"✓ Saved flights dataset: {len(final_df)} total flights")
    print(f"  Weather match rate: {success_rate:.1f}%")
else:
    # No new weather data, just use existing
    if existing_flights is not None:
        final_df = existing_flights
        final_df.to_csv(output_file, index=False)
        print(f"✓ No new flights to add, using existing dataset: {len(final_df)} flights")
    else:
        flights.to_csv(CLEANED_DIR / "flights.csv", index=False)
        print("✓ Saved basic flights data (no weather data available)")