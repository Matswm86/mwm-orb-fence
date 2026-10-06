"""Win card mock (Pillow) over the dimmed world 1 frame.

python3 wincard.py <world1_raw.png> <picture.png> <out.png>
Layout per GDD 8.4: full picture, one big star, discs at y 1300 (replay x 270 / 200 px,
map x 540 / 200 px, next x 810 / 240 px). No text.
"""

import sys

import overlay as ov
from overlay import GOLD, INK, SS, WHITE, S
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

CARD = (244, 248, 255)  # card #F4F8FF
CARD_EDGE = (110, 137, 184)  # card_edge #6E89B8


def icon_replay(d, cx, cy):
    """Counter-clockwise arrow (replay): open circle, arrowhead at the top-right end."""
    import math

    r = 44
    d.arc(S(cx - r, cy - r, cx + r, cy + r), 330, 250, fill=INK, width=15 * SS)
    th = math.radians(330)
    px, py = cx + r * math.cos(th), cy + r * math.sin(th)
    tx, ty = math.sin(th), -math.cos(th)  # tangent toward decreasing angle (counter-clockwise on screen)
    nx, ny = math.cos(th), math.sin(th)
    tip = (px + tx * 30, py + ty * 30)
    b1 = (px + nx * 24 - tx * 4, py + ny * 24 - ty * 4)
    b2 = (px - nx * 24 - tx * 4, py - ny * 24 - ty * 4)
    d.polygon([tuple(S(*q)) for q in (tip, b1, b2)], fill=INK)


def icon_map(d, cx, cy):
    # three dots on a curved path = the world map
    d.line([tuple(S(*p)) for p in ((cx - 48, cy + 30), (cx - 10, cy - 6), (cx + 16, cy + 16), (cx + 50, cy - 30))], fill=INK, width=8 * SS, joint="curve")
    for x, y in ((cx - 48, cy + 30), (cx + 2, cy + 4), (cx + 50, cy - 30)):
        d.ellipse(S(x - 16, y - 16, x + 16, y + 16), fill=INK)


def icon_play(d, cx, cy):
    d.polygon([tuple(S(*p)) for p in ((cx - 30, cy - 50), (cx - 30, cy + 50), (cx + 52, cy))], fill=INK)


def main(raw, pic, out):
    base = Image.open(raw).convert("RGB")
    base = ImageEnhance.Brightness(base.filter(ImageFilter.GaussianBlur(6))).enhance(0.45).convert("RGBA")
    W, H = base.size
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    sh = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(S(100, 360 + 12, 980, 1450 + 12), radius=56 * SS, fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(8 * SS))
    card = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle(S(100, 360, 980, 1450), radius=56 * SS, fill=CARD, outline=CARD_EDGE, width=4 * SS)
    # picture window, rounded, with an ink frame
    px0, py0, px1, py1 = 150, 410, 930, 1060
    p = Image.open(pic).convert("RGB")
    pw, ph = px1 - px0, py1 - py0
    scale = max(pw / p.width, ph / p.height)
    p = p.resize((int(p.width * scale), int(p.height * scale)), Image.LANCZOS)
    left = (p.width - pw) // 2
    top = int((p.height - ph) * 0.55)
    p = p.crop((left, top, left + pw, top + ph))
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, pw - 1, ph - 1), radius=36, fill=255)
    picl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    picl.paste(p, (px0, py0), mask)
    d.rounded_rectangle(S(px0 - 3, py0 - 3, px1 + 3, py1 + 3), radius=38 * SS, outline=INK, width=5 * SS)
    # big star on the picture's lower edge
    pts = [tuple(S(*q)) for q in ov.star_points(540, 1050, 110, 48)]
    d.polygon(pts, fill=GOLD, outline=INK, width=12 * SS)
    # discs
    for cx, r, fill, icon in ((270, 100, WHITE, icon_replay), (540, 100, WHITE, icon_map), (810, 120, GOLD, icon_play)):
        cy = 1300
        d.ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=fill, outline=INK, width=6 * SS)
        icon(d, cx, cy)
    layer = layer.resize((W, H), Image.LANCZOS)
    sh = sh.resize((W, H), Image.LANCZOS)
    img = Image.alpha_composite(base, sh)
    img = Image.alpha_composite(img, card.resize((W, H), Image.LANCZOS))
    img = Image.alpha_composite(img, picl)
    img = Image.alpha_composite(img, layer)
    # home disc stays (stand-alone build)
    hl = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    ov.draw_home(ImageDraw.Draw(hl))
    img = Image.alpha_composite(img, hl.resize((W, H), Image.LANCZOS))
    img.convert("RGB").save(out)
    print("wrote", out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
