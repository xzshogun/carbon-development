#!/usr/bin/env python3
"""
Carbon Tile Cropper — Interactive Region Selector for Blank Tile
Allows users to select any region of an image (with locked 4.75:1 tile ratio or freeform),
crops the image with PIL, and saves it for Quickshell's blank tile.
"""

import os
import sys
import time
from PIL import Image as PILImage

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gtk, Adw, Gdk, GdkPixbuf, GLib

CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
HYPR_DIR = os.path.expanduser("~/.config/hypr")

BLANK_TILE_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-blank-tile.json")
BLANK_TILE_CROP_PATH = os.path.join(CONFIG_DIR, "blank-tile-crop.png")
BLANK_TILE_HYPR_PATH = os.path.join(HYPR_DIR, "carbon-blank-tile.json")
BLANK_TILE_HYPR_CROP_PATH = os.path.join(HYPR_DIR, "blank-tile-crop.png")


class ImageCropDialog(Gtk.Window):
    def __init__(self, parent_window, image_path, initial_rect=None, accent_hex="#e1b68e", on_apply=None):
        super().__init__(title="Select Region for Blank Tile", transient_for=parent_window, modal=True)
        self.set_default_size(920, 680)
        self.image_path = os.path.abspath(image_path)
        self.accent_hex = accent_hex
        self.on_apply = on_apply

        try:
            self.pil_img = PILImage.open(self.image_path)
            self.orig_w, self.orig_h = self.pil_img.size
        except Exception as e:
            print("[CropDialog] Error opening image:", e)
            return

        # Target Tile Aspect Ratio (standard ~4.744)
        self.tile_aspect = 408.0 / 86.0
        self.lock_aspect = True

        # Crop rect in original image pixel coords: [x, y, w, h]
        if initial_rect and initial_rect.get("width", 0) > 10 and initial_rect.get("height", 0) > 10:
            self.crop_x = max(0, min(self.orig_w - 10, int(initial_rect["x"])))
            self.crop_y = max(0, min(self.orig_h - 10, int(initial_rect["y"])))
            self.crop_w = max(10, min(self.orig_w - self.crop_x, int(initial_rect["width"])))
            self.crop_h = max(10, min(self.orig_h - self.crop_y, int(initial_rect["height"])))
        else:
            # Default to an aesthetic horizontal slice centered in image
            if (self.orig_w / self.orig_h) > self.tile_aspect:
                self.crop_h = max(30, int(self.orig_h * 0.65))
                self.crop_w = int(round(self.crop_h * self.tile_aspect))
            else:
                self.crop_w = max(30, int(self.orig_w * 0.85))
                self.crop_h = int(round(self.crop_w / self.tile_aspect))
            self.crop_x = max(0, (self.orig_w - self.crop_w) // 2)
            self.crop_y = max(0, (self.orig_h - self.crop_h) // 2)

        # Transformation cache for drawing area
        self.draw_scale = 1.0
        self.offset_x = 0
        self.offset_y = 0
        self.pixbuf = None
        self.cached_pw = 0
        self.cached_ph = 0

        # Mouse interaction
        self.drag_mode = None  # None, "move", "nw", "ne", "sw", "se", "n", "s", "e", "w", "new"
        self.drag_start_x = 0
        self.drag_start_y = 0
        self.start_crop_rect = (0, 0, 0, 0)

        self.build_ui()

    def build_ui(self):
        root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root_box)

        # ── Header Bar ──────────────────────────────────────────────
        header = Adw.HeaderBar()
        header.set_show_end_title_buttons(False)
        header.set_show_start_title_buttons(False)

        btn_cancel = Gtk.Button(label="Cancel")
        btn_cancel.connect("clicked", lambda b: self.close())
        header.pack_start(btn_cancel)

        # Center Title & Ratio Switcher
        title_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        t_lbl = Gtk.Label(label="Select Region")
        t_lbl.add_css_class("heading")
        title_box.append(t_lbl)

        # Ratio Mode Buttons
        self.btn_ratio_lock = Gtk.CheckButton(label="Lock Tile Ratio (4.75:1)")
        self.btn_ratio_lock.set_active(True)
        self.btn_ratio_lock.connect("toggled", self.on_ratio_toggled)
        title_box.append(self.btn_ratio_lock)

        header.set_title_widget(title_box)

        btn_apply = Gtk.Button(label="Apply Crop")
        btn_apply.add_css_class("suggested-action")
        btn_apply.connect("clicked", self.on_apply_crop)
        header.pack_end(btn_apply)

        root_box.append(header)

        # ── Info / Instruction Bar ──────────────────────────────────
        info_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        info_bar.set_margin_start(16)
        info_bar.set_margin_end(16)
        info_bar.set_margin_top(8)
        info_bar.set_margin_bottom(8)

        lbl_hint = Gtk.Label(label="Drag the box to move it. Drag handles to resize. Click & drag anywhere to draw a new region.")
        lbl_hint.set_hexpand(True)
        lbl_hint.set_halign(Gtk.Align.START)
        lbl_hint.add_css_class("dim-label")
        info_bar.append(lbl_hint)

        self.lbl_dims = Gtk.Label(label=f"Selected: {self.crop_w} × {self.crop_h} px")
        self.lbl_dims.add_css_class("accent-label")
        info_bar.append(self.lbl_dims)

        root_box.append(info_bar)

        # ── Interactive Canvas ──────────────────────────────────────
        self.drawing_area = Gtk.DrawingArea()
        self.drawing_area.set_vexpand(True)
        self.drawing_area.set_hexpand(True)
        self.drawing_area.set_draw_func(self.on_draw)

        # Gesture controllers
        self.drag_gesture = Gtk.GestureDrag.new()
        self.drag_gesture.connect("drag-begin", self.on_drag_begin)
        self.drag_gesture.connect("drag-update", self.on_drag_update)
        self.drag_gesture.connect("drag-end", self.on_drag_end)
        self.drawing_area.add_controller(self.drag_gesture)

        self.motion_controller = Gtk.EventControllerMotion.new()
        self.motion_controller.connect("motion", self.on_mouse_motion)
        self.drawing_area.add_controller(self.motion_controller)

        root_box.append(self.drawing_area)

    def on_ratio_toggled(self, btn):
        self.lock_aspect = btn.get_active()
        if self.lock_aspect:
            # Re-align current crop rect to tile ratio
            self.crop_h = max(10, int(round(self.crop_w / self.tile_aspect)))
            if self.crop_y + self.crop_h > self.orig_h:
                self.crop_h = self.orig_h - self.crop_y
                self.crop_w = int(round(self.crop_h * self.tile_aspect))
            self.lbl_dims.set_text(f"Selected: {self.crop_w} × {self.crop_h} px")
            self.drawing_area.queue_draw()

    def get_screen_rect(self):
        """Converts original image coords to drawing area canvas pixel coords."""
        sx = self.offset_x + self.crop_x * self.draw_scale
        sy = self.offset_y + self.crop_y * self.draw_scale
        sw = self.crop_w * self.draw_scale
        sh = self.crop_h * self.draw_scale
        return sx, sy, sw, sh

    def hit_test_handle(self, mx, my, sx, sy, sw, sh):
        """Returns handle id if cursor is close to a handle, or 'inside' or None."""
        radius = 12
        corners = {
            "nw": (sx, sy),
            "ne": (sx + sw, sy),
            "sw": (sx, sy + sh),
            "se": (sx + sw, sy + sh),
            "n": (sx + sw / 2, sy),
            "s": (sx + sw / 2, sy + sh),
            "w": (sx, sy + sh / 2),
            "e": (sx + sw / 2, sy + sh / 2),
        }
        for h_name, (hx, hy) in corners.items():
            if abs(mx - hx) <= radius and abs(my - hy) <= radius:
                return h_name

        if sx <= mx <= sx + sw and sy <= my <= sy + sh:
            return "inside"
        return None

    def on_mouse_motion(self, controller, x, y):
        sx, sy, sw, sh = self.get_screen_rect()
        hit = self.hit_test_handle(x, y, sx, sy, sw, sh)
        cursor_name = "default"
        if hit in ("nw", "se"):
            cursor_name = "nwse-resize"
        elif hit in ("ne", "sw"):
            cursor_name = "nesw-resize"
        elif hit in ("n", "s"):
            cursor_name = "ns-resize"
        elif hit in ("w", "e"):
            cursor_name = "ew-resize"
        elif hit == "inside":
            cursor_name = "move"
        else:
            cursor_name = "crosshair"
        self.set_cursor_from_name(cursor_name)

    def on_drag_begin(self, gesture, start_x, start_y):
        sx, sy, sw, sh = self.get_screen_rect()
        hit = self.hit_test_handle(start_x, start_y, sx, sy, sw, sh)
        self.drag_start_x = start_x
        self.drag_start_y = start_y
        self.start_crop_rect = (self.crop_x, self.crop_y, self.crop_w, self.crop_h)

        if hit == "inside":
            self.drag_mode = "move"
        elif hit in ("nw", "ne", "sw", "se", "n", "s", "w", "e"):
            self.drag_mode = hit
        else:
            # Clicked outside: start drawing new selection box
            self.drag_mode = "new"
            ix = max(0, min(self.orig_w - 1, int((start_x - self.offset_x) / self.draw_scale)))
            iy = max(0, min(self.orig_h - 1, int((start_y - self.offset_y) / self.draw_scale)))
            self.crop_x = ix
            self.crop_y = iy
            self.crop_w = 10
            self.crop_h = 10
            self.drawing_area.queue_draw()

    def on_drag_update(self, gesture, offset_x, offset_y):
        if not self.drag_mode or self.draw_scale <= 0:
            return

        dx_img = offset_x / self.draw_scale
        dy_img = offset_y / self.draw_scale
        ox, oy, ow, oh = self.start_crop_rect

        if self.drag_mode == "move":
            new_x = int(round(ox + dx_img))
            new_y = int(round(oy + dy_img))
            self.crop_x = max(0, min(self.orig_w - self.crop_w, new_x))
            self.crop_y = max(0, min(self.orig_h - self.crop_h, new_y))

        elif self.drag_mode == "new":
            cur_x = self.drag_start_x + offset_x
            cur_y = self.drag_start_y + offset_y
            ix1 = max(0, min(self.orig_w, int((self.drag_start_x - self.offset_x) / self.draw_scale)))
            iy1 = max(0, min(self.orig_h, int((self.drag_start_y - self.offset_y) / self.draw_scale)))
            ix2 = max(0, min(self.orig_w, int((cur_x - self.offset_x) / self.draw_scale)))
            iy2 = max(0, min(self.orig_h, int((cur_y - self.offset_y) / self.draw_scale)))

            nw = abs(ix2 - ix1)
            nh = abs(iy2 - iy1)
            if self.lock_aspect:
                nh = max(10, int(round(nw / self.tile_aspect)))

            self.crop_x = min(ix1, ix2)
            self.crop_y = min(iy1, iy2)
            self.crop_w = max(20, min(self.orig_w - self.crop_x, nw))
            self.crop_h = max(20, min(self.orig_h - self.crop_y, nh))

        else:
            # Handle resizing
            nx, ny, nw, nh = ox, oy, ow, oh
            if "e" in self.drag_mode:
                nw = max(20, min(self.orig_w - ox, int(round(ow + dx_img))))
            if "w" in self.drag_mode:
                cand_w = max(20, int(round(ow - dx_img)))
                shift_x = ow - cand_w
                nx = max(0, ox + shift_x)
                nw = ow + (ox - nx)
            if "s" in self.drag_mode:
                nh = max(20, min(self.orig_h - oy, int(round(oh + dy_img))))
            if "n" in self.drag_mode:
                cand_h = max(20, int(round(oh - dy_img)))
                shift_y = oh - cand_h
                ny = max(0, oy + shift_y)
                nh = oh + (oy - ny)

            if self.lock_aspect:
                if self.drag_mode in ("e", "w"):
                    nh = max(20, min(self.orig_h - ny, int(round(nw / self.tile_aspect))))
                else:
                    nw = max(20, min(self.orig_w - nx, int(round(nh * self.tile_aspect))))

            self.crop_x = nx
            self.crop_y = ny
            self.crop_w = nw
            self.crop_h = nh

        self.lbl_dims.set_text(f"Selected: {self.crop_w} × {self.crop_h} px")
        self.drawing_area.queue_draw()

    def on_drag_end(self, gesture, offset_x, offset_y):
        self.drag_mode = None

    def on_draw(self, area, cr, w, h):
        if w <= 0 or h <= 0 or self.orig_w <= 0 or self.orig_h <= 0:
            return

        # Calculate best fit scale
        margin = 16
        avail_w = max(50, w - margin * 2)
        avail_h = max(50, h - margin * 2)
        scale = min(avail_w / self.orig_w, avail_h / self.orig_h)
        self.draw_scale = scale

        disp_w = int(round(self.orig_w * scale))
        disp_h = int(round(self.orig_h * scale))
        self.offset_x = (w - disp_w) // 2
        self.offset_y = (h - disp_h) // 2

        # Cache scaled Pixbuf
        if self.pixbuf is None or self.cached_pw != disp_w or self.cached_ph != disp_h:
            try:
                base_pb = GdkPixbuf.Pixbuf.new_from_file(self.image_path)
                self.pixbuf = base_pb.scale_simple(disp_w, disp_h, GdkPixbuf.InterpType.BILINEAR)
                self.cached_pw = disp_w
                self.cached_ph = disp_h
            except Exception as e:
                print("[CropDialog] Pixbuf scale error:", e)

        # 1. Dark canvas background
        cr.set_source_rgb(0.06, 0.06, 0.08)
        cr.paint()

        # 2. Paint scaled source image
        if self.pixbuf:
            Gdk.cairo_set_source_pixbuf(cr, self.pixbuf, self.offset_x, self.offset_y)
            cr.paint()

        # 3. Semi-transparent dark mask over unselected region
        sx, sy, sw, sh = self.get_screen_rect()

        cr.set_source_rgba(0.0, 0.0, 0.0, 0.65)
        # Top mask
        cr.rectangle(self.offset_x, self.offset_y, disp_w, max(0, sy - self.offset_y))
        # Bottom mask
        cr.rectangle(self.offset_x, sy + sh, disp_w, max(0, (self.offset_y + disp_h) - (sy + sh)))
        # Left mask
        cr.rectangle(self.offset_x, sy, max(0, sx - self.offset_x), sh)
        # Right mask
        cr.rectangle(sx + sw, sy, max(0, (self.offset_x + disp_w) - (sx + sw)), sh)
        cr.fill()

        # 4. Crop Box Border
        cr.set_line_width(2.0)
        cr.set_source_rgba(0.37, 0.92, 0.83, 0.95)  # Teal accent
        cr.rectangle(sx, sy, sw, sh)
        cr.stroke()

        # 5. Rule-of-thirds grid lines
        cr.set_line_width(0.75)
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.22)
        # Verticals
        cr.move_to(sx + sw / 3.0, sy)
        cr.line_to(sx + sw / 3.0, sy + sh)
        cr.move_to(sx + 2.0 * sw / 3.0, sy)
        cr.line_to(sx + 2.0 * sw / 3.0, sy + sh)
        # Horizontals
        cr.move_to(sx, sy + sh / 3.0)
        cr.line_to(sx + sw, sy + sh / 3.0)
        cr.move_to(sx, sy + 2.0 * sh / 3.0)
        cr.line_to(sx + sw, sy + 2.0 * sh / 3.0)
        cr.stroke()

        # 6. Corner & edge handle squares
        handle_size = 9.0
        hs2 = handle_size / 2.0
        handles = [
            (sx - hs2, sy - hs2),
            (sx + sw - hs2, sy - hs2),
            (sx - hs2, sy + sh - hs2),
            (sx + sw - hs2, sy + sh - hs2),
            (sx + sw / 2 - hs2, sy - hs2),
            (sx + sw / 2 - hs2, sy + sh - hs2),
            (sx - hs2, sy + sh / 2 - hs2),
            (sx + sw - hs2, sy + sh / 2 - hs2),
        ]
        cr.set_source_rgb(1.0, 1.0, 1.0)
        for hx, hy in handles:
            cr.rectangle(hx, hy, handle_size, handle_size)
            cr.fill()

    def on_apply_crop(self, btn):
        # Crop the high-res image with PIL
        try:
            x1 = max(0, min(self.orig_w, self.crop_x))
            y1 = max(0, min(self.orig_h, self.crop_y))
            x2 = max(x1 + 10, min(self.orig_w, self.crop_x + self.crop_w))
            y2 = max(y1 + 10, min(self.orig_h, self.crop_y + self.crop_h))

            cropped = self.pil_img.crop((x1, y1, x2, y2))

            # Ensure target config directories exist
            os.makedirs(CONFIG_DIR, exist_ok=True)
            os.makedirs(HYPR_DIR, exist_ok=True)

            # Save cropped PNG
            cropped.save(BLANK_TILE_CROP_PATH, format="PNG")
            if BLANK_TILE_HYPR_CROP_PATH != BLANK_TILE_CROP_PATH:
                cropped.save(BLANK_TILE_HYPR_CROP_PATH, format="PNG")

            cfg = {
                "enabled": True,
                "imagePath": self.image_path,
                "cropPath": BLANK_TILE_CROP_PATH,
                "cropRect": {"x": x1, "y": y1, "width": x2 - x1, "height": y2 - y1},
                "opacity": 1.0,
                "timestamp": int(time.time() * 1000)
            }

            import json
            with open(BLANK_TILE_CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2)
            if BLANK_TILE_HYPR_PATH != BLANK_TILE_CONFIG_PATH:
                with open(BLANK_TILE_HYPR_PATH, "w", encoding="utf-8") as f:
                    json.dump(cfg, f, indent=2)

            if self.on_apply:
                self.on_apply(cfg)

            try:
                import socket
                sock_path = "/tmp/carbon-shell.sock"
                if os.path.exists(sock_path):
                    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                        s.settimeout(0.5)
                        s.connect(sock_path)
                        s.sendall(b"reload-blank-tile\n")
            except Exception:
                pass

            self.close()

        except Exception as e:
            print("[CropDialog] Error applying crop:", e)
