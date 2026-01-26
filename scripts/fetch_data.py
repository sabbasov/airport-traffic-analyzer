import requests
import json
import time
from pathlib import Path
import pandas as pd
import openmeteo_requests
import datetime

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
CLEANED_DIR = DATA_DIR / "cleaned"
DATA_DIR.mkdir(exist_ok=True)
CLEANED_DIR.mkdir(parents=True, exist_ok=True)

API_KEY = "285122daf0a57d6e80a80ed9d132b1da"
BASE_URL = "https://api.aviationstack.com/v1"

FETCH_FROM_API = False

ENDPOINTS = {
    "flights": "flights",
    "airports": "airports",
    "airlines": "airlines",
    "cities": "cities",
    "countries": "countries",
}

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
flights_data = fetch_or_load("flights")
cities_data = fetch_or_load("cities")
countries_data = fetch_or_load("countries")

airports_df = pd.DataFrame(airports_data["data"])
airports_df = airports_df.drop_duplicates(subset=["iata_code"])
airports_df = airports_df.dropna(subset=["latitude", "longitude"])
airports_df = airports_df[airports_df["latitude"] != 0]
airports_lookup = airports_df.set_index("iata_code")[["latitude", "longitude"]]

flights = pd.json_normalize(flights_data["data"], sep='_')

flights["departure_estimated"] = pd.to_datetime(flights["departure_estimated"], utc=True)
flights["flight_date_str"] = pd.to_datetime(flights["flight_date"]).dt.strftime('%Y-%m-%d')

flights = flights.merge(airports_lookup, left_on="departure_iata", right_index=True, how="left")

weather_tasks = flights.dropna(subset=["latitude", "longitude", "flight_date_str"])
unique_locations = weather_tasks.drop_duplicates(subset=["departure_iata", "flight_date_str"])

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

    success_rate = final_df["wind_speed_10m"].notna().mean() * 100
    final_df.to_csv(CLEANED_DIR / "flights_with_weather.csv", index=False)
    print(f"Successfully saved flights with weather data. Weather match rate: {success_rate:.1f}%")
else:
    flights.to_csv(CLEANED_DIR / "flights.csv", index=False)
    print("Saved basic flights data (no weather data available)")