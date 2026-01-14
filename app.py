import requests
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)

API_KEY = "285122daf0a57d6e80a80ed9d132b1da"

# Toggle whether to fetch from API or load from cache
FETCH_FROM_API = False

# Define all endpoints you care about
ENDPOINTS = {
    "flights": "flights",
    "routes": "routes",
    "airports": "airports",
    "airlines": "airlines",
    "airplanes": "airplanes",
    "aircraft_types": "aircraft_types",
    "aviation_taxes": "aviation_taxes",
    "cities": "cities",
    "countries": "countries",
    "flight_schedules": "schedules",
    "future_flight_schedules": "schedules/future"
}

BASE_URL = "https://api.aviationstack.com/v1"

def fetch_or_load(endpoint_name):
    """Fetch data from API or load from cached JSON file."""
    endpoint_path = ENDPOINTS[endpoint_name]
    cache_file = DATA_DIR / f"{endpoint_name}.json"

    if FETCH_FROM_API:
        print(f"Fetching {endpoint_name} from API...")
        params = {"access_key": API_KEY}
        response = requests.get(f"{BASE_URL}/{endpoint_path}", params=params)
        response.raise_for_status()
        data = response.json()

        # Save to cache
        with open(cache_file, "w") as f:
            json.dump(data, f, indent=2)
        print(f"Saved {endpoint_name} data to {cache_file}")
    else:
        print(f"Loading {endpoint_name} from cache...")
        with open(cache_file) as f:
            data = json.load(f)

    return data

flights_data = fetch_or_load("flights")
airports_data = fetch_or_load("airports")
airlines_data = fetch_or_load("airlines")
# routes_data = fetch_or_load("routes") # not included in free plan
airplanes_data = fetch_or_load("airplanes")
aircraft_types_data = fetch_or_load("aircraft_types")
# aviation_taxes_data = fetch_or_load("aviation_taxes") # not included in free plan
cities_data = fetch_or_load("cities")
countries_data = fetch_or_load("countries")
# flight_schedules_data = fetch_or_load("flight_schedules") # not included in free plan
# future_flight_schedules_data = fetch_or_load("future_flight_schedules") # not included in free plan
cnt = 0
for country in countries_data["data"]:
    if country["currency_name"] == "Dollar":
        print(
            f"{country["currency_name"]}, {country["capital"]}, {country["country_name"]}"
        )