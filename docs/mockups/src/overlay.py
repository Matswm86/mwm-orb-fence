"""HUD + controls overlay for the Orb Fence world 1 mock (Pillow).

python3 overlay.py <world1_raw.png> <out.png> [--zones <zones.png>]
Draws: stand-alone home disc, capture meter with target star, ball-count orbs,
direction toggle (vertical selected). Sizes match docs/DESIGN.md section 4.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = Path(__file__).resolve().parents[3] / "assets" / "fonts" / "Fredoka.ttf"
SS = 2  # supersample for smooth edges

INK = (36, 33, 29)
WHITE = (255, 255, 255)
PANEL = (13, 26, 51)  # hud_panel #0D1A33
PANEL_EDGE = (169, 189, 224)  # hud_edge #A9BDE0
TRACK = (6, 12, 28)  # meter_track #060C1C
CRYSTAL = (127, 182, 255)  # crystal_w1 #7FB6FF
CRYSTAL_DEEP = (79, 130, 224)
GOLD = (255, 201, 77)  # beam / player gold #FFC94D
CORAL = (255, 111, 97)  # orb_shell #FF6F61


def font(size, weight=b"SemiBold"):
    f = ImageFont.truetype(str(FONT), size * SS)
    try:
        f.set_variation_by_name(weight)
    except (OSError, ValueError):
        pass
    return f


def S(*v):
    return [int(round(x * SS)) for x in v]


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_home(d):
    cx, cy, r = 104, 104, 68
    d.ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=WHITE, outline=INK, width=5 * SS)
    # house: roof triangle + body with door
    roof = [(cx, cy - 34), (cx + 36, cy - 2), (cx - 36, cy - 2)]
    d.polygon([tuple(S(*p)) for p in roof], fill=INK)
    d.rectangle(S(cx - 24, cy - 4, cx + 24, cy + 32), fill=INK)
    d.rectangle(S(cx - 8, cy + 10, cx + 8, cy + 32), fill=WHITE)


def rounded(d, box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle(S(*box), radius=r * SS, fill=fill, outline=outline, width=width * SS)


def diamond(d, cx, cy, r, fill=None, outline=None, width=0):
    pts = [(cx, cy - r), (cx + r * 0.75, cy), (cx, cy + r), (cx - r * 0.75, cy)]
    d.polygon([tuple(S(*p)) for p in pts], fill=fill, outline=outline, width=width * SS)


def draw_meter(d, pct=0.35, target=0.65, digits=False):
    """GDD 8.2: glass tube x 280-1040, y 96-176; star at the target; 4 notches at 25/50/75/100% of target."""
    x0, y0, x1, y1 = 280, 96, 1040, 176
    rounded(d, (x0, y0, x1, y1), 40, fill=PANEL + (235,), outline=PANEL_EDGE, width=4)
    ix0, iy0, ix1, iy1 = x0 + 14, y0 + 14, x1 - 14, y1 - 14
    rounded(d, (ix0, iy0, ix1, iy1), 26, fill=TRACK)
    fx = ix0 + (ix1 - ix0) * pct
    rounded(d, (ix0, iy0, fx, iy1), 26, fill=CRYSTAL)
    for x in range(ix0 + 22, int(fx) - 40, 36):
        d.polygon([tuple(S(*p)) for p in ((x, iy1 - 2), (x + 18, iy0 + 2), (x + 30, iy0 + 2), (x + 12, iy1 - 2))], fill=(186, 216, 255))
    # glass highlight
    rounded(d, (ix0 + 14, iy0 + 5, fx - 14, iy0 + 11), 3, fill=(235, 245, 255))
    # milestone notches at 25/50/75% of target, on the tube centre line: lit = white + ink edge, unlit = hollow
    for k in (0.25, 0.5, 0.75):
        nx = ix0 + (ix1 - ix0) * target * k
        reached = pct >= target * k
        if reached:
            diamond(d, nx, (y0 + y1) / 2, 17, fill=WHITE, outline=INK, width=3)
        else:
            diamond(d, nx, (y0 + y1) / 2, 15, fill=None, outline=PANEL_EDGE, width=3)
    gx = ix0 + (ix1 - ix0) * target
    d.rectangle(S(gx - 3, iy0, gx + 3, iy1), fill=GOLD)
    pts = [tuple(S(*p)) for p in star_points(gx, (y0 + y1) / 2, 50, 22)]
    d.polygon(pts, fill=GOLD, outline=INK, width=5 * SS)
    if digits:
        d.text(S(990, 136), f"{round(pct * 100)}%", font=font(40), fill=WHITE, anchor="mm")


def sparkle(d, cx, cy, r, fill=None, outline=None, width=0):
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else r * 0.36
        a = math.radians(-90 + i * 45)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon([tuple(S(*p)) for p in pts], fill=fill, outline=outline, width=width * SS)


def draw_sparks(d, total=9, left=6):
    """Vanlig spark bar, GDD 8.2: y 192-220 under the meter. Gold 4-point sparkles (not diamonds, so they
    never read as the meter notches). A spent spark is a hollow outline."""
    for i in range(total):
        cx = 316 + i * 44
        if i < left:
            sparkle(d, cx, 206, 17, fill=GOLD, outline=INK, width=2)
        else:
            sparkle(d, cx, 206, 15, fill=None, outline=PANEL_EDGE, width=3)


def draw_orb_icon(d, cx, cy, r=18):
    d.ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=CORAL)
    d.ellipse(S(cx - r * 0.5, cy - r * 0.55, cx + r * 0.25, cy + r * 0.15), fill=(255, 214, 205))
    d.arc(S(cx - r * 1.65, cy - r * 0.6, cx + r * 1.65, cy + r * 0.6), 200, 340, fill=WHITE, width=4 * SS)
    d.arc(S(cx - r * 1.65, cy - r * 0.6, cx + r * 1.65, cy + r * 0.6), 0, 160, fill=WHITE, width=4 * SS)


def draw_ballcount(d, n=3):
    rounded(d, (256, 170, 256 + 40 + n * 64, 222), 26, fill=PANEL + (232,), outline=PANEL_EDGE, width=3)
    for i in range(n):
        draw_orb_icon(d, 300 + i * 64, 196)


def arrow_icon(d, cx, cy, vertical, color, outline_only=False, scale=1.0):
    L, W, head = 62 * scale, 14 * scale, 26 * scale
    if vertical:
        body = (cx - W / 2, cy - L + head, cx + W / 2, cy + L - head)
        heads = [
            [(cx, cy - L - 4), (cx + head, cy - L + head + 4), (cx - head, cy - L + head + 4)],
            [(cx, cy + L + 4), (cx + head, cy + L - head - 4), (cx - head, cy + L - head - 4)],
        ]
    else:
        body = (cx - L + head, cy - W / 2, cx + L - head, cy + W / 2)
        heads = [
            [(cx - L - 4, cy), (cx - L + head + 4, cy - head), (cx - L + head + 4, cy + head)],
            [(cx + L + 4, cy), (cx + L - head - 4, cy - head), (cx + L - head - 4, cy + head)],
        ]
    if outline_only:
        d.rectangle(S(*body), outline=color, width=4 * SS)
        for h in heads:
            d.polygon([tuple(S(*p)) for p in h], outline=color, width=4 * SS)
    else:
        d.rectangle(S(*body), fill=color)
        for h in heads:
            d.polygon([tuple(S(*p)) for p in h], fill=color)
    # origin dot
    d.ellipse(S(cx - 11, cy - 11, cx + 11, cy + 11), fill=color if not outline_only else None, outline=color, width=4 * SS)


def draw_direction_buttons(d, vertical_selected=True):
    """GDD 3.2: discs at (330,1540) and (750,1540), hit 240x240. Chosen = raised 216 px, gold, ink ring,
    white halo ring; other = flat 176 px dark glass disc with an outline icon (size + ring + fill, not colour only)."""
    for cx, vert in ((330, True), (750, False)):
        cy = 1540
        chosen = vert == vertical_selected
        if chosen:
            r = 108
            d.ellipse(S(cx - r - 12, cy - r - 12, cx + r + 12, cy + r + 12), outline=WHITE, width=5 * SS)
            d.ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=GOLD, outline=INK, width=6 * SS)
            arrow_icon(d, cx, cy, vert, INK)
        else:
            r = 88
            d.ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=PANEL + (240,), outline=PANEL_EDGE, width=4 * SS)
            arrow_icon(d, cx, cy, vert, WHITE, outline_only=True, scale=0.8)


def main():
    src, out = sys.argv[1], sys.argv[2]
    zones = sys.argv[sys.argv.index("--zones") + 1] if "--zones" in sys.argv else None
    base = Image.open(src).convert("RGBA")
    W, H = base.size
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # soft drop shadow layer for the panels (flat, dark, offset 6 px)
    sh = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle(S(280, 104, 1040, 184), radius=40 * SS, fill=(0, 0, 0, 140))
    sd.ellipse(S(330 - 120, 1540 - 112, 330 + 120, 1540 + 128), fill=(0, 0, 0, 170))
    sh = sh.filter(ImageFilter.GaussianBlur(6 * SS))
    draw_home(d)
    draw_meter(d, digits="--vanlig" in sys.argv)
    draw_direction_buttons(d, True)
    sh = sh.resize((W, H), Image.LANCZOS)
    layer = layer.resize((W, H), Image.LANCZOS)
    img = Image.alpha_composite(base, sh)
    img = Image.alpha_composite(img, layer)
    img.convert("RGB").save(out)
    print("wrote", out)
    if zones:
        zl = Image.new("RGBA", img.size, (0, 0, 0, 0))
        zd = ImageDraw.Draw(zl)
        zd.rectangle((0, 0, 232, 232), outline=(255, 255, 255, 255), width=4)
        zd.rectangle((0, 0, 216, 216), fill=(255, 255, 255, 50))
        zd.rectangle((36, 256, 1044, 1408), outline=(255, 230, 0, 255), width=4)
        zd.rectangle((210, 1420, 450, 1660), fill=(0, 220, 120, 70), outline=(0, 220, 120, 255), width=3)
        zd.rectangle((630, 1420, 870, 1660), fill=(0, 220, 120, 70), outline=(0, 220, 120, 255), width=3)
        zd.rectangle((256, 40, 1044, 224), outline=(120, 200, 255, 255), width=3)
        zd.rectangle((0, 1664, W, H), fill=(255, 40, 40, 70), outline=(255, 40, 40, 255), width=4)
        z = Image.alpha_composite(img, zl)
        z.convert("RGB").save(zones)
        print("wrote", zones)


if __name__ == "__main__":
    main()
