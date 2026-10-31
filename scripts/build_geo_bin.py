#!/usr/bin/env python3
"""Pack the map's GeoJSON into the compact asset the app loads.

The app used to bundle and parse world_admin1.min.json (4.4 MB) and
world_countries.min.json (2.5 MB) as JSON. Every coordinate in them has at
most 2 decimals (see simplify_geo.py), so each fits exactly in an int16 of
hundredths of a degree; decoding `n / 100` gives back the very same double the
JSON parser produced (a -0.0 comes back as 0.0, which compares and draws the
same). The JSON files stay the editable source: re-run this after changing
them; test/map/geo_regions_test.dart fails while the two disagree.

  python3 scripts/build_geo_bin.py   # writes assets/geo/world_geo.bin

Layout, little-endian (read by GeoRegions in lib/map/geo_regions.dart):
  b"TGEO", u16 version (1)
  u32 country outline ring count, then each ring
  u32 province count, then each province:
      iso, cc, name, admin, en, ru  (u16 byte length + UTF-8; null -> "")
      u32 ring count, then each ring
  ring: u32 point count, then per point i16 lng*100, i16 lat*100
Polygon and MultiPolygon rings are flattened in file order (outer rings and
holes alike), as the app always did.
"""
import json
import os
import struct

GEO = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'geo')
VERSION = 1
PROPS = ('iso', 'cc', 'name', 'admin', 'en', 'ru')


def ring_bytes(ring):
    out = [struct.pack('<I', len(ring))]
    for point in ring:
        assert len(point) == 2, point
        packed = []
        for value in point:
            q = round(value * 100)
            # Exact: the app must see the same double the JSON held.
            assert q / 100 == value and -32768 <= q <= 32767, value
            packed.append(q)
        out.append(struct.pack('<hh', *packed))
    return b''.join(out)


def text_bytes(value):
    data = (value or '').encode('utf-8')
    assert len(data) < 65536
    return struct.pack('<H', len(data)) + data


def main():
    with open(os.path.join(GEO, 'world_countries.min.json'), encoding='utf-8') as f:
        base = json.load(f)
    with open(os.path.join(GEO, 'world_admin1.min.json'), encoding='utf-8') as f:
        admin = json.load(f)

    out = [b'TGEO', struct.pack('<H', VERSION)]
    out.append(struct.pack('<I', len(base['rings'])))
    out.extend(ring_bytes(ring) for ring in base['rings'])

    features = admin['features']
    out.append(struct.pack('<I', len(features)))
    for feature in features:
        props = feature['properties']
        for key in PROPS:
            value = props.get(key)
            # "" stands for missing, so a real empty value would be misread.
            assert value is None or value != '', (key, props)
            out.append(text_bytes(value))
        geometry = feature['geometry']
        if geometry['type'] == 'Polygon':
            rings = list(geometry['coordinates'])
        elif geometry['type'] == 'MultiPolygon':
            rings = [ring for polygon in geometry['coordinates'] for ring in polygon]
        else:
            rings = []
        out.append(struct.pack('<I', len(rings)))
        out.extend(ring_bytes(ring) for ring in rings)

    data = b''.join(out)
    path = os.path.join(GEO, 'world_geo.bin')
    with open(path, 'wb') as f:
        f.write(data)
    print(f'{path}: {len(data) / 1e6:.2f} MB, '
          f'{len(base["rings"])} outline rings, {len(features)} provinces')


if __name__ == '__main__':
    main()
