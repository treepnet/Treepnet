import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/location_picker_map.dart';

/// The sheet's dark surface colour.
const _sheetBackground = Color(0xFF191919);

/// A location the story will be pinned to (lat/lng + a display name).
typedef _Point = ({double lat, double lng, String? name});

/// Opens the "Pin story" sheet: choose places and highlights, then confirm to
/// pin. Owner-only; the caller (the story's "more" menu) guards that.
Future<void> showPinStorySheet(
  BuildContext context, {
  required Story story,
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => PinStorySheet(story: story, userId: userId),
  );
}

/// {@template pin_story_sheet}
/// Pins a story to places and highlights. Selections are held locally and only
/// written when the ✓ in the header is tapped — nothing is pinned until then.
/// {@endtemplate}
class PinStorySheet extends StatefulWidget {
  /// {@macro pin_story_sheet}
  const PinStorySheet({required this.story, required this.userId, super.key});

  final Story story;
  final String userId;

  @override
  State<PinStorySheet> createState() => _PinStorySheetState();
}

class _PinStorySheetState extends State<PinStorySheet> {
  /// The single selected existing place — at most one location may be pinned.
  _Point? _selectedLocation;

  /// A brand-new place created through the map — takes the "Add location" slot.
  PickedLocation? _newLocation;

  /// The single selected existing highlight id — at most one highlight.
  String? _selectedHighlightId;

  /// A brand-new highlight to create on confirm — takes the "New highlight"
  /// slot, mirroring how a new place takes the "Add location" slot.
  String? _newHighlightName;

  bool _saving = false;

  /// Both a location AND a highlight must be picked before the ✓ enables —
  /// pinning to only one is not allowed.
  bool get _hasSelection =>
      (_newLocation != null || _selectedLocation != null) &&
      (_newHighlightName != null || _selectedHighlightId != null);

  String _key(double lat, double lng) => '$lat,$lng';

  StoriesRepository get _stories => context.read<StoriesRepository>();

  String _nameOf(PickedLocation l) =>
      (l.placeName?.trim().isNotEmpty ?? false) ? l.placeName! : l.region.name;

  Future<void> _pickNewLocation() async {
    final picked = await showLocationPicker(context);
    if (picked == null || !mounted) return;
    // Max one location: a new place clears any selected existing one.
    setState(() {
      _newLocation = picked;
      _selectedLocation = null;
    });
  }

  void _removeNewLocation() => setState(() => _newLocation = null);

  void _toggleLocation(_Point p) {
    setState(() {
      final selected = _selectedLocation;
      if (selected != null &&
          _key(selected.lat, selected.lng) == _key(p.lat, p.lng)) {
        _selectedLocation = null;
      } else {
        _selectedLocation = p;
        _newLocation = null; // max one location
      }
    });
  }

  void _toggleHighlight(String id) {
    setState(() {
      if (_selectedHighlightId == id) {
        _selectedHighlightId = null;
      } else {
        _selectedHighlightId = id;
        _newHighlightName = null; // max one highlight
      }
    });
  }

  void _removeNewHighlight() => setState(() => _newHighlightName = null);

  Future<void> _promptNewHighlight() async {
    final name = await _highlightNameDialog();
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() {
      _newHighlightName = name.trim();
      _selectedHighlightId = null; // max one highlight
    });
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final storyId = widget.story.id;

      // New place created via the map.
      final nl = _newLocation;
      if (nl != null) {
        await _stories.pinStoryToLocation(
          userId: widget.userId,
          storyId: storyId,
          regionIso: nl.region.iso,
          lat: nl.lat,
          lng: nl.lng,
        );
        await _stories.setStoryLocation(
          storyId: storyId,
          lat: nl.lat,
          lng: nl.lng,
          name: _nameOf(nl),
        );
      }

      // Selected existing place.
      final sel = _selectedLocation;
      if (sel != null) {
        await GeoRegions.instance.load();
        final iso = GeoRegions.instance.regionAt(sel.lng, sel.lat)?.iso;
        if (iso != null) {
          await _stories.pinStoryToLocation(
            userId: widget.userId,
            storyId: storyId,
            regionIso: iso,
            lat: sel.lat,
            lng: sel.lng,
          );
          await _stories.setStoryLocation(
            storyId: storyId,
            lat: sel.lat,
            lng: sel.lng,
            name: sel.name,
          );
        }
      }

      // Highlights.
      final selHl = _selectedHighlightId;
      if (selHl != null) {
        await _stories.addStoryToHighlight(highlightId: selHl, storyId: storyId);
      }
      final newName = _newHighlightName;
      if (newName != null) {
        await _stories.createStoryHighlight(
          userId: widget.userId,
          name: newName,
          storyIds: [storyId],
          coverUrl: widget.story.contentUrl,
        );
      }

      if (mounted) {
        Navigator.of(context).maybePop();
        openSnackbar(
          SnackbarMessage.success(title: context.l10n.successfullyPinnedText),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _highlightNameDialog() {
    final controller = TextEditingController();
    final cover = widget.story.contentUrl;
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _sheetBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The story itself is the highlight cover — shown as an avatar,
              // top-centre.
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.inputSpace,
                backgroundImage: cover.isNotEmpty
                    ? CachedNetworkImageProvider(cover)
                    : null,
              ),
              const Gap.v(AppSpacing.lg),
              // Placeholder and caret both centred, no border.
              TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: context.l10n.highlightNameText,
                  hintStyle: const TextStyle(color: AppColors.grey),
                ),
                onSubmitted: (v) => Navigator.of(context).pop(v),
              ),
              const Gap.v(AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancelText),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(controller.text),
                    child: Text(context.l10n.createText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap-content, not a fixed-fraction DraggableScrollableSheet: the sheet is
    // exactly as tall as its two rows, so there is no dead space below them and
    // more of the story shows above it.
    return Container(
      decoration: const BoxDecoration(
        color: _sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header: centred title, and a ✓ that pins the selections.
            Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    context.l10n.pinStoryText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Tappable.faded(
                        onTap: _hasSelection ? _confirm : null,
                        child: Icon(
                          Icons.check,
                          color: _hasSelection
                              ? AppColors.white
                              : const Color(0xFF414141),
                        ),
                      ),
              ],
            ),
            const Gap.v(AppSpacing.lg),
            _LocationRow(
              userId: widget.userId,
              newLocation: _newLocation,
              newLocationName: _newLocation == null
                  ? null
                  : _nameOf(_newLocation!),
              selectedKey: _selectedLocation == null
                  ? null
                  : _key(_selectedLocation!.lat, _selectedLocation!.lng),
              onAddOrEdit: _pickNewLocation,
              onRemoveNew: _removeNewLocation,
              onToggle: _toggleLocation,
              keyOf: _key,
            ),
            const Divider(
              height: AppSpacing.xlg,
              color: AppColors.borderOutline,
            ),
            _HighlightRow(
              userId: widget.userId,
              storyCoverUrl: widget.story.contentUrl,
              newName: _newHighlightName,
              selectedId: _selectedHighlightId,
              onNewOrEdit: _promptNewHighlight,
              onRemoveNew: _removeNewHighlight,
              onToggle: _toggleHighlight,
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal list of the user's places. The first slot is either the "Add
/// location" button or, once a place has been created on the map, that place
/// (tapping it re-opens the map to edit it).
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.userId,
    required this.newLocation,
    required this.newLocationName,
    required this.selectedKey,
    required this.onAddOrEdit,
    required this.onRemoveNew,
    required this.onToggle,
    required this.keyOf,
  });

  final String userId;
  final PickedLocation? newLocation;
  final String? newLocationName;
  final String? selectedKey;
  final VoidCallback onAddOrEdit;
  final VoidCallback onRemoveNew;
  final ValueChanged<_Point> onToggle;
  final String Function(double lat, double lng) keyOf;

  @override
  Widget build(BuildContext context) {
    final posts = context.read<PostsRepository>();
    return StreamBuilder<List<_Point>>(
      stream: posts.visitedPointsOf(userId: userId),
      builder: (context, snap) {
        final points = snap.data ?? const <_Point>[];
        final seen = <String>{};
        final unique = points.where((p) => seen.add(keyOf(p.lat, p.lng))).toList();
        final children = <Widget>[
          if (newLocation == null)
            _AddTile(
              icon: Icons.add_location_alt_outlined,
              label: context.l10n.addLocationText,
              onTap: onAddOrEdit,
            )
          else
            // The just-created place takes the "Add location" slot; tapping it
            // re-opens the map to edit it, and the X removes it (bringing the
            // "Add location" button back).
            _PinTile(
              name: newLocationName ?? context.l10n.locationText,
              selected: true,
              onTap: onAddOrEdit,
              onRemove: onRemoveNew,
            ),
          for (final p in unique)
            _PinTile(
              name: (p.name?.trim().isNotEmpty ?? false)
                  ? p.name!
                  : context.l10n.locationText,
              selected: selectedKey == keyOf(p.lat, p.lng),
              onTap: () => onToggle(p),
            ),
        ];
        // Nothing to scroll through yet: centre the lone "Add location" button.
        final onlyAdd = newLocation == null && unique.isEmpty;
        return SizedBox(
          height: 100,
          child: onlyAdd
              ? Center(child: children.first)
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: children,
                ),
        );
      },
    );
  }
}

/// Horizontal list of the user's highlights plus a "Name" tile that names a new
/// highlight (created on confirm).
class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.userId,
    required this.storyCoverUrl,
    required this.newName,
    required this.selectedId,
    required this.onNewOrEdit,
    required this.onRemoveNew,
    required this.onToggle,
  });

  final String userId;

  /// The story being pinned — a brand-new highlight uses it as its cover, so
  /// the tile shows the story itself rather than a blank circle.
  final String? storyCoverUrl;

  /// The name of the not-yet-created highlight; null until one is named.
  final String? newName;
  final String? selectedId;
  final VoidCallback onNewOrEdit;
  final VoidCallback onRemoveNew;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final stories = context.read<StoriesRepository>();
    return StreamBuilder<List<StoryHighlight>>(
      stream: stories.storyHighlightsOf(userId: userId),
      builder: (context, snap) {
        // Only real highlights that still have stories — mirror the profile
        // row's filter so emptied/deleted highlights don't show here either.
        final highlights = (snap.data ?? const <StoryHighlight>[])
            .where((h) => h.storyCount > 0)
            .toList();
        final children = <Widget>[
          // The just-named highlight takes the "New highlight" slot (with the
          // story as its cover); tapping it re-opens the name dialog.
          if (newName == null)
            _AddTile(
              icon: Icons.add,
              label: context.l10n.newHighlightText,
              onTap: onNewOrEdit,
            )
          else
            _HighlightTile(
              name: newName!,
              coverUrl: storyCoverUrl,
              selected: true,
              onTap: onNewOrEdit,
              onRemove: onRemoveNew,
            ),
          for (final h in highlights)
            _HighlightTile(
              name: h.name,
              coverUrl: h.coverUrl,
              selected: selectedId == h.id,
              onTap: () => onToggle(h.id),
            ),
        ];
        final onlyAdd = newName == null && highlights.isEmpty;
        return SizedBox(
          height: 104,
          child: onlyAdd
              ? Center(child: children.first)
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: children,
                ),
        );
      },
    );
  }
}

/// The circular "add" tile — same shape as the highlight "Name" tile, used for
/// both the "Add location" and "Name" (new highlight) slots.
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Tappable.faded(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.inputSpace,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.grey),
            ),
            const Gap.v(AppSpacing.xs),
            SizedBox(
              width: 72,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTile extends StatelessWidget {
  const _PinTile({
    required this.name,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  /// When set, a small X sits in the top-left corner; tapping it removes the
  /// tile (used only for the just-created "new location" slot).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Tappable.faded(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.white,
                    size: 56,
                  ),
                  if (selected)
                    const Positioned(right: 4, bottom: 8, child: _CheckBadge()),
                  if (onRemove != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _RemoveBadge(onTap: onRemove!),
                    ),
                ],
              ),
            ),
            const Gap.v(AppSpacing.xs),
            SizedBox(
              width: 72,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.name,
    required this.coverUrl,
    required this.selected,
    this.onTap,
    this.onRemove,
  });

  final String name;
  final String? coverUrl;
  final bool selected;
  final VoidCallback? onTap;

  /// When set, a small X sits in the top-left corner; tapping it removes the
  /// tile (used only for the just-created "new highlight" slot).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cover = coverUrl;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Tappable.faded(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.inputSpace,
                    image: (cover != null && cover.isNotEmpty)
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(cover),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
                if (selected)
                  const Positioned(right: 0, bottom: 0, child: _CheckBadge()),
                if (onRemove != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _RemoveBadge(onTap: onRemove!),
                  ),
              ],
            ),
            const Gap.v(AppSpacing.xs),
            SizedBox(
              width: 72,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small X in the top-left corner of a just-created tile — removing it brings
/// the "Add location" / "New highlight" button back.
class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 1),
        ),
        child: const Icon(Icons.close, color: AppColors.white, size: 12),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: _sheetBackground, width: 2),
      ),
      child: const Icon(Icons.check, color: AppColors.white, size: 12),
    );
  }
}
