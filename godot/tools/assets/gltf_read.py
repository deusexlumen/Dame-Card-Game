"""Minimaler glTF-Leser fuer die Asset-Werkzeuge (nur was wir brauchen)."""
import json, os, struct
import numpy as np

_CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Gltf:
    def __init__(self, path):
        self.path = path
        self.dir = os.path.dirname(path)
        self.j = json.load(open(path, encoding="utf8"))
        self.buffers = [open(os.path.join(self.dir, b["uri"]), "rb").read() for b in self.j["buffers"]]

    def acc(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        buf = self.buffers[bv["buffer"]]
        dt = np.dtype(_CT[a["componentType"]])
        n = _N[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0) or dt.itemsize * n
        count = a["count"]
        raw = np.frombuffer(buf, dtype=np.uint8, count=stride * (count - 1) + dt.itemsize * n, offset=off)
        out = np.lib.stride_tricks.as_strided(raw, shape=(count, dt.itemsize * n), strides=(stride, 1)).copy()
        arr = out.view(dt).reshape(count, n)
        if a.get("normalized"):
            arr = arr.astype(np.float32) / np.iinfo(dt).max
        return arr

    def mesh_named(self, name):
        for m in self.j["meshes"]:
            if m["name"] == name:
                return m
        raise KeyError(name)

    def joint_names(self, skin=0):
        return [self.j["nodes"][n]["name"] for n in self.j["skins"][skin]["joints"]]
