#!/usr/bin/env python3
"""
Weather module for Waybar, backed by wttr.in.

wttr.in needs no account and no API key — it is literally a `curl` to a URL —
and it works out the location from the IP address, so nothing has to be
configured to get started.

Prints one JSON object per run, in the shape Waybar expects:
    {"text": "...", "tooltip": "...", "class": "..."}
The "class" key becomes a CSS selector, e.g. `#custom-weather.rain`.

wttr.in rate-limits requests per IP, so the last response is kept in
~/.cache/waybar/weather.json and only refreshed after CACHE_TTL seconds. If the
network goes down the stale cache is reused and flagged, rather than leaving
the bar empty.

Adjust the constants below; nothing else in the file needs touching.

To test by hand, run ~/.config/waybar/scripts/weather.py — it should print a
single line of JSON.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────

# Empty means wttr.in works it out from your IP. To pin it, use a city name
# like "Sao Paulo" or "Lisbon", a postal code, or an airport code like "GRU".
LOCATION = ""

# How long a response stays valid before querying again, in seconds.
CACHE_TTL = 900  # 15 minutes

# Seconds before giving up on the request. Deliberately short: the bar must
# not hang waiting on the network.
TIMEOUT = 10

# Show the "feels like" temperature alongside the real one?
SHOW_FEELS_LIKE = True

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "waybar" / "weather.json"


# ── WWO condition codes (the backend behind wttr.in) ───────────────────────
# Mapped here instead of asking the service for localized text, so the output is
# always the same and does not depend on a remote response being right.
# Each entry: code -> (day icon, night icon, description, css_class)
CONDITIONS: dict[int, tuple[str, str, str, str]] = {
    113: ("󰖙", "󰖔", "clear sky", "clear"),
    116: ("󰖕", "󰼱", "partly cloudy", "cloudy"),
    119: ("󰖐", "󰖐", "cloudy", "cloudy"),
    122: ("󰖐", "󰖐", "overcast", "cloudy"),
    143: ("󰖑", "󰖑", "mist", "fog"),
    176: ("󰼳", "󰼳", "patchy rain possible", "rain"),
    179: ("󰼴", "󰼴", "patchy snow possible", "snow"),
    182: ("󰙿", "󰙿", "patchy sleet possible", "snow"),
    185: ("󰙿", "󰙿", "freezing drizzle possible", "snow"),
    200: ("󰙾", "󰙾", "thundery outbreaks possible", "storm"),
    227: ("󰼶", "󰼶", "blowing snow", "snow"),
    230: ("󰼶", "󰼶", "blizzard", "snow"),
    248: ("󰖑", "󰖑", "fog", "fog"),
    260: ("󰖑", "󰖑", "freezing fog", "fog"),
    263: ("󰼳", "󰼳", "patchy light drizzle", "rain"),
    266: ("󰖗", "󰖗", "light drizzle", "rain"),
    281: ("󰙿", "󰙿", "freezing drizzle", "snow"),
    284: ("󰙿", "󰙿", "heavy freezing drizzle", "snow"),
    293: ("󰼳", "󰼳", "patchy light rain", "rain"),
    296: ("󰖗", "󰖗", "light rain", "rain"),
    299: ("󰖗", "󰖗", "moderate rain at times", "rain"),
    302: ("󰖖", "󰖖", "moderate rain", "rain"),
    305: ("󰖖", "󰖖", "heavy rain at times", "rain"),
    308: ("󰖖", "󰖖", "heavy rain", "rain"),
    311: ("󰙿", "󰙿", "light freezing rain", "snow"),
    314: ("󰙿", "󰙿", "heavy freezing rain", "snow"),
    317: ("󰙿", "󰙿", "light sleet", "snow"),
    320: ("󰙿", "󰙿", "moderate sleet", "snow"),
    323: ("󰼴", "󰼴", "patchy light snow", "snow"),
    326: ("󰖘", "󰖘", "light snow", "snow"),
    329: ("󰼶", "󰼶", "patchy moderate snow", "snow"),
    332: ("󰖘", "󰖘", "moderate snow", "snow"),
    335: ("󰼶", "󰼶", "patchy heavy snow", "snow"),
    338: ("󰼶", "󰼶", "heavy snow", "snow"),
    350: ("󰖒", "󰖒", "ice pellets", "snow"),
    353: ("󰼳", "󰼳", "light rain shower", "rain"),
    356: ("󰖖", "󰖖", "rain shower", "rain"),
    359: ("󰖖", "󰖖", "torrential rain shower", "rain"),
    362: ("󰙿", "󰙿", "light sleet showers", "snow"),
    365: ("󰙿", "󰙿", "heavy sleet showers", "snow"),
    368: ("󰼴", "󰼴", "light snow showers", "snow"),
    371: ("󰼶", "󰼶", "snow showers", "snow"),
    374: ("󰖒", "󰖒", "light ice pellet showers", "snow"),
    377: ("󰖒", "󰖒", "ice pellet showers", "snow"),
    386: ("󰙾", "󰙾", "rain with thunder", "storm"),
    389: ("󰙾", "󰙾", "heavy rain with thunder", "storm"),
    392: ("󰙾", "󰙾", "snow with thunder", "storm"),
    395: ("󰙾", "󰙾", "heavy snow with thunder", "storm"),
}

UNKNOWN = ("󰖐", "󰖐", "unknown", "cloudy")


def emit(text: str, tooltip: str, css_class: str = "") -> None:
    """Prints the JSON Waybar reads, then exits."""
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}, ensure_ascii=False))
    sys.exit(0)


def fetch() -> dict:
    """Queries wttr.in. Raises if the network fails."""
    url = f"https://wttr.in/{urllib.parse.quote(LOCATION)}?format=j1"
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8 waybar-weather"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def read_cache() -> tuple[dict | None, float]:
    """Returns (data, age_in_seconds), or (None, inf) when there is no cache."""
    try:
        raw = json.loads(CACHE.read_text(encoding="utf-8"))
        return raw["data"], time.time() - raw["saved_at"]
    except (OSError, ValueError, KeyError):
        return None, float("inf")


def write_cache(data: dict) -> None:
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(
            json.dumps({"saved_at": time.time(), "data": data}, ensure_ascii=False),
            encoding="utf-8",
        )
    except OSError:
        pass  # the cache is an optimization; it must not break the module


def is_daytime(data: dict) -> bool:
    """Works out whether it is daytime by comparing local time to sunrise/sunset."""
    try:
        astro = data["weather"][0]["astronomy"][0]
        now = datetime.now().time()
        sunrise = datetime.strptime(astro["sunrise"], "%I:%M %p").time()
        sunset = datetime.strptime(astro["sunset"], "%I:%M %p").time()
        return sunrise <= now <= sunset
    except (KeyError, IndexError, ValueError):
        return 6 <= datetime.now().hour < 18


def format_output(data: dict, stale: bool) -> tuple[str, str, str]:
    current = data["current_condition"][0]
    code = int(current.get("weatherCode", 0))
    icon_day, icon_night, description, css_class = CONDITIONS.get(code, UNKNOWN)
    icon = icon_day if is_daytime(data) else icon_night

    temp = int(current["temp_C"])
    feels_like = int(current["FeelsLikeC"])

    text = f"{icon} {temp}°C"
    if SHOW_FEELS_LIKE and abs(feels_like - temp) >= 2:
        text += f" (feels {feels_like}°)"
    if stale:
        text += " ·"  # a discreet dot means stale data, network down

    # ── Tooltip: current conditions plus a 3-day forecast ──────────────────
    try:
        area = data["nearest_area"][0]
        place = f"{area['areaName'][0]['value']}, {area['region'][0]['value']}"
    except (KeyError, IndexError):
        place = "unknown location"

    lines = [
        f"<b>{place}</b>",
        f"{description.capitalize()} · {temp}°C (feels like {feels_like}°C)",
        f"󰖎 humidity {current['humidity']}%   󰖝 wind {current['windspeedKmph']} km/h",
        f"󰈈 visibility {current['visibility']} km   󰡄 {current['pressure']} hPa",
        "",
    ]

    weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i, day in enumerate(data.get("weather", [])[:3]):
        try:
            day_date = datetime.strptime(day["date"], "%Y-%m-%d")
            label = "today" if i == 0 else ("tomorrow" if i == 1 else weekdays[day_date.weekday()])
            rain_chance = max(int(h.get("chanceofrain", 0)) for h in day.get("hourly", [{}]))
            lines.append(
                f"<b>{label:<7}</b> {day['mintempC']:>3}° … {day['maxtempC']:>3}°   󰖗 {rain_chance}%"
            )
        except (KeyError, ValueError):
            continue

    if stale:
        lines += ["", "<i>Offline — showing last known data.</i>"]

    try:
        astro = data["weather"][0]["astronomy"][0]
        lines += ["", f"󰖜 {astro['sunrise']}   󰖛 {astro['sunset']}"]
    except (KeyError, IndexError):
        pass

    return text, "\n".join(lines), css_class


def main() -> None:
    cache, age = read_cache()

    # Cache still fresh: skip the network entirely.
    if cache is not None and age < CACHE_TTL:
        emit(*format_output(cache, stale=False))

    try:
        data = fetch()
        write_cache(data)
        emit(*format_output(data, stale=False))
    except (urllib.error.URLError, OSError, ValueError, KeyError, IndexError) as err:
        # Network down or a strange response: fall back to the stale cache.
        if cache is not None:
            emit(*format_output(cache, stale=True))
        emit("󰅤 --", f"Could not fetch weather.\n{type(err).__name__}: {err}", "error")


if __name__ == "__main__":
    main()
