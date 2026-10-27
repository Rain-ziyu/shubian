"""Regenerate the original UV-space mineral emission mask (requires Pillow)."""
from math import cos, pi, sin
from pathlib import Path

from PIL import Image


def smooth(a, b, value):
    t = max(0, min(1, (value - a) / (b - a)))
    return t * t * (3 - 2 * t)


image = Image.new("RGB", (256, 256))
for y in range(256):
    v = y / 255
    for x in range(256):
        angle = x / 255 * 2 * pi
        crown = smooth(-0.15, 0.85, cos(angle))
        vein = (0.5 + 0.5 * cos(v * 2 * pi * 5.3 + 0.22 * sin(angle))) ** 14
        ends = smooth(0.025, 0.13, v) * (1 - smooth(0.87, 0.975, v))
        rim = smooth(0.88, 0.99, cos(angle))
        value = (0.025 + 0.62 * vein * (0.25 + 0.75 * crown) + 0.24 * rim) * ends
        shade = round(255 * min(1, value))
        image.putpixel((x, y), (shade, shade, shade))

output = Path(__file__).resolve().parents[1] / "assets/textures/creature/stormcrest-energy-mask.png"
output.parent.mkdir(parents=True, exist_ok=True)
image.save(output)
