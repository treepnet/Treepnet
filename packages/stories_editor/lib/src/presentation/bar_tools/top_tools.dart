import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stories_editor/src/domain/models/editable_items.dart';
import 'package:stories_editor/src/domain/providers/notifiers/control_provider.dart';
import 'package:stories_editor/src/domain/providers/notifiers/draggable_widget_notifier.dart';
import 'package:stories_editor/src/domain/providers/notifiers/painting_notifier.dart';
import 'package:stories_editor/src/domain/sevices/save_as_image.dart';
import 'package:stories_editor/src/presentation/utils/constants/app_enums.dart';
import 'package:stories_editor/src/presentation/utils/mixins/safe_set_state_mixin.dart';
import 'package:stories_editor/src/presentation/utils/modal_sheets.dart';
import 'package:stories_editor/src/presentation/widgets/animated_onTap_button.dart';
import 'package:stories_editor/src/presentation/widgets/tool_button.dart';

/// Finds the country and region the story belongs to. Supplied by the app,
/// which owns both the EXIF reading and the region index — the editor only
/// knows that it wants a label.
typedef StoryPlaceResolver = Future<String?> Function(BuildContext context);

/// The editor's toolbar: leave, add text, stamp the time, stamp the place, and
/// finish.
///
/// Time and place are added as ordinary draggable text items, so they can be
/// dragged and scaled like anything else on the story instead of being pinned
/// where the toolbar happened to put them.
class TopTools extends StatefulWidget {
  final GlobalKey contentKey;
  final BuildContext context;

  /// Renders the story and hands back the file. The tick lives up here with the
  /// other controls rather than in a bar of its own at the bottom.
  final Function(String imageUri) onDone;

  /// Resolves the place label. Null hides the place button.
  final StoryPlaceResolver? onResolvePlace;

  const TopTools({
    super.key,
    required this.contentKey,
    required this.context,
    required this.onDone,
    this.onResolvePlace,
  });

  @override
  State<TopTools> createState() => _TopToolsState();
}

class _TopToolsState extends State<TopTools> with SafeSetStateMixin {
  /// Blocks a second tap while the story is rendering.
  bool _finishing = false;

  /// Waiting on the place lookup, which can open a map or ask a permission.
  bool _resolvingPlace = false;

  static const _iconSize = 24.0;

  Widget _icon(String name) => SvgPicture.asset(
        'packages/stories_editor/assets/svg/$name.svg',
        width: _iconSize,
        height: _iconSize,
      );

  Widget get _spinner => const SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );

  /// Drops a chip onto the story — white text on a translucent dark pill, the
  /// design's style for time and place.
  /// The design's chip fill: #191919 at 50%.
  static const chipBackground = Color(0x80191919);

  void _addChip(
    DraggableWidgetNotifier itemNotifier,
    String text, {
    double fontSize = 20,
  }) {
    // Reassign rather than .add(): the getter hands back the raw list, so
    // mutating it never notifies and the chip only appeared on the next tap.
    itemNotifier.draggableWidget = [
      ...itemNotifier.draggableWidget,
      EditableItem()
        ..type = ItemType.text
        ..text = text
        ..textList = [text]
        ..textColor = Colors.white
        ..backGroundColor = chipBackground
        ..fontSize = fontSize
        ..textAlign = TextAlign.center
        ..position = const Offset(0.0, 0.0),
    ];
    safeSetState(() {});
  }

  String get _now {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _addPlace(DraggableWidgetNotifier itemNotifier) async {
    final resolve = widget.onResolvePlace;
    if (resolve == null || _resolvingPlace) return;
    safeSetState(() => _resolvingPlace = true);
    try {
      final label = await resolve(context);
      if (label != null && label.trim().isNotEmpty) {
        _addChip(itemNotifier, label.trim());
      }
    } finally {
      if (mounted) safeSetState(() => _resolvingPlace = false);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    safeSetState(() => _finishing = true);
    final bytes = await takePicture(
      contentKey: widget.contentKey,
      context: context,
      saveToGallery: false,
    );
    if (bytes != null) {
      // Stays disabled — the editor closes behind this.
      widget.onDone(bytes);
      return;
    }
    // Rendering failed: let them try again.
    if (mounted) safeSetState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ControlNotifier, PaintingNotifier,
        DraggableWidgetNotifier>(
      builder: (_, controlNotifier, paintingNotifier, itemNotifier, __) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20.w),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// leave
                _BarButton(
                  onTap: () => exitDialog(
                    context: widget.context,
                    contentKey: widget.contentKey,
                  ).then((exit) {
                    if (exit == null || !exit) return;
                    if (!context.mounted) return;
                    // Discarded: the flow reopens the camera on `true`.
                    context.pop(true);
                  }),
                  child: _icon('back'),
                ),

                /// only a blank story has a background to cycle
                if (controlNotifier.mediaPath.isEmpty)
                  _selectColor(
                    controlProvider: controlNotifier,
                    onTap: () {
                      if (controlNotifier.gradientIndex >=
                          controlNotifier.gradientColors!.length - 1) {
                        safeSetState(() => controlNotifier.gradientIndex = 0);
                      } else {
                        safeSetState(() => controlNotifier.gradientIndex += 1);
                      }
                    },
                  ),

                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BarButton(
                        onTap: () => controlNotifier.isTextEditing =
                            !controlNotifier.isTextEditing,
                        child: _icon('text'),
                      ),
                      _BarButton(
                        // Bigger than the rest: a clock is short, and at the
                        // shared size it was fiddly to grab and move.
                        onTap: () => _addChip(itemNotifier, _now, fontSize: 34),
                        child: _icon('time'),
                      ),
                      if (widget.onResolvePlace != null)
                        _BarButton(
                          onTap: () => _addPlace(itemNotifier),
                          child: _resolvingPlace ? _spinner : _icon('place'),
                        ),
                    ],
                  ),
                ),
                _BarButton(
                  onTap: _finish,
                  child: _finishing ? _spinner : _icon('done'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// gradient color selector
  Widget _selectColor({onTap, controlProvider}) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, top: 8),
      child: AnimatedOnTapButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: controlProvider
                      .gradientColors![controlProvider.gradientIndex]),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A bare glyph with a comfortable tap target — no ring, unlike [ToolButton].
class _BarButton extends StatelessWidget {
  const _BarButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOnTapButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: child,
      ),
    );
  }
}
