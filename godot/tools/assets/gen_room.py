"""Erzeugt Raumtexturen fuer den 3D-Tisch: Tapete, Holzboden, Teppich, Filz.

Ausgabe nach godot/assets/room/. Aufruf: python gen_room.py
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "room"))
rnd = random.Random(7)


def wallpaper(size=512):
    base = (52, 16, 24)
    img = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(img)
    # Damast-artiges Rautenmuster mit Lilien-Andeutung, nahtlos kachelbar.
    step = size // 4
    for gy in range(-1, 5):
        for gx in range(-1, 5):
            cx = gx * step + (step // 2 if gy % 2 else 0)
            cy = gy * step
            col = (70, 24, 33)
            d.polygon([(cx, cy - step * 0.45), (cx + step * 0.28, cy), (cx, cy + step * 0.45), (cx - step * 0.28, cy)], outline=col, width=3)
            d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=col)
            for a in range(4):
                ang = a * math.pi / 2 + math.pi / 4
                px, py = cx + math.cos(ang) * step * 0.2, cy + math.sin(ang) * step * 0.2
                d.ellipse([px - 4, py - 4, px + 4, py + 4], fill=(78, 30, 38))
    # Feine Streifen fuer Stoffstruktur.
    for x in range(0, size, 4):
        d.line([(x, 0), (x, size)], fill=(48, 14, 22))
    return img.filter(ImageFilter.GaussianBlur(0.6))


def floor(size=512):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    plank_h = size // 8
    for row in range(8):
        y = row * plank_h
        off = rnd.randint(0, size)
        x = -off
        while x < size:
            w = rnd.randint(size // 3, size // 2 + size // 4)
            tone = rnd.randint(-8, 8)
            c = (58 + tone, 36 + tone // 2, 24 + tone // 3)
            d.rectangle([x, y, x + w, y + plank_h - 2], fill=c)
            for k in range(14):
                yy = y + rnd.randint(2, plank_h - 4)
                d.line([(x, yy), (x + w, yy + rnd.randint(-2, 2))], fill=(c[0] - 7, c[1] - 5, c[2] - 3), width=1)
            d.line([(x, y), (x, y + plank_h)], fill=(30, 18, 12), width=2)
            x += w
        d.line([(0, y + plank_h - 1), (size, y + plank_h - 1)], fill=(28, 17, 11), width=2)
    return img.filter(ImageFilter.GaussianBlur(0.5))


def rug(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    d.ellipse([4, 4, size - 4, size - 4], fill=(60, 14, 22, 255))
    for r, col, w in [(0.48, (176, 140, 70), 6), (0.44, (120, 30, 40), 18), (0.40, (176, 140, 70), 3), (0.2, (176, 140, 70), 3)]:
        rr = r * size
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col + (255,), width=w)
    for k in range(24):
        a = k / 24 * math.tau
        x1, y1 = c + math.cos(a) * size * 0.22, c + math.sin(a) * size * 0.22
        x2, y2 = c + math.cos(a) * size * 0.38, c + math.sin(a) * size * 0.38
        d.line([(x1, y1), (x2, y2)], fill=(96, 26, 34, 255), width=10)
    return img.filter(ImageFilter.GaussianBlur(1.0))


def felt(size=512):
    # Graustufen-Struktur, wird im Spiel mit der Filzfarbe multipliziert.
    img = Image.new("L", (size, size), 200)
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = 200 + rnd.randint(-22, 22)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    return img.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    wallpaper().save(os.path.join(OUT, "wallpaper.png"), optimize=True)
    floor().save(os.path.join(OUT, "floor.png"), optimize=True)
    rug().save(os.path.join(OUT, "rug.png"), optimize=True)
    felt().save(os.path.join(OUT, "felt.png"), optimize=True)
    print("ROOM_OK")


if __name__ == "__main__":
    main()
