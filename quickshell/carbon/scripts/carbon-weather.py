#!/usr/bin/env python3
"""
Carbon Weather Service Helper
Reads and updates ~/.config/waybar/weather.conf and queries OpenWeatherMap.
Outputs structured JSON for Quickshell UI consumption.
"""

import os
import sys
import json
import time
import datetime
import urllib.request
import urllib.parse
import urllib.error
import argparse
from pathlib import Path

CONFIG_PATHS = [
    Path.home() / ".config" / "waybar" / "weather.conf",
    Path.home() / ".config" / "hypr" / "weather.conf",
    Path.home() / ".config" / "carbon" / "weather.conf"
]
CACHE_FILE = Path("/tmp/carbon-weather-cache.json")
CACHE_TTL = 300  # 5 minutes cache

ICON_MAP = {
    '01d': '󰖨', '01n': '󰖩',  # clear
    '02d': '󰖕', '02n': '󰖔',  # few clouds
    '03d': '󰖐', '03n': '󰖐',  # scattered clouds
    '04d': '󰖐', '04n': '󰖐',  # broken clouds
    '09d': '󰖗', '09n': '󰖗',  # shower rain
    '10d': '󰖕', '10n': '󰖔',  # rain
    '11d': '󰖓', '11n': '󰖓',  # thunderstorm
    '13d': '󰖘', '13n': '󰖘',  # snow
    '50d': '󰖑', '50n': '󰖑',  # mist
}

WMO_MAP = {
    0: ("Clear", "󰖨"),
    1: ("Mainly Clear", "󰖕"),
    2: ("Partly Cloudy", "󰖕"),
    3: ("Overcast", "󰖐"),
    45: ("Foggy", "󰖑"),
    48: ("Rime Fog", "󰖑"),
    51: ("Light Drizzle", "󰖗"),
    53: ("Drizzle", "󰖗"),
    55: ("Dense Drizzle", "󰖗"),
    56: ("Freezing Drizzle", "󰖘"),
    57: ("Dense Freezing Drizzle", "󰖘"),
    61: ("Slight Rain", "󰖗"),
    63: ("Moderate Rain", "󰖖"),
    65: ("Heavy Rain", "󰖖"),
    66: ("Freezing Rain", "󰖘"),
    67: ("Heavy Freezing Rain", "󰖘"),
    71: ("Slight Snow", "󰖘"),
    73: ("Moderate Snow", "󰖘"),
    75: ("Heavy Snow", "󰖘"),
    77: ("Snow Grains", "󰖘"),
    80: ("Slight Showers", "󰖖"),
    81: ("Moderate Showers", "󰖖"),
    82: ("Violent Showers", "󰖖"),
    85: ("Snow Showers", "󰖘"),
    86: ("Heavy Snow Showers", "󰖘"),
    95: ("Thunderstorm", "󰖓"),
    96: ("Thunderstorm w/ Hail", "󰖓"),
    99: ("Thunderstorm w/ Heavy Hail", "󰖓"),
}

def get_primary_config_path():
    for p in CONFIG_PATHS:
        if p.exists():
            return p
    return CONFIG_PATHS[0]

def load_config():
    p = get_primary_config_path()
    cfg = {
        "API_KEY": "",
        "CITY_NAME": "Patna,IN",
        "CITY_ID": "",
        "UNIT": "metric"
    }
    if p.exists():
        try:
            with open(p, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        cfg[k.strip()] = v.strip()
        except Exception:
            pass
    return cfg

def save_config(api_key=None, city_name=None, unit=None):
    cfg = load_config()
    if api_key is not None:
        cfg["API_KEY"] = api_key.strip()
    if city_name is not None:
        cfg["CITY_NAME"] = city_name.strip()
    if unit is not None:
        cfg["UNIT"] = unit.strip()

    content = f"""# Weather configuration for Waybar and Carbon Shell
# Get your free API key at: https://openweathermap.org/api
API_KEY={cfg.get('API_KEY', '')}
CITY_NAME={cfg.get('CITY_NAME', '')}
UNIT={cfg.get('UNIT', 'metric')}
"""
    for p in CONFIG_PATHS:
        try:
            p.parent.mkdir(parents=True, exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception:
            pass
    # Invalidate cache on config save
    if CACHE_FILE.exists():
        try:
            CACHE_FILE.unlink()
        except Exception:
            pass
    return cfg

def fetch_weather(force=False):
    cfg = load_config()
    api_key = cfg.get("API_KEY", "")
    city_name = cfg.get("CITY_NAME", "")
    unit = cfg.get("UNIT", "metric")
    unit_sym = "°C" if unit == "metric" else "°F"
    speed_sym = "km/h" if unit == "metric" else "mph"

    result = {
        "api_key": api_key,
        "city_name": city_name,
        "unit": unit,
        "unit_symbol": unit_sym,
        "city": city_name.split(",")[0] if city_name else "Unknown",
        "country": city_name.split(",")[1] if "," in city_name else "",
        "temp": "--",
        "feels_like": "--",
        "description": "Configure Weather",
        "icon": "󰇨",
        "humidity": "--",
        "wind": "--",
        "forecast": [],
        "success": False,
        "error": ""
    }

    if not api_key or api_key == "YOUR_API_KEY_HERE":
        result["error"] = "API key not set. Please enter OpenWeatherMap API key."
        result["description"] = "No API Key"
        return result

    if not city_name:
        result["error"] = "City name not configured."
        result["description"] = "No City Set"
        return result

    now = time.time()
    if not force and CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                cached = json.load(f)
                if now - cached.get("_timestamp", 0) < CACHE_TTL:
                    cached["api_key"] = api_key
                    cached["city_name"] = city_name
                    cached["unit"] = unit
                    return cached
        except Exception:
            pass

    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?q={urllib.parse.quote(city_name)}&appid={api_key}&units={unit}"
        req = urllib.request.Request(url, headers={"User-Agent": "CarbonShell/1.0"})
        with urllib.request.urlopen(req, timeout=8) as response:
            data = json.loads(response.read().decode("utf-8"))

        temp = round(data["main"]["temp"])
        feels_like = round(data["main"]["feels_like"])
        description = data["weather"][0]["description"].title() if data.get("weather") else ""
        icon_code = data["weather"][0]["icon"] if data.get("weather") else ""
        icon = ICON_MAP.get(icon_code, "󰖐")
        humidity = data["main"].get("humidity", 0)
        wind_speed_raw = data.get("wind", {}).get("speed", 0)
        wind_val = round(wind_speed_raw * 3.6) if unit == "metric" else round(wind_speed_raw)

        # 7-day daily forecast via Open-Meteo using coordinates from OWM
        coord = data.get("coord", {})
        lat = coord.get("lat")
        lon = coord.get("lon")
        forecast = []
        if lat is not None and lon is not None:
            try:
                om_unit = "&temperature_unit=fahrenheit&wind_speed_unit=mph" if unit == "imperial" else ""
                om_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto{om_unit}"
                om_req = urllib.request.Request(om_url, headers={"User-Agent": "CarbonShell/1.0"})
                with urllib.request.urlopen(om_req, timeout=6) as om_resp:
                    om_data = json.loads(om_resp.read().decode("utf-8"))
                    daily = om_data.get("daily", {})
                    d_times = daily.get("time", [])
                    d_codes = daily.get("weathercode", [])
                    d_maxs = daily.get("temperature_2m_max", [])
                    d_mins = daily.get("temperature_2m_min", [])

                    for i in range(min(7, len(d_times))):
                        d_str = d_times[i]
                        try:
                            dt = datetime.date.fromisoformat(d_str)
                            day_name = "Today" if i == 0 else dt.strftime("%a")
                            date_str = dt.strftime("%b %d")
                        except Exception:
                            day_name = "Day"
                            date_str = d_str

                        code = d_codes[i] if i < len(d_codes) else 0
                        cond_name, cond_icon = WMO_MAP.get(code, ("Cloudy", "󰖐"))
                        max_t = round(d_maxs[i]) if i < len(d_maxs) else temp
                        min_t = round(d_mins[i]) if i < len(d_mins) else temp

                        forecast.append({
                            "day": day_name,
                            "date": date_str,
                            "code": code,
                            "desc": cond_name,
                            "icon": cond_icon,
                            "temp_max": max_t,
                            "temp_min": min_t,
                            "temp_max_str": f"{max_t}{unit_sym}",
                            "temp_min_str": f"{min_t}{unit_sym}",
                            "temp_range": f"{min_t}° - {max_t}°"
                        })
            except Exception:
                pass

        result.update({
            "city": data.get("name", result["city"]),
            "country": data.get("sys", {}).get("country", result["country"]),
            "temp": f"{temp}{unit_sym}",
            "temp_num": temp,
            "feels_like": f"{feels_like}{unit_sym}",
            "description": description,
            "icon": icon,
            "humidity": f"{humidity}%",
            "wind": f"{wind_val} {speed_sym}",
            "forecast": forecast,
            "success": True,
            "error": "",
            "_timestamp": now
        })

        try:
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(result, f)
        except Exception:
            pass

        return result

    except urllib.error.HTTPError as e:
        msg = f"HTTP Error {e.code}"
        if e.code == 401:
            msg = "Invalid API key"
        elif e.code == 404:
            msg = f"City '{city_name}' not found"
        result["error"] = msg
        result["description"] = msg
        return result
    except Exception as e:
        result["error"] = str(e)
        result["description"] = "Connection Error"
        return result

def main():
    parser = argparse.ArgumentParser(description="Carbon Weather Helper")
    parser.add_argument("action", choices=["status", "update"], nargs="?", default="status")
    parser.add_argument("--api-key", dest="api_key", default=None)
    parser.add_argument("--city", dest="city", default=None)
    parser.add_argument("--unit", dest="unit", default=None)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    if args.action == "update":
        save_config(args.api_key, args.city, args.unit)
        data = fetch_weather(force=True)
    else:
        data = fetch_weather(force=args.force)

    print(json.dumps(data, indent=2))

if __name__ == "__main__":
    main()
