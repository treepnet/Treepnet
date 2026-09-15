#!/usr/bin/env python3
"""Simplify world_admin1 polygon geometry: RDP + 2-decimal precision.

RDP (iterative) removes redundant vertices; rounding to 2 decimals (~1.1 km,
matching world_countries.min.json) shrinks the coordinate strings and lets
consecutive duplicates collapse. Feature properties are untouched. Degenerate
rings (< 4 points after processing) fall back to their rounded-original so no
region vanishes.
"""
import json, sys, os

EPS = float(sys.argv[1]) if len(sys.argv) > 1 else 0.02  # ~2.2 km
GEO = "/Users/apple/Desktop/Treepnet/assets/geo"
DEC = 2

def pd2(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return (px - ax) ** 2 + (py - ay) ** 2
    num = dx * (ay - py) - (ax - px) * dy
    return num * num / (dx * dx + dy * dy)

def rdp(pts, e2):
    n = len(pts)
    if n < 3:
        return pts
    keep = [False] * n
    keep[0] = keep[n - 1] = True
    st = [(0, n - 1)]
    while st:
        s, e = st.pop()
        if e <= s + 1:
            continue
        ax, ay = pts[s]
        bx, by = pts[e]
        dm, idx = 0.0, -1
        for i in range(s + 1, e):
            d = pd2(pts[i][0], pts[i][1], ax, ay, bx, by)
            if d > dm:
                dm, idx = d, i
        if dm > e2 and idx != -1:
            keep[idx] = True
            st.append((s, idx))
            st.append((idx, e))
    return [pts[i] for i in range(n) if keep[i]]

def dedup_round(ring):
    out = []
    for x, y in ring:
        p = [round(x, DEC), round(y, DEC)]
        if not out or out[-1] != p:
            out.append(p)
    return out

def simplify_ring(ring, e2):
    s = rdp(ring, e2)
    s = dedup_round(s)
    if len(s) < 4:
        s = dedup_round(ring)  # keep original shape (rounded) rather than drop
    # keep the ring closed
    if len(s) >= 2 and s[0] != s[-1]:
        s.append(s[0][:])
    return s

def cnt(c):
    if c and isinstance(c[0], (int, float)):
        return 1
    return sum(cnt(x) for x in c)

e2 = EPS * EPS
path = os.path.join(GEO, "world_admin1.min.json")
data = json.load(open(path))
before = after = 0
for feat in data["features"]:
    g = feat["geometry"]
    if g["type"] == "Polygon":
        before += cnt(g["coordinates"])
        g["coordinates"] = [simplify_ring(r, e2) for r in g["coordinates"]]
        after += cnt(g["coordinates"])
    elif g["type"] == "MultiPolygon":
        before += cnt(g["coordinates"])
        g["coordinates"] = [[simplify_ring(r, e2) for r in poly]
                            for poly in g["coordinates"]]
        after += cnt(g["coordinates"])

json.dump(data, open(path, "w"), separators=(",", ":"), ensure_ascii=False)
sz = os.path.getsize(path)
print(f"admin1: {before} -> {after} pts ({100*after/before:.0f}% kept), "
      f"{sz/1e6:.2f}MB  (eps={EPS}, {DEC}-decimal)")
