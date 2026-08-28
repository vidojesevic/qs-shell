#!/usr/bin/env python3
"""Set Helium (Chromium) seed color in Preferences. Usage: helium.py '#rrggbb' [prefs]
Chromium reads this at startup and rewrites it on exit, so run only while the
browser is closed."""
import json, sys, os

color = sys.argv[1].lstrip("#")
prefs = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(
    "~/.config/net.imput.helium/Default/Preferences")

argb = 0xFF000000 | int(color, 16)
if argb >= 0x80000000:          # SkColor stored as signed 32-bit int
    argb -= 0x100000000

with open(prefs) as f:
    d = json.load(f)
t = d.setdefault("browser", {}).setdefault("theme", {})
t["user_color"] = argb
t["color_variant"] = 1          # tonal spot
t["is_grayscale2"] = False
t["follows_system_colors"] = False
with open(prefs, "w") as f:
    json.dump(d, f, separators=(",", ":"))
