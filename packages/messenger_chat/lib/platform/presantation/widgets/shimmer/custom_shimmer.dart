
part of messenger_chat;

class _CustomShimmerEffect extends StatelessWidget {

  const _CustomShimmerEffect({
    required this.child,
    this.isLoading = false,
    this.effectType = _ShimmerEffectType.none,
  });
  final Widget child;
  final bool isLoading;
  final _ShimmerEffectType effectType;

  @override
  Widget build(BuildContext context) => Skeletonizer(
      justifyMultiLineText: true,
      enabled: isLoading,
      effect: ShimmerEffect(
        baseColor: Colors.grey.withAlpha((255 * 0.2).round()),
        highlightColor: Colors.grey.shade100.withAlpha((255 * 0.5).round()),
        begin: const Alignment(-1, -1),
        end: const Alignment(1, -0.7),
      ),
      child: _effectType(child, effectType),
    );

  static Widget _effectType(Widget child, _ShimmerEffectType effectType) => switch (effectType) {
      _ShimmerEffectType.none => child,
      _ShimmerEffectType.leaf => Skeleton.leaf(
        child: child,
      ),
      _ShimmerEffectType.shade => Skeleton.shade(child: child),
      _ShimmerEffectType.replace =>
          Skeleton.replace(child: child),
      _ShimmerEffectType.ignorePointer =>
          Skeleton.ignorePointer(child: child),
      _ShimmerEffectType.ignore => Skeleton.ignore(child: child),
      _ShimmerEffectType.unite => Skeleton.unite(child: child),
      _ShimmerEffectType.keep => Skeleton.keep(child: child),
    };

  static Widget sliver(
      BuildContext context, {
        required Widget child,
        final bool? isLoading,
        _ShimmerEffectType effectType = _ShimmerEffectType.none,
      }) => Skeletonizer.sliver(
      effect: ShimmerEffect(
        highlightColor: Colors.grey.withAlpha((255 * 0.3).round()),
        baseColor: Colors.grey.shade100,
        begin: const Alignment(-1, -1),
        end: const Alignment(1, -0.7),
      ),
      enabled: isLoading ?? false,
      child: _effectType(child, effectType),
    );
}

enum _ShimmerEffectType {
  none,
  leaf,
  shade,
  replace,
  ignorePointer,
  ignore,
  unite,
  keep,
}
