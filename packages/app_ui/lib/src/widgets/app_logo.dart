import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// {@template app_logo}
/// The Application logo that displays the Treepnet logo and text.
/// {@endtemplate}
class AppLogo extends StatelessWidget {
  /// {@macro app_logo}
  const AppLogo({
    this.fit = BoxFit.contain,
    super.key,
    this.width,
    this.height,
    this.color,
  });

  /// The fit of the logo.
  final BoxFit fit;

  /// The width of the logo.
  final double? width;

  /// The height of the logo.
  final double? height;

  /// The color of the logo.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final logoSize = height ?? 32.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(logoSize * 0.25),
            child: Image.asset(
              'assets/images/logo.jpg',
              package: 'app_ui',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.bubble_chart_rounded,
                    color: Colors.white,
                    size: logoSize * 0.6,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Treepnet',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: logoSize * 0.7,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: color ?? context.adaptiveColor,
          ),
        ),
      ],
    );
  }
}
