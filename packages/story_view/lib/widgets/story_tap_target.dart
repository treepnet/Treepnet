import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A tap target inside a story page, such as a Retry button.
///
/// The story view lays its own tap-to-advance detector over the whole page,
/// and that detector would win an ordinary button's tap: pressing it moved on
/// to the next story. This claims the tap the moment the finger lands, so the
/// page underneath never sees it.
class StoryTapTarget extends StatelessWidget {
  const StoryTapTarget({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EagerTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerTapGestureRecognizer>(
          _EagerTapGestureRecognizer.new,
          (recognizer) => recognizer.onTap = onTap,
        ),
      },
      child: child,
    );
  }
}

class _EagerTapGestureRecognizer extends TapGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
