#!/usr/bin/env python3
"""Derive the menu-bar template icon from `menubaricon.png`.

`menubaricon.png` is a dark glyph on an opaque white background. A macOS
menu-bar icon must be a *template* image: a silhouette whose shape is defined
by its alpha channel so the system can tint it for light/dark mode. This
script converts luminance to alpha (dark → opaque, white → transparent),
paints the glyph black, and downscales (aspect preserved) for a crisp render.

Run:  python3 scripts/make_menubar_icon.py
"""
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "menubaricon.png")
OUT = os.path.join(ROOT, "Sources", "DailySutra", "Resources", "MenubarIcon.png")
MAX_DIM = 128  # px; larger than any menubar render, small bundle

if not os.path.exists(SRC):
    sys.exit(f"missing source: {SRC}")

im = Image.open(SRC).convert("RGBA")
px = im.load()
w, h = im.size
for y in range(h):
    for x in range(w):
        r, g, b, _ = px[x, y]
        lum = (r + g + b) // 3            # source is grayscale; lum ~= each channel
        px[x, y] = (0, 0, 0, 255 - lum)   # dark glyph → opaque, white bg → transparent

# downscale preserving aspect, fit within MAX_DIM
scale = MAX_DIM / max(w, h)
if scale < 1:
    im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)

im.save(OUT)
print(f">> wrote {OUT}  ({im.size[0]}x{im.size[1]}, template)")