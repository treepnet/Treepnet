import 'dart:io';

import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';
import 'package:treepnet/map/geo_regions.dart';

/// Works out what to write on a story's place chip: "Region, Country".
///
/// The picture is asked first — a photo from the gallery usually carries the
/// GPS tag of where it was taken, which is more truthful than wherever the
/// phone happens to be while editing. The in-app camera strips that tag, so
/// the phone's own position is the fallback.
///
/// Never opens a map: the button is meant to stamp the place, not start a
/// task. Returns null when neither source can say where this is, and the
/// caller simply adds nothing.
///
/// The country/region name comes from the offline admin-1 index, so this works
/// with no network and no geocoding key.
Future<String?> resolveStoryPlaceLabel({required String? mediaPath}) async {
  final fromPhoto = await _placeFromExif(mediaPath);
  if (fromPhoto != null) return fromPhoto;
  return _placeFromDevice();
}

/// Where the phone is now, as a region label. Null when the permission is
/// refused or location services are off — nothing is stamped in that case.
Future<String?> _placeFromDevice() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        // A region is hundreds of kilometres wide; no need to wait for a
        // precise fix.
        timeLimit: Duration(seconds: 8),
      ),
    );
    await GeoRegions.instance.load();
    final region = GeoRegions.instance.regionAt(
      position.longitude,
      position.latitude,
    );
    return region == null ? null : _label(region);
  } catch (_) {
    // Timeout, no fix, or a platform refusal — the chip is optional.
    return null;
  }
}

String _label(GeoRegion region) => '${region.name}, ${region.countryName}';

/// Reads the photo's GPS tag and maps it to a region, or null when the file has
/// no coordinates.
Future<String?> _placeFromExif(String? mediaPath) async {
  if (mediaPath == null || mediaPath.isEmpty) return null;
  final file = File(mediaPath);
  if (!file.existsSync()) return null;

  try {
    final tags = await readExifFromBytes(await file.readAsBytes());
    final lat = _degrees(tags['GPS GPSLatitude'], tags['GPS GPSLatitudeRef']);
    final lng = _degrees(tags['GPS GPSLongitude'], tags['GPS GPSLongitudeRef']);
    if (lat == null || lng == null) return null;

    await GeoRegions.instance.load();
    final region = GeoRegions.instance.regionAt(lng, lat);
    return region == null ? null : _label(region);
  } catch (_) {
    // A corrupt or unreadable header is not worth failing the whole button
    // over; the map fallback still works.
    return null;
  }
}

/// EXIF stores coordinates as three rationals — degrees, minutes, seconds —
/// with the hemisphere in a separate ref tag.
double? _degrees(IfdTag? value, IfdTag? ref) {
  final parts = value?.values.toList();
  if (parts == null || parts.length < 3) return null;

  double part(int i) {
    final ratio = parts[i];
    if (ratio is Ratio) {
      if (ratio.denominator == 0) return 0;
      return ratio.numerator / ratio.denominator;
    }
    return double.tryParse('$ratio') ?? 0;
  }

  final decimal = part(0) + part(1) / 60 + part(2) / 3600;
  final hemisphere = ref?.printable.trim().toUpperCase();
  return (hemisphere == 'S' || hemisphere == 'W') ? -decimal : decimal;
}
