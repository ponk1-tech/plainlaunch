#!/usr/bin/env python3
"""
Generates PlainLaunch's App Store icon: a black square with four left-aligned white bars of
decreasing width, evoking the app's own widget (a short list of plain text rows). No text, no
borrowed logos, pure geometry so it stays legible at 40x40 down to 1024x1024.

Apple no longer wants pre-rounded/alpha icons (App Store Connect rounds/masks the 1024 upload
itself), so every generated PNG here is a flat opaque square with no alpha channel and no corner
rounding — Xcode/App Store Connect applies the mask at render time.
"""
import math
import os

from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "PlainLaunch", "Resources", "Assets.xcassets", "AppIcon.appiconset")

SIZES = {
    "icon-40.png": 40,
    "icon-60.png": 60,
    "icon-58.png": 58,
    "icon-87.png": 87,
    "icon-80.png": 80,
    "icon-120.png": 120,
    "icon-120-60.png": 120,
    "icon-180.png": 180,
    "icon-1024.png": 1024,
}

BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)

# Bars are drawn at a fixed 1024 canvas, then resized down — keeps proportions identical
# across every exported size.
CANVAS = 1024


def render(size: int) -> Image.Image:
    scale = size / CANVAS
    img = Image.new("RGB", (CANVAS, CANVAS), BLACK[:3])
    draw = ImageDraw.Draw(img)

    margin = 220
    bar_height = 84
    gap = 66
    widths = [584, 584, 424, 264]  # decreasing widths, like a short left-aligned text list
    total_height = len(widths) * bar_height + (len(widths) - 1) * gap
    start_y = (CANVAS - total_height) // 2
    radius = bar_height / 2

    y = start_y
    for w in widths:
        rect = [margin, y, margin + w, y + bar_height]
        draw.rounded_rectangle(rect, radius=radius, fill=WHITE[:3])
        y += bar_height + gap

    if scale != 1.0:
        img = img.resize((size, size), Image.LANCZOS)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for filename, size in SIZES.items():
        img = render(size)
        path = os.path.join(OUT_DIR, filename)
        img.save(path, "PNG")
        print(f"wrote {path} ({size}x{size})")


if __name__ == "__main__":
    main()
