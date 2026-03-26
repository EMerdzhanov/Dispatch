#!/usr/bin/env python3
"""Generate a polished DMG background image for Dispatch.

Creates a dark gradient background with double-chevron arrows
pointing from the app icon position to the Applications folder.

Note: create-dmg icon Y positions are offset ~22px from the background
image due to the Finder title bar. The arrow is drawn accounting for this.
"""

import os
from PIL import Image, ImageDraw

# DMG window dimensions (must match build-dmg.sh --window-size)
WIDTH = 600
HEIGHT = 400

# Icon positions in create-dmg coordinates (matching build-dmg.sh)
APP_X = 150
DROP_X = 450
ICON_Y = 190

# Title bar offset: create-dmg Y coords are relative to window content,
# but the background image covers the full window including title bar area.
TITLE_BAR_OFFSET = 22
ARROW_Y = ICON_Y + TITLE_BAR_OFFSET

# Colors
BG_TOP = (30, 30, 35)
BG_BOTTOM = (18, 18, 22)
CHEVRON_COLOR = (120, 120, 130)


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient(draw, width, height, top, bottom):
    for y in range(height):
        t = y / height
        color = lerp_color(top, bottom, t)
        draw.line([(0, y), (width, y)], fill=color)


def draw_chevron(draw, cx, cy, size, thickness, color):
    """Draw a single > chevron centered at (cx, cy)."""
    half = size // 2
    for t in range(-thickness // 2, thickness // 2 + 1):
        # Upper arm: from left-center to right-tip
        draw.line([(cx - half, cy - half + t), (cx + half, cy + t)], fill=color)
        # Lower arm: from right-tip to left-center
        draw.line([(cx + half, cy + t), (cx - half, cy + half + t)], fill=color)


def draw_double_chevron(draw, x, y):
    """Draw a >> double chevron between the two icon positions."""
    center_x = (APP_X + DROP_X) // 2
    spacing = 22
    size = 16
    thickness = 3

    draw_chevron(draw, center_x - spacing // 2, y, size, thickness, CHEVRON_COLOR)
    draw_chevron(draw, center_x + spacing // 2, y, size, thickness, CHEVRON_COLOR)


def main():
    img = Image.new("RGB", (WIDTH, HEIGHT))
    draw = ImageDraw.Draw(img)

    draw_gradient(draw, WIDTH, HEIGHT, BG_TOP, BG_BOTTOM)
    draw_double_chevron(draw, 0, ARROW_Y)

    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "dmg")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "background.png")
    img.save(out_path, "PNG")
    print(f"Background saved to {out_path}")


if __name__ == "__main__":
    main()
