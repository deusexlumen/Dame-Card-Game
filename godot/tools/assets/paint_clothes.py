"""Erzeugt Kleidungsmasken fuer die Quaternius-Koerper.

Jedes Dreieck des Koerpers wird ueber seine Knochen einer Zone zugeordnet und
im UV-Raum in eine Maske gemalt: R = Oberteil, G = Hose, B = Schuhe.
Der Shader im Spiel faerbt damit Kleidung beliebig ein.

Aufruf: python paint_clothes.py <gltf> <body-mesh-name> <out.png> [size]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from gltf_read import Gltf

TOP = ("spine_", "clavicle_", "upperarm_", "lowerarm_")
BOTTOM = ("pelvis", "thigh_", "calf_")
SHOES = ("foot_", "ball_")


def zone(name):
    if name.startswith(TOP):
        return 0
    if name.startswith(BOTTOM):
        return 1
    if name.startswith(SHOES):
        return 2
    return -1


def main(path, mesh_name, out, size=1024):
    g = Gltf(path)
    names = g.joint_names()
    prim = g.mesh_named(mesh_name)["primitives"][0]
    uv = g.acc(prim["attributes"]["TEXCOORD_0"])
    joints = g.acc(prim["attributes"]["JOINTS_0"])
    weights = g.acc(prim["attributes"]["WEIGHTS_0"]).astype(np.float32)
    idx = g.acc(prim["indices"]).reshape(-1, 3)
    # Gewicht je Zone pro Vertex, damit Uebergaenge (Handgelenk, Hals) sauber kippen.
    zw = np.zeros((len(uv), 3), np.float32)
    for k in range(4):
        z = np.array([zone(names[j]) for j in joints[:, k]])
        for zi in range(3):
            zw[:, zi] += np.where(z == zi, weights[:, k], 0.0)
    layers = [Image.new("L", (size, size), 0) for _ in range(3)]
    draws = [ImageDraw.Draw(l) for l in layers]
    for tri in idx:
        w = zw[tri].mean(0)
        zi = int(w.argmax())
        # Haut nur, wenn Kopf/Haende ueberwiegen; sonst staerkste Kleidungszone.
        if w.sum() < 0.5:
            continue
        pts = [(float(uv[v, 0]) * size, float(uv[v, 1]) * size) for v in tri]
        draws[zi].polygon(pts, fill=255, outline=255)
    # Leicht ausdehnen gegen Naehte an UV-Kanten, dann weich machen.
    layers = [l.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2)) for l in layers]
    Image.merge("RGB", layers).save(out, optimize=True)
    print("MASK", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 1024)
