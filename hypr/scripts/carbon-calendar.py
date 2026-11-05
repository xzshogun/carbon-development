#!/usr/bin/env python3
"""
Carbon Calendar & Indian Festivals Backend
Manages Indian national holidays, major festivals (2024-2028),
and persistent user events stored in ~/.config/hypr/carbon-calendar-events.json.
"""

import sys
import os
import json
import uuid
import argparse
from datetime import datetime

CARBON_CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
EVENTS_FILE = os.path.join(CARBON_CONFIG_DIR, "carbon-calendar-events.json")
if not os.path.exists(EVENTS_FILE) and os.path.exists(os.path.expanduser("~/.config/hypr/carbon-calendar-events.json")):
    EVENTS_FILE = os.path.expanduser("~/.config/hypr/carbon-calendar-events.json")


# ── Indian Calendar Festivals & Holidays Database ─────────────────────────────
# Fixed annual national/cultural holidays (month, day)
FIXED_HOLIDAYS = {
    (1, 1): {"title": "New Year's Day", "category": "observance", "icon": "🎉"},
    (1, 14): {"title": "Makar Sankranti / Pongal", "category": "festival", "icon": "🪁"},
    (1, 15): {"title": "Pongal / Magh Bihu", "category": "festival", "icon": "🌾"},
    (1, 26): {"title": "Republic Day", "category": "national", "icon": "🇮🇳"},
    (2, 14): {"title": "Vasant Panchami", "category": "festival", "icon": "🌼"},
    (3, 8): {"title": "International Women's Day", "category": "observance", "icon": "🌸"},
    (4, 14): {"title": "Ambedkar Jayanti / Baisakhi", "category": "national", "icon": "📜"},
    (5, 1): {"title": "Maharashtra Day / Labour Day", "category": "observance", "icon": "🛠️"},
    (8, 15): {"title": "Independence Day", "category": "national", "icon": "🇮🇳"},
    (10, 2): {"title": "Gandhi Jayanti", "category": "national", "icon": "🕊️"},
    (10, 31): {"title": "Sardar Patel Jayanti / Ekta Diwas", "category": "observance", "icon": "🇮🇳"},
    (11, 14): {"title": "Children's Day", "category": "observance", "icon": "🎈"},
    (12, 25): {"title": "Christmas", "category": "festival", "icon": "🎄"},
    (12, 31): {"title": "New Year's Eve", "category": "observance", "icon": "✨"}
}

# Variable lunar/religious festivals by year (YYYY-MM-DD)
LUNAR_FESTIVALS = {
    # 2024
    "2024-03-08": {"title": "Maha Shivratri", "category": "festival", "icon": "🕉️"},
    "2024-03-25": {"title": "Holi", "category": "festival", "icon": "🎨"},
    "2024-03-29": {"title": "Good Friday", "category": "festival", "icon": "✝️"},
    "2024-04-11": {"title": "Eid-ul-Fitr", "category": "festival", "icon": "🌙"},
    "2024-04-17": {"title": "Rama Navami", "category": "festival", "icon": "🏹"},
    "2024-04-21": {"title": "Mahavir Jayanti", "category": "festival", "icon": "🕊️"},
    "2024-05-23": {"title": "Buddha Purnima", "category": "festival", "icon": "☸️"},
    "2024-06-17": {"title": "Eid-ul-Adha (Bakrid)", "category": "festival", "icon": "🌙"},
    "2024-07-17": {"title": "Muharram", "category": "observance", "icon": "🕌"},
    "2024-08-19": {"title": "Raksha Bandhan", "category": "festival", "icon": "🧵"},
    "2024-08-26": {"title": "Krishna Janmashtami", "category": "festival", "icon": "🦚"},
    "2024-09-07": {"title": "Ganesh Chaturthi", "category": "festival", "icon": "🐘"},
    "2024-09-16": {"title": "Milad-un-Nabi", "category": "festival", "icon": "🌙"},
    "2024-10-12": {"title": "Dussehra (Vijayadashami)", "category": "festival", "icon": "🏹"},
    "2024-10-31": {"title": "Diwali (Deepavali)", "category": "festival", "icon": "🪔"},
    "2024-11-02": {"title": "Govardhan Puja", "category": "festival", "icon": "🪔"},
    "2024-11-03": {"title": "Bhai Dooj", "category": "festival", "icon": "🪔"},
    "2024-11-07": {"title": "Chhath Puja", "category": "festival", "icon": "☀️"},
    "2024-11-15": {"title": "Guru Nanak Jayanti", "category": "festival", "icon": "☬"},

    # 2025
    "2025-02-26": {"title": "Maha Shivratri", "category": "festival", "icon": "🕉️"},
    "2025-03-14": {"title": "Holi", "category": "festival", "icon": "🎨"},
    "2025-03-31": {"title": "Eid-ul-Fitr", "category": "festival", "icon": "🌙"},
    "2025-04-06": {"title": "Rama Navami", "category": "festival", "icon": "🏹"},
    "2025-04-10": {"title": "Mahavir Jayanti", "category": "festival", "icon": "🕊️"},
    "2025-04-18": {"title": "Good Friday", "category": "festival", "icon": "✝️"},
    "2025-05-12": {"title": "Buddha Purnima", "category": "festival", "icon": "☸️"},
    "2025-06-07": {"title": "Eid-ul-Adha (Bakrid)", "category": "festival", "icon": "🌙"},
    "2025-07-06": {"title": "Muharram", "category": "observance", "icon": "🕌"},
    "2025-08-09": {"title": "Raksha Bandhan", "category": "festival", "icon": "🧵"},
    "2025-08-16": {"title": "Krishna Janmashtami", "category": "festival", "icon": "🦚"},
    "2025-08-27": {"title": "Ganesh Chaturthi", "category": "festival", "icon": "🐘"},
    "2025-09-05": {"title": "Milad-un-Nabi", "category": "festival", "icon": "🌙"},
    "2025-10-02": {"title": "Dussehra (Vijayadashami)", "category": "festival", "icon": "🏹"},
    "2025-10-20": {"title": "Diwali (Deepavali)", "category": "festival", "icon": "🪔"},
    "2025-10-22": {"title": "Bhai Dooj", "category": "festival", "icon": "🪔"},
    "2025-10-27": {"title": "Chhath Puja", "category": "festival", "icon": "☀️"},
    "2025-11-05": {"title": "Guru Nanak Jayanti", "category": "festival", "icon": "☬"},

    # 2026 (Current year)
    "2026-02-15": {"title": "Maha Shivratri", "category": "festival", "icon": "🕉️"},
    "2026-03-03": {"title": "Holi", "category": "festival", "icon": "🎨"},
    "2026-03-20": {"title": "Eid-ul-Fitr", "category": "festival", "icon": "🌙"},
    "2026-03-27": {"title": "Rama Navami", "category": "festival", "icon": "🏹"},
    "2026-03-31": {"title": "Mahavir Jayanti", "category": "festival", "icon": "🕊️"},
    "2026-04-03": {"title": "Good Friday", "category": "festival", "icon": "✝️"},
    "2026-05-01": {"title": "Buddha Purnima", "category": "festival", "icon": "☸️"},
    "2026-05-27": {"title": "Eid-ul-Adha (Bakrid)", "category": "festival", "icon": "🌙"},
    "2026-06-26": {"title": "Muharram", "category": "observance", "icon": "🕌"},
    "2026-08-28": {"title": "Raksha Bandhan", "category": "festival", "icon": "🧵"},
    "2026-09-04": {"title": "Krishna Janmashtami", "category": "festival", "icon": "🦚"},
    "2026-09-14": {"title": "Ganesh Chaturthi", "category": "festival", "icon": "🐘"},
    "2026-09-25": {"title": "Milad-un-Nabi", "category": "festival", "icon": "🌙"},
    "2026-10-11": {"title": "Navratri Begins", "category": "festival", "icon": "🌺"},
    "2026-10-19": {"title": "Maha Navami", "category": "festival", "icon": "🌺"},
    "2026-10-20": {"title": "Dussehra (Vijayadashami)", "category": "festival", "icon": "🏹"},
    "2026-11-08": {"title": "Diwali (Deepavali)", "category": "festival", "icon": "🪔"},
    "2026-11-09": {"title": "Govardhan Puja", "category": "festival", "icon": "🪔"},
    "2026-11-10": {"title": "Bhai Dooj", "category": "festival", "icon": "🪔"},
    "2026-11-15": {"title": "Chhath Puja", "category": "festival", "icon": "☀️"},
    "2026-11-24": {"title": "Guru Nanak Jayanti", "category": "festival", "icon": "☬"},

    # 2027
    "2027-03-06": {"title": "Maha Shivratri", "category": "festival", "icon": "🕉️"},
    "2027-03-22": {"title": "Holi", "category": "festival", "icon": "🎨"},
    "2027-03-10": {"title": "Eid-ul-Fitr", "category": "festival", "icon": "🌙"},
    "2027-03-26": {"title": "Good Friday", "category": "festival", "icon": "✝️"},
    "2027-04-15": {"title": "Rama Navami", "category": "festival", "icon": "🏹"},
    "2027-04-19": {"title": "Mahavir Jayanti", "category": "festival", "icon": "🕊️"},
    "2027-05-20": {"title": "Buddha Purnima", "category": "festival", "icon": "☸️"},
    "2027-05-17": {"title": "Eid-ul-Adha (Bakrid)", "category": "festival", "icon": "🌙"},
    "2027-06-16": {"title": "Muharram", "category": "observance", "icon": "🕌"},
    "2027-08-17": {"title": "Raksha Bandhan", "category": "festival", "icon": "🧵"},
    "2027-08-25": {"title": "Krishna Janmashtami", "category": "festival", "icon": "🦚"},
    "2027-09-04": {"title": "Ganesh Chaturthi", "category": "festival", "icon": "🐘"},
    "2027-10-09": {"title": "Dussehra", "category": "festival", "icon": "🏹"},
    "2027-10-29": {"title": "Diwali (Deepavali)", "category": "festival", "icon": "🪔"},
    "2027-11-14": {"title": "Guru Nanak Jayanti", "category": "festival", "icon": "☬"}
}


def load_user_events():
    if not os.path.exists(EVENTS_FILE):
        return {}
    try:
        with open(EVENTS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_user_events(events):
    os.makedirs(os.path.dirname(EVENTS_FILE), exist_ok=True)
    with open(EVENTS_FILE, "w", encoding="utf-8") as f:
        json.dump(events, f, indent=2, ensure_ascii=False)


def get_events_for_date(date_str):
    """Return all events for YYYY-MM-DD (Indian holidays + user events)"""
    results = []
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return results

    # 1. Check fixed Indian holidays
    key = (dt.month, dt.day)
    if key in FIXED_HOLIDAYS:
        h = FIXED_HOLIDAYS[key]
        results.append({
            "id": f"fest-fixed-{dt.month}-{dt.day}",
            "title": h["title"],
            "category": h["category"],
            "icon": h["icon"],
            "type": "festival",
            "time": "All day",
            "is_user": False
        })

    # 2. Check variable lunar festivals
    if date_str in LUNAR_FESTIVALS:
        h = LUNAR_FESTIVALS[date_str]
        results.append({
            "id": f"fest-lunar-{date_str}",
            "title": h["title"],
            "category": h["category"],
            "icon": h["icon"],
            "type": "festival",
            "time": "All day",
            "is_user": False
        })

    # 3. User custom events
    user_events = load_user_events()
    if date_str in user_events:
        for ev in user_events[date_str]:
            ev_copy = dict(ev)
            ev_copy["type"] = "user"
            ev_copy["is_user"] = True
            if "icon" not in ev_copy:
                ev_copy["icon"] = "📌"
            results.append(ev_copy)

    return results


def get_events_for_month(year, month):
    """Return map of { "YYYY-MM-DD": [events...] } for all dates in the month"""
    month_events = {}
    for day in range(1, 32):
        try:
            dt = datetime(year, month, day)
            date_str = dt.strftime("%Y-%m-%d")
            evs = get_events_for_date(date_str)
            if evs:
                month_events[date_str] = evs
        except ValueError:
            break
    return month_events


def add_user_event(date_str, title, time_str="All day", desc=""):
    events = load_user_events()
    if date_str not in events:
        events[date_str] = []

    ev_id = "ev-" + uuid.uuid4().hex[:8]
    new_ev = {
        "id": ev_id,
        "title": title.strip(),
        "time": time_str.strip() or "All day",
        "desc": desc.strip(),
        "icon": "📌"
    }
    events[date_str].append(new_ev)
    save_user_events(events)
    return new_ev


def edit_user_event(ev_id, new_title, new_time=None, new_desc=None):
    events = load_user_events()
    found = False
    for d, ev_list in events.items():
        for ev in ev_list:
            if ev.get("id") == ev_id:
                if new_title is not None:
                    ev["title"] = new_title.strip()
                if new_time is not None:
                    ev["time"] = new_time.strip() or "All day"
                if new_desc is not None:
                    ev["desc"] = new_desc.strip()
                found = True
                break
        if found:
            break
    if found:
        save_user_events(events)
    return found


def delete_user_event(ev_id):
    events = load_user_events()
    found = False
    for d in list(events.keys()):
        orig_len = len(events[d])
        events[d] = [ev for ev in events[d] if ev.get("id") != ev_id]
        if len(events[d]) != orig_len:
            found = True
        if len(events[d]) == 0:
            del events[d]
    if found:
        save_user_events(events)
    return found


def get_upcoming_agenda():
    now = datetime.now()
    all_evs = get_events_for_month(now.year, now.month)

    agenda = []
    today_str = now.strftime("%Y-%m-%d")
    for d_str in sorted(all_evs.keys()):
        if d_str >= today_str:
            dt = datetime.strptime(d_str, "%Y-%m-%d")
            month_name = dt.strftime("%b")
            day_num = dt.strftime("%d")
            for ev in all_evs[d_str]:
                agenda.append({
                    "date": f"{month_name} {day_num}",
                    "title": ev["title"],
                    "raw_date": d_str,
                    "time": ev.get("time", "All day"),
                    "icon": ev.get("icon", "📌"),
                    "type": ev.get("type", "festival"),
                    "is_user": ev.get("is_user", False)
                })

    agenda_file = os.path.join(CARBON_CONFIG_DIR, "agenda.json")
    try:
        os.makedirs(CARBON_CONFIG_DIR, exist_ok=True)
        with open(agenda_file, "w", encoding="utf-8") as f:
            json.dump(agenda, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

    return agenda


def main():
    parser = argparse.ArgumentParser(description="Carbon Calendar Backend")
    parser.add_argument("--get-month", nargs=2, type=int, metavar=("YEAR", "MONTH"), help="Get all events for year and month (1-12)")
    parser.add_argument("--get-day", type=str, metavar="YYYY-MM-DD", help="Get events for a specific day")
    parser.add_argument("--get-all", action="store_true", help="Dump user events JSON")
    parser.add_argument("--agenda", action="store_true", help="Get upcoming calendar events formatted as agenda items")
    parser.add_argument("--add", nargs=2, metavar=("YYYY-MM-DD", "TITLE"), help="Add custom event")
    parser.add_argument("--time", type=str, default="All day", help="Event time")
    parser.add_argument("--desc", type=str, default="", help="Event description")
    parser.add_argument("--edit", type=str, metavar="EVENT_ID", help="Edit custom event ID")
    parser.add_argument("--title", type=str, help="New title for edit")
    parser.add_argument("--delete", type=str, metavar="EVENT_ID", help="Delete custom event by ID")

    args = parser.parse_args()

    if args.agenda:
        data = get_upcoming_agenda()
        print(json.dumps(data, indent=2, ensure_ascii=False))
    elif args.get_month:
        year, month = args.get_month
        data = get_events_for_month(year, month)
        print(json.dumps(data, indent=2, ensure_ascii=False))
    elif args.get_day:
        data = get_events_for_date(args.get_day)
        print(json.dumps(data, indent=2, ensure_ascii=False))
    elif args.add:
        d, title = args.add
        ev = add_user_event(d, title, args.time, args.desc)
        get_upcoming_agenda()
        print(json.dumps({"status": "ok", "event": ev}))
    elif args.edit:
        ok = edit_user_event(args.edit, args.title, args.time, args.desc)
        if ok:
            get_upcoming_agenda()
        print(json.dumps({"status": "ok" if ok else "not_found"}))
    elif args.delete:
        ok = delete_user_event(args.delete)
        if ok:
            get_upcoming_agenda()
        print(json.dumps({"status": "ok" if ok else "not_found"}))
    elif args.get_all:
        events = load_user_events()
        print(json.dumps(events, indent=2, ensure_ascii=False))
    else:
        now = datetime.now()
        data = get_events_for_month(now.year, now.month)
        print(json.dumps(data, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
