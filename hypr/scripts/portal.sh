#!/usr/bin/env bash
# ==============================================================================
#  Wayland Portal Startup Script for Hyprland
#  Ensures PipeWire and xdg-desktop-portal-hyprland start cleanly for Screen Casting
# ==============================================================================

sleep 1
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland HYPRLAND_INSTANCE_SIGNATURE

systemctl --user stop pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk 2>/dev/null || true
systemctl --user start pipewire wireplumber
sleep 0.5
systemctl --user start xdg-desktop-portal-hyprland
sleep 0.5
systemctl --user start xdg-desktop-portal
