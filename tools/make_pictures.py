"""Hidden pictures for world 1 levels 1, 2, 4 and 5 (level 3 comes from docs/mockups/src/picture_w1.py).

python3 tools/make_pictures.py [out_dir]
1008 x 1152 px = the field at 1 px per logic px. Same style rules as the level 3 sample
(DESIGN.md 7e): flat friendly space shapes with light outlines, the world 1 crystal tint as a
vertical ramp, white 4-point sparkles, no ball coral and no beam gold at full strength.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

W, H = 1008, 1152
SS = 2
TOP, BOT = (70, 112, 214), (128, 182, 255)
WHITE = (244, 248, 255)
OUTLINE = (40, 60, 140)
TEAL = (63, 214, 200)
TEAL_DARK = (30, 156, 152)
TEAL_LIGHT = (126, 240, 214)
LILAC = (155, 168, 255)
CREAM = (255, 244, 214)
GREY = (196, 206, 232)
GREY_DARK = (140, 152, 196)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def canvas(seed: int, stars: int = 46):
    img = Image.new("RGB", (W * SS, H * SS))
    d = ImageDraw.Draw(img)
    for y in range(H * SS):
        d.line([(0, y), (W * SS, y)], fill=lerp(TOP, BOT, y / (H * SS)))
    rnd = random.Random(seed)
    for _ in range(stars):
        sparkle(d, rnd.uniform(30, W - 30), rnd.uniform(30, H - 30), rnd.choice((6, 8, 10, 14)))
    return img, d


def sparkle(d, x, y, r, fill=WHITE):
    s = SS
    pts = [
        (x, y - r),
        (x + r * 0.28, y - r * 0.28),
        (x + r, y),
        (x + r * 0.28, y + r * 0.28),
        (x, y + r),
        (x - r * 0.28, y + r * 0.28),
        (x - r, y),
        (x - r * 0.28, y - r * 0.28),
    ]
    d.polygon([(px * s, py * s) for px, py in pts], fill=fill)


def circle(d, cx, cy, r, fill=None, outline=None, width=0):
    s = SS
    d.ellipse(
        [(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s],
        fill=fill,
        outline=outline,
        width=int(width * s),
    )


def poly(d, pts, fill=None, outline=None, width=0, rot=0.0, at=(0.0, 0.0)):
    s = SS
    c, n = math.cos(rot), math.sin(rot)
    out = [((at[0] + x * c - y * n) * s, (at[1] + x * n + y * c) * s) for x, y in pts]
    d.polygon(out, fill=fill, outline=outline, width=int(width * s))


def save(img, out: Path):
    img.resize((W, H), Image.LANCZOS).filter(ImageFilter.SMOOTH).save(out)
    print("wrote", out)


def rocket(out: Path):
    """Level 1: a rocket lifting off from a small moon, puffy smoke trail."""
    img, d = canvas(11)
    # small moon hill at the bottom
    circle(d, 504, 1560, 640, fill=GREY, outline=WHITE, width=8)
    for cx, cy, r in ((300, 1010, 50), (700, 1060, 70), (520, 1120, 36)):
        circle(d, cx, cy, r, fill=GREY_DARK)
    # smoke puffs
    for cx, cy, r in ((470, 930, 90), (560, 950, 80), (400, 990, 70), (640, 1000, 64)):
        circle(d, cx, cy, r, fill=WHITE)
    rx, ry = 512, 520
    flame = [(-44, 230), (0, 380), (44, 230)]
    poly(d, flame, fill=CREAM, at=(rx, ry))
    poly(d, [(-28, 230), (0, 320), (28, 230)], fill=(255, 255, 240), at=(rx, ry))
    fins = [[(-90, 120), (-170, 250), (-90, 230)], [(90, 120), (170, 250), (90, 230)]]
    for f in fins:
        poly(d, f, fill=LILAC, outline=OUTLINE, width=5, at=(rx, ry))
    body = [(0, -260), (60, -170), (90, -40), (90, 230), (-90, 230), (-90, -40), (-60, -170)]
    poly(d, body, fill=WHITE, outline=OUTLINE, width=6, at=(rx, ry))
    poly(d, [(0, -260), (60, -170), (-60, -170)], fill=TEAL, outline=OUTLINE, width=5, at=(rx, ry))
    circle(d, rx, ry - 40, 46, fill=TEAL, outline=OUTLINE, width=7)
    circle(d, rx - 12, ry - 52, 14, fill=TEAL_LIGHT)
    d.rectangle([(rx - 90) * SS, (ry + 120) * SS, (rx + 90) * SS, (ry + 150) * SS], fill=LILAC)
    save(img, out)


def satellite(out: Path):
    """Level 2: a friendly satellite with two solar wings over a crescent moon."""
    img, d = canvas(22)
    # crescent moon bottom-left
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    mx, my, mr = 250, 900, 190
    md.ellipse([(mx - mr) * SS, (my - mr) * SS, (mx + mr) * SS, (my + mr) * SS], fill=255)
    md.ellipse(
        [(mx - mr + 90) * SS, (my - mr - 50) * SS, (mx + mr + 90) * SS, (my + mr - 50) * SS],
        fill=0,
    )
    img.paste(WHITE, (0, 0), mask)
    d = ImageDraw.Draw(img)
    cx, cy, rot = 560, 470, math.radians(-18)
    for side in (-1, 1):
        x0 = side * 120
        x1 = side * 400
        panel = [(x0, -80), (x1, -80), (x1, 80), (x0, 80)]
        poly(d, panel, fill=(88, 120, 230), outline=WHITE, width=6, rot=rot, at=(cx, cy))
        for k in range(1, 4):
            xs = x0 + (x1 - x0) * k / 4
            poly(
                d,
                [(xs - 2, -80), (xs + 2, -80), (xs + 2, 80), (xs - 2, 80)],
                fill=WHITE,
                rot=rot,
                at=(cx, cy),
            )
        poly(
            d,
            [(side * 70, -10), (x0, -10), (x0, 10), (side * 70, 10)],
            fill=GREY,
            rot=rot,
            at=(cx, cy),
        )
    body = [(-90, -110), (90, -110), (90, 110), (-90, 110)]
    poly(d, body, fill=CREAM, outline=OUTLINE, width=6, rot=rot, at=(cx, cy))
    poly(
        d,
        [(-60, 110), (60, 110), (90, 170), (-90, 170)],
        fill=GREY,
        outline=OUTLINE,
        width=5,
        rot=rot,
        at=(cx, cy),
    )
    # dish
    dx, dy = cx + 30, cy - 200
    d.chord(
        [(dx - 90) * SS, (dy - 60) * SS, (dx + 90) * SS, (dy + 60) * SS],
        180,
        360,
        fill=WHITE,
        outline=OUTLINE,
        width=5 * SS,
    )
    d.line([(dx) * SS, (dy) * SS, (cx + 10) * SS, (cy - 110) * SS], fill=OUTLINE, width=8 * SS)
    circle(d, dx, dy - 40, 12, fill=TEAL)
    circle(d, cx, cy, 34, fill=TEAL, outline=OUTLINE, width=6)
    # signal arcs
    for k, r in enumerate((60, 95, 130)):
        d.arc(
            [(dx - r) * SS, (dy - 40 - r) * SS, (dx + r) * SS, (dy - 40 + r) * SS],
            210,
            330,
            fill=WHITE,
            width=8 * SS - k * 4,
        )
    save(img, out)


def rover(out: Path):
    """Level 4: a little rover on a cratered moon, the blue home planet in the sky."""
    img, d = canvas(44, 36)
    # home planet top-right
    px, py, pr = 760, 260, 150
    circle(d, px, py, pr, fill=(84, 150, 240), outline=WHITE, width=8)
    for cx, cy, w, h in ((700, 210, 120, 50), (800, 300, 90, 40), (740, 330, 60, 26)):
        d.ellipse(
            [(cx - w / 2) * SS, (cy - h / 2) * SS, (cx + w / 2) * SS, (cy + h / 2) * SS],
            fill=TEAL_LIGHT,
        )
    # ground
    pts = [
        (0, 760),
        (180, 720),
        (380, 750),
        (600, 700),
        (820, 740),
        (1008, 710),
        (1008, 1152),
        (0, 1152),
    ]
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=GREY, outline=WHITE)
    d.line([(x * SS, y * SS) for x, y in pts[:6]], fill=WHITE, width=8 * SS)
    for cx, cy, r in (
        (150, 900, 70),
        (420, 1020, 100),
        (800, 880, 60),
        (720, 1080, 44),
        (300, 820, 30),
    ):
        d.ellipse(
            [(cx - r) * SS, (cy - r * 0.45) * SS, (cx + r) * SS, (cy + r * 0.45) * SS],
            fill=GREY_DARK,
        )
        d.arc(
            [(cx - r) * SS, (cy - r * 0.45) * SS, (cx + r) * SS, (cy + r * 0.45) * SS],
            200,
            340,
            fill=WHITE,
            width=5 * SS,
        )
    # rover
    rx, ry = 520, 640
    for wx in (-120, 0, 120):
        circle(d, rx + wx, ry + 70, 46, fill=OUTLINE)
        circle(d, rx + wx, ry + 70, 20, fill=GREY)
    d.rounded_rectangle(
        [(rx - 170) * SS, (ry - 40) * SS, (rx + 170) * SS, (ry + 50) * SS],
        radius=26 * SS,
        fill=CREAM,
        outline=OUTLINE,
        width=6 * SS,
    )
    d.rounded_rectangle(
        [(rx - 110) * SS, (ry - 120) * SS, (rx + 60) * SS, (ry - 40) * SS],
        radius=18 * SS,
        fill=LILAC,
        outline=OUTLINE,
        width=5 * SS,
    )
    circle(d, rx - 50, ry - 80, 24, fill=TEAL, outline=OUTLINE, width=5)
    d.line(
        [(rx + 120) * SS, (ry - 40) * SS, (rx + 150) * SS, (ry - 190) * SS],
        fill=OUTLINE,
        width=8 * SS,
    )
    circle(d, rx + 150, ry - 200, 22, fill=WHITE, outline=OUTLINE, width=5)
    save(img, out)


def sunrise(out: Path):
    """Level 5 (breather): sunrise over the home planet's limb."""
    img, d = canvas(55, 40)
    sx, sy = 504, 690
    for r, a in ((330, 0.18), (260, 0.32), (200, 0.5)):
        circle(d, sx, sy, r, fill=lerp(BOT, CREAM, a))
    circle(d, sx, sy, 150, fill=(255, 238, 196), outline=WHITE, width=8)
    # planet limb (ocean + clouds)
    circle(d, 504, 1900, 1100, fill=(60, 128, 226), outline=WHITE, width=10)
    for cx, cy, w, h in (
        (260, 900, 260, 60),
        (640, 870, 300, 54),
        (480, 1000, 360, 70),
        (840, 980, 200, 50),
        (150, 1060, 220, 60),
    ):
        d.ellipse(
            [(cx - w / 2) * SS, (cy - h / 2) * SS, (cx + w / 2) * SS, (cy + h / 2) * SS], fill=WHITE
        )
    for cx, cy, w, h in ((380, 1090, 240, 90), (760, 1100, 220, 80)):
        d.ellipse(
            [(cx - w / 2) * SS, (cy - h / 2) * SS, (cx + w / 2) * SS, (cy + h / 2) * SS], fill=TEAL
        )
    # rays
    for k in range(9):
        a = math.radians(200 + k * 17.5)
        x0, y0 = sx + math.cos(a) * 190, sy + math.sin(a) * 190
        x1, y1 = sx + math.cos(a) * 280, sy + math.sin(a) * 280
        d.line([(x0 * SS, y0 * SS), (x1 * SS, y1 * SS)], fill=WHITE, width=10 * SS)
    sparkle(d, 860, 200, 30)
    sparkle(d, 160, 260, 24)
    save(img, out)


def main() -> None:
    out_dir = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path(__file__).resolve().parent.parent / "assets" / "textures" / "pictures"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    rocket(out_dir / "w1_l1_rocket.png")
    satellite(out_dir / "w1_l2_satellite.png")
    rover(out_dir / "w1_l4_rover.png")
    sunrise(out_dir / "w1_l5_sunrise.png")


if __name__ == "__main__":
    main()
