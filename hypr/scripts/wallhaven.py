#!/usr/bin/env python3
"""
Wallhaven & Local Wallpaper helper for Carbon Shell.
Subcommands:
  search [--sort toplist|date_added|random] [--query <query>] [--page <n>] [--seed <seed>]
  list-local [--query <query>]
  list-favorites
  toggle-favorite <path_or_url>
  download <url> <filename>
  apply <path>
"""

import sys
import os
import re
import json
import time
import hashlib
import urllib.request
import urllib.parse
import subprocess
import shutil
from concurrent.futures import ThreadPoolExecutor

CARBON_CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
LIVE_WALLPAPER_DIR = os.path.expanduser("~/Pictures/Live_Wallpapers")
THUMB_CACHE_DIR = os.path.expanduser("~/.cache/carbon/thumbs")
WALLPAPER_CACHE_DIR = os.path.expanduser("~/.cache/carbon/wallpapers")
FAVORITES_FILE = os.path.join(CARBON_CONFIG_DIR, "wallpaper_favorites.json")
RATE_LIMIT_FILE = os.path.join(os.path.expanduser("~/.cache/carbon"), "wallhaven_last_req.txt")
WALLPAPER_SOURCE_FILE = os.path.join(CARBON_CONFIG_DIR, "carbon-wallpaper-source.json")


DEFAULT_UNSPLASH_KEYS = [
    "5fda81bc223a576f33934dd4dee20cf2217f2777f798c4c0f1e00e377cba5bcc",
    "hl_hWM-KgpMrszqEC8I44CbpTjveujxaWlA7dTNOw3o"
]


def get_wallpaper_config():
    """Retrieve online wallpaper provider settings."""
    cfg = {"provider": "unsplash", "unsplash_access_key": DEFAULT_UNSPLASH_KEYS[0]}
    paths = [
        WALLPAPER_SOURCE_FILE,
        os.path.expanduser("~/.config/hypr/carbon-wallpaper-source.json")
    ]
    for p in paths:
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        if "provider" in data:
                            cfg["provider"] = str(data["provider"]).lower()
                        if "unsplash_access_key" in data and str(data["unsplash_access_key"]).strip():
                            cfg["unsplash_access_key"] = str(data["unsplash_access_key"]).strip()
                        return cfg
            except Exception:
                pass
    return cfg

WP_APPLY_SCRIPT = os.path.join(CARBON_CONFIG_DIR, "scripts", "wp-apply.sh")
if not os.path.isfile(WP_APPLY_SCRIPT):
    WP_APPLY_SCRIPT = os.path.expanduser("~/.config/hypr/scripts/wp-apply.sh")
if not os.path.isfile(WP_APPLY_SCRIPT):
    WP_APPLY_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wp-apply.sh")

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"


def get_configured_dirs():
    """Retrieve list of wallpaper directories to scan."""
    dirs_file = os.path.join(CARBON_CONFIG_DIR, "wallpaper_dirs.json")
    custom_dirs = []
    if os.path.isfile(dirs_file):
        try:
            with open(dirs_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    custom_dirs = [os.path.expanduser(p) for p in data]
                elif isinstance(data, dict) and "dirs" in data:
                    custom_dirs = [os.path.expanduser(p) for p in data["dirs"]]
        except Exception:
            pass
    if not custom_dirs:
        custom_dirs = [WALLPAPER_DIR, LIVE_WALLPAPER_DIR]
    return [d for d in custom_dirs if os.path.isdir(d)]


def get_favorites():
    """Load list of favorite wallpaper identifiers/paths."""
    if os.path.isfile(FAVORITES_FILE):
        try:
            with open(FAVORITES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
        except Exception:
            pass
    return []


def save_favorites(favs):
    """Save favorite wallpaper identifiers/paths."""
    os.makedirs(CARBON_CONFIG_DIR, exist_ok=True)
    try:
        with open(FAVORITES_FILE, "w", encoding="utf-8") as f:
            json.dump(favs, f, indent=2)
    except Exception:
        pass


def toggle_favorite(identifier):
    """Toggle favorite status for an item (by path or URL)."""
    favs = get_favorites()
    is_fav = False
    existing_idx = -1
    for i, item in enumerate(favs):
        target = item if isinstance(item, str) else item.get("path") or item.get("url") or item.get("id")
        if target == identifier:
            existing_idx = i
            break

    if existing_idx >= 0:
        favs.pop(existing_idx)
        is_fav = False
    else:
        favs.append(identifier)
        is_fav = True

    save_favorites(favs)
    print(json.dumps({"success": True, "identifier": identifier, "is_favorite": is_fav}))


def get_thumb_path(file_path, mtime):
    """Return cache path for 256px thumbnail based on hash of path and mtime."""
    hash_key = hashlib.sha1(f"{file_path}:{mtime}".encode("utf-8")).hexdigest()[:16]
    return os.path.join(THUMB_CACHE_DIR, f"{hash_key}.jpg")


def _pil_thumbnail(src, dest, size=256):
    """Fallback thumbnail generator using Pillow (no ImageMagick needed)."""
    try:
        from PIL import Image, ImageOps
        with Image.open(src) as im:
            im = ImageOps.exif_transpose(im)
            im = im.convert("RGB")
            im = ImageOps.fit(im, (size, size), Image.LANCZOS)
            im.save(dest, "JPEG", quality=85)
        return True
    except Exception:
        return False


def ensure_thumbnail(file_path, mtime, is_video=False):
    """Generate 256px thumbnail if not already present in cache."""
    os.makedirs(THUMB_CACHE_DIR, exist_ok=True)
    thumb_path = get_thumb_path(file_path, mtime)
    if os.path.isfile(thumb_path) and os.path.getsize(thumb_path) > 0:
        return f"file://{thumb_path}"

    temp_thumb = f"{thumb_path}.tmp.{os.getpid()}.jpg"
    try:
        if is_video:
            if shutil.which("ffmpeg"):
                cmd = [
                    "ffmpeg", "-y", "-ss", "00:00:00.500", "-i", file_path,
                    "-vframes", "1", "-vf", "scale=256:256:force_original_aspect_ratio=increase,crop=256:256",
                    temp_thumb
                ]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
        else:
            if shutil.which("magick"):
                cmd = [
                    "magick", f"{file_path}[0]",
                    "-strip", "-auto-orient",
                    "-resize", "256x256^", "-gravity", "center", "-extent", "256x256",
                    "-quality", "85", temp_thumb
                ]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
            if not (os.path.isfile(temp_thumb) and os.path.getsize(temp_thumb) > 0):
                _pil_thumbnail(file_path, temp_thumb)

        if os.path.isfile(temp_thumb) and os.path.getsize(temp_thumb) > 0:
            os.replace(temp_thumb, thumb_path)
            return f"file://{thumb_path}"
        else:
            if os.path.isfile(temp_thumb):
                os.remove(temp_thumb)
    except Exception:
        if os.path.isfile(temp_thumb):
            try:
                os.remove(temp_thumb)
            except Exception:
                pass

    return f"file://{file_path}"


def rate_limit_guard():
    """Ensure at least 1.35s between requests to stay safely under 45 req/min."""
    os.makedirs(os.path.dirname(RATE_LIMIT_FILE), exist_ok=True)
    now = time.time()
    try:
        if os.path.isfile(RATE_LIMIT_FILE):
            with open(RATE_LIMIT_FILE, "r") as f:
                last_time = float(f.read().strip())
                elapsed = now - last_time
                if elapsed < 1.35:
                    time.sleep(1.35 - elapsed)
    except Exception:
        pass
    try:
        with open(RATE_LIMIT_FILE, "w") as f:
            f.write(str(time.time()))
    except Exception:
        pass


def search_unsplash(sort="toplist", query="", page=1, access_key=""):
    os.makedirs(WALLPAPER_DIR, exist_ok=True)
    os.makedirs(WALLPAPER_CACHE_DIR, exist_ok=True)

    order_by = "latest" if sort == "date_added" else ("relevant" if query else "popular")

    candidate_keys = []
    if access_key and access_key.strip():
        candidate_keys.append(access_key.strip())
    for k in DEFAULT_UNSPLASH_KEYS:
        if k not in candidate_keys:
            candidate_keys.append(k)

    if query and query.strip():
        url = f"https://api.unsplash.com/search/photos?query={urllib.parse.quote(query.strip())}&page={page}&per_page=20&orientation=landscape&order_by={order_by}"
    else:
        url = f"https://api.unsplash.com/topics/wallpapers/photos?page={page}&per_page=20&orientation=landscape&order_by={order_by}"

    def fetch_url(target_url, key):
        cmd = ["curl", "-s", "--max-time", "12", "-H", f"Authorization: Client-ID {key}", "-H", "Accept-Version: v1", target_url]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=14)
        if res.returncode == 0 and res.stdout:
            try:
                parsed = json.loads(res.stdout.decode("utf-8", errors="ignore"))
                if isinstance(parsed, (dict, list)) and not (isinstance(parsed, dict) and "errors" in parsed):
                    return parsed
            except Exception:
                pass
        return None

    data = None
    for k in candidate_keys:
        try:
            data = fetch_url(url, k)
            if data:
                break
        except Exception:
            continue

    if not data or (isinstance(data, dict) and "errors" in data):
        # Graceful fallback: If Unsplash quota is exhausted or unreachable, provide Wallhaven wallpapers
        try:
            return search_wallhaven(sort=sort, query=query, page=page)
        except Exception:
            pass

    fav_list = set()
    for item in get_favorites():
        ident = item if isinstance(item, str) else item.get("path") or item.get("url") or item.get("id")
        if ident:
            fav_list.add(ident)

    if data and not (isinstance(data, dict) and "errors" in data):
        raw_items = []
        total = 18000
        last_page = 900
        if isinstance(data, dict) and "results" in data:
            raw_items = data.get("results", [])
            total = data.get("total", len(raw_items))
            last_page = data.get("total_pages", 1)
        elif isinstance(data, list):
            raw_items = data
            total = 18000
            last_page = 900

        items = []
        for photo in raw_items:
            photo_id = str(photo.get("id", ""))
            if not photo_id:
                continue
            width = photo.get("width", 0)
            height = photo.get("height", 0)
            res = f"{width}x{height}" if width and height else "HD"

            urls = photo.get("urls", {})
            thumb_url = urls.get("small") or urls.get("regular") or urls.get("thumb") or ""
            full_url = urls.get("full") or (urls.get("raw", "") + "&q=85&fm=jpg") or thumb_url
            filename = f"unsplash-{photo_id}.jpg"

            cached_wall = os.path.join(WALLPAPER_DIR, filename)
            alt_cached = os.path.join(WALLPAPER_CACHE_DIR, filename)
            exists = os.path.isfile(cached_wall) or os.path.isfile(alt_cached)

            is_fav = (photo_id in fav_list) or (full_url in fav_list) or (filename in fav_list)

            # Category
            category = "wallpapers"
            topic_subs = photo.get("topic_submissions", {})
            if isinstance(topic_subs, dict) and topic_subs:
                for tname in topic_subs.keys():
                    if tname:
                        category = tname
                        break

            # Title
            user_info = photo.get("user", {})
            user_name = user_info.get("name") or user_info.get("username") or ""
            desc = photo.get("description") or photo.get("alt_description") or ""
            if desc:
                name = desc.strip()[:42]
                name = name[0].upper() + name[1:]
            elif user_name:
                name = f"Photo by {user_name}"
            else:
                name = f"Unsplash #{photo_id}"

            items.append({
                "id": photo_id,
                "resolution": res,
                "category": category,
                "thumb": thumb_url,
                "url": full_url,
                "filename": filename,
                "name": name,
                "is_local": False,
                "is_favorite": is_fav,
                "exists": exists
            })

        print(json.dumps({
            "success": True,
            "data": items,
            "meta": {
                "current_page": page,
                "last_page": last_page,
                "total": total
            }
        }))
        return

    # Offline fallback
    cached_items = []
    valid_exts = {".jpg", ".jpeg", ".png", ".webp"}
    try:
        for fname in os.listdir(WALLPAPER_DIR):
            if not (fname.startswith("unsplash-") or fname.startswith("wallhaven-")):
                continue
            ext = os.path.splitext(fname)[1].lower()
            if ext not in valid_exts:
                continue
            full_path = os.path.join(WALLPAPER_DIR, fname)
            if not os.path.isfile(full_path):
                continue
            if query and query.strip().lower() not in fname.lower():
                continue

            mtime = os.path.getmtime(full_path)
            thumb_url = ensure_thumbnail(full_path, mtime, is_video=False)

            res = "HD"
            m = re.search(r"(\d{3,5}x\d{3,5})", fname)
            if m:
                res = m.group(1)

            is_fav = (fname in fav_list) or (full_path in fav_list)

            src_type = "unsplash" if fname.startswith("unsplash-") else "wallhaven"
            cached_items.append({
                "id": fname,
                "resolution": res,
                "category": f"{src_type} (cached)",
                "thumb": thumb_url,
                "url": f"file://{full_path}",
                "path": full_path,
                "filename": fname,
                "name": fname.replace("unsplash-", "").replace("wallhaven-", "").rsplit(".", 1)[0],
                "mtime": mtime,
                "is_local": True,
                "is_favorite": is_fav,
                "exists": True
            })
        cached_items.sort(key=lambda x: x["mtime"], reverse=True)
    except Exception:
        pass

    print(json.dumps({
        "success": True,
        "data": cached_items,
        "offline_fallback": True,
        "meta": {"current_page": 1, "last_page": 1, "total": len(cached_items)},
        "notice": "Online Unsplash service unavailable. Showing downloaded wallpapers.",
        "error": "Failed to fetch from Unsplash"
    }))


def search_wallhaven(sort="toplist", query="", page=1, seed=None):
    os.makedirs(WALLPAPER_DIR, exist_ok=True)
    os.makedirs(WALLPAPER_CACHE_DIR, exist_ok=True)

    params = {
        "purity": "100",  # SFW
        "sorting": sort,
        "ratios": "landscape",
        "page": str(page),
    }
    if query and query.strip():
        params["q"] = query.strip()
    if seed and sort == "random":
        params["seed"] = seed

    url = f"https://wallhaven.cc/api/v1/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

    rate_limit_guard()

    fav_list = set()
    for item in get_favorites():
        ident = item if isinstance(item, str) else item.get("path") or item.get("url") or item.get("id")
        if ident:
            fav_list.add(ident)

    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            data = json.loads(response.read().decode("utf-8"))
            meta = data.get("meta", {})
            items = []
            for entry in data.get("data", []):
                wall_id = entry.get("id")
                res = entry.get("resolution", "HD")
                full_path = entry.get("path")
                file_type = entry.get("file_type", "image/jpeg")
                ext = "png" if "png" in file_type else "jpg"
                filename = f"wallhaven-{wall_id}.{ext}"

                cached_wall = os.path.join(WALLPAPER_DIR, filename)
                alt_cached = os.path.join(WALLPAPER_CACHE_DIR, filename)
                exists = os.path.isfile(cached_wall) or os.path.isfile(alt_cached)

                thumbs = entry.get("thumbs", {})
                thumb_url = thumbs.get("large") or thumbs.get("small") or full_path

                is_fav = (str(wall_id) in fav_list) or (full_path in fav_list) or (filename in fav_list)

                items.append({
                    "id": str(wall_id),
                    "resolution": res,
                    "category": entry.get("category", "general"),
                    "thumb": thumb_url,
                    "url": full_path,
                    "filename": filename,
                    "name": f"Wallhaven #{wall_id}",
                    "is_local": False,
                    "is_favorite": is_fav,
                    "exists": exists
                })

            print(json.dumps({
                "success": True,
                "data": items,
                "meta": {
                    "current_page": meta.get("current_page", page),
                    "last_page": meta.get("last_page", 1),
                    "total": meta.get("total", len(items)),
                    "seed": meta.get("seed", seed)
                }
            }))
    except Exception as e:
        cached_items = []
        valid_exts = {".jpg", ".jpeg", ".png", ".webp"}
        try:
            for fname in os.listdir(WALLPAPER_DIR):
                if not fname.startswith("wallhaven-"):
                    continue
                ext = os.path.splitext(fname)[1].lower()
                if ext not in valid_exts:
                    continue
                full_path = os.path.join(WALLPAPER_DIR, fname)
                if not os.path.isfile(full_path):
                    continue
                if query and query.strip().lower() not in fname.lower():
                    continue

                mtime = os.path.getmtime(full_path)
                thumb_url = ensure_thumbnail(full_path, mtime, is_video=False)

                res = "HD"
                m = re.search(r"(\d{3,5}x\d{3,5})", fname)
                if m:
                    res = m.group(1)

                is_fav = (fname in fav_list) or (full_path in fav_list)

                cached_items.append({
                    "id": fname,
                    "resolution": res,
                    "category": "wallhaven (cached)",
                    "thumb": thumb_url,
                    "url": f"file://{full_path}",
                    "path": full_path,
                    "filename": fname,
                    "name": fname.replace("wallhaven-", "").rsplit(".", 1)[0],
                    "mtime": mtime,
                    "is_local": True,
                    "is_favorite": is_fav,
                    "exists": True
                })
            cached_items.sort(key=lambda x: x["mtime"], reverse=True)
        except Exception:
            pass

        print(json.dumps({
            "success": True,
            "data": cached_items,
            "offline_fallback": True,
            "meta": {"current_page": 1, "last_page": 1, "total": len(cached_items)},
            "notice": "Online Wallhaven service unavailable. Showing your downloaded library.",
            "error": str(e)
        }))


def search(sort="toplist", query="", page=1, seed=None, client=None, provider=None):
    if provider is None:
        if client == "picker":
            cfg = get_wallpaper_config()
            provider = cfg.get("provider", "unsplash")
            access_key = cfg.get("unsplash_access_key", "")
        else:
            # Default for Vanish Mode or other callers
            provider = "wallhaven"
            access_key = ""
    else:
        cfg = get_wallpaper_config()
        access_key = cfg.get("unsplash_access_key", "")

    if provider.lower() == "unsplash":
        search_unsplash(sort=sort, query=query, page=page, access_key=access_key)
    else:
        search_wallhaven(sort=sort, query=query, page=page, seed=seed)


def list_local(query="", live_only=False):
    valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".gif", ".mp4", ".mkv", ".webm"}
    video_exts = {".mp4", ".mkv", ".webm"}
    dirs = get_configured_dirs()

    fav_list = set()
    for item in get_favorites():
        ident = item if isinstance(item, str) else item.get("path") or item.get("url") or item.get("id")
        if ident:
            fav_list.add(ident)

    found_files = []
    for d in dirs:
        for root_dir, _, files in os.walk(d):
            for fname in files:
                ext = os.path.splitext(fname)[1].lower()
                if ext in valid_exts:
                    if live_only and ext not in video_exts:
                        continue
                    full_path = os.path.join(root_dir, fname)
                    if os.path.isfile(full_path):
                        if query and query.strip().lower() not in fname.lower():
                            continue
                        try:
                            mtime = os.path.getmtime(full_path)
                        except OSError:
                            mtime = 0
                        found_files.append((full_path, fname, ext, mtime))

    found_files.sort(key=lambda x: x[3], reverse=True)

    entries = []
    to_thumb = [(p, mt, ext in video_exts) for p, fn, ext, mt in found_files[:40]]
    with ThreadPoolExecutor(max_workers=8) as executor:
        thumb_results = list(executor.map(lambda args: ensure_thumbnail(*args), to_thumb))

    for i, (full_path, fname, ext, mtime) in enumerate(found_files):
        is_video = ext in video_exts
        if i < len(thumb_results):
            thumb_url = thumb_results[i]
        else:
            cached_p = get_thumb_path(full_path, mtime)
            thumb_url = f"file://{cached_p}" if os.path.isfile(cached_p) else f"file://{full_path}"

        res = "LIVE" if is_video else "HD"
        m = re.search(r"(\d{3,5}x\d{3,5})", fname)
        if m:
            res = m.group(1)

        is_fav = (full_path in fav_list) or (fname in fav_list)

        entries.append({
            "id": fname,
            "resolution": res,
            "category": "live" if is_video else "local",
            "thumb": thumb_url,
            "url": f"file://{full_path}",
            "path": full_path,
            "filename": fname,
            "name": os.path.splitext(fname)[0],
            "mtime": mtime,
            "is_local": True,
            "is_live": is_video,
            "is_favorite": is_fav,
            "exists": True
        })

    print(json.dumps({"success": True, "data": entries, "total": len(entries)}))


def list_favorites():
    """Return all favorites that exist locally, plus remote ones."""
    favs = get_favorites()
    entries = []
    valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".gif", ".mp4", ".mkv", ".webm"}
    video_exts = {".mp4", ".mkv", ".webm"}

    for item in favs:
        p = item if isinstance(item, str) else item.get("path") or item.get("url")
        if not p:
            continue
        if os.path.isfile(p):
            fname = os.path.basename(p)
            ext = os.path.splitext(fname)[1].lower()
            mtime = os.path.getmtime(p)
            is_video = ext in video_exts
            thumb = ensure_thumbnail(p, mtime, is_video)
            res = "LIVE" if is_video else "HD"
            m = re.search(r"(\d{3,5}x\d{3,5})", fname)
            if m:
                res = m.group(1)
            entries.append({
                "id": fname,
                "resolution": res,
                "category": "favorite",
                "thumb": thumb,
                "url": f"file://{p}",
                "path": p,
                "filename": fname,
                "name": os.path.splitext(fname)[0],
                "mtime": mtime,
                "is_local": True,
                "is_live": is_video,
                "is_favorite": True,
                "exists": True
            })
        elif isinstance(item, dict):
            item["is_favorite"] = True
            entries.append(item)

    print(json.dumps({"success": True, "data": entries, "total": len(entries)}))


def download(url, filename):
    os.makedirs(WALLPAPER_DIR, exist_ok=True)
    os.makedirs(WALLPAPER_CACHE_DIR, exist_ok=True)
    dest_path = os.path.join(WALLPAPER_DIR, os.path.basename(filename))

    downloaded = False
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as response, open(dest_path, "wb") as out_file:
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                out_file.write(chunk)
        if os.path.isfile(dest_path) and os.path.getsize(dest_path) > 1000:
            downloaded = True
    except Exception:
        pass

    if not downloaded:
        try:
            cmd = ["curl", "-s", "-L", "--max-time", "40", "-o", dest_path, url]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
            if os.path.isfile(dest_path) and os.path.getsize(dest_path) > 1000:
                downloaded = True
        except Exception:
            pass

    if downloaded:
        try:
            mtime = os.path.getmtime(dest_path)
            ensure_thumbnail(dest_path, mtime, is_video=False)
        except Exception:
            pass

        if os.path.isfile(WP_APPLY_SCRIPT):
            subprocess.run(["sh", WP_APPLY_SCRIPT, dest_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

        print(json.dumps({"success": True, "path": dest_path}))
    else:
        print(json.dumps({"success": False, "error": "Failed to download image"}))


def apply_local(path):
    if os.path.isfile(path) and os.path.isfile(WP_APPLY_SCRIPT):
        subprocess.run(["sh", WP_APPLY_SCRIPT, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        print(json.dumps({"success": True, "path": path}))
    else:
        print(json.dumps({"success": False, "error": "File not found"}))


def main():
    if len(sys.argv) < 2:
        print("Usage: wallhaven.py <search|list-local|list-live|list-favorites|toggle-favorite|download|apply> [args...]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "search":
        sort = "toplist"
        query = ""
        page = 1
        seed = None
        client = None
        provider = None

        i = 2
        while i < len(sys.argv):
            if sys.argv[i] == "--sort" and i + 1 < len(sys.argv):
                sort = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--query" and i + 1 < len(sys.argv):
                query = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--page" and i + 1 < len(sys.argv):
                try:
                    page = int(sys.argv[i + 1])
                except ValueError:
                    page = 1
                i += 2
            elif sys.argv[i] == "--seed" and i + 1 < len(sys.argv):
                seed = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--client" and i + 1 < len(sys.argv):
                client = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--provider" and i + 1 < len(sys.argv):
                provider = sys.argv[i + 1]
                i += 2
            else:
                i += 1
        search(sort=sort, query=query, page=page, seed=seed, client=client, provider=provider)

    elif cmd in ("list-local", "local"):
        query = ""
        if len(sys.argv) > 2 and sys.argv[2] == "--query" and len(sys.argv) > 3:
            query = sys.argv[3]
        elif len(sys.argv) > 2:
            query = sys.argv[2]
        list_local(query=query)

    elif cmd in ("list-live", "live"):
        query = ""
        if len(sys.argv) > 2 and sys.argv[2] == "--query" and len(sys.argv) > 3:
            query = sys.argv[3]
        elif len(sys.argv) > 2:
            query = sys.argv[2]
        list_local(query=query, live_only=True)

    elif cmd in ("list-favorites", "favorites"):
        list_favorites()

    elif cmd in ("toggle-favorite", "fav"):
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing identifier"}))
            sys.exit(1)
        toggle_favorite(sys.argv[2])

    elif cmd == "download":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Missing url or filename"}))
            sys.exit(1)
        download(sys.argv[2], sys.argv[3])

    elif cmd == "apply":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing path"}))
            sys.exit(1)
        apply_local(sys.argv[2])

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()

