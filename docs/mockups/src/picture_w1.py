"""Sample hidden picture for world 1 level 3 (revealed inside captured crystal).

python3 picture_w1.py <out.png>
1008 x 1152 px = the field at 1 px per logic px. Style rules (DESIGN.md 7e): flat neon shapes,
2-4 px light outlines, world tint as the background, no ball coral and no beam gold.
"""

import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 1008, 1152
SS = 2


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main(out):
    img = Image.new("RGB", (W * SS, H * SS))
    d = ImageDraw.Draw(img)
    top, bot = (70, 112, 214), (128, 182, 255)  # world 1 tint ramp #4670D6 -> #80B6FF
    for y in range(H * SS):
        d.line([(0, y), (W * SS, y)], fill=lerp(top, bot, y / (H * SS)))
    s = SS
    random.seed(4)
    # stars: 4-point sparkles
    for _ in range(46):
        x, y = random.uniform(30, W - 30), random.uniform(30, H - 30)
        r = random.choice((6, 8, 10, 14))
        pts = [(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28),
               (x, y + r), (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28)]
        d.polygon([(px * s, py * s) for px, py in pts], fill=(240, 248, 255))
    # big ringed planet, centre-left
    cx, cy, R = 430, 640, 250
    ring_back = [cx - R * 1.75, cy - R * 0.42, cx + R * 1.75, cy + R * 0.42]
    d.ellipse([v * s for v in ring_back], outline=(226, 222, 255), width=26 * s)
    d.ellipse([(cx - R) * s, (cy - R) * s, (cx + R) * s, (cy + R) * s], fill=(63, 214, 200))
    # bands
    for i, (dy, w, c) in enumerate(((-150, 34, (30, 156, 152)), (-60, 50, (126, 240, 214)), (40, 30, (30, 156, 152)), (120, 44, (126, 240, 214)))):
        yy = cy + dy
        half = math.sqrt(max(R * R - dy * dy, 0))
        d.rounded_rectangle([(cx - half + 10) * s, (yy - w / 2) * s, (cx + half - 10) * s, (yy + w / 2) * s], radius=w * s // 2, fill=c)
    # re-mask planet edge with outline
    d.ellipse([(cx - R) * s, (cy - R) * s, (cx + R) * s, (cy + R) * s], outline=(236, 255, 250), width=8 * s)
    # front half of ring over the planet
    d.arc([v * s for v in ring_back], 0, 180, fill=(242, 240, 255), width=26 * s)
    # crescent moon top-right
    mx, my, mr = 820, 230, 110
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([(mx - mr) * s, (my - mr) * s, (mx + mr) * s, (my + mr) * s], fill=255)
    md.ellipse([(mx - mr + 52) * s, (my - mr - 30) * s, (mx + mr + 52) * s, (my + mr - 30) * s], fill=0)
    img.paste((244, 248, 255), (0, 0), mask)
    # small rocket bottom-right, flying up-left
    rx, ry = 800, 960
    body = [(0, -110), (40, -40), (40, 70), (-40, 70), (-40, -40)]
    rot = math.radians(-35)

    def tr(p):
        x, y = p
        return ((rx + x * math.cos(rot) - y * math.sin(rot)) * s, (ry + x * math.sin(rot) + y * math.cos(rot)) * s)

    fins = [[(-40, 20), (-80, 90), (-40, 70)], [(40, 20), (80, 90), (40, 70)]]
    flame = [(-24, 72), (0, 150), (24, 72)]
    d.polygon([tr(p) for p in flame], fill=(255, 244, 214))
    for f in fins:
        d.polygon([tr(p) for p in f], fill=(155, 168, 255))
    d.polygon([tr(p) for p in body], fill=(246, 249, 255), outline=(40, 60, 140), width=4 * s)
    wx, wy = tr((0, -20))
    d.ellipse([wx - 22 * s, wy - 22 * s, wx + 22 * s, wy + 22 * s], fill=(63, 214, 200), outline=(40, 60, 140), width=5 * s)
    img = img.resize((W, H), Image.LANCZOS).filter(ImageFilter.SMOOTH)
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
