"""App icon (DESIGN 9): one coral ringed orb caught between two crossing gold beams over a
crystal corner, on the deep-space gradient. No text; must read at 48 px.

python3 tools/make_icon.py [out.png]   (default: icon.png in the project root)
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 512
SS = 4
N = S * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main() -> None:
    out = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else Path(__file__).resolve().parent.parent / "icon.png"
    )
    img = Image.new("RGB", (N, N))
    d = ImageDraw.Draw(img)
    for y in range(N):
        d.line([(0, y), (N, y)], fill=lerp((5, 8, 22), (14, 61, 102), y / N))
    rnd = random.Random(5)
    for _ in range(60):
        x, y, r = rnd.uniform(0, N), rnd.uniform(0, N), rnd.uniform(2, 6) * SS / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 235, 255))
    # crystal corner (bottom-left), faceted tiles
    cell = 96 * SS
    for cx in range(0, 3):
        for cy in range(2, 6):
            if cx + (5 - cy) > 3:
                continue
            x0, y0 = cx * cell, cy * cell - 64 * SS
            base = lerp((96, 150, 245), (150, 200, 255), (cx + cy) / 8)
            d.rectangle([x0 + 4, y0 + 4, x0 + cell - 4, y0 + cell - 4], fill=base)
            d.polygon(
                [(x0 + 4, y0 + 4), (x0 + cell - 4, y0 + 4), (x0 + cell * 0.6, y0 + cell * 0.45)],
                fill=lerp(base, (255, 255, 255), 0.25),
            )
            d.polygon(
                [(x0 + 4, y0 + cell - 4), (x0 + 4, y0 + 4), (x0 + cell * 0.6, y0 + cell * 0.45)],
                fill=lerp(base, (40, 70, 160), 0.18),
            )
    glow = Image.new("RGB", (N, N))
    g = ImageDraw.Draw(glow)
    gold, core = (255, 201, 77), (255, 246, 218)
    # two crossing beams
    bx, by = int(0.62 * N), int(0.40 * N)
    for w, c in ((90, (120, 90, 30)), (44, gold), (14, core)):
        g.line([(bx, 0), (bx, N)], fill=c, width=w * SS // 4)
        g.line([(0, by), (N, by)], fill=c, width=w * SS // 4)
    glow = glow.filter(ImageFilter.GaussianBlur(10 * SS))
    lit = np.asarray(img, dtype=float) + np.asarray(glow, dtype=float) * 1.6
    img = Image.fromarray(np.clip(lit, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(img)
    for w, c in ((22, gold), (8, core)):
        d.line([(bx, 0), (bx, N)], fill=c, width=w * SS)
        d.line([(0, by), (N, by)], fill=c, width=w * SS)
    # orb in the open quadrant (top-right of the cross)
    ox, oy, r = int(0.80 * N) - 10 * SS, int(0.22 * N), 62 * SS
    halo = Image.new("L", (N, N), 0)
    ImageDraw.Draw(halo).ellipse([ox - r * 2.2, oy - r * 2.2, ox + r * 2.2, oy + r * 2.2], fill=150)
    halo = halo.filter(ImageFilter.GaussianBlur(30 * SS))
    img.paste((255, 111, 97), (0, 0), halo)
    d = ImageDraw.Draw(img)
    for k, c in enumerate([(255, 111, 97), (255, 179, 166), (255, 230, 220), (255, 246, 238)]):
        rr = r * (1.0 - k * 0.22)
        d.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=c)
    d.ellipse(
        [ox - r * 1.75, oy - r * 0.5, ox + r * 1.75, oy + r * 0.5],
        outline=(255, 255, 255),
        width=9 * SS,
    )
    # front half of the orb over the ring's back half
    top = Image.new("L", (N, N), 0)
    ImageDraw.Draw(top).pieslice([ox - r, oy - r, ox + r, oy + r], 180, 360, fill=255)
    orb = Image.new("RGB", (N, N))
    od = ImageDraw.Draw(orb)
    for k, c in enumerate([(255, 111, 97), (255, 179, 166), (255, 230, 220), (255, 246, 238)]):
        rr = r * (1.0 - k * 0.22)
        od.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=c)
    img.paste(orb, (0, 0), top)
    img.resize((S, S), Image.LANCZOS).save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
