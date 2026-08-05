import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class CarouselDotIndicator extends StatelessWidget {
  const CarouselDotIndicator({
    required this.mediaCount,
    required this.activeMediaIndex,
    super.key,
  });

  final int mediaCount;
  final int activeMediaIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      // Without this the row stretches and the dots sit against the left edge
      // instead of centring on the photo.
      mainAxisSize: MainAxisSize.min,
      children: List.generate(mediaCount, (i) => i)
          .map((i) => _DotIndicator(isActive: i == activeMediaIndex))
          .toList(growable: false),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: AppSpacing.xxs,
        right: AppSpacing.xxs,
      ),
      height: isActive ? 7.5 : 6.0,
      width: isActive ? 7.5 : 6.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // White for the page you are on, #414141 for the rest.
        color: isActive ? AppColors.white : const Color(0xFF414141),
      ),
    );
  }
}
