"""Original restrained metal albedo/roughness maps; regenerate with Pillow."""
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

random = Random(7831)
coarse = Image.new("L", (16, 16))
coarse.putdata([random.randrange(256) for _ in range(256)])
coarse = coarse.resize((256, 256), Image.Resampling.BICUBIC)
albedo = Image.new("RGB", (256, 256))
roughness = Image.new("L", (256, 256))
for y in range(256):
    for x in range(256):
        grain = random.uniform(-1, 1)
        patina = coarse.getpixel((x, y)) / 255
        value = round(239 + 12 * patina + grain * 2)
        albedo.putpixel((x, y), (value, value, value))
        roughness.putpixel((x, y), round(175 + 65 * patina + grain * 6))

color_lines = ImageDraw.Draw(albedo)
rough_lines = ImageDraw.Draw(roughness)
for _ in range(85):
    x, y = random.randrange(256), random.randrange(256)
    dx, dy = random.randrange(-8, 9), random.randrange(4, 25)
    color_lines.line((x, y, x + dx, y + dy), fill=(250, 250, 250))
    rough_lines.line((x, y, x + dx, y + dy), fill=random.randrange(150, 185))

output = Path(__file__).resolve().parents[1] / "assets/textures/armor"
output.mkdir(parents=True, exist_ok=True)
albedo.save(output / "ranger-metal-albedo.png")
roughness.save(output / "ranger-metal-roughness.png")
