import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show instantiateImageCodec;
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:stories_editor/src/domain/models/editable_items.dart';
import 'package:stories_editor/src/domain/providers/notifiers/control_provider.dart';
import 'package:stories_editor/src/domain/providers/notifiers/draggable_widget_notifier.dart';
import 'package:stories_editor/src/domain/providers/notifiers/gradient_notifier.dart';
import 'package:stories_editor/src/domain/providers/notifiers/text_editing_notifier.dart';
import 'package:stories_editor/src/l10n/stories_editor_localization.dart';
import 'package:stories_editor/src/presentation/bar_tools/top_tools.dart';
import 'package:stories_editor/src/presentation/draggable_items/delete_item.dart';
import 'package:stories_editor/src/presentation/draggable_items/draggable_widget.dart';
import 'package:stories_editor/src/presentation/text_editor_view/text_editor.dart';
import 'package:stories_editor/src/presentation/utils/constants/app_enums.dart';
import 'package:stories_editor/src/presentation/utils/mixins/safe_set_state_mixin.dart';
import 'package:stories_editor/src/presentation/utils/modal_sheets.dart';

/// The gap between the toolbar and the top of the story.
const double _kToolsToCanvasGap = 10;

/// A toolbar button is 35 tall with 8 of padding above it.
const double _kToolButtonHeight = 43;

class MainView extends StatefulWidget {
  /// on done
  final Function(String)? onDone;
  final StoryPlaceResolver? onResolvePlace;

  final StoriesEditorLocalizationDelegate? storiesEditorLocalizationDelegate;

  /// image the editor opens with, already placed on the canvas
  final String? initialMediaPath;

  const MainView({
    super.key,
    required this.onDone,
    this.onResolvePlace,
    this.initialMediaPath,
    this.storiesEditorLocalizationDelegate,
  });

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> with SafeSetStateMixin {
  /// content container key
  final GlobalKey contentKey = GlobalKey();

  ///Editable item
  EditableItem? _activeItem;

  /// Gesture Detector listen changes
  Offset _initPos = const Offset(0, 0);
  Offset _currentPos = const Offset(0, 0);
  double _currentScale = 1;
  double _currentRotation = 0;

  /// delete position
  bool _isDeletePosition = false;
  bool _inAction = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      StoriesEditorLocalization().init(
        storiesEditorLocalizationDelegate:
            widget.storiesEditorLocalizationDelegate,
      );

      var control = Provider.of<ControlNotifier>(context, listen: false);

      /// open straight onto the picture the caller handed us, the same way the
      /// gallery page seeds the canvas once something is picked
      final initialMediaPath = widget.initialMediaPath;
      if (initialMediaPath != null && initialMediaPath.isNotEmpty) {
        control.mediaPath = initialMediaPath;
        final items =
            Provider.of<DraggableWidgetNotifier>(context, listen: false);
        final item = EditableItem()
          ..type = ItemType.image
          ..position = const Offset(0.0, 0);
        items.draggableWidget.insert(0, item);
        // Measuring the file is async; apply the zoom once it comes back so the
        // canvas is filled without the picture ever being cropped.
        unawaited(
          _coverScale(initialMediaPath).then((scale) {
            if (!mounted || scale <= 1) return;
            item.scale = scale;
            items.draggableWidget = [...items.draggableWidget];
          }),
        );
      }
    });
    super.initState();
  }

  /// How far the picture has to be scaled up to fill the canvas.
  ///
  /// The image is drawn at its natural size and only zoomed — nothing is cut —
  /// so this is the factor that makes the shorter side reach the edge. Zooming
  /// back out from here reveals the rest of the picture over the gradient,
  /// which is the point: a crop would have thrown those pixels away.
  Future<double> _coverScale(String path) async {
    try {
      // Only the shape matters, so decode a small copy (decoding applies the
      // photo's orientation, so it is the shape shown) — not the whole 12-50
      // MP picture, on the main thread, just to read its size.
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
        targetWidth: 512,
      );
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      final screen = ScreenUtil();
      final byWidth = screen.screenWidth / width;
      final byHeight = screen.screenHeight / height;
      // The picture already fits `contain`; scaling by the ratio of the two
      // fits turns that into `cover`.
      final scale = (byWidth > byHeight ? byWidth : byHeight) /
          (byWidth < byHeight ? byWidth : byHeight);
      return scale.isFinite && scale > 1 ? scale : 1;
    } catch (_) {
      // Unreadable file: leave it at natural size rather than guessing.
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _popScope,
      child: Material(
        color: Colors.black,
        child: Consumer4<ControlNotifier, DraggableWidgetNotifier,
            GradientNotifier, TextEditingNotifier>(
          builder: (context, controlNotifier, itemProvider, colorProvider,
              editingProvider, child) {
            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        /// gradient container
                        /// this container will contain all widgets(image/texts/draws/sticker)
                        /// wrap this widget with coloredFilter
                        GestureDetector(
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          // No tap-to-type: tapping the canvas used to open
                          // the keyboard, which made moving items fiddly. The
                          // Aa button is the only way in.
                          // Starts below the toolbar instead of running up
                          // behind it, so the buttons sit on the page rather
                          // than on top of the picture.
                          child: Padding(
                            // Exactly clears TopTools: its own 20 of padding
                            // above and below the 43-tall buttons, then the
                            // gap. Only the padding scales — the button and
                            // the gap are fixed sizes.
                            padding: EdgeInsets.only(
                              top: 40.w +
                                  _kToolButtonHeight +
                                  _kToolsToCanvasGap,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: _StoryFrame(
                                  child: RepaintBoundary(
                                    key: contentKey,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      // Behind the picture: its own
                                      // colours, shown where it is zoomed out.
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                        colors: [
                                          colorProvider.color1,
                                          colorProvider.color2
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )),
                                      child: GestureDetector(
                                        onScaleStart: _onScaleStart,
                                        onScaleUpdate: _onScaleUpdate,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            /// in this case photo view works as a main background container to manage
                                            /// the gestures of all movable items.
                                            PhotoView.customChild(
                                              backgroundDecoration:
                                                  const BoxDecoration(
                                                      color:
                                                          Colors.transparent),
                                              child: Container(),
                                            ),

                                            ///list items
                                            ...itemProvider.draggableWidget
                                                .map((editableItem) {
                                              return DraggableWidget(
                                                context: context,
                                                draggableWidget: editableItem,
                                                onPointerDown: (details) {
                                                  _updateItemPosition(
                                                    editableItem,
                                                    details,
                                                  );
                                                },
                                                onPointerUp: (details) {
                                                  _deleteItemOnCoordinates(
                                                    editableItem,
                                                    details,
                                                  );
                                                },
                                                onPointerMove: (details) {
                                                  _deletePosition(
                                                    editableItem,
                                                    details,
                                                  );
                                                },
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// top tools
                        Visibility(
                          visible: !controlNotifier.isTextEditing,
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: TopTools(
                                contentKey: contentKey,
                                context: context,
                                onResolvePlace: widget.onResolvePlace,
                                onDone: (bytes) {
                                  // Null only if the route lost its data;
                                  // nothing to hand the story to then.
                                  safeSetState(() {
                                    widget.onDone?.call(bytes);
                                  });
                                },
                              )),
                        ),

                        /// delete item when the item is in position
                        DeleteItem(
                          activeItem: _activeItem,
                          animationsDuration: const Duration(milliseconds: 300),
                          isDeletePosition: _isDeletePosition,
                        ),

                        /// show text editor
                        Visibility(
                          visible: controlNotifier.isTextEditing,
                          child: TextEditor(
                            context: context,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// The bottom bar is gone: the tick moved up to TopTools,
                  /// so there is nothing left for it to hold.
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// validate pop scope gesture
  Future<bool> _popScope() async {
    final controlNotifier =
        Provider.of<ControlNotifier>(context, listen: false);

    /// change to false text editing
    if (controlNotifier.isTextEditing) {
      controlNotifier.isTextEditing = !controlNotifier.isTextEditing;
      return false;
    }

    /// show close dialog
    else {
      late final exit = exitDialog(context: context, contentKey: contentKey);

      return (await exit) ?? false;
    }
  }

  /// start item scale
  void _onScaleStart(ScaleStartDetails details) {
    if (_activeItem == null) {
      return;
    }
    _initPos = details.focalPoint;
    _currentPos = _activeItem!.position;
    _currentScale = _activeItem!.scale;
    _currentRotation = _activeItem!.rotation;
  }

  /// update item scale
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final ScreenUtil screenUtil = ScreenUtil();
    if (_activeItem == null) {
      return;
    }
    final delta = details.focalPoint - _initPos;

    final left = (delta.dx / screenUtil.screenWidth) + _currentPos.dx;
    final top = (delta.dy / screenUtil.screenHeight) + _currentPos.dy;

    safeSetState(() {
      _activeItem!.position = Offset(left, top);
      _activeItem!.rotation = details.rotation + _currentRotation;
      _activeItem!.scale = details.scale * _currentScale;
    });
  }

  /// active delete widget with offset position
  void _deletePosition(EditableItem item, PointerMoveEvent details) {
    if (item.type == ItemType.text &&
        item.position.dy >= 0.75.h &&
        item.position.dx >= -0.4.w &&
        item.position.dx <= 0.2.w) {
      safeSetState(() {
        _isDeletePosition = true;
        item.deletePosition = true;
      });
    } else {
      safeSetState(() {
        _isDeletePosition = false;
        item.deletePosition = false;
      });
    }
  }

  /// delete item widget with offset position
  void _deleteItemOnCoordinates(EditableItem item, PointerUpEvent details) {
    var itemProvider =
        Provider.of<DraggableWidgetNotifier>(context, listen: false)
            .draggableWidget;
    _inAction = false;
    if (item.type == ItemType.image) {
    } else if (item.type == ItemType.text &&
        item.position.dy >= 0.75.h &&
        item.position.dx >= -0.4.w &&
        item.position.dx <= 0.2.w) {
      safeSetState(() {
        itemProvider.removeAt(itemProvider.indexOf(item));
        HapticFeedback.heavyImpact();
      });
    } else {
      safeSetState(() {
        _activeItem = null;
      });
    }
    safeSetState(() {
      _activeItem = null;
    });
  }

  /// update item position, scale, rotation
  void _updateItemPosition(EditableItem item, PointerDownEvent details) {
    if (_inAction) {
      return;
    }

    _inAction = true;
    _activeItem = item;
    _initPos = details.position;
    _currentPos = item.position;
    _currentScale = item.scale;
    _currentRotation = item.rotation;

    /// set vibrate
    HapticFeedback.lightImpact();
  }
}

/// The story's frame: always 9:16, as wide as the screen unless that is too
/// tall for the room under the toolbar, then narrower (a short phone shows a
/// thin black band each side). It used to take whatever height was left, so a
/// story's shape was the poster's phone's: one made on a tall phone lost its
/// bottom on a shorter one, where people put the place and time.
class _StoryFrame extends StatelessWidget {
  const _StoryFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        var width = box.maxWidth;
        var height = width * 16 / 9;
        if (height > box.maxHeight) {
          height = box.maxHeight;
          width = height * 9 / 16;
        }
        return SizedBox(width: width, height: height, child: child);
      },
    );
  }
}
