#!/usr/bin/env python3
"""
Carbon Pomodoro & Focus Tracker
A sleek, modern GTK4 + Libadwaita application linked with Carbon Shell's Pomodoro timer,
tasks (~/.config/hypr/carbon-todos.json), and shared state (~/.config/hypr/carbon-pomodoro.json).
Features signature Carbon Lewis Dot splash animation, interactive circular timer,
a floating draggable PiP capsule when closed while running, and transition sound effects.
"""

import os
import sys
import json
import math
import time
import subprocess
import threading
from datetime import datetime, date

# Ensure user site-packages are accessible across environments
user_site = os.path.expanduser(f"~/.local/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages")
if os.path.exists(user_site) and user_site not in sys.path:
    sys.path.insert(0, user_site)

# Ensure instant GTK4 launch without Vulkan GPU enumeration stalls
os.environ.setdefault("GSK_RENDERER", "cairo")

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gtk, Adw, Gio, GLib, Pango, Gdk, PangoCairo

try:
    import cairo
except ImportError:
    try:
        from gi.repository import cairo
    except ImportError as e:
        subprocess.run([
            "notify-send", "-a", "Carbon Pomodoro", "-u", "critical",
            "Missing Cairo Dependency",
            "python-cairo is required to render the Carbon Pomodoro progress ring."
        ], check=False)
        raise e


def _resolve_config_dirs():
    dirs = []
    env_dir = os.environ.get("CARBON_CONFIG_DIR")
    if env_dir:
        dirs.append(os.path.abspath(os.path.expanduser(env_dir)))
    for p in ["~/.config/carbon", "~/.config/hypr"]:
        full = os.path.abspath(os.path.expanduser(p))
        if full not in dirs:
            dirs.append(full)
    return dirs


CONFIG_DIRS = _resolve_config_dirs()


def get_read_path(filename):
    for d in CONFIG_DIRS:
        p = os.path.join(d, filename)
        if os.path.exists(p):
            return p
    for d in CONFIG_DIRS:
        if os.path.isdir(d):
            return os.path.join(d, filename)
    return os.path.join(CONFIG_DIRS[0], filename)


def get_write_paths(filename):
    paths = []
    for d in CONFIG_DIRS:
        if os.path.isdir(d):
            paths.append(os.path.join(d, filename))
    if not paths:
        paths.append(os.path.expanduser(f"~/.config/hypr/{filename}"))
    return paths


POMO_STATE_PATH = get_read_path("carbon-pomodoro.json")
TODOS_PATH = get_read_path("carbon-todos.json")
THEME_JSON_PATH = get_read_path("theme.json")


def load_theme():
    theme = {}
    theme_path = get_read_path("theme.json")
    if os.path.exists(theme_path):
        try:
            with open(theme_path, "r", encoding="utf-8") as f:
                theme = json.load(f)
        except Exception:
            pass
    return {
        "bg": theme.get("bg", "#121214"),
        "accent": theme.get("accent", "#00F0FF"),
        "accentLit": theme.get("accentLit", "#FFFFFF"),
        "fg": theme.get("fg", "#e5e5e5"),
        "fgDim": theme.get("fgDim", "#ababab"),
        "fgFaint": theme.get("fgFaint", "#767676"),
        "isDark": theme.get("isDark", True)
    }


_last_sound_time = 0.0

def play_sound(sound_name="complete"):
    """
    Play a clean, single notification sound using paplay / canberra-gtk-play.
    Debounced so it cannot fire multiple times in rapid succession,
    and runs in a daemon thread so it never leaves zombie defunct processes.
    """
    global _last_sound_time
    now = time.time()
    if now - _last_sound_time < 2.0:
        return
    _last_sound_time = now

    def _worker():
        sound_map = {
            "complete": "/usr/share/sounds/freedesktop/stereo/complete.oga",
            "bell": "/usr/share/sounds/freedesktop/stereo/bell.oga",
        }
        fpath = sound_map.get(sound_name)
        if fpath and os.path.exists(fpath):
            try:
                subprocess.run(
                    ["paplay", fpath],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=3
                )
                return
            except Exception:
                pass
        try:
            subprocess.run(
                ["canberra-gtk-play", "-i", sound_name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3
            )
        except Exception:
            pass

    threading.Thread(target=_worker, daemon=True).start()


# ── Opening Splash Animation ──────────────────────────────────────────────────
class CarbonSplashWidget(Gtk.DrawingArea):
    """
    Signature Carbon Lewis dot opening animation:
    1. Central 'C' with 4 valence dots smoothly fade in.
    2. The 4 dots glide outward toward the 4 window corners with cubic ease-out.
    3. The central 'C' dissolves gracefully.
    4. The dark splash backdrop dissolves smoothly, unveiling the application.
    """
    def __init__(self, accent_hex="#00F0FF", accent_lit_hex="#FFFFFF", bg_hex="#121214", on_finish=None):
        super().__init__()
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.set_can_target(False)
        self.on_finish = on_finish
        self.start_time = None
        self.current_elapsed = 0.0
        self.tick_id = None
        self.is_finished = False

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) == 8:
                return int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, int(h[6:8], 16) / 255.0
            elif len(h) == 6:
                return int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return 0.07, 0.07, 0.08

        self.accent_rgb = hex_to_rgb(accent_hex)
        self.accent_lit_rgb = hex_to_rgb(accent_lit_hex)
        self.bg_rgb = hex_to_rgb(bg_hex)

        self.font_desc = Pango.FontDescription("Valley Sans Bold 44")
        self.pango_layout = None
        self.c_w = 0
        self.c_h = 0

        self.set_draw_func(self.on_draw)
        self.connect("map", self.on_map)

    def on_map(self, widget):
        if not self.is_finished:
            self.start()

    def start(self):
        if self.is_finished:
            return
        self.start_time = None
        self.current_elapsed = 0.0
        self.set_visible(True)
        if self.tick_id is None:
            self.tick_id = self.add_tick_callback(self.on_tick)

    def on_tick(self, widget, frame_clock):
        t = frame_clock.get_frame_time() / 1_000_000.0
        if self.start_time is None:
            self.start_time = t

        elapsed = t - self.start_time
        self.current_elapsed = elapsed
        self.queue_draw()

        if elapsed >= 0.70:
            self.is_finished = True
            self.tick_id = None
            self.set_visible(False)
            if self.on_finish:
                self.on_finish()
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def on_draw(self, area, cr, width, height):
        if self.is_finished:
            return

        elapsed = max(0.0, self.current_elapsed)
        cx = width / 2.0
        cy = height / 2.0

        bg_alpha = 1.0
        if elapsed > 0.46:
            bg_alpha = max(0.0, 1.0 - (elapsed - 0.46) / 0.24)

        br, bg, bb = self.bg_rgb
        cr.set_source_rgba(br, bg, bb, bg_alpha)
        cr.paint()

        if bg_alpha <= 0.001:
            return

        ar, ag, ab = self.accent_rgb
        alr, alg, alb = self.accent_lit_rgb

        c_alpha = 1.0
        if elapsed < 0.12:
            c_alpha = elapsed / 0.12
        elif elapsed > 0.18:
            c_alpha = max(0.0, 1.0 - (elapsed - 0.18) / 0.20)

        if c_alpha > 0.005:
            if self.pango_layout is None:
                self.pango_layout = PangoCairo.create_layout(cr)
                self.pango_layout.set_font_description(self.font_desc)
                self.pango_layout.set_text("C", -1)
                ink, log = self.pango_layout.get_pixel_extents()
                self.c_w = log.width
                self.c_h = log.height
            else:
                PangoCairo.update_layout(cr, self.pango_layout)

            c_scale = 1.0
            if elapsed > 0.18:
                c_scale = 1.0 - 0.10 * min(1.0, (elapsed - 0.18) / 0.20)

            cr.save()
            cr.translate(cx, cy)
            cr.scale(c_scale, c_scale)
            cr.set_source_rgba(alr, alg, alb, c_alpha * bg_alpha)
            cr.move_to(-self.c_w / 2.0, -self.c_h / 2.0)
            PangoCairo.show_layout(cr, self.pango_layout)
            cr.restore()

        r0 = 42.0
        pad = 32.0
        start_dots = [
            (cx, cy - r0),
            (cx + r0, cy),
            (cx, cy + r0),
            (cx - r0, cy)
        ]
        target_dots = [
            (pad, pad),
            (width - pad, pad),
            (width - pad, height - pad),
            (pad, height - pad)
        ]

        t_travel = max(0.0, min(1.0, (elapsed - 0.12) / 0.36))
        ease = 1.0 - math.pow(1.0 - t_travel, 3)

        dot_alpha = 1.0
        if elapsed < 0.12:
            dot_alpha = elapsed / 0.12
        elif t_travel > 0.70:
            dot_alpha = max(0.0, 1.0 - (t_travel - 0.70) / 0.30)

        dot_alpha *= bg_alpha

        if dot_alpha > 0.005:
            for i in range(4):
                sx, sy = start_dots[i]
                tx, ty = target_dots[i]
                cur_x = sx + (tx - sx) * ease
                cur_y = sy + (ty - sy) * ease

                cr.set_source_rgba(ar, ag, ab, 0.35 * dot_alpha)
                cr.arc(cur_x, cur_y, 8.5, 0, 2 * math.pi)
                cr.fill()

                cr.set_source_rgba(alr, alg, alb, dot_alpha)
                cr.arc(cur_x, cur_y, 5.5, 0, 2 * math.pi)
                cr.fill()


# ── Interactive Circular Timer Ring Widget ────────────────────────────────────
class CircularTimerWidget(Gtk.DrawingArea):
    """
    Interactive Cairo Timer Circle:
    - Click anywhere on the circle to Start / Pause
    - Scroll up / down with mouse wheel to adjust minutes (+/- 1 min)
    - Hover glow indication
    - Displays progress arc, pulsing bead, and crisp typography
    """
    def __init__(self, accent_hex="#00F0FF", accent_lit_hex="#FFFFFF", on_click=None, on_scroll=None):
        super().__init__()
        self.set_hexpand(True)
        self.set_vexpand(True)
        self.set_size_request(200, 200)
        self.set_cursor(Gdk.Cursor.new_from_name("pointer", None))

        self.on_click_callback = on_click
        self.on_scroll_callback = on_scroll

        self.progress = 1.0
        self.time_str = "25:00"
        self.phase_str = "FOCUS"
        self.session_str = "Session 1 of 4"
        self.is_running = False
        self.is_hovered = False

        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) >= 6:
                return int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            return 0.0, 0.94, 1.0

        self.accent_rgb = hex_to_rgb(accent_hex)
        self.accent_lit_rgb = hex_to_rgb(accent_lit_hex)

        self.font_time = Pango.FontDescription("Valley Sans Bold 34")
        self.font_phase = Pango.FontDescription("Valley Sans Bold 10")
        self.font_sub = Pango.FontDescription("Valley Sans 10")
        self.set_draw_func(self.on_draw)

        # Click gesture
        click_gesture = Gtk.GestureClick.new()
        click_gesture.connect("released", self._on_gesture_released)
        self.add_controller(click_gesture)

        # Scroll controller
        scroll_controller = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
        scroll_controller.connect("scroll", self._on_scroll_event)
        self.add_controller(scroll_controller)

        # Motion / Hover controller
        motion_controller = Gtk.EventControllerMotion.new()
        motion_controller.connect("enter", self._on_motion_enter)
        motion_controller.connect("leave", self._on_motion_leave)
        self.add_controller(motion_controller)

    def _on_gesture_released(self, gesture, n_press, x, y):
        if self.on_click_callback:
            self.on_click_callback()

    def _on_scroll_event(self, controller, dx, dy):
        if self.on_scroll_callback:
            delta = -1 if dy > 0 else 1
            self.on_scroll_callback(delta)
        return True

    def _on_motion_enter(self, controller, x, y):
        self.is_hovered = True
        self.queue_draw()

    def _on_motion_leave(self, controller):
        self.is_hovered = False
        self.queue_draw()

    def update_state(self, progress, time_str, phase_str, session_str, is_running):
        self.progress = max(0.0, min(1.0, progress))
        self.time_str = time_str
        self.phase_str = phase_str
        self.session_str = session_str
        self.is_running = is_running
        self.queue_draw()

    def on_draw(self, area, cr, width, height):
        cx = width / 2.0
        cy = height / 2.0
        radius = min(cx, cy) - 18.0
        if radius < 30:
            return

        ar, ag, ab = self.accent_rgb
        alr, alg, alb = self.accent_lit_rgb

        if self.is_hovered:
            cr.set_source_rgba(ar, ag, ab, 0.05)
            cr.arc(cx, cy, radius, 0, 2 * math.pi)
            cr.fill()

        cr.set_line_width(7.0)
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.07 if not self.is_hovered else 0.12)
        cr.arc(cx, cy, radius, 0, 2 * math.pi)
        cr.stroke()

        if self.progress > 0.001:
            cr.set_line_cap(cairo.LINE_CAP_ROUND)
            start_angle = -math.pi / 2.0
            end_angle = start_angle + (2 * math.pi * self.progress)

            if self.is_running or self.is_hovered:
                cr.set_line_width(12.0)
                cr.set_source_rgba(ar, ag, ab, 0.25 if self.is_running else 0.15)
                cr.arc(cx, cy, radius, start_angle, end_angle)
                cr.stroke()

            cr.set_line_width(6.5)
            cr.set_source_rgba(ar, ag, ab, 0.95)
            cr.arc(cx, cy, radius, start_angle, end_angle)
            cr.stroke()

            head_x = cx + radius * math.cos(end_angle)
            head_y = cy + radius * math.sin(end_angle)

            cr.set_source_rgba(alr, alg, alb, 1.0)
            cr.arc(head_x, head_y, 4.0, 0, 2 * math.pi)
            cr.fill()

            cr.set_source_rgba(ar, ag, ab, 0.45)
            cr.arc(head_x, head_y, 7.0, 0, 2 * math.pi)
            cr.fill()

        phase_layout = PangoCairo.create_layout(cr)
        phase_layout.set_font_description(self.font_phase)
        phase_layout.set_text(self.phase_str, -1)
        ink, log = phase_layout.get_pixel_extents()
        cr.set_source_rgba(ar, ag, ab, 0.95)
        cr.move_to(cx - log.width / 2.0, cy - 38.0)
        PangoCairo.show_layout(cr, phase_layout)

        time_layout = PangoCairo.create_layout(cr)
        time_layout.set_font_description(self.font_time)
        time_layout.set_text(self.time_str, -1)
        ink, log = time_layout.get_pixel_extents()
        cr.set_source_rgba(alr, alg, alb, 1.0)
        cr.move_to(cx - log.width / 2.0, cy - log.height / 2.0 + 2.0)
        PangoCairo.show_layout(cr, time_layout)

        sub_layout = PangoCairo.create_layout(cr)
        sub_layout.set_font_description(self.font_sub)
        sub_txt = "Click to Start • Scroll to adjust" if (not self.is_running and self.is_hovered) else self.session_str
        sub_layout.set_text(sub_txt, -1)
        ink, log = sub_layout.get_pixel_extents()
        cr.set_source_rgba(0.75, 0.75, 0.78, 0.75 if not self.is_hovered else 0.95)
        cr.move_to(cx - log.width / 2.0, cy + 28.0)
        PangoCairo.show_layout(cr, sub_layout)


# ── Floating Draggable PiP Digits Window ──────────────────────────────────────
class FloatingPipWindow(Gtk.Window):
    """
    Ultra-clean mini floating digits HUD that appears in the center of the screen when the
    main app is closed while a timer is running.
    - Contains ONLY the countdown digits (e.g. 24:59). No pause, no resume, no buttons.
    - Floating & Pinned above all windows in Hyprland.
    - Draggable anywhere by holding SUPER + Left Mouse Button.
    - Double-click or click restores the main focus tracker app.
    """
    def __init__(self, app):
        super().__init__(application=app, title="Carbon Focus Mini")
        self.app = app
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(170, 58)
        self.add_css_class("pip-window")

        root_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        root_box.add_css_class("pip-capsule-digits")
        root_box.set_halign(Gtk.Align.CENTER)
        root_box.set_valign(Gtk.Align.CENTER)

        self.lbl_time = Gtk.Label(label="25:00")
        self.lbl_time.add_css_class("pip-digits-only")
        root_box.append(self.lbl_time)

        click = Gtk.GestureClick.new()
        click.connect("pressed", self.on_clicked)
        root_box.add_controller(click)

        self.set_child(root_box)

    def on_clicked(self, gesture, n_press, x, y):
        if n_press >= 2:
            self.app.restore_main_window()

    def update_display(self, state, todos):
        mode = state.get("mode", "pomo")
        if mode == "pomo":
            rem = state.get("remaining", state.get("workSec", 1500))
            m = rem // 60
            sec = rem % 60
            time_str = f"{m:02d}:{sec:02d}"
        else:
            elapsed = state.get("elapsed", 0)
            m = elapsed // 60
            sec = elapsed % 60
            time_str = f"{m:02d}:{sec:02d}"

        self.lbl_time.set_label(time_str)


# ── Main Pomodoro & Tracker Window ───────────────────────────────────────────
class PomodoroWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Carbon Focus & Tracker")
        self.app = app
        self.set_default_size(980, 610)

        self.theme = load_theme()
        accent = self.theme["accent"]
        accent_lit = self.theme["accentLit"]

        # Intercept window close to minimize to PiP if running
        self.connect("close-request", self.on_close_request)

        # Load state & todos
        self.state = self.load_state()
        self.todos = self.load_todos()

        # Style manager dark scheme
        try:
            sm = Adw.StyleManager.get_default()
            sm.set_color_scheme(Adw.ColorScheme.FORCE_DARK if self.theme.get("isDark", True) else Adw.ColorScheme.FORCE_LIGHT)
        except Exception:
            pass

        # Custom CSS for Carbon Aesthetics
        def hex_to_rgb(h):
            h = h.lstrip("#")
            if len(h) >= 6:
                return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            return 0, 240, 255

        ar, ag, ab = hex_to_rgb(accent)
        css = f"""
        @define-color accent_color {accent};
        @define-color accent_bg_color {accent};

        .suggested-action {{
            background-color: {accent};
            color: #121214;
            font-weight: 700;
            border-radius: 9999px;
            padding: 7px 22px;
            font-size: 13px;
        }}
        .suggested-action:hover {{
            background-color: {accent_lit};
            color: #121214;
        }}
        .circular-btn {{
            border-radius: 9999px;
            padding: 7px 16px;
            font-size: 12px;
            font-weight: 600;
        }}
        .glass-card {{
            background-color: rgba(255, 255, 255, 0.04);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 10px;
            padding: 10px 12px;
        }}
        .glass-card:hover {{
            background-color: rgba(255, 255, 255, 0.06);
            border-color: rgba({ar}, {ag}, {ab}, 0.35);
        }}
        .task-row-active {{
            background-color: rgba({ar}, {ag}, {ab}, 0.12);
            border: 1px solid rgba({ar}, {ag}, {ab}, 0.4);
            border-radius: 8px;
        }}
        .badge-active {{
            background-color: rgba({ar}, {ag}, {ab}, 0.18);
            color: {accent};
            border-radius: 9999px;
            font-weight: bold;
            font-size: 11px;
            padding: 3px 10px;
        }}
        .stat-val {{
            font-family: 'Valley Sans', sans-serif;
            font-size: 18px;
            font-weight: 800;
            color: {accent_lit};
        }}
        .stat-lbl {{
            font-size: 10px;
            color: #888892;
            text-transform: uppercase;
            letter-spacing: 0.6px;
        }}
        .preset-btn {{
            font-size: 11px;
            font-weight: 600;
            padding: 4px 10px;
            border-radius: 6px;
        }}
        .preset-btn-active {{
            background-color: rgba({ar}, {ag}, {ab}, 0.22);
            color: {accent};
            border: 1px solid rgba({ar}, {ag}, {ab}, 0.5);
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 6px;
        }}
        /* PiP Transparent Digits-Only HUD CSS */
        window.pip-window {{
            background-color: transparent;
            background: none;
            border: none;
            box-shadow: none;
        }}
        .pip-capsule-digits {{
            background-color: transparent;
            background: none;
            border: none;
            box-shadow: none;
            padding: 0;
            margin: 0;
        }}
        .pip-digits-only {{
            font-family: 'Valley Sans Bold', sans-serif;
            font-size: 38px;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: 1px;
            text-shadow: 0 2px 12px rgba(0, 0, 0, 0.9), 0 0 24px rgba(0, 0, 0, 0.75);
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER + 50
        )

        # Root Overlay holding Main Content + Splash Animation
        self.root_overlay = Gtk.Overlay()
        outer_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.toast_overlay = Adw.ToastOverlay.new()
        self.toast_overlay.set_child(outer_box)
        self.root_overlay.set_child(self.toast_overlay)

        # Splash Widget covering window with exact Carbon Lewis Dot animation
        self.splash_widget = CarbonSplashWidget(
            accent_hex=accent,
            accent_lit_hex=accent_lit,
            bg_hex=self.theme.get("bg", "#121214"),
            on_finish=self.on_splash_finished
        )
        self.root_overlay.add_overlay(self.splash_widget)
        self.set_content(self.root_overlay)

        # Header Bar
        header = Adw.HeaderBar()
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        title_lbl = Gtk.Label(label="Carbon Focus")
        title_lbl.add_css_class("title")
        subtitle_lbl = Gtk.Label(label="Pomodoro & Study Tracker")
        subtitle_lbl.add_css_class("subtitle")
        title_box.append(title_lbl)
        title_box.append(subtitle_lbl)
        header.set_title_widget(title_box)

        # Mode switch in Header
        mode_switcher = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        mode_switcher.add_css_class("linked")
        self.btn_pomo = Gtk.ToggleButton(label="Pomodoro", active=(self.state.get("mode", "pomo") == "pomo"))
        self.btn_stop = Gtk.ToggleButton(label="Stopwatch", active=(self.state.get("mode") == "stop"))
        self.btn_pomo.connect("toggled", self.on_mode_toggled, "pomo")
        self.btn_stop.connect("toggled", self.on_mode_toggled, "stop")
        mode_switcher.append(self.btn_pomo)
        mode_switcher.append(self.btn_stop)
        header.pack_start(mode_switcher)

        # Active Session Pill & Mini Float button in header
        right_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.phase_badge = Gtk.Label(label="⚡ Focus Session")
        self.phase_badge.add_css_class("badge-active")
        btn_pip_mode = Gtk.Button(label="⤢ Float")
        btn_pip_mode.set_tooltip_text("Minimize into floating PiP capsule (holds on top)")
        btn_pip_mode.add_css_class("flat")
        btn_pip_mode.connect("clicked", lambda b: self.app.show_pip_window())
        right_header_box.append(self.phase_badge)
        right_header_box.append(btn_pip_mode)
        header.pack_end(right_header_box)

        outer_box.append(header)

        # Balanced Main Content Box (2 Columns)
        content_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        content_box.set_hexpand(True)
        content_box.set_vexpand(True)
        content_box.set_margin_top(12)
        content_box.set_margin_bottom(12)
        content_box.set_margin_start(16)
        content_box.set_margin_end(16)
        outer_box.append(content_box)

        # ── Left Column: Timer & Controls ──
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        left_box.set_hexpand(True)
        left_box.set_vexpand(True)
        content_box.append(left_box)

        # Active Task Banner
        self.active_task_banner = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.active_task_banner.add_css_class("glass-card")
        self.task_banner_icon = Gtk.Label(label="🎯")
        self.task_banner_lbl = Gtk.Label(label="Pick a task on the right to focus", hexpand=True, xalign=0)
        self.task_banner_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        self.active_task_banner.append(self.task_banner_icon)
        self.active_task_banner.append(self.task_banner_lbl)
        left_box.append(self.active_task_banner)

        # Interactive Circular Timer Display
        self.timer_widget = CircularTimerWidget(
            accent_hex=accent,
            accent_lit_hex=accent_lit,
            on_click=self.on_timer_clicked,
            on_scroll=self.on_timer_scrolled
        )
        left_box.append(self.timer_widget)

        # Session Dots (4 rounds)
        self.dots_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.dots_box.set_halign(Gtk.Align.CENTER)
        self.cycle_dots = []
        for i in range(4):
            dot = Gtk.Label(label="○")
            dot.add_css_class("dim-label")
            self.cycle_dots.append(dot)
            self.dots_box.append(dot)
        left_box.append(self.dots_box)

        # Primary Controls Row
        controls_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        controls_row.set_halign(Gtk.Align.CENTER)

        self.btn_reset = Gtk.Button(label="Reset")
        self.btn_reset.add_css_class("circular-btn")
        self.btn_reset.connect("clicked", self.on_reset_clicked)

        self.btn_start = Gtk.Button(label="START FOCUS")
        self.btn_start.add_css_class("suggested-action")
        self.btn_start.connect("clicked", self.on_start_pause_clicked)

        self.btn_skip = Gtk.Button(label="Skip Phase")
        self.btn_skip.add_css_class("circular-btn")
        self.btn_skip.connect("clicked", self.on_skip_clicked)

        controls_row.append(self.btn_reset)
        controls_row.append(self.btn_start)
        controls_row.append(self.btn_skip)
        left_box.append(controls_row)

        # Quick Interval Adjuster row (25m / 50m / 5m / 15m)
        self.interval_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.interval_box.set_halign(Gtk.Align.CENTER)

        self.btn_25 = Gtk.Button(label="25m Focus")
        self.btn_25.connect("clicked", self.on_set_work_min, 25)
        self.btn_50 = Gtk.Button(label="50m Focus")
        self.btn_50.connect("clicked", self.on_set_work_min, 50)
        self.btn_5 = Gtk.Button(label="5m Break")
        self.btn_5.connect("clicked", self.on_set_break_min, 5)
        self.btn_15 = Gtk.Button(label="15m Long")
        self.btn_15.connect("clicked", self.on_set_long_break_min, 15)

        for b in (self.btn_25, self.btn_50, self.btn_5, self.btn_15):
            b.add_css_class("preset-btn")
            self.interval_box.append(b)

        left_box.append(self.interval_box)

        # Separator line between columns
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        content_box.append(sep)

        # ── Right Column: Linked Tracker & Tasks ──
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        right_box.set_hexpand(True)
        right_box.set_vexpand(True)
        content_box.append(right_box)

        # Stats Cards Row (3 Cards)
        stats_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        stats_row.set_homogeneous(True)

        card1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card1.add_css_class("glass-card")
        self.lbl_stat_sessions = Gtk.Label(label="0", xalign=0)
        self.lbl_stat_sessions.add_css_class("stat-val")
        lbl1_desc = Gtk.Label(label="COMPLETED TODAY", xalign=0)
        lbl1_desc.add_css_class("stat-lbl")
        card1.append(self.lbl_stat_sessions)
        card1.append(lbl1_desc)
        stats_row.append(card1)

        card2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card2.add_css_class("glass-card")
        self.lbl_stat_time = Gtk.Label(label="0m", xalign=0)
        self.lbl_stat_time.add_css_class("stat-val")
        lbl2_desc = Gtk.Label(label="FOCUS TIME", xalign=0)
        lbl2_desc.add_css_class("stat-lbl")
        card2.append(self.lbl_stat_time)
        card2.append(lbl2_desc)
        stats_row.append(card2)

        card3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        card3.add_css_class("glass-card")
        self.lbl_stat_target = Gtk.Label(label="0 / 8", xalign=0)
        self.lbl_stat_target.add_css_class("stat-val")
        lbl3_desc = Gtk.Label(label="DAILY GOAL", xalign=0)
        lbl3_desc.add_css_class("stat-lbl")
        card3.append(self.lbl_stat_target)
        card3.append(lbl3_desc)
        stats_row.append(card3)

        right_box.append(stats_row)

        # Daily Goal Progress Bar
        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_fraction(0.0)
        right_box.append(self.progress_bar)

        # Task Header & Quick Add Input
        task_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        task_header_lbl = Gtk.Label(label="Study & Focus Tasks", hexpand=True, xalign=0)
        task_header_lbl.add_css_class("heading")
        task_sync_lbl = Gtk.Label(label="Synced with Carbon Shell", xalign=1)
        task_sync_lbl.add_css_class("dim-label")
        task_header_box.append(task_header_lbl)
        task_header_box.append(task_sync_lbl)
        right_box.append(task_header_box)

        add_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.task_entry = Gtk.Entry()
        self.task_entry.set_placeholder_text("Add a new task or focus goal (press Enter)...")
        self.task_entry.set_hexpand(True)
        self.task_entry.connect("activate", self.on_add_task_entered)
        btn_add_task = Gtk.Button(label="Add")
        btn_add_task.connect("clicked", self.on_add_task_entered)
        add_box.append(self.task_entry)
        add_box.append(btn_add_task)
        right_box.append(add_box)

        # Task List (Scrolled)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        self.task_list_box = Gtk.ListBox()
        self.task_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.task_list_box.add_css_class("boxed-list")
        self.task_list_box.connect("row-activated", self.on_task_row_activated)
        scrolled.set_child(self.task_list_box)
        right_box.append(scrolled)

        # Render Task List initially
        self.render_task_list()

        # Re-render UI from initial state
        self.render_all(skip_tasks=True)

        read_path = get_read_path("carbon-pomodoro.json")
        self.last_saved_mtime = os.path.getmtime(read_path) if os.path.exists(read_path) else 0.0

        # Timer tick handler (1 second)
        GLib.timeout_add(1000, self.on_second_tick)

    def on_close_request(self, window):
        """
        When user closes the window:
        - If timer is running -> hide main window & pop up mini floating PiP capsule!
        - If timer is not running (paused) -> hide main window (app stays in background ready for instant Super+P).
        """
        self.save_state()
        self.set_visible(False)
        if self.state.get("running", False):
            self.app.show_pip_window()
        else:
            if hasattr(self.app, "pip_win") and self.app.pip_win:
                self.app.pip_win.hide()
        return True  # Stop destruction, keep window alive in background

    def on_splash_finished(self):
        try:
            self.root_overlay.remove_overlay(self.splash_widget)
        except Exception:
            pass
        self.splash_widget.set_visible(False)
        self.splash_widget.set_can_target(False)

    def show_toast(self, text):
        toast = Adw.Toast.new(text)
        toast.set_timeout(2)
        self.toast_overlay.add_toast(toast)

    # ── State Storage ─────────────────────────────────────────────────────────
    def reload_state_from_disk(self):
        disk_state = self.load_state()
        self.state.update(disk_state)
        self.todos = self.load_todos()

    def load_state(self):
        default_state = {
            "running": False,
            "mode": "pomo",
            "phase": "work",
            "remaining": 25 * 60,
            "elapsed": 0,
            "workSec": 25 * 60,
            "breakSec": 5 * 60,
            "longBreakSec": 15 * 60,
            "cycles": 0,
            "activeTaskId": None,
            "todayDate": str(date.today()),
            "todaySessions": 0,
            "todayFocusSeconds": 0,
            "targetSessions": 8,
            "history": []
        }
        read_path = get_read_path("carbon-pomodoro.json")
        if os.path.exists(read_path):
            try:
                self.last_saved_mtime = os.path.getmtime(read_path)
                with open(read_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    default_state.update(data)
            except Exception:
                pass

        today_str = str(date.today())
        if default_state.get("todayDate") != today_str:
            default_state["todayDate"] = today_str
            default_state["todaySessions"] = 0
            default_state["todayFocusSeconds"] = 0

        return default_state

    def save_state(self):
        latest_mtime = 0.0
        for p in get_write_paths("carbon-pomodoro.json"):
            try:
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "w", encoding="utf-8") as f:
                    json.dump(self.state, f, indent=2)
                latest_mtime = max(latest_mtime, os.path.getmtime(p))
            except Exception as e:
                print(f"Error saving pomodoro state to {p}:", e)
        if latest_mtime > 0.0:
            self.last_saved_mtime = latest_mtime

    def load_todos(self):
        read_path = get_read_path("carbon-todos.json")
        if os.path.exists(read_path):
            try:
                with open(read_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return []

    def save_todos(self):
        for p in get_write_paths("carbon-todos.json"):
            try:
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "w", encoding="utf-8") as f:
                    json.dump(self.todos, f, indent=2)
            except Exception as e:
                print(f"Error saving todos to {p}:", e)

    # ── UI Rendering ──────────────────────────────────────────────────────────
    def fmt_time(self, s):
        m = s // 60
        sec = s % 60
        if m >= 60:
            h = m // 60
            rm = m % 60
            return f"{h:02d}:{rm:02d}:{sec:02d}"
        return f"{m:02d}:{sec:02d}"

    def render_all(self, skip_tasks=False):
        mode = self.state.get("mode", "pomo")
        running = self.state.get("running", False)
        phase = self.state.get("phase", "work")
        cycles = self.state.get("cycles", 0)

        self.btn_pomo.handler_block_by_func(self.on_mode_toggled)
        self.btn_stop.handler_block_by_func(self.on_mode_toggled)
        self.btn_pomo.set_active(mode == "pomo")
        self.btn_stop.set_active(mode == "stop")
        self.btn_pomo.handler_unblock_by_func(self.on_mode_toggled)
        self.btn_stop.handler_unblock_by_func(self.on_mode_toggled)

        if mode == "pomo":
            rem = self.state.get("remaining", self.state.get("workSec", 1500))
            if phase == "work":
                tot = self.state.get("workSec", 1500)
                phase_label = "FOCUS"
            elif phase == "short_break":
                tot = self.state.get("breakSec", 300)
                phase_label = "SHORT BREAK"
            else:
                tot = self.state.get("longBreakSec", 900)
                phase_label = "LONG BREAK"

            current_session = (cycles % 4) + 1
            progress = rem / max(1, tot) if tot > 0 else 0.0
            time_display = self.fmt_time(rem)
            session_display = f"Session {current_session} of 4"
        else:
            current_session = 1
            elapsed = self.state.get("elapsed", 0)
            progress = (elapsed % 60) / 60.0
            time_display = self.fmt_time(elapsed)
            phase_label = "STOPWATCH"
            session_display = f"Elapsed {elapsed}s"

        self.timer_widget.update_state(progress, time_display, phase_label, session_display, running)

        if running:
            self.btn_start.set_label("PAUSE")
            self.btn_start.remove_css_class("suggested-action")
        else:
            self.btn_start.set_label("START FOCUS" if mode == "pomo" else "START TIMER")
            self.btn_start.add_css_class("suggested-action")

        if mode == "stop":
            self.phase_badge.set_label("⏱️ Stopwatch")
        elif phase == "work":
            self.phase_badge.set_label(f"⚡ Focus {current_session}/4")
        elif phase == "short_break":
            self.phase_badge.set_label("☕ Short Break")
        else:
            self.phase_badge.set_label("🌴 Long Break")

        work_m = self.state.get("workSec", 1500) // 60
        break_m = self.state.get("breakSec", 300) // 60
        long_m = self.state.get("longBreakSec", 900) // 60

        def update_btn_style(btn, active):
            btn.remove_css_class("preset-btn-active")
            btn.remove_css_class("preset-btn")
            btn.add_css_class("preset-btn-active" if active else "preset-btn")

        update_btn_style(self.btn_25, phase == "work" and work_m == 25)
        update_btn_style(self.btn_50, phase == "work" and work_m == 50)
        update_btn_style(self.btn_5, phase == "short_break" and break_m == 5)
        update_btn_style(self.btn_15, phase == "long_break" and long_m == 15)

        mod4 = cycles % 4
        for idx, dot in enumerate(self.cycle_dots):
            if idx < mod4:
                dot.set_label("●")
                dot.remove_css_class("dim-label")
            elif idx == mod4 and phase == "work":
                dot.set_label("◉")
                dot.remove_css_class("dim-label")
            else:
                dot.set_label("○")
                dot.add_css_class("dim-label")

        active_id = self.state.get("activeTaskId")
        active_task = next((t for t in self.todos if t.get("id") == active_id), None)
        if active_task:
            self.task_banner_lbl.set_label(f"Focusing on: {active_task.get('text', '')}")
            self.task_banner_icon.set_label("🎯")
        else:
            self.task_banner_lbl.set_label("No active target — Click any task on the right")
            self.task_banner_icon.set_label("💡")

        today_sessions = self.state.get("todaySessions", 0)
        today_sec = self.state.get("todayFocusSeconds", 0)
        target = self.state.get("targetSessions", 8)

        self.lbl_stat_sessions.set_label(str(today_sessions))
        mins = today_sec // 60
        if mins >= 60:
            hrs = mins // 60
            rm = mins % 60
            self.lbl_stat_time.set_label(f"{hrs}h {rm}m")
        else:
            self.lbl_stat_time.set_label(f"{mins}m")
        self.lbl_stat_target.set_label(f"{today_sessions} / {target}")
        self.progress_bar.set_fraction(min(1.0, today_sessions / max(1, target)))

        if not skip_tasks:
            self.render_task_list()

        # Also update floating pip window if open
        if hasattr(self.app, "pip_win") and self.app.pip_win and self.app.pip_win.get_visible():
            self.app.pip_win.update_display(self.state, self.todos)

    def render_task_list(self):
        while True:
            child = self.task_list_box.get_first_child()
            if child is None:
                break
            self.task_list_box.remove(child)

        active_id = self.state.get("activeTaskId")

        if not self.todos:
            empty_row = Gtk.ListBoxRow()
            empty_lbl = Gtk.Label(label="No tasks yet. Type above to add one!", margin_top=14, margin_bottom=14)
            empty_lbl.add_css_class("dim-label")
            empty_row.set_child(empty_lbl)
            self.task_list_box.append(empty_row)
            return

        for idx, item in enumerate(self.todos):
            row = Gtk.ListBoxRow()
            row.item_idx = idx
            row.task_id = item.get("id")

            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            box.set_margin_top(6)
            box.set_margin_bottom(6)
            box.set_margin_start(10)
            box.set_margin_end(10)

            is_active = (item.get("id") == active_id)
            if is_active:
                box.add_css_class("task-row-active")

            check = Gtk.CheckButton()
            check.set_active(item.get("done", False))
            check.connect("toggled", self.on_task_check_toggled, idx)
            box.append(check)

            lbl = Gtk.Label(label=item.get("text", ""), hexpand=True, xalign=0)
            lbl.set_ellipsize(Pango.EllipsizeMode.END)
            if item.get("done", False):
                lbl.add_css_class("dim-label")
            box.append(lbl)

            btn_target = Gtk.Button(label="🎯 Active" if is_active else "Focus")
            btn_target.add_css_class("suggested-action" if is_active else "flat")
            btn_target.connect("clicked", self.on_task_focus_clicked, item.get("id"))
            box.append(btn_target)

            btn_del = Gtk.Button(icon_name="user-trash-symbolic")
            btn_del.add_css_class("flat")
            btn_del.connect("clicked", self.on_task_delete_clicked, idx)
            box.append(btn_del)

            row.set_child(box)
            self.task_list_box.append(row)

    # ── Interactive Handlers ──────────────────────────────────────────────────
    def on_timer_clicked(self):
        self.state["running"] = not self.state.get("running", False)
        self.save_state()
        self.render_all(skip_tasks=True)
        status = "Started" if self.state["running"] else "Paused"
        self.show_toast(f"Timer {status}")

    def on_timer_scrolled(self, delta):
        if self.state.get("mode") == "stop":
            return
        phase = self.state.get("phase", "work")
        if phase == "work":
            curr_min = self.state.get("workSec", 1500) // 60
            new_min = max(1, min(180, curr_min + delta))
            self.state["workSec"] = new_min * 60
            if not self.state.get("running", False):
                self.state["remaining"] = self.state["workSec"]
            self.show_toast(f"Focus time: {new_min} min")
        elif phase == "short_break":
            curr_min = self.state.get("breakSec", 300) // 60
            new_min = max(1, min(60, curr_min + delta))
            self.state["breakSec"] = new_min * 60
            if not self.state.get("running", False):
                self.state["remaining"] = self.state["breakSec"]
            self.show_toast(f"Short break: {new_min} min")
        else:
            curr_min = self.state.get("longBreakSec", 900) // 60
            new_min = max(5, min(90, curr_min + delta))
            self.state["longBreakSec"] = new_min * 60
            if not self.state.get("running", False):
                self.state["remaining"] = self.state["longBreakSec"]
            self.show_toast(f"Long break: {new_min} min")

        self.save_state()
        self.render_all(skip_tasks=True)

    def on_task_row_activated(self, listbox, row):
        task_id = getattr(row, "task_id", None)
        if task_id:
            if self.state.get("activeTaskId") == task_id:
                self.state["activeTaskId"] = None
            else:
                self.state["activeTaskId"] = task_id
            self.save_state()
            self.render_all(skip_tasks=False)

    def on_second_tick(self):
        # Check if external source (e.g. TimerPane in Carbon Shell) modified the state
        try:
            read_path = get_read_path("carbon-pomodoro.json")
            if os.path.exists(read_path):
                mtime = os.path.getmtime(read_path)
                if mtime > getattr(self, "last_saved_mtime", 0.0) + 0.1:
                    with open(read_path, "r", encoding="utf-8") as f:
                        external = json.load(f)
                    self.last_saved_mtime = mtime
                    self.state.update(external)
                    self.render_all(skip_tasks=True)
        except Exception:
            pass

        if not self.state.get("running", False):
            return True

        mode = self.state.get("mode", "pomo")
        if mode == "stop":
            self.state["elapsed"] = self.state.get("elapsed", 0) + 1
        else:
            rem = self.state.get("remaining", self.state.get("workSec", 1500)) - 1
            if rem <= 0:
                self.on_phase_finished()
            else:
                self.state["remaining"] = rem
                if self.state.get("phase") == "work":
                    self.state["todayFocusSeconds"] = self.state.get("todayFocusSeconds", 0) + 1

        self.save_state()
        self.render_all(skip_tasks=True)
        return True

    def on_phase_finished(self):
        phase = self.state.get("phase", "work")
        cycles = self.state.get("cycles", 0)
        today_sessions = self.state.get("todaySessions", 0)

        # Stop timer so it does NOT loop automatically and ring unexpectedly
        self.state["running"] = False

        if phase == "work":
            # Focus period just completed -> BREAK PERIOD READY!
            cycles += 1
            today_sessions += 1
            self.state["cycles"] = cycles
            self.state["todaySessions"] = today_sessions

            active_id = self.state.get("activeTaskId")
            active_task = next((t for t in self.todos if t.get("id") == active_id), None)
            task_name = active_task.get("text") if active_task else "General Focus"

            self.state.setdefault("history", []).append({
                "timestamp": int(time.time()),
                "task": task_name,
                "duration": self.state.get("workSec", 1500)
            })

            # Check if long break (every 4 cycles)
            if cycles % 4 == 0:
                self.state["phase"] = "long_break"
                self.state["remaining"] = self.state.get("longBreakSec", 900)
                msg = "Pomodoro completed! Take a well-deserved 15-minute long break."
            else:
                self.state["phase"] = "short_break"
                self.state["remaining"] = self.state.get("breakSec", 300)
                msg = f"Pomodoro session {((cycles - 1) % 4) + 1} of 4 complete! Time for a 5-minute break."

            # Play gentle break notification sound ONCE
            play_sound("complete")

            subprocess.run([
                "notify-send", "-a", "Carbon Focus",
                "☕ Break Period Ready", msg
            ], check=False)
            self.show_toast("☕ Break Period Ready!")
        else:
            # Break just completed -> FOCUS PERIOD READY!
            self.state["phase"] = "work"
            self.state["remaining"] = self.state.get("workSec", 1500)

            # Play gentle focus notification sound ONCE
            play_sound("bell")

            subprocess.run([
                "notify-send", "-a", "Carbon Focus",
                "⚡ Focus Period Ready", "Break finished! Ready to concentrate on your next session?"
            ], check=False)
            self.show_toast("⚡ Focus Period Ready!")

    def on_start_pause_clicked(self, btn):
        was_running = self.state.get("running", False)
        self.state["running"] = not was_running
        self.save_state()
        self.render_all(skip_tasks=True)

    def on_reset_clicked(self, btn):
        self.state["running"] = False
        mode = self.state.get("mode", "pomo")
        if mode == "stop":
            self.state["elapsed"] = 0
        else:
            self.state["phase"] = "work"
            self.state["remaining"] = self.state.get("workSec", 1500)
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast("Timer Reset")

    def on_skip_clicked(self, btn):
        mode = self.state.get("mode", "pomo")
        if mode == "pomo":
            self.on_phase_finished()
            self.save_state()
            self.render_all(skip_tasks=False)

    def on_mode_toggled(self, btn, target_mode):
        if not btn.get_active():
            return
        if self.state.get("mode") == target_mode:
            return
        self.state["mode"] = target_mode
        self.state["running"] = False
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Switched to {target_mode.capitalize()} mode")

    def on_set_work_min(self, btn, mins):
        self.state["workSec"] = mins * 60
        self.state["phase"] = "work"
        if not self.state.get("running", False):
            self.state["remaining"] = self.state["workSec"]
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Focus set to {mins} min")

    def on_set_break_min(self, btn, mins):
        self.state["breakSec"] = mins * 60
        self.state["phase"] = "short_break"
        if not self.state.get("running", False):
            self.state["remaining"] = self.state["breakSec"]
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Short break set to {mins} min")

    def on_set_long_break_min(self, btn, mins):
        self.state["longBreakSec"] = mins * 60
        self.state["phase"] = "long_break"
        if not self.state.get("running", False):
            self.state["remaining"] = self.state["longBreakSec"]
        self.save_state()
        self.render_all(skip_tasks=True)
        self.show_toast(f"Long break set to {mins} min")

    def on_add_task_entered(self, widget):
        txt = self.task_entry.get_text().strip()
        if not txt:
            return
        new_task = {
            "id": int(time.time() * 1000),
            "text": txt,
            "done": False
        }
        self.todos.append(new_task)
        self.save_todos()
        self.task_entry.set_text("")
        if self.state.get("activeTaskId") is None:
            self.state["activeTaskId"] = new_task["id"]
            self.save_state()
        self.render_all(skip_tasks=False)
        self.show_toast(f"Task added: {txt[:20]}")

    def on_task_check_toggled(self, check, idx):
        if 0 <= idx < len(self.todos):
            self.todos[idx]["done"] = check.get_active()
            self.save_todos()
            self.render_all(skip_tasks=False)

    def on_task_focus_clicked(self, btn, task_id):
        if self.state.get("activeTaskId") == task_id:
            self.state["activeTaskId"] = None
            self.show_toast("Focus target cleared")
        else:
            self.state["activeTaskId"] = task_id
            active_task = next((t for t in self.todos if t.get("id") == task_id), None)
            if active_task:
                self.show_toast(f"Focus target: {active_task.get('text', '')[:20]}")
        self.save_state()
        self.render_all(skip_tasks=False)

    def on_task_delete_clicked(self, btn, idx):
        if 0 <= idx < len(self.todos):
            deleted = self.todos.pop(idx)
            if self.state.get("activeTaskId") == deleted.get("id"):
                self.state["activeTaskId"] = None
                self.save_state()
            self.save_todos()
            self.render_all(skip_tasks=False)
            self.show_toast("Task removed")


# ── Application Main Entrypoint ──────────────────────────────────────────────
class CarbonPomodoroApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="org.carbon.pomodoro",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS
        )
        self.win = None
        self.pip_win = None
        self.connect("startup", self.on_startup)
        self.connect("activate", self.on_activate)

    def on_startup(self, app):
        # Keep application daemon resident in memory so hiding windows doesn't quit the process
        self.hold()

    def on_activate(self, app):
        # If PiP window is visible, hide it and restore main window
        if self.pip_win and self.pip_win.get_visible():
            self.pip_win.hide()

        if not self.win:
            self.win = PomodoroWindow(app)

        self.win.reload_state_from_disk()
        self.win.set_visible(True)
        self.win.present()
        self.win.render_all(skip_tasks=False)

        # Focus window in Hyprland
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "focuswindow", "class:org.carbon.pomodoro"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception:
            pass

    def show_pip_window(self):
        if self.win:
            self.win.set_visible(False)
        if not self.pip_win:
            self.pip_win = FloatingPipWindow(self)
        if self.win:
            self.pip_win.update_display(self.win.state, self.win.todos)
        self.pip_win.set_visible(True)
        self.pip_win.present()

    def restore_main_window(self):
        if self.pip_win:
            self.pip_win.hide()
        if not self.win:
            self.win = PomodoroWindow(self)
        self.win.set_visible(True)
        self.win.present()
        self.win.render_all(skip_tasks=False)
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", "focuswindow", "class:org.carbon.pomodoro"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception:
            pass


def main():
    app = CarbonPomodoroApp()
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
