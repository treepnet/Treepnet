import 'package:flutter/material.dart';

/// The auth-screen brand lockup, pinned to the bottom of every login / sign-up
/// screen: the logo mark on top, then "Treepnet" with a small "beta" tag.
///
/// Identical size and placement on every auth screen, so the flow reads as one
/// product — only the inputs and copy above it change from step to step.
class AuthBrand extends StatelessWidget {
  /// {@macro auth_brand}
  const AuthBrand({this.logoSize = 46, super.key});

  /// The size of the square logo mark.
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The colourful "T" mark — same gradient tile the app logo uses.
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(logoSize * 0.25),
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(logoSize * 0.25),
            child: Image.asset(
              'assets/images/logo.jpg',
              package: 'app_ui',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.bubble_chart_rounded,
                  color: Colors.white,
                  size: logoSize * 0.6,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // "Treepnet" centred under the logo, with a small "beta" tag on its
        // right, sitting on the SAME line — the two share a text baseline, so
        // "beta" reads as an inline word beside the wordmark, not dropped below
        // it. Its smaller size is kept.
        //
        // The centring trick: an invisible copy of the beta tag (and its gap)
        // mirrors the real one on the left, so the two cancel out and
        // "Treepnet" itself lands dead-centre under the logo instead of being
        // shoved left by the tag on the right.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Opacity(opacity: 0, child: _BetaTag()),
            SizedBox(width: 5),
            Text(
              'Treepnet',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 5),
            _BetaTag(),
          ],
        ),
      ],
    );
  }
}

/// The dimmer "beta" tag beside the wordmark. Pulled out so the real tag and
/// its invisible left-hand mirror (used for centring) stay in lockstep.
class _BetaTag extends StatelessWidget {
  const _BetaTag();

  @override
  Widget build(BuildContext context) {
    return Text(
      'beta',
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    );
  }
}
