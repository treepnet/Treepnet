#!/usr/bin/env python3
"""Gives every admin-1 shape its own code in assets/geo/world_admin1.min.json.

The source (Natural Earth) filed 152 shapes under 59 codes that each appear
more than once. The app keys regions by code, so it kept only the last shape
of each: the rest weren't drawn, couldn't be tapped and didn't resolve story
places, and the country lists showed the region several times. Most of those
shapes are really other regions — a city next to its province, a province
next to a neighbour the source mislabelled — and get their real name and
code here: the official ISO 3166-2 code where there is one, otherwise a
4-letter code of our own (longer than any ISO code after the dash, so it
can't collide). Shapes that truly are pieces of one region are merged.

Each shape is found by its original code and the centre of its outer rings;
the script stops if anything doesn't match, and refuses to run twice. Then
run scripts/build_geo_bin.py. No stored row used any of these codes
(checked on prod, 2026-10-31).
"""

import json
import os
import sys

GEO = os.path.join(os.path.dirname(__file__), '..', 'assets', 'geo')
PATH = os.path.join(GEO, 'world_admin1.min.json')

# (code now, lat, lng) -> (new code, en, ru); None keeps that part of it.
RENAME = [
    # A province and its capital / a city and its district.
    (('KZ-ALA', 44.82, 78.59), ('KZ-ALM', 'Almaty Region', 'Алматинская область')),
    (('MZ-L', -25.92, 32.60), ('MZ-MPM', 'Maputo City', 'Мапуту')),
    (('MZ-L', -25.67, 32.59), (None, 'Maputo Province', 'провинция Мапуту')),
    (('LA-VI', 18.16, 102.55), ('LA-VT', 'Vientiane Prefecture', 'префектура Вьентьян')),
    (('LA-VI', 18.65, 102.47), (None, 'Vientiane Province', 'провинция Вьентьян')),
    (('PE-LIM', -12.02, -76.91), ('PE-LMA', 'Metropolitan Lima', 'Большая Лима')),
    (('PE-LIM', -11.62, -76.77), (None, 'Lima Region', 'регион Лима')),
    (('CO-CUN', 4.31, -74.19), ('CO-DC', 'Bogotá', 'Богота')),
    (('AZ-SA', 41.14, 47.17), ('AZ-SAK', 'Shaki District', 'Шекинский район')),
    (('AZ-YEV', 40.62, 47.15), ('AZ-YE', 'Yevlakh', 'Евлах')),
    (('AZ-YEV', 40.60, 46.95), (None, 'Yevlakh District', 'Евлахский район')),
    # The source's "AZ-LAN Lankaran" is Lachin; Lankaran District sat under
    # the city's code.
    (('AZ-LAN', 39.67, 46.41), ('AZ-LAC', 'Lachin District', 'Лачинский район')),
    (('AZ-LA', 38.96, 48.93), ('AZ-LAN', 'Lankaran District', 'Ленкоранский район')),
    # Latvia: the municipality around each state city.
    (('LV-JEL', 56.57, 23.63), ('LV-041', 'Jelgava Municipality', 'Елгавский край')),
    (('LV-DGV', 55.94, 26.63), ('LV-025', 'Daugavpils Municipality', 'Даугавпилсский край')),
    (('LV-VEN', 57.28, 21.80), ('LV-106', 'Ventspils Municipality', 'Вентспилсский край')),
    (('LV-REZ', 56.46, 27.26), ('LV-077', 'Rēzekne Municipality', 'Резекненский край')),
    (('LV-JKB', 56.30, 25.99), ('LV-042', 'Jēkabpils Municipality', 'Екабпилсский край')),
    # Ireland: city councils next to their counties; Dublin's four councils.
    (('IE-CO', 51.88, -8.44), ('IE-CORK', 'Cork City', 'город Корк')),
    (('IE-CO', 51.79, -9.01), (None, 'County Cork', 'графство Корк')),
    (('IE-G', 53.28, -8.98), ('IE-GALW', 'Galway City', 'город Голуэй')),
    (('IE-G', 53.34, -9.35), (None, 'County Galway', 'графство Голуэй')),
    (('IE-D', 53.38, -6.22), (None, 'Dublin City', 'Дублин')),
    (('IE-D', 53.28, -6.18), ('IE-DUNL', None, None)),
    (('IE-D', 53.47, -6.23), ('IE-FING', None, None)),
    (('IE-D', 53.28, -6.42), ('IE-SDUB', None, None)),
    # A neighbour the source filed under this code.
    (('MW-CT', -9.95, 34.02), ('MW-KR', 'Karonga', 'Каронга')),
    (('SD-DE', 12.43, 23.51), ('SD-DC', 'Central Darfur', 'Центральный Дарфур')),
    (('SD-DS', 11.22, 26.25), ('SD-DE', 'East Darfur', 'Восточный Дарфур')),
    (('SD-DS', 10.19, 24.25), (None, 'South Darfur', 'Южный Дарфур')),
    (('HR-12', 45.44, 17.72), ('HR-11', None, None)),
    (('HR-12', 45.20, 17.72), (None, 'Brod-Posavina', 'Бродско-Посавская жупания')),
    (('MD-RE', 47.78, 29.07), ('MD-RIB', 'Rîbnița', 'Рыбница')),
    (('AF-PAR', 35.50, 69.82), ('AF-PAN', 'Panjshir', 'Панджшер')),
    (('AF-URU', 33.70, 66.21), ('AF-DAY', 'Daykundi', 'Дайкунди')),
    (('IR-07', 35.62, 51.78), (None, 'Tehran', 'Тегеран')),
    (('IR-07', 35.88, 50.73), ('IR-32', None, None)),
    (('UG-410', -0.17, 30.82), ('UG-418', 'Kiruhura', 'Кирухура')),
    (('SB-CH', -8.09, 157.10), ('SB-WE', 'Western', 'Западная провинция')),
    (('GL-UO', 78.27, -28.49),
     ('GL-NEG', 'Northeast Greenland National Park',
      'Северо-Восточный Гренландский национальный парк')),
    # Bosnia and Herzegovina: the Federation's cantons (ISO BA-01 … BA-10).
    (('BA-BIH', 44.76, 16.17), ('BA-01', None, None)),
    (('BA-BIH', 44.60, 18.56), ('BA-03', None, None)),
    (('BA-BIH', 44.26, 18.14), ('BA-04', None, None)),
    (('BA-BIH', 43.68, 18.78), ('BA-05', None, None)),
    (('BA-BIH', 44.09, 17.67), ('BA-06', None, None)),
    (('BA-BIH', 43.29, 17.83), ('BA-07', None, None)),
    (('BA-BIH', 43.41, 17.48), ('BA-08', None, None)),
    (('BA-BIH', 43.83, 18.34), ('BA-09', None, None)),
    (('BA-BIH', 43.96, 16.96), ('BA-10', None, None)),
    # Madagascar: the regions inside each old province (the region holding
    # the provincial capital keeps the province code).
    (('MG-M', -15.13, 48.18), ('MG-SOFI', None, None)),
    (('MG-M', -17.75, 44.96), ('MG-MELA', None, None)),
    (('MG-M', -17.28, 46.95), ('MG-BETS', None, None)),
    (('MG-D', -14.11, 49.81), ('MG-SAVA', None, None)),
    (('MG-A', -16.23, 49.52), ('MG-ANJR', None, None)),
    (('MG-A', -17.93, 48.37), ('MG-ALAO', None, None)),
    (('MG-F', -21.35, 47.79), ('MG-VATO', None, None)),
    (('MG-F', -23.36, 47.17), ('MG-ATSA', None, None)),
    (('MG-F', -20.42, 46.72), ('MG-AMOR', None, None)),
    (('MG-F', -22.67, 45.99), ('MG-IHOR', None, None)),
    (('MG-U', -24.06, 46.44), ('MG-ANOS', None, None)),
    (('MG-U', -24.78, 45.50), ('MG-ANDR', None, None)),
    (('MG-U', -20.05, 44.89), ('MG-MENA', None, None)),
    (('MG-T', -18.59, 46.06), ('MG-BONG', None, None)),
    (('MG-T', -19.82, 46.87), ('MG-VAKI', None, None)),
    (('MG-T', -19.12, 46.95), ('MG-ITAS', None, None)),
    # Philippines: cities next to their provinces.
    (('PH-NCO', 7.25, 124.24), ('PH-COTA', 'Cotabato City', 'город Котабато')),
    (('PH-CEB', 10.34, 123.90), ('PH-CEBU', 'Cebu City', 'город Себу')),
    (('PH-ILI', 10.75, 122.55), ('PH-ILOI', 'Iloilo City', 'город Илоило')),
    (('PH-DAV', 7.22, 125.46), ('PH-DAVA', 'Davao City', 'город Давао')),
    (('PH-PLW', 9.93, 118.76), ('PH-PUER', None, None)),
    (('PH-AGN', 8.93, 125.56), ('PH-BUTU', None, None)),
    (('PH-MSR', 8.46, 124.64), ('PH-CAGA', None, None)),
    (('PH-LAN', 8.22, 124.39), ('PH-ILIG', None, None)),
    (('PH-ZAN', 7.21, 122.17), ('PH-ZAMB', None, None)),
    (('PH-SCO', 6.14, 125.15), ('PH-GENS', None, None)),
    (('PH-LEY', 11.26, 124.98), ('PH-TACL', None, None)),
    (('PH-LEY', 11.06, 124.58), ('PH-ORMO', None, None)),
    (('PH-QUE', 13.93, 121.58), ('PH-LUCE', None, None)),
    (('PH-CAS', 13.63, 123.26), ('PH-NAGA', None, None)),
    (('PH-PAM', 15.14, 120.60), ('PH-ANGE', None, None)),
    (('PH-ZMB', 14.86, 120.32), ('PH-OLON', None, None)),
    (('PH-PAN', 16.05, 120.32), ('PH-DAGU', None, None)),
    (('PH-ISA', 16.70, 121.49), ('PH-SANT', None, None)),
    (('PH-BEN', 16.40, 120.60), ('PH-BAGU', None, None)),
    # Metro Manila's cities (Manila keeps PH-MNL).
    (('PH-MNL', 14.46, 120.99), ('PH-LASP', None, None)),
    (('PH-MNL', 14.49, 121.01), ('PH-PARA', None, None)),
    (('PH-MNL', 14.53, 121.01), ('PH-PASA', None, None)),
    (('PH-MNL', 14.65, 120.95), ('PH-NAVO', None, None)),
    (('PH-MNL', 14.40, 121.08), ('PH-MUNT', None, None)),
    (('PH-MNL', 14.70, 121.03), ('PH-CALO', None, None)),
    (('PH-MNL', 14.67, 120.96), ('PH-MALA', None, None)),
    (('PH-MNL', 14.71, 120.98), ('PH-VALE', None, None)),
    (('PH-MNL', 14.70, 121.09), ('PH-QUEC', None, None)),
    (('PH-MNL', 14.51, 121.09), ('PH-TAGU', None, None)),
    (('PH-MNL', 14.64, 121.12), ('PH-MARI', None, None)),
    (('PH-MNL', 14.58, 121.11), ('PH-PASI', None, None)),
    (('PH-MNL', 14.54, 121.05), ('PH-MAKA', None, None)),
    (('PH-MNL', 14.57, 121.05), ('PH-MAND', None, None)),
    (('PH-MNL', 14.60, 121.04), ('PH-SANJ', None, None)),
]

# Truly one region in several pieces: one shape (en, ru; None keeps them).
MERGE = {
    'AU-NSW': ('New South Wales', 'Новый Южный Уэльс'),  # with Lord Howe Island
    'IE-LK': (None, None),  # one council since 2014
    'IE-WD': (None, None),  # one council since 2014
    'IE-TA': ('Tipperary', 'Типперэри'),  # North + South, one since 2014
    'MD-SN': (None, None),
    'MU-PL': (None, None),
    'SI-054': (None, None),
}


def centre(feature):
    geometry = feature['geometry']
    polygons = (geometry['coordinates'] if geometry['type'] == 'MultiPolygon'
                else [geometry['coordinates']])
    points = [p for polygon in polygons for p in polygon[0]]
    return (sum(p[1] for p in points) / len(points),
            sum(p[0] for p in points) / len(points))


def polygons_of(feature):
    geometry = feature['geometry']
    if geometry['type'] == 'MultiPolygon':
        return list(geometry['coordinates'])
    return [geometry['coordinates']]


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    features = data['features']
    if any(f['properties']['iso'] in ('MW-KR', 'PH-CEBU') for f in features):
        sys.exit('Already applied.')

    for (iso, lat, lng), (new_iso, en, ru) in RENAME:
        hits = [f for f in features if f['properties']['iso'] == iso
                and abs(centre(f)[0] - lat) < 0.006
                and abs(centre(f)[1] - lng) < 0.006]
        if len(hits) != 1:
            sys.exit(f'{iso} at {lat},{lng}: {len(hits)} matches')
        props = hits[0]['properties']
        if new_iso:
            props['iso'] = new_iso
        if en:
            props['name'] = en
            props['en'] = en
        if ru:
            props['ru'] = ru

    for iso, (en, ru) in MERGE.items():
        parts = [f for f in features if f['properties']['iso'] == iso]
        if len(parts) < 2:
            sys.exit(f'{iso}: {len(parts)} part(s) to merge')
        first = parts[0]
        first['geometry'] = {
            'type': 'MultiPolygon',
            'coordinates': [p for part in parts for p in polygons_of(part)],
        }
        if en:
            first['properties']['name'] = en
            first['properties']['en'] = en
        if ru:
            first['properties']['ru'] = ru
        for part in parts[1:]:
            features.remove(part)

    seen = {}
    for f in features:
        iso = f['properties']['iso']
        if iso in seen:
            sys.exit(f'still repeated: {iso}')
        seen[iso] = True

    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{len(features)} shapes, every code once')


if __name__ == '__main__':
    main()
