#!/usr/bin/env python3
"""Enrich the bundled admin-1 geo asset with localized names (en / ru).

WHAT IT DOES
------------
The app ships ``assets/geo/world_admin1.min.json`` — Natural Earth admin-1
polygons whose geometry has already been *simplified* down to ~6 MB. That
simplified geometry is deliberately kept (re-exporting from raw Natural Earth
would bloat it back to ~40 MB and slow the map). This script therefore does
NOT touch geometry: it only *adds* two properties to every feature —

    "en": English name  (Natural Earth ``name_en``)
    "ru": Russian name  (Natural Earth ``name_ru``)

and writes a small companion asset ``assets/geo/country_names.min.json``
mapping country code -> {en, ru}. The existing ``iso/cc/name/admin`` fields
and the geometry are left byte-for-byte intact, so the current app (which
ignores the new keys) behaves exactly as before. Phase F2 starts reading them.

SOURCE (public domain, CC0) — download once, pass paths as args:
    https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_1_states_provinces.geojson
    https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries.geojson

USAGE
    python3 tool/build_geo_i18n.py <ne_admin1.geojson> <ne_admin0.geojson>
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ADMIN1 = REPO / "assets/geo/world_admin1.min.json"
COUNTRY_OUT = REPO / "assets/geo/country_names.min.json"


def clean(x):
    return (x or "").strip()


# 11 Natural-Earth synthetic "X~" placeholder codes that carry no name_ru
# (some no name at all). Identified by centroid; see the planning sheet.
# ⚠ marked ones are best-effort identifications worth a human check.
FILL = {
    "AE-X01~": ("Fujairah", "Эль-Фуджайра"),
    "AE-X02~": ("Sayh Mudayrah", "Сайх-Мудайра"),
    "AS-X01~": ("Eastern District", "Восточный округ"),
    "AS-X02~": ("Manu'a Islands", "Острова Мануа"),
    "HK-X03~": ("Siu Ma Shan", "Сиу-Ма-Шань"),
    "AI-X00": ("Anguilla", "Ангилья"),
    "KI-X02~": ("Line Islands", "Острова Лайн"),
    "CO-X01~": ("Malpelo Island", "Остров Мальпело"),
    "MX-X01~": ("Alacranes Reef", "Рифы Алакранес"),   # ⚠
    "RU-X01~": ("Ural (fragment)", "Урал (фрагмент)"),  # ⚠
    "AQ-X02~": ("Antarctica", "Антарктида"),            # ⚠
}


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: build_geo_i18n.py <ne_admin1.geojson> <ne_admin0.geojson>")
    ne1 = json.load(open(sys.argv[1], encoding="utf-8"))["features"]
    ne0 = json.load(open(sys.argv[2], encoding="utf-8"))["features"]

    # admin-1 name lookups by ISO 3166-2
    reg_en, reg_ru = {}, {}
    for f in ne1:
        p = f["properties"]
        iso = clean(p.get("iso_3166_2"))
        if not iso:
            continue
        reg_en[iso] = clean(p.get("name_en")) or clean(p.get("name"))
        reg_ru[iso] = clean(p.get("name_ru"))

    # admin-0 country names by ISO_A2 (Natural Earth sets ISO_A2 to "-99" for
    # a handful — France, Norway, … — so fall back to ISO_A2_EH).
    c_en, c_ru = {}, {}
    for f in ne0:
        p = f["properties"]
        en = clean(p.get("NAME_EN")) or clean(p.get("NAME"))
        ru = clean(p.get("NAME_RU"))
        for key in (clean(p.get("ISO_A2")), clean(p.get("ISO_A2_EH"))):
            if key and key != "-99":
                c_en.setdefault(key, en)
                c_ru.setdefault(key, ru)

    # Codes with no Natural Earth match at all (special / disputed).
    COUNTRY_FILL = {
        "XK": ("Kosovo", "Косово"),
        "-1": ("Dhekelia Sovereign Base Area", "Декелия"),
    }
    for cc, (en, ru) in COUNTRY_FILL.items():
        c_en.setdefault(cc, en)
        c_ru.setdefault(cc, ru)

    # ---- enrich admin-1 (geometry untouched) ----
    doc = json.load(open(ADMIN1, encoding="utf-8"))
    feats = doc["features"]
    en_hit = ru_hit = 0
    for f in feats:
        p = f["properties"]
        iso = clean(p.get("iso"))
        name = clean(p.get("name"))
        en = reg_en.get(iso, "")
        ru = reg_ru.get(iso, "")
        if (not en or not ru) and iso in FILL:
            fen, fru = FILL[iso]
            en = en or fen
            ru = ru or fru
        en = en or name          # en never empty (fallback to current)
        if en == "Zürich":       # requested: plain ASCII
            en = "Zurich"
        p["en"] = en
        p["ru"] = ru             # may be "" only for truly unfillable; read-time falls back
        if en:
            en_hit += 1
        if ru:
            ru_hit += 1

    # ---- country companion asset ----
    countries = {}
    for f in feats:
        p = f["properties"]
        cc = clean(p.get("cc"))
        if not cc or cc in countries:
            continue
        countries[cc] = {
            "en": c_en.get(cc) or clean(p.get("admin")),
            "ru": c_ru.get(cc) or "",
        }

    N = len(feats)
    # write minified, keep Cyrillic as UTF-8 (compact + readable)
    with open(ADMIN1, "w", encoding="utf-8") as fp:
        json.dump(doc, fp, ensure_ascii=False, separators=(",", ":"))
    with open(COUNTRY_OUT, "w", encoding="utf-8") as fp:
        json.dump(countries, fp, ensure_ascii=False, separators=(",", ":"))

    print(f"admin-1 features : {N}")
    print(f"  en filled      : {en_hit}/{N}")
    print(f"  ru filled      : {ru_hit}/{N}  (empty: {N - ru_hit})")
    print(f"countries        : {len(countries)}  (ru empty: {sum(1 for c in countries.values() if not c['ru'])})")
    print(f"wrote {ADMIN1.relative_to(REPO)}  ({ADMIN1.stat().st_size} bytes)")
    print(f"wrote {COUNTRY_OUT.relative_to(REPO)}  ({COUNTRY_OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
