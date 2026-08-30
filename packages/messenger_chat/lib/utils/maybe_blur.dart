part of messenger_chat;

/// `BackdropFilter` (blur) eski GPU larda juda qimmat - har bir kadrda
/// save-layer + blur o'tishini talab qiladi. Unumdorlikni o'lchash yoki
/// zaif qurilmalarda ishlash uchun uni butunlay o'chirib qo'yish mumkin:
///
///   flutter build apk --dart-define=DISABLE_BLUR=true
///
/// Parametrlari `BackdropFilter` bilan bir xil, shuning uchun almashtirish
/// hech qanday boshqa o'zgarishni talab qilmaydi.
/// Blur yoqilganmi - shaffof sirtlar shunga qarab alpha tanlaydi.
///
/// Blur o'chirilganda yarim shaffof panel orqasidagi xabarlar ko'rinib
/// qoladi, shuning uchun bunday holatda sirtlar noshaffof bo'lishi kerak.
bool get _blurEnabled =>
    !_MaybeBlur._disabledAtBuildTime && _ChatRuntime.instance.features.blurEffects;

/// Blur yoqilgan bo'lsa [translucent], aks holda to'liq noshaffof rang.
Color _surfaceColor(Color base, double translucent) =>
    base.withValues(alpha: _blurEnabled ? translucent : 1);

class _MaybeBlur extends StatelessWidget {
  const _MaybeBlur({required this.filter, this.child});

  final ui.ImageFilter filter;
  final Widget? child;

  /// Build vaqtidagi butunlay o'chirish (o'lchov uchun qulay).
  static const bool _disabledAtBuildTime = bool.fromEnvironment('DISABLE_BLUR');

  @override
  Widget build(BuildContext context) {
    if (!_blurEnabled) return child ?? const SizedBox.shrink();
    return BackdropFilter(filter: filter, child: child);
  }
}
