"""Erzeugt Kartenvorder- und -rueckseiten im Casino-Stil als PNG.

Ausgabe: godot/assets/cards/faces/<skin>/<RANK><suit>[_<lang>].png und
godot/assets/cards/backs/<skin>.png. Bube und Dame gibt es je Sprache
(de: B/D, en: J/Q), alle anderen Karten sind sprachneutral.

Aufruf: python gen_cards.py  (aus beliebigem Ordner)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
FONTS = os.path.join(ROOT, "assets", "fonts")
OUT = os.path.join(ROOT, "assets", "cards")

SS = 2  # Supersampling
W, H = 288, 404
R = 18  # Eckenradius

RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
SUITS = {"hearts": "♥", "diamonds": "♦", "clubs": "♣", "spades": "♠"}
LABEL = {"de": {"J": "B", "Q": "D", "K": "K", "A": "A"}, "en": {"J": "J", "Q": "Q", "K": "K", "A": "A"}}
VALUE = {"A": 1, "J": 10, "Q": 0, "K": 10}

SKINS = {
    "klassisch": {"bg": (250, 248, 240), "hearts": (178, 24, 36), "diamonds": (178, 24, 36), "clubs": (22, 22, 26), "spades": (22, 22, 26), "frame": (176, 141, 60), "muted": (120, 115, 105), "jumbo": False},
    "vierfarben": {"bg": (250, 248, 240), "hearts": (178, 24, 36), "diamonds": (24, 78, 170), "clubs": (24, 118, 62), "spades": (22, 22, 26), "frame": (176, 141, 60), "muted": (120, 115, 105), "jumbo": False},
    "jumbo": {"bg": (252, 250, 244), "hearts": (190, 22, 34), "diamonds": (190, 22, 34), "clubs": (18, 18, 22), "spades": (18, 18, 22), "frame": (176, 141, 60), "muted": (120, 115, 105), "jumbo": True},
    "noir": {"bg": (24, 24, 28), "hearts": (232, 86, 96), "diamonds": (232, 86, 96), "clubs": (236, 226, 200), "spades": (236, 226, 200), "frame": (200, 165, 80), "muted": (150, 140, 120), "jumbo": False},
}

BACKS = {
    "bordeaux": {"base": (112, 16, 30), "line": (168, 52, 64), "gold": (214, 176, 92), "style": "lattice"},
    "royal": {"base": (20, 34, 86), "line": (60, 84, 150), "gold": (214, 176, 92), "style": "lattice"},
    "deco": {"base": (16, 16, 18), "line": (120, 96, 46), "gold": (218, 180, 96), "style": "deco"},
    "smaragd": {"base": (10, 72, 50), "line": (40, 120, 88), "gold": (214, 176, 92), "style": "lattice"},
    "karo": {"base": (26, 10, 14), "line": (120, 20, 34), "gold": (214, 176, 92), "style": "checker"},
}

# Symbolpositionen je Zahlenwert im Innenfeld (x, y in 0..1), unten liegende werden gedreht.
PIPS = {
    2: [(0.5, 0.0), (0.5, 1.0)],
    3: [(0.5, 0.0), (0.5, 0.5), (0.5, 1.0)],
    4: [(0, 0), (1, 0), (0, 1), (1, 1)],
    5: [(0, 0), (1, 0), (0.5, 0.5), (0, 1), (1, 1)],
    6: [(0, 0), (1, 0), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
    7: [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
    8: [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0.5, 0.75), (0, 1), (1, 1)],
    9: [(0, 0), (1, 0), (0, 1 / 3), (1, 1 / 3), (0.5, 0.5), (0, 2 / 3), (1, 2 / 3), (0, 1), (1, 1)],
    10: [(0, 0), (1, 0), (0.5, 1 / 6), (0, 1 / 3), (1, 1 / 3), (0, 2 / 3), (1, 2 / 3), (0.5, 5 / 6), (0, 1), (1, 1)],
}


def font(name, size, weight=None):
    f = ImageFont.truetype(os.path.join(FONTS, name), size * SS)
    if weight is not None:
        try:
            f.set_variation_by_axes([weight] if "Playfair" in name else [14, weight])
        except OSError:
            pass
    return f


def rounded_mask():
    m = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W * SS - 1, H * SS - 1], R * SS, fill=255)
    return m


def glyph(img, ch, cx, cy, size, color, rot=False):
    """Zeichen zentriert auf (cx, cy) in Supersampling-Koordinaten, optional kopfueber."""
    f = font("DejaVuSans.ttf", size)
    tile = Image.new("RGBA", (int(size * SS * 1.6), int(size * SS * 1.6)), (0, 0, 0, 0))
    ImageDraw.Draw(tile).text((tile.width / 2, tile.height / 2), ch, font=f, fill=color, anchor="mm")
    if rot:
        tile = tile.rotate(180)
    img.alpha_composite(tile, (int(cx - tile.width / 2), int(cy - tile.height / 2)))


def text(img, s, cx, cy, fnt, color, rot=False):
    bbox = fnt.getbbox(s, anchor="mm")
    tw, th = bbox[2] - bbox[0] + 8 * SS, bbox[3] - bbox[1] + 8 * SS
    tile = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(tile).text((tw / 2, th / 2), s, font=fnt, fill=color, anchor="mm")
    if rot:
        tile = tile.rotate(180)
    img.alpha_composite(tile, (int(cx - tw / 2), int(cy - th / 2)))


def crown(d, cx, cy, w, color):
    h = w * 0.62
    pts = [(cx - w / 2, cy + h / 2), (cx - w / 2, cy - h / 6), (cx - w / 4, cy + h / 8), (cx, cy - h / 2), (cx + w / 4, cy + h / 8), (cx + w / 2, cy - h / 6), (cx + w / 2, cy + h / 2)]
    d.polygon(pts, fill=color)
    for px in (cx - w / 2, cx, cx + w / 2):
        py = cy - h / 2 if px == cx else cy - h / 6
        d.ellipse([px - w * 0.07, py - w * 0.07, px + w * 0.07, py + w * 0.07], fill=color)


def face(skin, rank, suit, lang):
    st = SKINS[skin]
    col = st[suit] + (255,)
    img = Image.new("RGBA", (W * SS, H * SS), st["bg"] + (255,))
    d = ImageDraw.Draw(img)
    # Feiner Innenrand.
    m = 7 * SS
    d.rounded_rectangle([m, m, W * SS - m, H * SS - m], (R - 5) * SS, outline=st["frame"] + (110,), width=SS)
    label = LABEL[lang].get(rank, rank)
    jumbo = st["jumbo"]
    idx_size = 46 if jumbo else 30
    fidx = font("PlayfairDisplay.ttf", idx_size, 800)
    ix, iy = (30 if jumbo else 22) * SS, (34 if jumbo else 26) * SS
    for rot in (False, True):
        x, y = (ix, iy) if not rot else (W * SS - ix, H * SS - iy)
        sgn = -1 if rot else 1
        text(img, label, x, y, fidx, col, rot)
        glyph(img, SUITS[suit], x, y + sgn * (idx_size * 0.95) * SS, 20 if not jumbo else 30, col, rot)
    sym = SUITS[suit]
    if rank in ("J", "Q", "K"):
        # Doppelkoepfiges Bild: obere Haelfte zeichnen, gedreht unten einsetzen.
        fx0, fy0, fx1, fy1 = 54 * SS, 50 * SS, (W - 54) * SS, (H - 50) * SS
        d.rectangle([fx0, fy0, fx1, fy1], fill=tuple(int(c * 0.94 + 255 * 0.06) for c in st["bg"]) + (255,), outline=st["frame"] + (255,), width=3 * SS)
        d.rectangle([fx0 + 6 * SS, fy0 + 6 * SS, fx1 - 6 * SS, fy1 - 6 * SS], outline=st["frame"] + (160,), width=SS)
        half = Image.new("RGBA", (fx1 - fx0, (fy1 - fy0) // 2), (0, 0, 0, 0))
        hd = ImageDraw.Draw(half)
        hw, hh = half.size
        if rank in ("K", "Q"):
            crown(hd, hw / 2, hh * 0.24, hw * (0.42 if rank == "K" else 0.34), st["frame"] + (255,))
        else:
            hd.ellipse([hw / 2 - 12 * SS, hh * 0.24 - 12 * SS, hw / 2 + 12 * SS, hh * 0.24 + 12 * SS], outline=st["frame"] + (255,), width=3 * SS)
        flet = font("PlayfairDisplay.ttf", 74, 900)
        text(half, label, hw / 2, hh * 0.66, flet, col)
        glyph(half, sym, hw * 0.18, hh * 0.2, 22, col)
        glyph(half, sym, hw * 0.82, hh * 0.2, 22, col)
        img.alpha_composite(half, (fx0, fy0))
        img.alpha_composite(half.rotate(180), (fx0, fy0 + hh + (fy1 - fy0) % 2))
        d.line([fx0 + 14 * SS, (fy0 + fy1) // 2, fx1 - 14 * SS, (fy0 + fy1) // 2], fill=st["frame"] + (200,), width=SS)
    elif rank == "A":
        glyph(img, sym, W * SS / 2, H * SS / 2, 150 if not jumbo else 110, col)
        if suit == "spades":
            d.ellipse([W * SS / 2 - 92 * SS, H * SS / 2 - 92 * SS, W * SS / 2 + 92 * SS, H * SS / 2 + 92 * SS], outline=st["frame"] + (200,), width=2 * SS)
    else:
        n = int(rank)
        x0, x1 = (0.33 if jumbo else 0.3) * W * SS, (0.67 if jumbo else 0.7) * W * SS
        y0, y1 = 0.19 * H * SS, 0.81 * H * SS
        size = 34 if jumbo else (46 if n <= 6 else 42)
        for px, py in PIPS[n]:
            cx = x0 + (x1 - x0) * px
            cy = y0 + (y1 - y0) * py
            glyph(img, sym, cx, cy, size, col, rot=py > 0.5)
    # Punktwert als kleine Plakette unten (sprachneutral; wichtig: Dame = 0).
    value = VALUE.get(rank, int(rank) if rank.isdigit() else 0)
    bx, by, br = W * SS / 2, (H - 19) * SS, 10 * SS
    d.ellipse([bx - br, by - br, bx + br, by + br], outline=st["muted"] + (255,), width=SS)
    text(img, str(value), bx, by + SS, font("Inter.ttf", 11, 700), st["muted"] + (255,))
    img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", img.size, 0), rounded_mask()))
    return img.resize((W, H), Image.LANCZOS)


def back(name):
    st = BACKS[name]
    img = Image.new("RGBA", (W * SS, H * SS), (246, 244, 236, 255))
    d = ImageDraw.Draw(img)
    b = 14 * SS
    inner = [b, b, W * SS - b, H * SS - b]
    d.rounded_rectangle(inner, 8 * SS, fill=st["base"] + (255,))
    pat = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pat)
    if st["style"] == "lattice":
        step = 22 * SS
        for k in range(-H * SS, W * SS + H * SS, step):
            pd.line([(k, 0), (k + H * SS, H * SS)], fill=st["line"] + (255,), width=2 * SS)
            pd.line([(k, H * SS), (k + H * SS, 0)], fill=st["line"] + (255,), width=2 * SS)
    elif st["style"] == "checker":
        step = 16 * SS
        for yy in range(0, H * SS, step):
            for xx in range(0, W * SS, step):
                if (xx // step + yy // step) % 2 == 0:
                    cx, cy = xx + step / 2, yy + step / 2
                    pd.polygon([(cx, cy - step / 2), (cx + step / 2, cy), (cx, cy + step / 2), (cx - step / 2, cy)], fill=st["line"] + (255,))
    else:
        cx, cy = W * SS / 2, H * SS / 2
        for k in range(48):
            a = k / 48 * math.tau
            pd.line([(cx, cy), (cx + math.cos(a) * W * SS, cy + math.sin(a) * W * SS)], fill=st["line"] + (255,), width=SS)
        for rr in range(30, 400, 26):
            pd.ellipse([cx - rr * SS, cy - rr * SS, cx + rr * SS, cy + rr * SS], outline=st["line"] + (140,), width=SS)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(inner, 8 * SS, fill=255)
    img.paste(pat, (0, 0), Image.composite(pat.getchannel("A"), Image.new("L", img.size, 0), mask))
    # Goldrahmen und Medaillon mit Monogramm.
    d.rounded_rectangle([b + 8 * SS, b + 8 * SS, W * SS - b - 8 * SS, H * SS - b - 8 * SS], 6 * SS, outline=st["gold"] + (255,), width=2 * SS)
    cx, cy = W * SS / 2, H * SS / 2
    ow, oh = 64 * SS, 84 * SS
    d.ellipse([cx - ow, cy - oh, cx + ow, cy + oh], fill=st["base"] + (255,), outline=st["gold"] + (255,), width=3 * SS)
    d.ellipse([cx - ow + 8 * SS, cy - oh + 8 * SS, cx + ow - 8 * SS, cy + oh - 8 * SS], outline=st["gold"] + (170,), width=SS)
    text(img, "D", cx, cy - 4 * SS, font("PlayfairDisplay.ttf", 92, 800), st["gold"] + (255,))
    img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", img.size, 0), rounded_mask()))
    return img.resize((W, H), Image.LANCZOS)


def main():
    for skin in SKINS:
        out = os.path.join(OUT, "faces", skin)
        os.makedirs(out, exist_ok=True)
        for suit in SUITS:
            for rank in RANKS:
                if rank in ("J", "Q"):
                    for lang in ("de", "en"):
                        face(skin, rank, suit, lang).save(os.path.join(out, "%s%s_%s.png" % (rank, suit, lang)), optimize=True)
                else:
                    face(skin, rank, suit, "de").save(os.path.join(out, "%s%s.png" % (rank, suit)), optimize=True)
    os.makedirs(os.path.join(OUT, "backs"), exist_ok=True)
    for name in BACKS:
        back(name).save(os.path.join(OUT, "backs", name + ".png"), optimize=True)
    print("CARDS_OK")


if __name__ == "__main__":
    main()
