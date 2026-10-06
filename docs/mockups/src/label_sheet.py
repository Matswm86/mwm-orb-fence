"""Compose docs/mockups/elements.png: the 3D element render (elements.py) in labelled rows,
plus a 2D UI row (direction buttons, meter, spark bar, win card thumbnail).

python3 label_sheet.py <elements_raw.png> <wincard_mock.png> <out.png>
"""

import sys

import overlay as ov
from PIL import Image, ImageDraw

BG = (10, 20, 48)
LABEL = (232, 240, 255)
SUB = (169, 189, 224)

ROWS = [
    ["Ball (orb + ring)", "Stor: double ring", "Kvikk: small + tail", "Ball under Snegl", "Caged ball (Bur)"],
    ["Wall growing", "Ghost wall", "Wall done", "Pop: soap bubbles", "Wall start ring"],
    ["Crystal cell", "Crystal + picture", "Stein (stone)", "Speil /", "Speil \\"],
    ["Snegl token", "Lyn token", "Skjold token", "Frame + nodes", "Halo fallback"],
]


def main(raw, wincard, out):
    src = Image.open(raw).convert("RGB")
    f = ov.font(15, b"Medium")  # ov.font multiplies by SS=2 -> 30 px
    fs = ov.font(13, b"Regular")
    row_h, lab_h = 340, 52
    ui_h = 560
    W = 1600
    H = 4 * (row_h + lab_h) + ui_h
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    for r in range(4):
        y_src = r * row_h
        y_dst = r * (row_h + lab_h)
        sheet.paste(src.crop((0, y_src, W, y_src + row_h)), (0, y_dst))
        for c, text in enumerate(ROWS[r]):
            d.text((160 + c * 320, y_dst + row_h + 22), text, font=f, fill=LABEL, anchor="mm")
    # ---- UI row (drawn at 1080x1920 coordinates, then cropped) ----
    y0 = 4 * (row_h + lab_h)
    d.text((24, y0 + 12), "UI (2D overlay, CanvasLayer)", font=f, fill=LABEL, anchor="lt")

    def ui_canvas(draw_fn):
        img = Image.new("RGBA", (1080 * ov.SS, 1920 * ov.SS), BG + (255,))
        draw_fn(ImageDraw.Draw(img))
        return img.resize((1080, 1920), Image.LANCZOS)

    a = ui_canvas(lambda dd: ov.draw_direction_buttons(dd, True)).crop((200, 1410, 880, 1670))
    b = ui_canvas(lambda dd: ov.draw_direction_buttons(dd, False)).crop((200, 1410, 880, 1670))
    sheet.paste(a.resize((442, 169), Image.LANCZOS), (20, y0 + 60))
    sheet.paste(b.resize((442, 169), Image.LANCZOS), (20, y0 + 280))
    d.text((241, y0 + 240), "Up-down chosen", font=fs, fill=SUB, anchor="mm")
    d.text((241, y0 + 460), "Side-side chosen", font=fs, fill=SUB, anchor="mm")

    def lett(dd):
        ov.draw_meter(dd, pct=0.35, target=0.65, digits=False)

    def vanlig(dd):
        ov.draw_meter(dd, pct=0.52, target=0.75, digits=True)
        ov.draw_sparks(dd, total=9, left=6)

    m1 = ui_canvas(lett).crop((270, 80, 1050, 190))
    m2 = ui_canvas(vanlig).crop((270, 80, 1050, 232))
    sheet.paste(m1.resize((624, 88), Image.LANCZOS), (490, y0 + 70))
    d.text((802, y0 + 176), "Meter, Lett: no digits, 2 of 3 notches lit", font=fs, fill=SUB, anchor="mm")
    sheet.paste(m2.resize((624, 122), Image.LANCZOS), (490, y0 + 230))
    d.text((802, y0 + 372), "Meter, Vanlig: small % + spark bar (6 of 9 left)", font=fs, fill=SUB, anchor="mm")
    wc = Image.open(wincard).convert("RGB").crop((80, 340, 1000, 1470))
    wc = wc.resize((int(920 * 0.42), int(1130 * 0.42)), Image.LANCZOS)
    sheet.paste(wc, (1190, y0 + 52))
    d.text((1383, y0 + 535), "Win card", font=fs, fill=SUB, anchor="mm")
    sheet.save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main(*sys.argv[1:4])
