"""PLACEHOLDER hidden pictures for worlds 2-6 (one per world).

python3 tools/make_placeholder_pictures.py [out_dir]

The real per-level pictures for levels 6-30 are graphic-designer's job
(DESIGN.md 7e) and do not exist yet. Until they do, each world gets one
1008 x 1152 placeholder: its crystal tint (DESIGN.md 2c) as a light-to-dark
vertical ramp, white 4-point sparkles, and faint diagonal hatching that marks
it as unfinished art. No text (children see it). Replace, do not polish.
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

W, H = 1008, 1152
TINTS = {
    2: (0x5E, 0xD8, 0xD0),
    3: (0x7F, 0xE8, 0xB0),
    4: (0xB4, 0xA6, 0xFF),
    5: (0x9F, 0xE6, 0xF2),
    6: (0x9C, 0x8C, 0xFF),
}
WHITE = (244, 248, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sparkle(d, x, y, r):
    pts = [
        (x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28),
        (x, y + r), (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28),
    ]
    d.polygon(pts, fill=WHITE)


def make(world: int, out: Path) -> None:
    tint = TINTS[world]
    top = lerp(tint, (255, 255, 255), 0.35)
    bot = lerp(tint, (10, 20, 50), 0.45)
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        d.line([(0, y), (W, y)], fill=lerp(top, bot, y / H))
    hatch = lerp(tint, (255, 255, 255), 0.15)
    for k in range(-H, W, 72):
        d.line([(k, 0), (k + H, H)], fill=hatch, width=6)
    rnd = random.Random(world * 31)
    for _ in range(40):
        sparkle(d, rnd.uniform(30, W - 30), rnd.uniform(30, H - 30), rnd.choice((6, 8, 10, 14)))
    img.save(out)
    print(out)


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path(__file__).resolve().parent.parent / "assets" / "textures" / "pictures"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    for w in TINTS:
        make(w, out_dir / f"placeholder_w{w}.png")


if __name__ == "__main__":
    main()
