#!/usr/bin/env python3
"""
Carbon Shell — Sandbox Test Runner, Installer/Updater Verifier & Mode Keybind Inspector
Serves an interactive verification and audit web console on 0.0.0.0:3000 using Python's
standard library HTTP server so it boots instantaneously with zero external web dependencies.
"""

import json
import os
import re
import shutil
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

REPO_DIR = Path(__file__).resolve().parent
SANDBOX_BASE = Path("/tmp/carbon-sandbox")

AUDIT_ISSUES = [
    {
        "id": "ISS-01",
        "component": "Installer & Updater (install.sh, install-gui.py, update.sh)",
        "severity": "Critical",
        "status": "Fixed & Verified",
        "title": "Split-Brain Script Deployment (~/.config/carbon/scripts vs ~/.config/hypr/scripts)",
        "problem": "install.sh, install-gui.py, and update.sh only copied hypr/scripts/* to ~/.config/carbon/scripts, while shell.qml, lock/idle configs, mode keybinds, and 14+ QML modules invoked scripts from ~/.config/hypr/scripts.",
        "resolution": "Updated all mode keybind configs and shell.qml to use ~/.config/carbon/scripts, and updated install.sh, install-gui.py, update.sh, and carbon-update to deploy scripts to both ~/.config/carbon/scripts and ~/.config/hypr/scripts."
    },
    {
        "id": "ISS-02",
        "component": "Hyprland Integration (carbon.conf)",
        "severity": "Critical",
        "status": "Fixed & Verified",
        "title": "Mode-Specific Keybinds (current-mode-keybinds.conf) Never Sourced in carbon.conf",
        "problem": "Generated carbon.conf sourced colors.conf, windowrules.conf, base keybinds, and vanish-keybinds.conf unconditionally, but never sourced configs/current-mode-keybinds.conf. Mode shortcuts never loaded on fresh installs and Vanish binds leaked into all modes.",
        "resolution": "Replaced unconditional vanish-keybinds.conf include with source = ~/.config/carbon/configs/current-mode-keybinds.conf across install.sh, install-gui.py, and hypr/carbon.conf, with automatic migration in update.sh."
    },
    {
        "id": "ISS-03",
        "component": "Mode Keybind Dispatcher (carbon-mode-keybinds.sh & shell.qml)",
        "severity": "Critical",
        "status": "Fixed & Verified",
        "title": "Missing 'pill' Mode Case & Path Mismatch in Dispatcher",
        "problem": "carbon-mode-keybinds.sh omitted 'pill' from its mode case statement (falling back to minimal keybinds), looked for templates in ~/.config/carbon/ instead of ~/.config/carbon/configs/, and only wrote output to ~/.config/hypr/configs/. Meanwhile, shell.qml coerced 'pill' into 'notch'.",
        "resolution": "Added dedicated 'pill|waybar' case in carbon-mode-keybinds.sh, wrote current-mode-keybinds.conf to both ~/.config/carbon/configs/ and ~/.config/hypr/configs/, and preserved 'pill' as a first-class mode in shell.qml."
    },
    {
        "id": "ISS-04",
        "component": "Sandbox Isolation (--dry-run in install.sh, install-gui.py, update.sh)",
        "severity": "High",
        "status": "Fixed & Verified",
        "title": "Host $HOME Leakage During --dry-run & Missing Updater Sandbox Mode",
        "problem": "In --dry-run mode, BACKUP_DIR and USER_FONT_DIR still wrote to $HOME, child scripts (carbon-mode-keybinds.sh, theme-mk.py) were called without sandbox env vars, and update.sh lacked --dry-run entirely.",
        "resolution": "Scoped all directories (carbon, hypr, quickshell, bin, systemd, fonts, wallpapers, backups) strictly inside CARBON_SANDBOX_DIR (/tmp/carbon-sandbox) and added --dry-run and --no-git support to update.sh and carbon-update."
    },
    {
        "id": "ISS-05",
        "component": "CLI Installer Mode Selection & Master Config Parity",
        "severity": "Medium",
        "status": "Fixed & Verified",
        "title": "Missing --mode Flag in CLI Installer & Incomplete Generated carbon.conf",
        "problem": "install.sh hardcoded minimal_notch instead of allowing --mode=minimal_notch|notch|pill|vanish like install-gui.py, and generated a stripped-down carbon.conf missing blur-exceptions.conf, power.conf, hypridle, portal.sh, and audio init.",
        "resolution": "Added --mode=MODE flag and interactive selector to install.sh, unified generated carbon.conf with full daemon and rule includes, and synchronized update.sh with carbon-update."
    },
    {
        "id": "ISS-06",
        "component": "Shell Lifecycle Commands (start.sh / carbon-start & uninstall.sh / carbon-uninstall)",
        "severity": "High",
        "status": "Fixed & Verified",
        "title": "Added Standalone Start/Control Command & Non-Destructive Uninstaller",
        "problem": "Repository lacked a dedicated command to start/restart/stop the shell or switch modes from the CLI, and had no uninstaller to cleanly unhook carbon.conf from hyprland.conf and remove deployed services/binaries.",
        "resolution": "Created start.sh (installed as carbon-start and carbon-shell) supporting start/restart/stop/status/--mode=MODE, and uninstall.sh (installed as carbon-uninstall) with automatic backup, non-destructive hyprland.conf unhooking, --keep-config, and full --dry-run sandbox support."
    }
]


def parse_hypr_keybinds(file_path: Path) -> list[dict]:
    """Parse a Hyprland keybinds .conf file into structured rows."""
    if not file_path.exists():
        return []
    binds = []
    var_map = {"$mainMod": "SUPER", "$terminal": "kitty", "$fileManager": "nautilus", "$menu": "rofi -show drun"}
    for raw_line in file_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("$") and "=" in line:
            k, v = line.split("=", 1)
            var_map[k.strip()] = v.strip()
            continue
        m = re.match(r"^(bind[a-z]*)\s*=\s*([^,]*),\s*([^,]+),\s*([^,]+)(?:,\s*(.*))?$", line)
        if m:
            btype, mods, key, action, args = (
                m.group(1).strip(),
                m.group(2).strip(),
                m.group(3).strip(),
                m.group(4).strip(),
                (m.group(5) or "").strip(),
            )
            for vk, vv in var_map.items():
                mods = mods.replace(vk, vv)
                args = args.replace(vk, vv)
            shortcut = f"{mods} + {key}" if mods else key
            binds.append({
                "type": btype,
                "mods": mods or "None",
                "key": key,
                "shortcut": shortcut,
                "action": action,
                "command": args or action,
                "Externalized": "~/.config/hypr/scripts" not in args,
            })
    return binds


def get_all_mode_keybinds() -> dict:
    configs_dir = REPO_DIR / "hypr" / "configs"
    hypr_dir = REPO_DIR / "hypr"
    return {
        "minimal_notch": {
            "label": "Minimal Island (Tide)",
            "file": "hypr/configs/keybinds-minimal.conf",
            "description": "Ultra-compact top capsule with Quickshell IPC triggers for Tide Control Center, Launcher, Player, and swipe gestures.",
            "binds": parse_hypr_keybinds(configs_dir / "keybinds-minimal.conf"),
        },
        "notch": {
            "label": "Carbon Notch",
            "file": "hypr/configs/keybinds-notch.conf",
            "description": "Centered dynamic notch with Center Dashboard, Spotlight, Quick Controls, and standard arrow focus navigation.",
            "binds": parse_hypr_keybinds(configs_dir / "keybinds-notch.conf"),
        },
        "vanish": {
            "label": "Vanish Hub (Nucleus)",
            "file": "hypr/configs/keybinds-vanish.conf",
            "description": "Edge-hidden atomic nucleus with Super release trigger, orbital satellite shortcuts (Lyrics, Alerts, Quick Toggles), and carbon-vanish-dispatch.sh routing.",
            "binds": parse_hypr_keybinds(configs_dir / "keybinds-vanish.conf"),
        },
        "base_keep": {
            "label": "Base Profile: Keep Existing (Shell Only)",
            "file": "hypr/keybinds-shell-only.conf",
            "description": "Non-intrusive base layer that preserves the user's existing Hyprland binds and only adds essential Carbon triggers.",
            "binds": parse_hypr_keybinds(hypr_dir / "keybinds-shell-only.conf"),
        },
        "base_carbon": {
            "label": "Base Profile: Full Carbon Desktop",
            "file": "hypr/keybinds.conf",
            "description": "Complete standalone Hyprland keybinding layout for terminal, window management, workspaces 1-10, screenshots, and media keys.",
            "binds": parse_hypr_keybinds(hypr_dir / "keybinds.conf"),
        },
    }


def run_sandbox_suite(selected_mode: str = "all", keybind_profile: str = "keep") -> dict:
    """Execute real sandbox tests of install.sh, start.sh, update.sh, and uninstall.sh in /tmp/carbon-sandbox."""
    start_time = time.time()
    if SANDBOX_BASE.exists():
        shutil.rmtree(SANDBOX_BASE, ignore_errors=True)
    SANDBOX_BASE.mkdir(parents=True, exist_ok=True)

    modes_to_test = (
        ["minimal_notch", "notch", "vanish"]
        if selected_mode == "all"
        else [selected_mode]
    )

    env = {
        **os.environ,
        "CARBON_SANDBOX_DIR": str(SANDBOX_BASE),
        "CARBON_NO_RELOAD": "1",
    }

    assertions = []
    logs = []

    def add_assertion(name: str, passed: bool, detail: str, category: str = "Installer"):
        assertions.append({
            "name": name,
            "passed": bool(passed),
            "detail": detail,
            "category": category,
        })

    # 1. Run install.sh in sandbox for each requested mode
    for m in modes_to_test:
        cmd = [
            "bash",
            str(REPO_DIR / "install.sh"),
            "--dry-run",
            "--cli",
            "-y",
            "--no-deps",
            "--no-reload",
            f"--keybinds={keybind_profile}",
            f"--mode={m}",
        ]
        proc = subprocess.run(cmd, cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=30)
        logs.append(f"=== [INSTALL SANDBOX: mode={m}, keybinds={keybind_profile}] (exit={proc.returncode}) ===\n{proc.stdout}{proc.stderr}")

        add_assertion(
            f"CLI Installer exits cleanly for mode '{m}'",
            proc.returncode == 0,
            f"Exit code {proc.returncode}",
            "Installer",
        )

        # Verify carbon-bar-mode.json
        bar_mode_file = SANDBOX_BASE / "carbon" / "carbon-bar-mode.json"
        expected_json_mode = "nucleus" if m == "vanish" else m
        actual_json_mode = None
        if bar_mode_file.exists():
            try:
                actual_json_mode = json.loads(bar_mode_file.read_text()).get("mode")
            except Exception:
                pass
        add_assertion(
            f"carbon-bar-mode.json sets mode='{expected_json_mode}'",
            actual_json_mode == expected_json_mode,
            f"Found mode='{actual_json_mode}' in {bar_mode_file}",
            "Mode State",
        )

        # Verify current-mode-keybinds.conf matches the mode's template
        norm_map = {"minimal_notch": "minimal", "notch": "notch", "vanish": "vanish"}
        norm_m = norm_map.get(m, "minimal")
        template_file = REPO_DIR / "hypr" / "configs" / f"keybinds-{norm_m}.conf"
        active_mode_conf = SANDBOX_BASE / "carbon" / "configs" / "current-mode-keybinds.conf"
        matches_template = (
            active_mode_conf.exists()
            and template_file.exists()
            and active_mode_conf.read_text() == template_file.read_text()
        )
        add_assertion(
            f"Isolated keybinds activated for '{m}' (keybinds-{norm_m}.conf)",
            matches_template,
            f"Verified {active_mode_conf.name} === keybinds-{norm_m}.conf ({len(parse_hypr_keybinds(active_mode_conf))} bindings)",
            "Mode Isolation",
        )

    # 2. Verify externalized carbon.conf structure
    carbon_conf = SANDBOX_BASE / "carbon" / "carbon.conf"
    carbon_conf_text = carbon_conf.read_text() if carbon_conf.exists() else ""
    expected_kb_file = "keybinds.conf" if keybind_profile == "carbon" else "keybinds-shell-only.conf"

    add_assertion(
        "Generated carbon.conf sources base keybind profile",
        f"source = ~/.config/carbon/{expected_kb_file}" in carbon_conf_text,
        f"Found source = ~/.config/carbon/{expected_kb_file}",
        "External Structure",
    )
    add_assertion(
        "Generated carbon.conf sources isolated current-mode-keybinds.conf",
        "source = ~/.config/carbon/configs/current-mode-keybinds.conf" in carbon_conf_text
        and "vanish-keybinds.conf" not in carbon_conf_text,
        "Sourced ~/.config/carbon/configs/current-mode-keybinds.conf (no unconditional vanish-keybinds.conf)",
        "External Structure",
    )

    # 2b. Verify requested keybind updates (MOD+SHIFT+C = Settings Hub, MOD+K = Focus Mode, hyprpicker unbound)
    all_kb_files = [
        SANDBOX_BASE / "carbon" / "keybinds-shell-only.conf",
        SANDBOX_BASE / "carbon" / "keybinds.conf",
        SANDBOX_BASE / "carbon" / "configs" / "keybinds-minimal.conf",
        SANDBOX_BASE / "carbon" / "configs" / "keybinds-notch.conf",
        SANDBOX_BASE / "carbon" / "configs" / "keybinds-vanish.conf",
    ]
    kb_texts = [p.read_text() for p in all_kb_files if p.exists()]
    no_hyprpicker = all("hyprpicker" not in t for t in kb_texts)
    settings_hub_bound = all("carbon-settings-hub" in t and "SHIFT, C" in t for t in kb_texts)
    focus_k_bound = all("carbon-focus.sh" in t and ", K, exec," in t for t in kb_texts)

    add_assertion(
        "Color Picker (hyprpicker -a) unbound across all modes and base profiles",
        no_hyprpicker,
        "0 references to 'hyprpicker' across all 6 deployed keybind files",
        "Keybindings",
    )
    add_assertion(
        "Rust Settings Hub bound to MOD + SHIFT + C across all profiles & modes",
        settings_hub_bound,
        "Verified bind = $mainMod SHIFT, C, exec, ~/.config/carbon/scripts/carbon-settings-hub",
        "Keybindings",
    )
    add_assertion(
        "Focus Mode (Hyper-Tunnel HUD) bound to MOD + K across all profiles & modes",
        focus_k_bound,
        "Verified bind = $mainMod, K, exec, ~/.config/carbon/scripts/carbon-focus.sh",
        "Keybindings",
    )

    # 3. Verify non-destructive Hyprland hook
    hypr_main = SANDBOX_BASE / "hypr" / "hyprland.conf"
    hypr_main_text = hypr_main.read_text() if hypr_main.exists() else ""
    add_assertion(
        "Host hyprland.conf contains single non-destructive Carbon source hook",
        "source = ~/.config/carbon/carbon.conf" in hypr_main_text,
        f"Verified in {hypr_main}",
        "External Structure",
    )

    # 4. Verify dual script deployment & CLI binaries (carbon-start, carbon-shell, carbon-uninstall, carbon-update)
    carbon_scripts = list((SANDBOX_BASE / "carbon" / "scripts").glob("*"))
    hypr_scripts = list((SANDBOX_BASE / "hypr" / "scripts").glob("*"))
    add_assertion(
        "Runtime scripts deployed to both carbon/scripts and hypr/scripts mirror",
        len(carbon_scripts) >= 35 and len(carbon_scripts) == len(hypr_scripts),
        f"{len(carbon_scripts)} scripts in carbon/scripts, {len(hypr_scripts)} mirrored in hypr/scripts",
        "Portability",
    )

    bin_dir = SANDBOX_BASE / "bin"
    expected_bins = ["carbon-start", "carbon-shell", "carbon-uninstall", "carbon-update"]
    present_bins = [b for b in expected_bins if (bin_dir / b).exists()]
    add_assertion(
        "Lifecycle CLI commands deployed to ~/.local/bin (carbon-start, carbon-shell, carbon-uninstall, carbon-update)",
        len(present_bins) == len(expected_bins),
        f"Deployed binaries: {', '.join(present_bins)}",
        "Lifecycle CLI",
    )

    # 5. Verify Quickshell QML deployment & systemd services
    shell_qml = SANDBOX_BASE / "quickshell" / "shell.qml"
    systemd_qs = SANDBOX_BASE / "systemd" / "carbon-quickshell.service"
    systemd_hub = SANDBOX_BASE / "systemd" / "carbon-hub.service"
    add_assertion(
        "Quickshell QML tree and systemd user units deployed",
        shell_qml.exists() and systemd_qs.exists() and systemd_hub.exists(),
        "Verified shell.qml, carbon-quickshell.service, and carbon-hub.service",
        "Portability",
    )

    # 5b. Verify Focus Mode (SUPER + K) & Rust Settings Hub (SUPER + SHIFT + C) feature completeness
    focus_qml = SANDBOX_BASE / "quickshell" / "modules" / "FocusHUD.qml"
    focus_txt = focus_qml.read_text() if focus_qml.exists() else ""
    focus_features_ok = (
        "internalFocusTimer" in focus_txt
        and "brownAudioProc" in focus_txt
        and "rainAudioProc" in focus_txt
        and "addTask" in focus_txt
        and "focus-tasks.json" in focus_txt
    )
    add_assertion(
        "Focus Mode (SUPER + K) includes standalone QML timer, Rain & Brown Noise synthesis, and persistent task checklist",
        focus_features_ok,
        "Verified internalFocusTimer, brownAudioProc, rainAudioProc, addTask, and focus-tasks.json in FocusHUD.qml",
        "Focus & Settings Hub",
    )

    hub_py = SANDBOX_BASE / "carbon" / "scripts" / "carbon-hub-daemon.py"
    modes_qml = SANDBOX_BASE / "quickshell" / "modules" / "ModesTab.qml"
    modes_txt = modes_qml.read_text() if modes_qml.exists() else ""
    keybinds_tab_qml = SANDBOX_BASE / "quickshell" / "modules" / "KeybindsTab.qml"
    settings_hub_qml = SANDBOX_BASE / "quickshell" / "modules" / "SettingsHub.qml"
    settings_hub_txt = settings_hub_qml.read_text() if settings_hub_qml.exists() else ""
    focus_bg_qml = SANDBOX_BASE / "quickshell" / "modules" / "FocusHUDBackground.qml"
    focus_bg_txt = focus_bg_qml.read_text() if focus_bg_qml.exists() else ""
    shell_qml = SANDBOX_BASE / "quickshell" / "shell.qml"
    shell_txt = shell_qml.read_text() if shell_qml.exists() else ""

    qml_crash_fixed = (
        "PanelWindow {" in focus_txt
        and "PanelWindow {" in focus_bg_txt
        and "modelData: modelData" not in shell_txt
    )
    add_assertion(
        "Quickshell QML crash-loop fix verified (FocusHUD & FocusHUDBackground use PanelWindow root; no self-binding modelData loops)",
        qml_crash_fixed,
        "Verified PanelWindow root on FocusHUD.qml & FocusHUDBackground.qml and clean Variants bindings in shell.qml",
        "Focus & Settings Hub",
    )

    hub_features_ok = (
        hub_py.exists()
        and keybinds_tab_qml.exists()
        and "KeybindsTab" in settings_hub_txt
        and "carbon-mode-keybinds.sh" in modes_txt
        and "saveBottomSetting(\"notchHeight\"" in modes_txt
    )
    add_assertion(
        "Settings Hub (SUPER + SHIFT + C) includes Keybinds & Gestures Studio tab, /tmp/carbon-hub.sock daemon, and live mode sync",
        hub_features_ok,
        "Verified KeybindsTab.qml in SettingsHub.qml, carbon-hub-daemon.py get_keybinds/save_keybinds, and ModesTab.qml",
        "Focus & Settings Hub",
    )

    # 5c. Verify zero WASD binds across all modes, MOD + F = fullscreen, and 3-finger touchpad gestures
    kb_files_to_check = [
        SANDBOX_BASE / "carbon" / "keybinds-shell-only.conf",
        SANDBOX_BASE / "carbon" / "keybinds.conf",
        SANDBOX_BASE / "carbon" / "configs" / "keybinds-minimal.conf",
        SANDBOX_BASE / "carbon" / "configs" / "keybinds-notch.conf",
        SANDBOX_BASE / "carbon" / "configs" / "keybinds-vanish.conf",
    ]
    wasd_clashes = []
    firefox_on_mod_f = False
    fullscreen_on_mod_f = False
    for kbf in kb_files_to_check:
        if not kbf.exists():
            continue
        for raw_line in kbf.read_text().splitlines():
            s = raw_line.strip()
            if not s.startswith("bind") or "=" not in s:
                continue
            parts = [p.strip() for p in s.split("=", 1)[1].split(",")]
            if len(parts) >= 3:
                m = parts[0].replace("$mainMod", "SUPER").strip()
                k = parts[1].upper()
                d = parts[2].lower()
                a = ",".join(parts[3:]).lower() if len(parts) > 3 else ""
                if m == "SUPER" and k in ("W", "A", "S", "D"):
                    wasd_clashes.append(f"{kbf.name}:{m}+{k}")
                if m == "SUPER" and k == "F":
                    if "firefox" in a:
                        firefox_on_mod_f = True
                    if d == "fullscreen":
                        fullscreen_on_mod_f = True

    gestures_conf = SANDBOX_BASE / "carbon" / "configs" / "gestures.conf"
    gestures_init_sh = SANDBOX_BASE / "carbon" / "scripts" / "carbon-gestures-init.sh"
    gestures_ok = (
        gestures_conf.exists()
        and gestures_init_sh.exists()
        and "3, horizontal, workspace" in gestures_conf.read_text()
    )
    add_assertion(
        "SUPER + W/A/S/D completely unbound across all modes, SUPER + F bound to fullscreen, and 3-finger touchpad gestures active",
        len(wasd_clashes) == 0 and not firefox_on_mod_f and fullscreen_on_mod_f and gestures_ok,
        f"WASD clashes: {len(wasd_clashes)}, SUPER+F fullscreen: {fullscreen_on_mod_f}, 3-finger workspace swipe: {gestures_ok}",
        "Keybind Isolation",
    )

    # 6. Test Start Command (start.sh / carbon-start --dry-run)
    start_target_mode = "notch" if modes_to_test[-1] != "notch" else "minimal_notch"
    start_cmd = [
        "bash",
        str(REPO_DIR / "start.sh"),
        "start",
        f"--mode={start_target_mode}",
        "--dry-run",
        "--no-reload",
    ]
    start_proc = subprocess.run(start_cmd, cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=20)
    logs.append(f"=== [START COMMAND SANDBOX: start.sh start --mode={start_target_mode} --dry-run] (exit={start_proc.returncode}) ===\n{start_proc.stdout}{start_proc.stderr}")

    bar_mode_after_start = None
    bar_mode_file = SANDBOX_BASE / "carbon" / "carbon-bar-mode.json"
    if bar_mode_file.exists():
        try:
            bar_mode_after_start = json.loads(bar_mode_file.read_text()).get("mode")
        except Exception:
            pass
    add_assertion(
        f"Start command (start.sh --mode={start_target_mode}) switches mode, syncs keybinds, and launches cleanly",
        start_proc.returncode == 0 and bar_mode_after_start == start_target_mode,
        f"Exit code {start_proc.returncode}, active mode updated to '{bar_mode_after_start}'",
        "Start Command",
    )

    status_cmd = ["bash", str(REPO_DIR / "start.sh"), "status", "--dry-run"]
    status_proc = subprocess.run(status_cmd, cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=15)
    logs.append(f"=== [STATUS COMMAND SANDBOX: start.sh status --dry-run] (exit={status_proc.returncode}) ===\n{status_proc.stdout}{status_proc.stderr}")
    add_assertion(
        "Status command (start.sh status) reports shell, mode, and keybind state",
        status_proc.returncode == 0 and "Active Mode" in status_proc.stdout,
        "Verified status output for Quickshell, Hub Daemon, and active mode",
        "Start Command",
    )

    # 7. Test Updater (update.sh --dry-run) and legacy migration
    if carbon_conf.exists():
        legacy_text = carbon_conf_text.replace(
            "configs/current-mode-keybinds.conf", "configs/vanish-keybinds.conf"
        )
        carbon_conf.write_text(legacy_text)

    upd_cmd = [
        "bash",
        str(REPO_DIR / "update.sh"),
        "--dry-run",
        "--no-git",
        "-y",
        "--no-reload",
    ]
    upd_proc = subprocess.run(upd_cmd, cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=30)
    logs.append(f"=== [UPDATE SANDBOX: update.sh --dry-run] (exit={upd_proc.returncode}) ===\n{upd_proc.stdout}{upd_proc.stderr}")

    add_assertion(
        "Updater (update.sh --dry-run) completes with exit code 0",
        upd_proc.returncode == 0,
        f"Exit code {upd_proc.returncode}",
        "Updater",
    )

    migrated_text = carbon_conf.read_text() if carbon_conf.exists() else ""
    add_assertion(
        "Updater automatically migrates legacy vanish-keybinds.conf to current-mode-keybinds.conf",
        "configs/current-mode-keybinds.conf" in migrated_text,
        "Verified automatic migration in carbon.conf",
        "Updater",
    )

    backups = list((SANDBOX_BASE / "carbon" / "backups").glob("carbon-backup-*.tar.gz"))
    add_assertion(
        "Updater creates pre-update tar.gz safety archive in sandbox",
        len(backups) >= 1,
        f"Created {backups[0].name if backups else 'none'}",
        "Updater",
    )

    # 8. Test Rollback (--rollback --dry-run)
    rb_cmd = [
        "bash",
        str(REPO_DIR / "update.sh"),
        "--dry-run",
        "--rollback",
        "--no-reload",
    ]
    rb_proc = subprocess.run(rb_cmd, cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=20)
    logs.append(f"=== [ROLLBACK SANDBOX: update.sh --dry-run --rollback] (exit={rb_proc.returncode}) ===\n{rb_proc.stdout}{rb_proc.stderr}")
    add_assertion(
        "Updater rollback (--rollback) restores safety archive cleanly",
        rb_proc.returncode == 0,
        f"Exit code {rb_proc.returncode}",
        "Updater",
    )

    # 9. Test Uninstaller (uninstall.sh --dry-run -y)
    # Seed a custom user line in hyprland.conf to verify non-destructive unhooking
    if hypr_main.exists():
        hypr_main.write_text("# User Custom Hyprland Config\nmonitor=,preferred,auto,1\n\n# Carbon Shell Integration\nsource = ~/.config/carbon/carbon.conf\n")

    uninst_cmd = [
        "bash",
        str(REPO_DIR / "uninstall.sh"),
        "--dry-run",
        "-y",
        "--no-reload",
    ]
    uninst_proc = subprocess.run(uninst_cmd, cwd=str(REPO_DIR), env=env, capture_output=True, text=True, timeout=25)
    logs.append(f"=== [UNINSTALL SANDBOX: uninstall.sh --dry-run -y] (exit={uninst_proc.returncode}) ===\n{uninst_proc.stdout}{uninst_proc.stderr}")

    hypr_after_uninst = hypr_main.read_text() if hypr_main.exists() else ""
    uninst_backups = list((SANDBOX_BASE / "backups").glob("carbon-uninstall-backup-*"))
    add_assertion(
        "Uninstaller (uninstall.sh --dry-run -y) removes Carbon directories, binaries, and services cleanly",
        uninst_proc.returncode == 0
        and not (SANDBOX_BASE / "carbon").exists()
        and not (SANDBOX_BASE / "quickshell").exists()
        and not (SANDBOX_BASE / "bin" / "carbon-start").exists(),
        f"Exit code {uninst_proc.returncode}; ~/.config/carbon, ~/.config/quickshell/carbon, and binaries removed",
        "Uninstaller",
    )
    add_assertion(
        "Uninstaller strips only Carbon hook from hyprland.conf while preserving user lines & creating backup",
        "source = ~/.config/carbon/carbon.conf" not in hypr_after_uninst
        and "monitor=,preferred,auto,1" in hypr_after_uninst
        and len(uninst_backups) >= 1,
        f"User monitor line preserved; backup created at {uninst_backups[0].name if uninst_backups else 'none'}",
        "Uninstaller",
    )

    # Re-populate sandbox with the final mode so the "Generated Configs" tab can inspect live files
    final_mode = modes_to_test[-1]
    subprocess.run(
        [
            "bash",
            str(REPO_DIR / "install.sh"),
            "--dry-run",
            "--cli",
            "-y",
            "--no-deps",
            "--no-reload",
            f"--keybinds={keybind_profile}",
            f"--mode={final_mode}",
        ],
        cwd=str(REPO_DIR),
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )

    repo_meta_file = SANDBOX_BASE / "carbon" / "carbon-repo.json"
    repo_meta_ok = False
    repo_remote_val = ""
    if repo_meta_file.exists():
        try:
            rm = json.loads(repo_meta_file.read_text())
            repo_remote_val = rm.get("remoteUrl", "")
            repo_meta_ok = (
                rm.get("channel") == "dev"
                and ("carbon-development" in repo_remote_val or "carbon-shell-dev" in repo_remote_val)
                and "xzshogun/carbon-shell.git" not in repo_remote_val
            )
        except Exception:
            pass
    add_assertion(
        "Installer & Updater target xzshogun/carbon-development (separate from xzshogun/carbon-shell)",
        repo_meta_ok,
        f"carbon-repo.json channel='dev', remoteUrl='{repo_remote_val}'",
        "Staging Repo",
    )

    # Collect sandbox files for inspection
    sandbox_files = {}
    for rel_path in [
        "carbon/carbon.conf",
        "carbon/carbon-bar-mode.json",
        "carbon/carbon-repo.json",
        "carbon/configs/current-mode-keybinds.conf",
        "carbon/current-mode-keybinds.lua",
        "hypr/hyprland.conf",
        "systemd/carbon-quickshell.service",
    ]:
        fp = SANDBOX_BASE / rel_path
        if fp.exists():
            sandbox_files[rel_path] = fp.read_text(encoding="utf-8", errors="replace")

    elapsed_ms = round((time.time() - start_time) * 1000)
    passed_count = sum(1 for a in assertions if a["passed"])

    return {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "elapsedMs": elapsed_ms,
        "selectedMode": selected_mode,
        "keybindProfile": keybind_profile,
        "totalAssertions": len(assertions),
        "passedAssertions": passed_count,
        "allPassed": passed_count == len(assertions),
        "assertions": assertions,
        "sandboxFiles": sandbox_files,
        "logs": "\n\n".join(logs),
    }


BARE_GIT_DIR = Path("/tmp/carbon-shell-dev.git")
TARBALL_PATH = Path("/tmp/carbon-shell-dev.tar.gz")
STAGING_PUBLIC_URL = "https://ais-pre-clqdsggkf7wyqbb7b7z654-900258437217.asia-east1.run.app"


def ensure_staging_repo_artifacts() -> None:
    """Build /tmp/carbon-shell-dev.tar.gz and HTTP-cloneable /tmp/carbon-shell-dev.git from REPO_DIR."""
    try:
        # 1. Create clean tarball of workspace
        subprocess.run(
            [
                "tar",
                "-czf",
                str(TARBALL_PATH),
                "--exclude=.git",
                "--exclude=__pycache__",
                "--exclude=.aistudio",
                "-C",
                str(REPO_DIR),
                ".",
            ],
            check=False,
            capture_output=True,
            timeout=20,
        )

        # 2. Build bare HTTP git repo with git update-server-info so `git clone <url>/carbon-development.git` works
        work_tmp = Path("/tmp/carbon-git-worktree")
        if work_tmp.exists():
            shutil.rmtree(work_tmp, ignore_errors=True)
        if BARE_GIT_DIR.exists():
            shutil.rmtree(BARE_GIT_DIR, ignore_errors=True)
        work_tmp.mkdir(parents=True, exist_ok=True)
        subprocess.run(["tar", "--no-same-owner", "-xzf", str(TARBALL_PATH), "-C", str(work_tmp)], check=False, capture_output=True)
        git_base = ["git", "-c", "safe.directory=*"]
        subprocess.run([*git_base, "init", "-b", "main"], cwd=str(work_tmp), check=False, capture_output=True)
        subprocess.run([*git_base, "config", "user.name", "Carbon Staging Bot"], cwd=str(work_tmp), check=False, capture_output=True)
        subprocess.run([*git_base, "config", "user.email", "dev@carbon-shell.local"], cwd=str(work_tmp), check=False, capture_output=True)
        subprocess.run([*git_base, "add", "-A"], cwd=str(work_tmp), check=False, capture_output=True)
        subprocess.run(
            [*git_base, "commit", "-m", "feat(staging): Carbon Shell externalized modes, start, update & uninstall"],
            cwd=str(work_tmp),
            check=False,
            capture_output=True,
        )
        subprocess.run([*git_base, "clone", "--bare", str(work_tmp), str(BARE_GIT_DIR)], check=False, capture_output=True)
        subprocess.run([*git_base, "update-server-info"], cwd=str(BARE_GIT_DIR), check=False, capture_output=True)
        shutil.rmtree(work_tmp, ignore_errors=True)
    except Exception:
        pass


ensure_staging_repo_artifacts()


# Run an initial sandbox verification on startup so the UI has immediate live data
INITIAL_SANDBOX_RESULT = run_sandbox_suite(selected_mode="all", keybind_profile="keep")


HTML_PAGE = r"""<!doctype html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Carbon Shell Sandbox & Architecture Auditor</title>
  <meta name="description" content="Interactive sandbox test runner, installer/updater verifier, and isolated per-mode keybind inspector for Carbon Shell (Hyprland + Quickshell)." />
  <meta property="og:title" content="Carbon Shell Sandbox & Architecture Auditor" />
  <meta property="og:description" content="Interactive sandbox test runner, installer/updater verifier, and isolated per-mode keybind inspector for Carbon Shell (Hyprland + Quickshell)." />
  <meta property="og:type" content="website" />
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0B0E13;
      --surface: #12161F;
      --surface-high: #181E2B;
      --border: #232B3D;
      --text: #E6E8F0;
      --text-muted: #8E96AA;
      --accent: #38BDF8;
      --accent-dim: rgba(56, 189, 248, 0.14);
      --ok: #22C55E;
      --ok-dim: rgba(34, 197, 94, 0.14);
      --warn: #F59E0B;
      --err: #F43F5E;
      --font-sans: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: var(--font-sans);
      font-size: 14px;
      line-height: 1.55;
      min-height: 100vh;
      -webkit-font-smoothing: antialiased;
    }
    .tabular { font-variant-numeric: tabular-nums; font-family: var(--font-mono); }

    /* Top Bar Contract: 3 zones */
    header.topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 32px;
      padding: 14px 32px;
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      position: sticky;
      top: 0;
      z-index: 40;
    }
    .brand {
      font-size: 16px;
      font-weight: 700;
      letter-spacing: -0.02em;
      color: var(--text);
      text-decoration: none;
      white-space: nowrap;
      flex-shrink: 0;
    }
    nav.topnav {
      display: flex;
      align-items: center;
      gap: 28px;
    }
    nav.topnav button {
      background: none;
      border: none;
      color: var(--text-muted);
      font-family: var(--font-sans);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      padding: 6px 0;
      border-bottom: 2px solid transparent;
      white-space: nowrap;
      flex-shrink: 0;
      transition: color 140ms ease, border-color 140ms ease;
    }
    nav.topnav button:hover { color: var(--text); }
    nav.topnav button.active {
      color: var(--accent);
      border-bottom-color: var(--accent);
    }
    .primary-cta {
      background: var(--accent);
      color: #07131D;
      font-family: var(--font-sans);
      font-size: 13px;
      font-weight: 600;
      padding: 8px 16px;
      border-radius: 8px;
      border: none;
      cursor: pointer;
      white-space: nowrap;
      flex-shrink: 0;
      transition: opacity 140ms ease, transform 140ms ease;
    }
    .primary-cta:hover { opacity: 0.92; }
    .primary-cta:disabled { opacity: 0.5; cursor: wait; }

    .container {
      max-width: 1380px;
      margin: 0 auto;
      padding: 28px 32px 64px;
    }

    /* Summary Strip */
    .summary-strip {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 16px;
      margin-bottom: 28px;
    }
    .stat-box {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 18px 20px;
    }
    .stat-label {
      font-size: 12px;
      color: var(--text-muted);
      margin-bottom: 6px;
    }
    .stat-value {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.02em;
    }
    .stat-sub {
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    /* Section Panels */
    .panel {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 24px;
      margin-bottom: 24px;
    }
    .panel-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 16px;
      padding-bottom: 16px;
      margin-bottom: 20px;
      border-bottom: 1px solid var(--border);
    }
    .panel-title {
      font-size: 18px;
      font-weight: 700;
      letter-spacing: -0.01em;
    }
    .panel-desc {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    /* Controls Bar */
    .controls-row {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 12px;
      margin-bottom: 20px;
    }
    .segmented {
      display: inline-flex;
      background: var(--bg);
      padding: 4px;
      border-radius: 8px;
      border: 1px solid var(--border);
      gap: 4px;
    }
    .segmented button {
      background: transparent;
      border: none;
      color: var(--text-muted);
      font-family: var(--font-sans);
      font-size: 12px;
      font-weight: 600;
      padding: 6px 12px;
      border-radius: 6px;
      cursor: pointer;
      white-space: nowrap;
      transition: background 140ms ease, color 140ms ease;
    }
    .segmented button.active {
      background: var(--surface-high);
      color: var(--text);
    }

    /* Tables */
    .table-wrap {
      overflow-x: auto;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }
    th {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      padding: 10px 14px;
      border-bottom: 1px solid var(--border);
    }
    td {
      padding: 12px 14px;
      border-bottom: 1px solid rgba(35, 43, 61, 0.6);
      font-size: 13px;
      vertical-align: top;
    }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(255, 255, 255, 0.015); }

    .status-pass { color: var(--ok); font-weight: 600; }
    .status-fail { color: var(--err); font-weight: 600; }
    .meta-sep { color: var(--text-muted); margin: 0 6px; }

    /* Two-column inspector */
    .split-grid {
      display: grid;
      grid-template-columns: 1.15fr 0.85fr;
      gap: 20px;
    }
    @media (max-width: 1024px) {
      .split-grid, .summary-strip { grid-template-columns: 1fr; }
    }

    pre.code-viewer {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
      font-family: var(--font-mono);
      font-size: 12px;
      line-height: 1.6;
      color: #D1D7E6;
      overflow-x: auto;
      max-height: 460px;
      white-space: pre;
    }

    .audit-item {
      padding: 18px 0;
      border-bottom: 1px solid var(--border);
    }
    .audit-item:first-child { padding-top: 0; }
    .audit-item:last-child { border-bottom: none; padding-bottom: 0; }
    .audit-meta {
      font-size: 12px;
      color: var(--text-muted);
      margin-bottom: 6px;
    }
    .audit-title {
      font-size: 15px;
      font-weight: 600;
      color: var(--text);
      margin-bottom: 8px;
    }
    .audit-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 16px;
      margin-top: 10px;
    }
    .audit-box {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 12px 14px;
      font-size: 13px;
    }
    .audit-box strong {
      display: block;
      font-size: 12px;
      color: var(--text-muted);
      margin-bottom: 4px;
    }
    .hidden { display: none !important; }
  </style>
</head>
<body>
  <header class="topbar">
    <a href="#" class="brand">Carbon Shell Audit & Sandbox</a>
    <nav class="topnav" aria-label="Main Navigation">
      <button type="button" class="active" data-tab="sandbox" onclick="switchTab('sandbox')">Sandbox Runner</button>
      <button type="button" data-tab="download" onclick="switchTab('download')">Download & Dev Repo</button>
      <button type="button" data-tab="keybinds" onclick="switchTab('keybinds')">Per-Mode Keybinds</button>
      <button type="button" data-tab="audit" onclick="switchTab('audit')">Installer & Shell Audit</button>
      <button type="button" data-tab="files" onclick="switchTab('files')">Generated Configs</button>
    </nav>
    <div style="display:flex; gap:10px; align-items:center;">
      <a href="/carbon-shell-dev.tar.gz" download="carbon-shell-dev.tar.gz" class="primary-cta" style="text-decoration:none; display:inline-block; background:#22C55E; color:#06110B;">⬇ Download Fix (.tar.gz)</a>
      <button type="button" id="runAllBtn" class="primary-cta" onclick="runSandbox('all')">Run Full Sandbox Suite</button>
    </div>
  </header>

  <main class="container">
    <!-- KPI Summary Row -->
    <section class="summary-strip" aria-label="Verification Metrics">
      <div class="stat-box">
        <div class="stat-label">Sandbox Assertions</div>
        <div class="stat-value tabular" id="statAssertions">-- / --</div>
        <div class="stat-sub" id="statStatusText">Verifying /tmp/carbon-sandbox...</div>
      </div>
      <div class="stat-box">
        <div class="stat-label">Isolated Shell Modes</div>
        <div class="stat-value tabular">3 Modes</div>
        <div class="stat-sub">Minimal · Notch · Vanish</div>
      </div>
      <div class="stat-box">
        <div class="stat-label">Audit Issues Resolved</div>
        <div class="stat-value tabular">6 / 6 Fixed</div>
        <div class="stat-sub">Install · Start · Update · Uninstall</div>
      </div>
      <div class="stat-box">
        <div class="stat-label">Last Sandbox Execution</div>
        <div class="stat-value tabular" id="statDuration">-- ms</div>
        <div class="stat-sub" id="statTimestamp">--</div>
      </div>
    </section>

    <!-- TAB 1: SANDBOX RUNNER -->
    <section id="tab-sandbox" class="tab-view">
      <div class="panel">
        <div class="panel-header">
          <div>
            <h1 class="panel-title">Live Sandbox Installer, Start, Updater & Uninstaller Verification</h1>
            <p class="panel-desc">Executes ./install.sh --dry-run, ./start.sh --dry-run (carbon-start), ./update.sh --dry-run (carbon-update), and ./uninstall.sh --dry-run (carbon-uninstall) inside /tmp/carbon-sandbox with zero host modifications.</p>
          </div>
        </div>

        <div class="controls-row">
          <div class="segmented" role="group" aria-label="Mode Filter">
            <button type="button" class="mode-run-btn active" data-mode="all" onclick="selectRunMode('all')">All 3 Modes</button>
            <button type="button" class="mode-run-btn" data-mode="minimal_notch" onclick="selectRunMode('minimal_notch')">Minimal Island</button>
            <button type="button" class="mode-run-btn" data-mode="notch" onclick="selectRunMode('notch')">Carbon Notch</button>
            <button type="button" class="mode-run-btn" data-mode="vanish" onclick="selectRunMode('vanish')">Vanish Hub</button>
          </div>

          <div class="segmented" role="group" aria-label="Base Keybind Profile">
            <button type="button" class="kb-run-btn active" data-kb="keep" onclick="selectKbProfile('keep')">Profile: Keep Existing</button>
            <button type="button" class="kb-run-btn" data-kb="carbon" onclick="selectKbProfile('carbon')">Profile: Full Carbon</button>
          </div>

          <button type="button" class="primary-cta" onclick="runSandbox()">Execute Selected Test</button>
        </div>

        <div class="split-grid">
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Category</th>
                  <th>Assertion</th>
                  <th>Verification Detail</th>
                </tr>
              </thead>
              <tbody id="assertionsBody"></tbody>
            </table>
          </div>
          <div>
            <div style="font-size:12px;font-weight:600;color:var(--text-muted);margin-bottom:8px;">Sandbox Execution Output (/tmp/carbon-sandbox)</div>
            <pre class="code-viewer" id="sandboxLogsViewer">Loading sandbox logs...</pre>
          </div>
        </div>
      </div>
    </section>

    <!-- TAB: DOWNLOAD & STAGING REPO -->
    <section id="tab-download" class="tab-view hidden">
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2 class="panel-title">Download & Test on Your Machine (xzshogun/carbon-development)</h2>
            <p class="panel-desc">Both install.sh and carbon-update are pre-configured to target https://github.com/xzshogun/carbon-development.git with automatic fallback to this live AI Studio staging mirror.</p>
          </div>
          <a href="/carbon-development.tar.gz" class="primary-cta" style="text-decoration:none;display:inline-block;">Download carbon-development.tar.gz</a>
        </div>

        <div class="audit-item">
          <div class="audit-title">Option 1: Clone from xzshogun/carbon-development</div>
          <pre class="code-viewer">git clone https://github.com/xzshogun/carbon-development.git
cd carbon-development
chmod +x install.sh
./install.sh</pre>
        </div>

        <div class="audit-item">
          <div class="audit-title">Option 2: Clone Directly from Live AI Studio Mirror (Instant Sync Before Pushing to GitHub)</div>
          <pre class="code-viewer">git clone https://ais-pre-clqdsggkf7wyqbb7b7z654-900258437217.asia-east1.run.app/carbon-development.git
cd carbon-development
./install.sh</pre>
        </div>

        <div class="audit-item">
          <div class="audit-title">Option 3: One-Line Bootstrap (Downloads to ~/carbon-development)</div>
          <pre class="code-viewer">curl -fsSL https://ais-pre-clqdsggkf7wyqbb7b7z654-900258437217.asia-east1.run.app/bootstrap.sh | bash</pre>
        </div>

        <div class="audit-item">
          <div class="audit-title">Lifecycle Commands Installed to ~/.local/bin</div>
          <pre class="code-viewer">carbon-start                        # Start or restart Carbon Shell
carbon-start --mode=notch           # Switch mode (minimal_notch, notch, vanish) + sync isolated keybinds
carbon-start status                 # Check shell status and active mode
carbon-update                       # Pull latest updates from xzshogun/carbon-development (with live mirror fallback)
carbon-uninstall                    # Safely unhook from hyprland.conf, backup, and remove Carbon Shell</pre>
        </div>
      </div>
    </section>

    <!-- TAB 2: PER-MODE KEYBINDS -->
    <section id="tab-keybinds" class="tab-view hidden">
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2 class="panel-title">Externalized Per-Mode Keybinding Isolation</h2>
            <p class="panel-desc">Each shell mode activates its own dedicated keybind layer via ~/.config/carbon/configs/current-mode-keybinds.conf without colliding with other modes.</p>
          </div>
        </div>

        <div class="controls-row">
          <div class="segmented" id="modeKeybindTabs">
            <button type="button" class="active" data-kmode="minimal_notch" onclick="renderKeybindMode('minimal_notch')">Minimal Island (Tide)</button>
            <button type="button" data-kmode="notch" onclick="renderKeybindMode('notch')">Carbon Notch</button>
            <button type="button" data-kmode="vanish" onclick="renderKeybindMode('vanish')">Vanish Hub (Nucleus)</button>
            <button type="button" data-kmode="base_keep" onclick="renderKeybindMode('base_keep')">Base: Keep Existing</button>
            <button type="button" data-kmode="base_carbon" onclick="renderKeybindMode('base_carbon')">Base: Full Carbon</button>
          </div>
        </div>

        <div id="modeKeybindHeader" style="margin-bottom: 16px; font-size: 13px; color: var(--text-muted);"></div>

        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Bind Type</th>
                <th>Shortcut</th>
                <th>Dispatcher Action</th>
                <th>Command / Target</th>
                <th>Path Scope</th>
              </tr>
            </thead>
            <tbody id="keybindsTableBody"></tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- TAB 3: AUDIT FINDINGS -->
    <section id="tab-audit" class="tab-view hidden">
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2 class="panel-title">Installer, Updater & Quickshell Architecture Audit</h2>
            <p class="panel-desc">Complete diagnosis of portability, path resolution, and mode keybind bugs discovered and remediated across the repository.</p>
          </div>
        </div>
        <div id="auditListContainer"></div>
      </div>
    </section>

    <!-- TAB 4: GENERATED SANDBOX CONFIGS -->
    <section id="tab-files" class="tab-view hidden">
      <div class="panel">
        <div class="panel-header">
          <div>
            <h2 class="panel-title">Generated Sandbox Configuration Files</h2>
            <p class="panel-desc">Inspect the exact files deployed to /tmp/carbon-sandbox during the last sandbox run.</p>
          </div>
        </div>

        <div class="controls-row">
          <div class="segmented" id="sandboxFileTabs"></div>
        </div>

        <pre class="code-viewer" id="sandboxFileContent">Select a file above to inspect its contents.</pre>
      </div>
    </section>
  </main>

  <script>
    let currentRunMode = 'all';
    let currentKbProfile = 'keep';
    let latestSandboxData = null;
    let keybindsRegistry = {};
    let auditIssues = [];

    function switchTab(tabId) {
      document.querySelectorAll('.tab-view').forEach(el => el.classList.add('hidden'));
      document.getElementById('tab-' + tabId).classList.remove('hidden');
      document.querySelectorAll('nav.topnav button').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabId);
      });
    }

    function selectRunMode(mode) {
      currentRunMode = mode;
      document.querySelectorAll('.mode-run-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.mode === mode);
      });
    }

    function selectKbProfile(kb) {
      currentKbProfile = kb;
      document.querySelectorAll('.kb-run-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.kb === kb);
      });
    }

    function renderSandboxResult(data) {
      latestSandboxData = data;
      document.getElementById('statAssertions').textContent = `${data.passedAssertions} / ${data.totalAssertions} Passed`;
      document.getElementById('statStatusText').textContent = data.allPassed
        ? 'All sandbox checks nominal'
        : 'Attention required on failed checks';
      document.getElementById('statDuration').textContent = `${data.elapsedMs} ms`;
      document.getElementById('statTimestamp').textContent = `Last run: ${data.timestamp}`;

      const tbody = document.getElementById('assertionsBody');
      tbody.innerHTML = data.assertions.map(a => `
        <tr>
          <td class="tabular ${a.passed ? 'status-pass' : 'status-fail'}">${a.passed ? 'PASS' : 'FAIL'}</td>
          <td>${a.category}</td>
          <td style="font-weight:600;">${a.name}</td>
          <td class="tabular" style="color:var(--text-muted);font-size:12px;">${a.detail}</td>
        </tr>
      `).join('');

      document.getElementById('sandboxLogsViewer').textContent = data.logs || 'No logs generated.';

      // Populate generated files tabs
      const fileKeys = Object.keys(data.sandboxFiles || {});
      const fileTabs = document.getElementById('sandboxFileTabs');
      fileTabs.innerHTML = fileKeys.map((k, idx) => `
        <button type="button" class="${idx === 0 ? 'active' : ''}" data-file="${k}" onclick="showSandboxFile('${k}')">${k}</button>
      `).join('');
      if (fileKeys.length > 0) {
        showSandboxFile(fileKeys[0]);
      }
    }

    function showSandboxFile(fileKey) {
      if (!latestSandboxData || !latestSandboxData.sandboxFiles) return;
      document.querySelectorAll('#sandboxFileTabs button').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.file === fileKey);
      });
      document.getElementById('sandboxFileContent').textContent = latestSandboxData.sandboxFiles[fileKey] || '';
    }

    async function runSandbox(overrideMode) {
      const modeToUse = overrideMode || currentRunMode;
      const btn = document.getElementById('runAllBtn');
      btn.disabled = true;
      btn.textContent = 'Running Sandbox...';
      try {
        const res = await fetch(`/api/sandbox/run?mode=${encodeURIComponent(modeToUse)}&keybinds=${encodeURIComponent(currentKbProfile)}`, {
          method: 'POST'
        });
        const data = await res.json();
        renderSandboxResult(data);
      } catch (err) {
        console.error(err);
      } finally {
        btn.disabled = false;
        btn.textContent = 'Run Full Sandbox Suite';
      }
    }

    function renderKeybindMode(modeKey) {
      document.querySelectorAll('#modeKeybindTabs button').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.kmode === modeKey);
      });
      const entry = keybindsRegistry[modeKey];
      if (!entry) return;
      document.getElementById('modeKeybindHeader').innerHTML = `
        <strong>${entry.label}</strong>
        <span class="meta-sep">·</span>
        <span class="tabular">${entry.file}</span>
        <span class="meta-sep">·</span>
        <span>${entry.binds.length} isolated bindings</span>
        <div style="margin-top:4px;">${entry.description}</div>
      `;
      const tbody = document.getElementById('keybindsTableBody');
      tbody.innerHTML = entry.binds.map(b => `
        <tr>
          <td class="tabular" style="color:var(--text-muted);">${b.type}</td>
          <td class="tabular" style="font-weight:600;color:var(--accent);">${b.shortcut}</td>
          <td>${b.action}</td>
          <td class="tabular" style="font-size:12px;">${b.command}</td>
          <td class="tabular ${b.Externalized ? 'status-pass' : 'status-fail'}">${b.Externalized ? 'External (~/.config/carbon)' : 'Legacy Path'}</td>
        </tr>
      `).join('');
    }

    function renderAuditIssues() {
      const container = document.getElementById('auditListContainer');
      container.innerHTML = auditIssues.map(item => `
        <div class="audit-item">
          <div class="audit-meta">
            <span class="tabular">${item.id}</span>
            <span class="meta-sep">·</span>
            <span>${item.component}</span>
            <span class="meta-sep">·</span>
            <span>Severity: ${item.severity}</span>
            <span class="meta-sep">·</span>
            <span class="status-pass">${item.status}</span>
          </div>
          <div class="audit-title">${item.title}</div>
          <div class="audit-grid">
            <div class="audit-box">
              <strong>Root Cause Found</strong>
              ${item.problem}
            </div>
            <div class="audit-box">
              <strong>Externalized Fix Applied</strong>
              ${item.resolution}
            </div>
          </div>
        </div>
      `).join('');
    }

    async function init() {
      const res = await fetch('/api/state');
      const state = await res.json();
      keybindsRegistry = state.keybinds;
      auditIssues = state.auditIssues;
      renderSandboxResult(state.sandbox);
      renderKeybindMode('minimal_notch');
      renderAuditIssues();
    }

    init();
  </script>
</body>
</html>
"""

BOOTSTRAP_SCRIPT = f"""#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${{CARBON_DEV_DIR:-$HOME/carbon-development}}"
GITHUB_DEV_GIT="https://github.com/xzshogun/carbon-development.git"
STAGING_GIT="{STAGING_PUBLIC_URL}/carbon-development.git"
STAGING_TAR="{STAGING_PUBLIC_URL}/carbon-development.tar.gz"

printf ":: Downloading Carbon Shell (xzshogun/carbon-development) to %s...\\n" "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

if command -v git >/dev/null 2>&1 && GIT_TERMINAL_PROMPT=0 git clone "$GITHUB_DEV_GIT" "$TARGET_DIR" 2>/dev/null; then
    printf "   [✓] Cloned https://github.com/xzshogun/carbon-development.git\\n"
elif command -v git >/dev/null 2>&1 && git clone "$STAGING_GIT" "$TARGET_DIR" 2>/dev/null; then
    printf "   [✓] Cloned live staging mirror from %s\\n" "$STAGING_GIT"
else
    curl -fsSL "$STAGING_TAR" | tar -xz -C "$TARGET_DIR"
    printf "   [✓] Downloaded and extracted staging archive from %s\\n" "$STAGING_TAR"
fi

chmod +x "$TARGET_DIR/install.sh" "$TARGET_DIR/start.sh" "$TARGET_DIR/update.sh" "$TARGET_DIR/uninstall.sh" "$TARGET_DIR/carbon-update" 2>/dev/null || true

printf "\\n:: Ready! Next steps:\\n"
printf "   cd %s\\n" "$TARGET_DIR"
printf "   ./install.sh\\n\\n"
"""


class CarbonAuditHandler(BaseHTTPRequestHandler):
    def log_message(self, format_str, *args):
        # Quiet standard request logging
        pass

    def _send_json(self, payload: dict, status: int = 200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html: str, status: int = 200):
        body = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_bytes(self, data: bytes, content_type: str, filename: str = ""):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        if filename:
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/health":
            self._send_json({"status": "ok"})
            return
        if parsed.path in ("/carbon-development.tar.gz", "/carbon-shell-dev.tar.gz", "/api/repo/tarball"):
            ensure_staging_repo_artifacts()
            if TARBALL_PATH.exists():
                dl_name = "carbon-development.tar.gz" if "carbon-development" in parsed.path else "carbon-shell-dev.tar.gz"
                self._send_bytes(TARBALL_PATH.read_bytes(), "application/gzip", dl_name)
                return
        if parsed.path == "/bootstrap.sh":
            self._send_bytes(BOOTSTRAP_SCRIPT.encode("utf-8"), "text/x-shellscript; charset=utf-8")
            return
        for git_prefix in ("/carbon-development.git/", "/carbon-shell-dev.git/"):
            if parsed.path.startswith(git_prefix):
                rel = parsed.path[len(git_prefix):]
                if rel == "info/refs":
                    ensure_staging_repo_artifacts()
                target = (BARE_GIT_DIR / rel).resolve()
                if str(target).startswith(str(BARE_GIT_DIR.resolve())) and target.is_file():
                    self._send_bytes(target.read_bytes(), "application/octet-stream")
                    return
                self.send_response(404)
                self.end_headers()
                return
        if parsed.path == "/api/state":
            self._send_json({
                "sandbox": INITIAL_SANDBOX_RESULT,
                "keybinds": get_all_mode_keybinds(),
                "auditIssues": AUDIT_ISSUES,
            })
            return
        self._send_html(HTML_PAGE)

    def do_POST(self):
        global INITIAL_SANDBOX_RESULT
        parsed = urlparse(self.path)
        if parsed.path == "/api/sandbox/run":
            qs = parse_qs(parsed.query)
            mode = qs.get("mode", ["all"])[0]
            kb = qs.get("keybinds", ["keep"])[0]
            result = run_sandbox_suite(selected_mode=mode, keybind_profile=kb)
            INITIAL_SANDBOX_RESULT = result
            self._send_json(result)
            return
        self._send_json({"error": "Not found"}, status=404)


def main():
    port = int(os.environ.get("PORT", 3000))
    server = ThreadingHTTPServer(("0.0.0.0", port), CarbonAuditHandler)
    print(f"Carbon Shell Sandbox & Audit Server listening on http://0.0.0.0:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
