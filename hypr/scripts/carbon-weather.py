#!/usr/bin/env python3
"""
carbon-weather.py - Weather fetching backend for Carbon Shell.
Supports:
1. Full custom API URL pasted by the user.
2. API key for WeatherAPI or OpenWeatherMap with optional custom city.
3. Auto-detected location via wttr.in fallback when no key is specified.
Persists configuration to ~/.config/hypr/carbon-weather.json.
Outputs clean, standardized JSON to stdout.
"""

import sys
import os
import json
import urllib.request
import urllib.parse
import re

CARBON_CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
CONFIG_PATH = os.path.join(CARBON_CONFIG_DIR, "carbon-weather.json")
if not os.path.exists(CONFIG_PATH) and os.path.exists(os.path.expanduser("~/.config/hypr/carbon-weather.json")):
    CONFIG_PATH = os.path.expanduser("~/.config/hypr/carbon-weather.json")


DEFAULT_CONFIG = {
    "apiUrl": "",
    "apiKey": "",
    "city": "",
    "units": "celsius"
}

def load_config():
    if os.path.isfile(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                return {**DEFAULT_CONFIG, **data}
        except Exception:
            pass
    return dict(DEFAULT_CONFIG)

def save_config(cfg):
    try:
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        sys.stderr.write(f"Failed to save config: {e}\n")

def get_weather_icon(desc, code=None):
    d = (desc or "").lower()
    if "thunder" in d or "storm" in d or "lightning" in d:
        return "\ue31d"
    elif "snow" in d or "blizzard" in d or "sleet" in d or "flurr" in d:
        return "\ue31a"
    elif "heavy rain" in d or "torrential" in d or "shower" in d or "rain" in d or "drizzle" in d:
        return "\ue318"
    elif "cloud" in d or "overcast" in d:
        if "part" in d or "few" in d or "scatter" in d:
            return "\ue302"
        return "\ue312"
    elif "clear" in d or "sun" in d:
        return "\ue30d"
    elif "smoke" in d:
        return "\ue35f"
    elif "fog" in d or "mist" in d or "haze" in d:
        return "\ue35c"
    elif "wind" in d:
        return "\ue354"
    return "\ue302"

def fetch_url(url, timeout=6):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (CarbonShell/1.0; Linux)"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8")

def parse_weatherapi(data):
    cur = data.get("current", {})
    loc = data.get("location", {})
    temp_c = cur.get("temp_c", 0.0)
    cond_text = cur.get("condition", {}).get("text", "Clear")
    wind_kph = cur.get("wind_kph", 0.0)
    humid = cur.get("humidity", 0)
    city_name = loc.get("name", "")
    country = loc.get("country", "")
    full_loc = f"{city_name}, {country}" if country else city_name

    forecast_list = []
    hourly_list = []
    fc_days = data.get("forecast", {}).get("forecastday", [])
    import datetime
    for idx, fd in enumerate(fc_days):
        day_info = fd.get("day", {})
        d_cond = day_info.get("condition", {}).get("text", "Clear")
        d_raw = fd.get("date", "")
        try:
            d_name = datetime.datetime.strptime(d_raw, "%Y-%m-%d").strftime("%A")
        except Exception:
            d_name = d_raw
        forecast_list.append({
            "id": idx,
            "date": d_raw,
            "day": d_name.upper(),
            "avg_temp": f"{int(round(day_info.get('avgtemp_c', temp_c)))}°C",
            "max_temp": f"{int(round(day_info.get('maxtemp_c', temp_c)))}°C",
            "min_temp": f"{int(round(day_info.get('mintemp_c', temp_c)))}°C",
            "condition": d_cond.strip(),
            "icon": get_weather_icon(d_cond),
            "wind": f"{int(round(day_info.get('maxwind_kph', wind_kph)))} km/h",
            "humidity": f"{day_info.get('avghumidity', humid)}%"
        })
        if idx == 0:
            for hr in fd.get("hour", []):
                hr_time = hr.get("time", "").split(" ")[-1]
                hr_cond = hr.get("condition", {}).get("text", "Clear")
                hr_temp = hr.get("temp_c", 0.0)
                hourly_list.append({
                    "time": hr_time,
                    "temp": f"{hr_temp:.1f}°",
                    "tempInt": f"{int(round(hr_temp))}°",
                    "condition": hr_cond.strip(),
                    "icon": get_weather_icon(hr_cond)
                })

    return {
        "status": "ok",
        "temp": f"{int(round(temp_c))}°C",
        "tempFull": f"{temp_c:.1f}°",
        "tempVal": float(temp_c),
        "condition": cond_text.strip(),
        "icon": get_weather_icon(cond_text),
        "wind": f"{int(round(wind_kph))} km/h",
        "humidity": f"{humid}%",
        "city": full_loc,
        "provider": "WeatherAPI",
        "message": f"Connected to WeatherAPI ({city_name})",
        "forecast": forecast_list,
        "hourly": hourly_list
    }

def parse_openweathermap(data):
    main = data.get("main", {})
    weather = data.get("weather", [{}])[0]
    wind = data.get("wind", {})
    temp = main.get("temp", 0.0)
    # If temp > 150, assume Kelvin
    if temp > 150:
        temp = temp - 273.15
    cond_text = weather.get("description", weather.get("main", "Clear")).title()
    wind_spd = wind.get("speed", 0.0)
    wind_kph = wind_spd * 3.6  # m/s to km/h
    humid = main.get("humidity", 0)
    city_name = data.get("name", "")

    return {
        "status": "ok",
        "temp": f"{int(round(temp))}°C",
        "tempFull": f"{temp:.1f}°",
        "tempVal": float(temp),
        "condition": cond_text.strip(),
        "icon": get_weather_icon(cond_text),
        "wind": f"{int(round(wind_kph))} km/h",
        "humidity": f"{humid}%",
        "city": city_name,
        "provider": "OpenWeatherMap",
        "message": f"Connected to OpenWeatherMap ({city_name})"
    }

def parse_openmeteo(data):
    cur = data.get("current_weather", {}) or data.get("current", {})
    temp = cur.get("temperature", cur.get("temperature_2m", 0.0))
    wind_spd = cur.get("windspeed", cur.get("wind_speed_10m", 0.0))
    cond_text = "Clear"
    return {
        "status": "ok",
        "temp": f"{int(round(temp))}°C",
        "tempFull": f"{temp:.1f}°",
        "tempVal": float(temp),
        "condition": cond_text,
        "icon": get_weather_icon(cond_text),
        "wind": f"{int(round(wind_spd))} km/h",
        "humidity": "50%",
        "city": "Current Location",
        "provider": "Open-Meteo",
        "message": "Connected to Open-Meteo"
    }

def parse_generic_json(raw_text):
    try:
        data = json.loads(raw_text)
    except Exception:
        return None

    if "current" in data and "condition" in data["current"]:
        return parse_weatherapi(data)
    if "main" in data and "weather" in data:
        return parse_openweathermap(data)
    if "current_weather" in data or ("current" in data and "temperature_2m" in data["current"]):
        return parse_openmeteo(data)
    if "current_condition" in data:
        return parse_wttr_json(data)

    # Generic heuristics
    temp = None
    for k in ["temp", "temperature", "temp_c", "current_temp"]:
        if k in data:
            temp = float(data[k])
            break
    if temp is not None:
        cond = str(data.get("condition", data.get("description", "Clear")))
        return {
            "status": "ok",
            "temp": f"{int(round(temp))}°C",
            "tempFull": f"{temp:.1f}°",
            "tempVal": float(temp),
            "condition": cond,
            "icon": get_weather_icon(cond),
            "wind": "10 km/h",
            "humidity": "50%",
            "city": str(data.get("city", data.get("location", "Custom API"))),
            "provider": "Custom API",
            "message": "Custom API connected"
        }
    return None

def parse_wttr_json(data):
    try:
        cur = data["current_condition"][0]
        area = data.get("nearest_area", [{}])[0]
        city = ""
        try:
            city = area["areaName"][0]["value"]
            country = area.get("country", [{}])[0].get("value", "")
            if country:
                city = f"{city}, {country}"
        except Exception:
            pass

        temp_c = float(cur.get("temp_C", "20"))
        desc = cur.get("weatherDesc", [{}])[0].get("value", "Clear").strip()
        wind_kph = float(cur.get("windspeedKmph", "10"))
        humid = cur.get("humidity", "50")

        return {
            "status": "ok",
            "temp": f"{int(round(temp_c))}°C",
            "tempFull": f"{temp_c:.1f}°",
            "tempVal": temp_c,
            "condition": desc,
            "icon": get_weather_icon(desc),
            "wind": f"{int(round(wind_kph))} km/h",
            "humidity": f"{humid}%",
            "city": city or "Local",
            "provider": "wttr.in",
            "message": f"Live Weather ({city or 'Auto-Detected'})"
        }
    except Exception as e:
        return None

def fetch_weather(config):
    api_url = (config.get("apiUrl") or "").strip()
    api_key = (config.get("apiKey") or "").strip()
    city = (config.get("city") or "").strip()

    # 1. Custom URL specified directly
    if api_url.startswith("http://") or api_url.startswith("https://"):
        try:
            text = fetch_url(api_url)
            parsed = parse_generic_json(text)
            if parsed:
                return parsed
            # If not JSON, check pipe-delimited format
            if "|" in text:
                parts = [p.strip() for p in text.split("|")]
                if len(parts) >= 3:
                    num_temp = float(re.sub(r"[^0-9.-]", "", parts[1]))
                    return {
                        "status": "ok",
                        "temp": f"{int(round(num_temp))}°C",
                        "tempFull": f"{num_temp:.1f}°",
                        "tempVal": num_temp,
                        "condition": parts[2],
                        "icon": get_weather_icon(parts[2]),
                        "wind": parts[3] if len(parts) > 3 else "10 km/h",
                        "humidity": parts[4] if len(parts) > 4 else "50%",
                        "city": parts[5] if len(parts) > 5 else "Custom",
                        "provider": "Custom Endpoint",
                        "message": "Custom endpoint loaded"
                    }
        except Exception as e:
            return {
                "status": "error",
                "temp": "--",
                "tempFull": "--",
                "condition": "Network Error",
                "icon": "⚠️",
                "wind": "--",
                "humidity": "--",
                "city": city or "Unknown",
                "provider": "Custom URL",
                "message": f"Failed to fetch API URL: {e}"
            }

    # 2. API Key specified (WeatherAPI or OpenWeatherMap)
    if api_key:
        target_city = city or "auto:ip"
        # Try WeatherAPI first
        # Try WeatherAPI forecast.json first
        try:
            w_url = f"https://api.weatherapi.com/v1/forecast.json?key={api_key}&q={urllib.parse.quote(target_city)}&days=3"
            text = fetch_url(w_url)
            data = json.loads(text)
            if "current" in data:
                return parse_weatherapi(data)
        except Exception:
            try:
                w_url = f"https://api.weatherapi.com/v1/current.json?key={api_key}&q={urllib.parse.quote(target_city)}"
                text = fetch_url(w_url)
                data = json.loads(text)
                if "current" in data:
                    return parse_weatherapi(data)
            except Exception:
                pass

        # Try OpenWeatherMap
        try:
            ow_city = city or "London"
            ow_url = f"https://api.openweathermap.org/data/2.5/weather?q={urllib.parse.quote(ow_city)}&appid={api_key}&units=metric"
            text = fetch_url(ow_url)
            data = json.loads(text)
            if "main" in data:
                return parse_openweathermap(data)
        except Exception as e:
            return {
                "status": "error",
                "temp": "--",
                "tempFull": "--",
                "condition": "Invalid Key",
                "icon": "⚠️",
                "wind": "--",
                "humidity": "--",
                "city": city or "Unknown",
                "provider": "API Key",
                "message": f"API Key rejected: {e}"
            }

    # 3. If no API key or URL is provided, do NOT auto-detect: show No API Key (0°)
    return {
        "status": "no_key",
        "temp": "0°",
        "tempFull": "0.0°",
        "tempVal": 0.0,
        "condition": "No API Key",
        "icon": "🌤️",
        "wind": "0 km/h",
        "humidity": "0%",
        "city": "No API Key",
        "provider": "None",
        "message": "No API key configured. Get a free key at weatherapi.com"
    }

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Carbon Weather Fetcher")
    parser.add_argument("--set-url", dest="set_url", help="Save custom API URL")
    parser.add_argument("--set-key", dest="set_key", help="Save API Key")
    parser.add_argument("--set-city", dest="set_city", help="Save City/Location")
    parser.add_argument("--fetch", action="store_true", help="Fetch weather and print JSON")
    args = parser.parse_args()

    cfg = load_config()
    changed = False

    if args.set_url is not None:
        cfg["apiUrl"] = args.set_url.strip()
        changed = True
    if args.set_key is not None:
        cfg["apiKey"] = args.set_key.strip()
        changed = True
    if args.set_city is not None:
        cfg["city"] = args.set_city.strip()
        changed = True

    if changed:
        save_config(cfg)

    result = fetch_weather(cfg)
    result["config"] = cfg
    print(json.dumps(result))

if __name__ == "__main__":
    main()
