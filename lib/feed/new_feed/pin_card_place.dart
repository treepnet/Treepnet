import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:treepnet/map/globe_view.dart';

/// Where a post goes on its globe, standing on its pin, and where the globe
/// opens for it.
///
/// - [PinCardPlace.photo] (Trends): its small photo; the globe turned to
///   put the pin in its middle.
/// - [PinCardPlace.card] (the new feed): its card, over an arrow down to the
///   pin, its top a little way down the box (below the travel count): the
///   globe turns so the pin sits a little above the middle (up to 20°) for
///   it, or a little below on a narrow phone — the card then covers less of
///   the globe while the post's place stays in view.
///
/// That is where it opens, until the globe is laid out; from then on it
/// stands where the globe draws the pin ([over]).
class PinCardPlace {
  const PinCardPlace._({required this.card, this.arrow, this.camera});

  /// Trends' photo on a [size]d globe, on [pin] (the post's pin as drawn),
  /// the globe turned to [camera] — or, the first time, to face the pin.
  factory PinCardPlace.photo({
    required Size size,
    required ({double lat, double lng})? pin,
    required ({double lat, double lng})? camera,
  }) {
    final side = photoSide(size);
    final r = GlobeView.wholeGlobeRadius(size);
    if (pin == null || r <= 0) {
      // No pin to stand on: the photo a little way down the middle.
      return PinCardPlace._(
        card: Rect.fromLTWH((size.width - side) / 2, _noPinTop, side, side),
      );
    }
    final turned = camera ?? (lat: pin.lat.clamp(-85.0, 85.0), lng: pin.lng);
    return PinCardPlace._(
      card: over(_drawn(size, turned, pin), Size.square(side)).card,
      camera: turned,
    );
  }

  /// The new feed's card on a [size]d globe, on [pin], the globe turned to
  /// [camera] — or, the first time, as the card needs it.
  factory PinCardPlace.card({
    required Size size,
    required ({double lat, double lng})? pin,
    required ({double lat, double lng})? camera,
  }) {
    final cardSize = cardSizeOn(size);
    // The card's top a little way down the box, clear of the travel count.
    final top = math.max(_noPinTop, size.height * _topShare);
    final r = GlobeView.wholeGlobeRadius(size);
    if (pin == null || r <= 0) {
      // No pin to stand on: the card where it would stand.
      return PinCardPlace._(
        card: Offset((size.width - cardSize.width) / 2, top) & cardSize,
      );
    }
    var turned = camera;
    if (turned == null) {
      // The card's bottom over the pin's icon, the arrow between them.
      const under = GlobeView.pinIconTop + _gap + _arrowHeight;
      final c = size.center(Offset.zero);
      final rise = ((c.dy - top - cardSize.height - under) / r).clamp(
        -math.sin(15 * _deg),
        math.sin(20 * _deg),
      );
      turned = (
        lat: (pin.lat - math.asin(rise) / _deg).clamp(-85.0, 85.0),
        lng: pin.lng,
      );
    }
    final onPin = over(_drawn(size, turned, pin), cardSize, withArrow: true);
    return PinCardPlace._(card: onPin.card, arrow: onPin.arrow, camera: turned);
  }

  /// A photo's side on a [box] globe (Trends): small, a sixth of its width
  /// or so.
  static double photoSide(Size box) => (box.width * 0.17).clamp(52.0, 76.0);

  /// The new feed's small card on a [box] globe: a square photo and its
  /// buttons' row under it.
  static Size cardSizeOn(Size box) {
    final width = (box.width * 0.34).clamp(96.0, 150.0);
    return Size(width, width + cardFooterHeight);
  }

  /// The new feed's small card's buttons' row.
  static const double cardFooterHeight = 34;

  /// A [size]d photo or card standing on the pin drawn [at]: its bottom just
  /// over the pin's icon — or, [withArrow] (the new feed's card), over an
  /// arrow down to it.
  static ({Rect card, Rect? arrow}) over(
    Offset at,
    Size size, {
    bool withArrow = false,
  }) {
    final under = GlobeView.pinIconTop + _gap + (withArrow ? _arrowHeight : 0);
    final bottom = at.dy - under;
    return (
      card: Rect.fromLTWH(
        at.dx - size.width / 2,
        bottom - size.height,
        size.width,
        size.height,
      ),
      arrow: withArrow
          ? Rect.fromLTWH(
              at.dx - _arrowWidth / 2,
              bottom - 0.5,
              _arrowWidth,
              _arrowHeight + 0.5,
            )
          : null,
    );
  }

  /// Where the whole globe in a [size] box, turned to [camera], draws [pin]
  /// (orthographic, north up, as the globe draws it).
  static Offset _drawn(
    Size size,
    ({double lat, double lng}) camera,
    ({double lat, double lng}) pin,
  ) {
    final r = GlobeView.wholeGlobeRadius(size);
    final c = size.center(Offset.zero);
    final p0 = camera.lat * _deg;
    final p = pin.lat * _deg;
    final dl = (pin.lng - camera.lng) * _deg;
    return Offset(
      c.dx + r * math.cos(p) * math.sin(dl),
      c.dy -
          r *
              (math.cos(p0) * math.sin(p) -
                  math.sin(p0) * math.cos(p) * math.cos(dl)),
    );
  }

  /// How far down the box the new feed's card's top goes (a share of its
  /// height), when the pin can be raised enough for it.
  static const double _topShare = 0.08;

  /// The top at least this far down: below the travel count in the corner.
  static const double _noPinTop = 44;
  static const double _gap = 2;
  static const double _arrowWidth = 14;
  static const double _arrowHeight = 7;
  static const double _deg = math.pi / 180;

  /// The photo or the card, in the globe's box.
  final Rect card;

  /// The new feed's card's arrow, its tip just over the pin's icon.
  final Rect? arrow;

  /// Where the globe is turned to (none without a pin).
  final ({double lat, double lng})? camera;
}
