#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess
import threading
import time
import json
from pathlib import Path

os.environ["GSK_RENDERER"] = "cairo"

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Gio

REPO_DIR = Path(__file__).resolve().parent
DRY_RUN = "--dry-run" in sys.argv

if DRY_RUN:
    SANDBOX = Path("/tmp/carbon-sandbox")
    CONFIG_DIR = SANDBOX / "carbon"
    HYPR_DIR = SANDBOX / "hypr"
    QUICKSHELL_DIR = SANDBOX / "quickshell"
    BIN_DIR = SANDBOX / "bin"
    SYSTEMD_DIR = SANDBOX / "systemd"
    FONTS_DIR = SANDBOX / "fonts"
    WP_DIR = SANDBOX / "wallpapers"
else:
    CONFIG_DIR = Path(os.environ.get("CARBON_CONFIG_DIR", Path.home() / ".config/carbon"))
    HYPR_DIR = Path.home() / ".config/hypr"
    QUICKSHELL_DIR = Path.home() / ".local/share/quickshell/carbon"
    BIN_DIR = Path.home() / ".local/bin"
    SYSTEMD_DIR = Path.home() / ".config/systemd/user"
    FONTS_DIR = Path.home() / ".local/share/fonts"
    WP_DIR = Path.home() / "Pictures/Wallpapers"

DEPS = [
    ("hyprland", "Hyprland compositor", True),
    ("quickshell", "Quickshell UI framework", True),
    ("python3", "Python runtime", True),
    ("playerctl", "Media controls", True),
    ("brightnessctl", "Display brightness", True),
    ("grim", "Screen capture backend", True),
    ("slurp", "Region selector", True),
    ("socat", "IPC socket communication", True),
    ("jq", "JSON parser", True),
    ("fastfetch", "System information", False),
    ("cava", "Audio visualizer", False),
    ("pipewire", "Audio server", True),
    ("wireplumber", "Session manager", True),
]

def check_m3shapes():
    for p in ["/usr/lib/qt6/qml", "/usr/lib64/qt6/qml", str(Path.home() / ".local/lib/qt6/qml")]:
        if (Path(p) / "M3Shapes/qmldir").exists():
            return True
    return False

def check_py_module(mod):
    try:
        __import__(mod)
        return True
    except ImportError:
        return False

def detect_distro():
    p = Path("/etc/os-release")
    if p.exists():
        for line in p.read_text().splitlines():
            if line.startswith("ID="):
                return line.split("=", 1)[1].strip('"').lower()
    return "unknown"


class InstallerWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        title = "Carbon Shell Installer" + (" (Dry-Run Sandbox)" if DRY_RUN else "")
        super().__init__(application=app, title=title)
        self.set_default_size(780, 580)
        self.set_size_request(600, 480)

        self.keybind_mode = "keep" if (HYPR_DIR / "hyprland.conf").exists() else "carbon"
        self.shell_mode = "minimal_notch"
        self.set_wallpaper = True
        self.is_installing = False

        self.toast_overlay = Adw.ToastOverlay()
        self.set_content(self.toast_overlay)

        self.view_stack = Adw.ViewStack()
        
        self.toolbar_view = Adw.ToolbarView()
        self.header_bar = Adw.HeaderBar()
        self.toolbar_view.add_top_bar(self.header_bar)
        self.toolbar_view.set_content(self.view_stack)
        self.toast_overlay.set_child(self.toolbar_view)

        self._build_welcome_page()
        self._build_deps_page()
        self._build_profile_page()
        self._build_mode_page()
        self._build_install_page()
        self._build_finish_page()

        self.view_stack.set_visible_child_name("welcome")

    def _build_welcome_page(self):
        page = Adw.StatusPage(
            title="Carbon Shell",
            description="A modular, dynamic Wayland desktop shell designed for Hyprland.",
            icon_name="preferences-desktop-display-symbolic"
        )
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_halign(Gtk.Align.CENTER)

        features_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        features_card.set_margin_top(8)
        features_card.set_margin_bottom(16)

        for icon, text in [
            ("view-paged-symbolic", "Adaptive Islands: Minimal Notch, Classic Notch, Pill Bar, and Vanish Hub"),
            ("color-select-symbolic", "Dynamic Material You palette extracted directly from wallpapers"),
            ("preferences-system-windows-symbolic", "Non-destructive Hyprland integration with isolated shell keybindings")
        ]:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            img = Gtk.Image.new_from_icon_name(icon)
            img.set_pixel_size(18)
            lbl = Gtk.Label(label=text, xalign=0)
            lbl.add_css_class("dim-label")
            row.append(img)
            row.append(lbl)
            features_card.append(row)

        box.append(features_card)

        btn = Gtk.Button(label="Begin Setup")
        btn.add_css_class("suggested-action")
        btn.add_css_class("pill")
        btn.set_size_request(180, 44)
        btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("deps"))
        box.append(btn)

        page.set_child(box)
        self.view_stack.add_named(page, "welcome")

    def _build_deps_page(self):
        clamp = Adw.Clamp(maximum_size=680)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(16)
        box.set_margin_end(16)

        header = Gtk.Label(label="System Compatibility Check", xalign=0)
        header.add_css_class("title-2")
        desc = Gtk.Label(label=f"Detected distribution: {detect_distro().title()}. Verifying required packages and runtimes.", xalign=0)
        desc.add_css_class("dim-label")
        box.append(header)
        box.append(desc)

        group = Adw.PreferencesGroup()
        self.dep_rows = []

        for cmd, label, required in DEPS:
            row = Adw.ActionRow(title=cmd, subtitle=label)
            ok = shutil.which(cmd) is not None
            badge = Gtk.Label(label="Installed" if ok else ("Missing" if required else "Optional"))
            badge.add_css_class("accent" if ok else ("error" if required else "dim-label"))
            row.add_suffix(badge)
            group.add(row)

        py_row = Adw.ActionRow(title="python-pillow & python-gobject", subtitle="Theme generator & GUI libraries")
        py_ok = check_py_module("PIL") and check_py_module("gi")
        py_badge = Gtk.Label(label="Installed" if py_ok else "Missing")
        py_badge.add_css_class("accent" if py_ok else "error")
        py_row.add_suffix(py_badge)
        group.add(py_row)

        m3_row = Adw.ActionRow(title="qt6-m3shapes", subtitle="Material 3 shape renderer for Quickshell")
        m3_ok = check_m3shapes()
        m3_badge = Gtk.Label(label="Installed" if m3_ok else "Missing")
        m3_badge.add_css_class("accent" if m3_ok else "dim-label")
        m3_row.add_suffix(m3_badge)
        group.add(m3_row)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_propagate_natural_height(True)
        scrolled.set_min_content_height(240)
        scrolled.set_child(group)
        box.append(scrolled)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.END)
        back_btn = Gtk.Button(label="Back")
        back_btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("welcome"))
        next_btn = Gtk.Button(label="Continue")
        next_btn.add_css_class("suggested-action")
        next_btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("profile"))
        btn_box.append(back_btn)
        btn_box.append(next_btn)
        box.append(btn_box)

        clamp.set_child(box)
        self.view_stack.add_named(clamp, "deps")

    def _build_profile_page(self):
        clamp = Adw.Clamp(maximum_size=680)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(16)
        box.set_margin_end(16)

        header = Gtk.Label(label="Keybindings & Integration", xalign=0)
        header.add_css_class("title-2")
        desc = Gtk.Label(label="Choose how Carbon keybindings integrate with your current Hyprland configuration.", xalign=0)
        desc.add_css_class("dim-label")
        box.append(header)
        box.append(desc)

        group = Adw.PreferencesGroup()
        row_keep = Adw.ActionRow(
            title="Keep Existing Keybindings (Recommended)",
            subtitle="Preserves all your current terminal, workspace, and window movement shortcuts. Only maps shell triggers (Super+C, Super+Tab, Super+Space, Super+N, Super+T)."
        )
        radio_keep = Gtk.CheckButton()
        radio_keep.set_active(self.keybind_mode == "keep")
        row_keep.add_prefix(radio_keep)
        row_keep.set_activatable_widget(radio_keep)

        row_full = Adw.ActionRow(
            title="Full Carbon Keybindings",
            subtitle="Complete standalone desktop layout with Super+Return for terminal, Super+1..9 for workspaces, and WASD/arrow window management."
        )
        radio_full = Gtk.CheckButton.new_with_label("")
        radio_full.set_group(radio_keep)
        radio_full.set_active(self.keybind_mode == "carbon")
        row_full.add_prefix(radio_full)
        row_full.set_activatable_widget(radio_full)

        def on_toggle_keep(btn):
            if btn.get_active():
                self.keybind_mode = "keep"

        def on_toggle_full(btn):
            if btn.get_active():
                self.keybind_mode = "carbon"

        radio_keep.connect("toggled", on_toggle_keep)
        radio_full.connect("toggled", on_toggle_full)

        group.add(row_keep)
        group.add(row_full)
        box.append(group)

        hypr_status = Adw.PreferencesGroup(title="Hyprland Config Safety")
        hypr_row = Adw.ActionRow(
            title="Non-Destructive Sourcing",
            subtitle="Your ~/.config/hypr/hyprland.conf is backed up. Carbon adds a single safe include without altering your existing rules."
        )
        hypr_status.add(hypr_row)
        box.append(hypr_status)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.END)
        back_btn = Gtk.Button(label="Back")
        back_btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("deps"))
        next_btn = Gtk.Button(label="Next")
        next_btn.add_css_class("suggested-action")
        next_btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("mode"))
        btn_box.append(back_btn)
        btn_box.append(next_btn)
        box.append(btn_box)

        clamp.set_child(box)
        self.view_stack.add_named(clamp, "profile")

    def _build_mode_page(self):
        clamp = Adw.Clamp(maximum_size=680)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(16)
        box.set_margin_end(16)

        header = Gtk.Label(label="Select Initial Shell Mode", xalign=0)
        header.add_css_class("title-2")
        desc = Gtk.Label(label="You can seamlessly switch modes anytime via Super+C in Carbon Settings.", xalign=0)
        desc.add_css_class("dim-label")
        box.append(header)
        box.append(desc)

        group = Adw.PreferencesGroup()
        modes = [
            ("minimal_notch", "Minimal Island (Tide)", "Dynamic top island notch with clock, media, and status controls"),
            ("notch", "Carbon Notch", "Centered dynamic island with integrated workspace and dashboard triggers"),
            ("pill", "Pill Bar", "Floating horizontal pill with system tray and media integration"),
            ("vanish", "Vanish Hub", "Edge-hidden satellite launcher that appears on demand"),
        ]

        first_radio = None
        for m_id, title, subt in modes:
            row = Adw.ActionRow(title=title, subtitle=subt)
            if first_radio is None:
                radio = Gtk.CheckButton()
                first_radio = radio
            else:
                radio = Gtk.CheckButton.new_with_label("")
                radio.set_group(first_radio)

            radio.set_active(self.shell_mode == m_id)
            row.add_prefix(radio)
            row.set_activatable_widget(radio)

            def make_handler(mode_val):
                return lambda btn: setattr(self, "shell_mode", mode_val) if btn.get_active() else None

            radio.connect("toggled", make_handler(m_id))
            group.add(row)

        box.append(group)

        wp_group = Adw.PreferencesGroup()
        wp_row = Adw.ActionRow(
            title="Configure Default Wallpaper & Theme",
            subtitle="Deploys default wallpaper asset and extracts dynamic Material You palette"
        )
        wp_switch = Gtk.Switch()
        wp_switch.set_active(self.set_wallpaper)
        wp_switch.connect("state-set", lambda _, state: setattr(self, "set_wallpaper", state))
        wp_row.add_suffix(wp_switch)
        wp_group.add(wp_row)
        box.append(wp_group)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.END)
        back_btn = Gtk.Button(label="Back")
        back_btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("profile"))
        next_btn = Gtk.Button(label="Proceed to Install")
        next_btn.add_css_class("suggested-action")
        next_btn.connect("clicked", lambda _: self.view_stack.set_visible_child_name("install"))
        btn_box.append(back_btn)
        btn_box.append(next_btn)
        box.append(btn_box)

        clamp.set_child(box)
        self.view_stack.add_named(clamp, "mode")

    def _build_install_page(self):
        clamp = Adw.Clamp(maximum_size=680)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(16)
        box.set_margin_end(16)

        header = Gtk.Label(label="Ready to Install", xalign=0)
        header.add_css_class("title-2")
        desc = Gtk.Label(label="Click Start Install to deploy Carbon Shell assets, runtime scripts, and configurations.", xalign=0)
        desc.add_css_class("dim-label")
        box.append(header)
        box.append(desc)

        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_fraction(0.0)
        box.append(self.progress_bar)

        self.status_lbl = Gtk.Label(label="Awaiting start...", xalign=0)
        self.status_lbl.add_css_class("dim-label")
        box.append(self.status_lbl)

        log_expander = Adw.ExpanderRow(title="Installation Log")
        log_expander.set_expanded(True)

        self.log_buffer = Gtk.TextBuffer()
        log_view = Gtk.TextView(buffer=self.log_buffer)
        log_view.set_editable(False)
        log_view.set_cursor_visible(False)
        log_view.set_monospace(True)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_min_content_height(160)
        scrolled.set_max_content_height(220)
        scrolled.set_child(log_view)
        log_expander.add_row(scrolled)
        box.append(log_expander)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.END)
        self.start_btn = Gtk.Button(label="Start Install")
        self.start_btn.add_css_class("suggested-action")
        self.start_btn.connect("clicked", lambda _: self._start_installation())
        btn_box.append(self.start_btn)
        box.append(btn_box)

        clamp.set_child(box)
        self.view_stack.add_named(clamp, "install")

    def _build_finish_page(self):
        page = Adw.StatusPage(
            title="Installation Complete",
            description="Carbon Shell has been installed and configured successfully.",
            icon_name="emblem-ok-symbolic"
        )
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_halign(Gtk.Align.CENTER)

        btn_start = Gtk.Button(label="Start Shell & Reload Hyprland")
        btn_start.add_css_class("suggested-action")
        btn_start.add_css_class("pill")
        btn_start.set_size_request(240, 44)
        btn_start.connect("clicked", lambda _: self._launch_and_exit())
        box.append(btn_start)

        btn_close = Gtk.Button(label="Close")
        btn_close.add_css_class("pill")
        btn_close.set_size_request(160, 40)
        btn_close.connect("clicked", lambda _: self.close())
        box.append(btn_close)

        page.set_child(box)
        self.view_stack.add_named(page, "finish")

    def _log(self, text):
        def _append():
            end_iter = self.log_buffer.get_end_iter()
            self.log_buffer.insert(end_iter, text + "\n")
        GLib.idle_add(_append)

    def _set_status(self, text, frac):
        def _update():
            self.status_lbl.set_text(text)
            self.progress_bar.set_fraction(frac)
        GLib.idle_add(_update)

    def _start_installation(self):
        if self.is_installing:
            return
        self.is_installing = True
        self.start_btn.set_sensitive(False)
        threading.Thread(target=self._run_install_thread, daemon=True).start()

    def _run_install_thread(self):
        try:
            self._set_status("Creating safety backup...", 0.1)
            self._log("==> Creating safety backup...")
            ts = time.strftime("%Y%m%d_%H%M%S")
            backup_dir = Path.home() / f".config/carbon_backup_{ts}"
            if CONFIG_DIR.exists():
                shutil.copytree(CONFIG_DIR, backup_dir / "carbon_config", dirs_exist_ok=True)
                self._log(f"Backed up {CONFIG_DIR} to {backup_dir}")

            self._set_status("Deploying isolated configs and scripts...", 0.3)
            self._log("==> Deploying runtime files to ~/.config/carbon...")
            CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            (CONFIG_DIR / "scripts").mkdir(parents=True, exist_ok=True)
            (CONFIG_DIR / "configs").mkdir(parents=True, exist_ok=True)

            (CONFIG_DIR / "repo_path").write_text(str(REPO_DIR))

            # Runtime scripts
            scripts_src = REPO_DIR / "hypr/scripts"
            if scripts_src.exists():
                for s in scripts_src.iterdir():
                    dst = CONFIG_DIR / "scripts" / s.name
                    if s.is_file():
                        shutil.copy2(s, dst)
                        dst.chmod(0o755)

            # Hyprland mode templates & configs
            configs_src = REPO_DIR / "hypr/configs"
            if configs_src.exists():
                for c in configs_src.iterdir():
                    if c.is_file():
                        shutil.copy2(c, CONFIG_DIR / "configs" / c.name)

            # JSON state files
            for j in (REPO_DIR / "hypr").glob("*.json"):
                target = CONFIG_DIR / j.name
                if not target.exists():
                    shutil.copy2(j, target)

            # Extra configs
            for conf_name in [
                "blur-exceptions.conf", "cava-island.conf", "cava-lock.conf",
                "power.conf", "hypridle.conf", "hyprlock.conf", "colors.conf",
                "windowrules.conf", "looknfeel.conf", "keybinds.conf",
                "keybinds-shell-only.conf"
            ]:
                src = REPO_DIR / "hypr" / conf_name
                dst = CONFIG_DIR / conf_name
                if src.exists() and not dst.exists():
                    shutil.copy2(src, dst)

            # Selected bar mode
            mode_data = {
                "mode": self.shell_mode,
                "islandStyle": "minimal" if self.shell_mode == "minimal_notch" else self.shell_mode,
                "islandPersistent": True,
                "wallpaperAnimation": "cinematic",
                "wallpaperDuration": 800,
                "nucleus": {"transition": True, "transitionWord": "Wooshh!!"}
            }
            (CONFIG_DIR / "carbon-bar-mode.json").write_text(json.dumps(mode_data, indent=2))

            # Generate carbon.conf
            kb_target = "keybinds-shell-only.conf" if self.keybind_mode == "keep" else "keybinds.conf"
            carbon_conf_content = f"""env = CARBON_CONFIG_DIR,$HOME/.config/carbon
env = PATH,$HOME/.local/bin:$PATH

source = ~/.config/carbon/colors.conf
source = ~/.config/carbon/windowrules.conf
source = ~/.config/carbon/{kb_target}
source = ~/.config/carbon/configs/vanish-keybinds.conf

cursor {{
    no_warps = true
}}

exec-once = systemctl --user start carbon-quickshell.service
exec-once = bash -c 'wl-paste --watch cliphist store'
exec-once = bash -c 'wl-paste --type image --watch cliphist store'
"""
            (CONFIG_DIR / "carbon.conf").write_text(carbon_conf_content)

            self._set_status("Deploying Quickshell assets...", 0.5)
            self._log("==> Copying Quickshell components to ~/.local/share/quickshell/carbon...")
            qs_src = REPO_DIR / "quickshell/carbon"
            if qs_src.exists():
                shutil.copytree(qs_src, QUICKSHELL_DIR, dirs_exist_ok=True)

            self._set_status("Installing fonts...", 0.6)
            fonts_src = REPO_DIR / "fonts"
            if fonts_src.exists():
                FONTS_DIR.mkdir(parents=True, exist_ok=True)
                for f in fonts_src.glob("*.ttf"):
                    shutil.copy2(f, FONTS_DIR / f.name)
                if shutil.which("fc-cache"):
                    subprocess.run(["fc-cache", "-f"], capture_output=True)

            self._set_status("Installing CLI binaries...", 0.7)
            BIN_DIR.mkdir(parents=True, exist_ok=True)
            for bin_name in ["carbon-config-editor", "carbon-pomodoro", "update.sh"]:
                if bin_name == "update.sh":
                    src = REPO_DIR / "update.sh"
                    if src.exists():
                        shutil.copy2(src, BIN_DIR / "carbon-update")
                        (BIN_DIR / "carbon-update").chmod(0o755)
                else:
                    src = CONFIG_DIR / "scripts" / bin_name
                    if src.exists():
                        shutil.copy2(src, BIN_DIR / bin_name)
                        (BIN_DIR / bin_name).chmod(0o755)

            for s in (CONFIG_DIR / "scripts").glob("carbon-screenshot-*.sh"):
                base = s.stem
                shutil.copy2(s, BIN_DIR / base)
                shutil.copy2(s, BIN_DIR / f"{base}.sh")
                (BIN_DIR / base).chmod(0o755)
                (BIN_DIR / f"{base}.sh").chmod(0o755)

            self._set_status("Setting up systemd service...", 0.8)
            srv = REPO_DIR / "systemd/carbon-quickshell.service"
            if srv.exists():
                SYSTEMD_DIR.mkdir(parents=True, exist_ok=True)
                shutil.copy2(srv, SYSTEMD_DIR / srv.name)
                if shutil.which("systemctl"):
                    subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True)
                    subprocess.run(["systemctl", "--user", "enable", "carbon-quickshell.service"], capture_output=True)

            self._set_status("Integrating with Hyprland...", 0.85)
            HYPR_DIR.mkdir(parents=True, exist_ok=True)
            hypr_main = HYPR_DIR / "hyprland.conf"
            src_line = "source = ~/.config/carbon/carbon.conf"
            if hypr_main.exists():
                text = hypr_main.read_text()
                if src_line not in text:
                    ts_b = time.strftime("%Y%m%d_%H%M%S")
                    shutil.copy2(hypr_main, HYPR_DIR / f"hyprland.conf.backup_{ts_b}")
                    with open(hypr_main, "a") as f:
                        f.write(f"\n# Carbon Shell Integration\n{src_line}\n")
                    self._log(f"Safely added source entry to {hypr_main}")
            else:
                hypr_main.write_text(f"# Hyprland Main Configuration\n{src_line}\n")
                self._log(f"Created starter {hypr_main}")

            # Wallpaper & Theme
            if self.set_wallpaper:
                self._set_status("Configuring initial wallpaper & theme...", 0.9)
                WP_DIR.mkdir(parents=True, exist_ok=True)
                wp_src = REPO_DIR / "assets/wallpapers/default.png"
                wp_dst = WP_DIR / "wallhaven-6ly7yw.png"
                if wp_src.exists() and not wp_dst.exists():
                    shutil.copy2(wp_src, wp_dst)
                if wp_dst.exists():
                    wp_link = CONFIG_DIR / "current_wallpaper"
                    if wp_link.is_symlink() or wp_link.exists():
                        wp_link.unlink()
                    wp_link.symlink_to(wp_dst)
                    (CONFIG_DIR / "current_wallpaper_path").write_text(str(wp_dst))

                theme_script = CONFIG_DIR / "scripts/theme-mk.py"
                if theme_script.exists():
                    subprocess.run([sys.executable, str(theme_script)], capture_output=True)

            # Generate initial mode keybinds
            mode_script = CONFIG_DIR / "scripts/carbon-mode-keybinds.sh"
            if mode_script.exists():
                subprocess.run(["bash", str(mode_script), self.shell_mode], capture_output=True)

            self._set_status("Done!", 1.0)
            self._log("==> Installation finished successfully.")
            GLib.idle_add(lambda: self.view_stack.set_visible_child_name("finish"))

        except Exception as e:
            self._set_status("Error during installation", 1.0)
            self._log(f"ERROR: {str(e)}")
            GLib.idle_add(lambda: self.start_btn.set_sensitive(True))

    def _launch_and_exit(self):
        if not DRY_RUN:
            try:
                if shutil.which("systemctl"):
                    subprocess.run(["systemctl", "--user", "restart", "carbon-quickshell.service"], capture_output=True)
                if shutil.which("hyprctl"):
                    subprocess.run(["hyprctl", "reload"], capture_output=True)
            except Exception:
                pass
        self.close()


class CarbonInstallerApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="io.github.reduct.CarbonInstaller")

    def do_activate(self):
        win = InstallerWindow(self)
        win.present()


def main():
    app = CarbonInstallerApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
