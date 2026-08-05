import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/map.dart';
import 'package:user_repository/user_repository.dart';

/// The last onboarding step: mark the places you've already been, so the travel
/// map — the app's whole point — is coloured in from day one instead of staying
/// blank until the first post.
///
/// Picking is deliberately two-handed: tap regions straight on the map, or use
/// the shortcut row of popular places — which also flies the map there, so the
/// two ways never disagree. Searching through 4,500 admin-1 regions (the first
/// attempt) was far too much work, and a country → region drill-down still
/// took three steps.
///
/// Saving is best-effort: if it fails the user still gets into the app rather
/// than being stuck behind a broken step.
class VisitedRegionsPage extends StatefulWidget {
  const VisitedRegionsPage({super.key});

  @override
  State<VisitedRegionsPage> createState() => _VisitedRegionsPageState();
}

class _VisitedRegionsPageState extends State<VisitedRegionsPage> {
  final _selected = <String>{};
  LatLngBounds? _focus;
  int _focusToken = 0;

  /// Captured once: a future recreated per build would reset the map.
  late final Future<void> _geoReady = GeoRegions.instance.load();
  bool _saving = false;

  /// The opening view: Central Asia framed, with the surrounding countries
  /// still on screen. Opening on a single province was far too tight.
  static final _centralAsia = LatLngBounds(
    const LatLng(33, 46),
    const LatLng(49, 85),
  );

  /// Camera box around a single region. The padding is a small fraction of the
  /// region — a fixed or generous margin made big regions (Karakalpakstan,
  /// say) frame so wide that picking one zoomed the map *out*.
  LatLngBounds? _boundsOf(String iso) {
    final b = GeoRegions.instance.regionByIso(iso)?.lngLatBounds;
    if (b == null) return null;
    final padLng = (b.width * 0.3).clamp(0.12, 2.0);
    final padLat = (b.height * 0.3).clamp(0.12, 2.0);
    return LatLngBounds(
      LatLng((b.top - padLat).clamp(-85, 85), (b.left - padLng).clamp(-180, 180)),
      LatLng(
        (b.bottom + padLat).clamp(-85, 85),
        (b.right + padLng).clamp(-180, 180),
      ),
    );
  }

  /// Tapping a chip both marks the place and flies the map to it, so the two
  /// ways of picking always agree.
  void _toggle(String iso, {bool focus = false}) => setState(() {
    if (!_selected.remove(iso)) _selected.add(iso);
    if (focus) {
      _focus = _boundsOf(iso);
      _focusToken++;
    }
  });

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final users = context.read<UserRepository>();
    final userId = context.read<AppBloc>().state.user.id;
    try {
      if (_selected.isNotEmpty) {
        await users.setVisitedRegions(userId: userId, regionIsos: _selected);
      }
    } catch (_) {
      // Marking places is a nice-to-have; never block getting into the app.
    }
    try {
      await users.completeOnboarding();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        body: SafeArea(
          child: FutureBuilder<void>(
            future: _geoReady,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              // The first frame needs a camera box too, not just after a tap.
              _focus ??= _centralAsia;
              return _buildBody(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final counts = {for (final iso in _selected) iso: 1};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.visitedTitle,
                style: context.displayMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: AppFontWeight.bold,
                ),
              ),
              const Gap.v(AppSpacing.xxs),
              Text(
                context.l10n.visitedSubtitle,
                style: context.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // The map is the main surface: tap any region to mark it and watch it
        // colour in immediately.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              child: TravelMap(
                visitedCounts: counts,
                height: double.infinity,
                tapAnyRegion: true,
                focusBounds: _focus,
                focusToken: _focusToken,
                onTargetTap: (target) => _toggle(target.region.iso),
              ),
            ),
          ),
        ),

        // Search: type a region or country, tap a result to mark it and fly
        // the map there.
        _RegionSearch(
          selected: _selected,
          onPicked: (iso) => _toggle(iso, focus: true),
        ),

        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _WideButton(
            label: _selected.isEmpty
                ? context.l10n.onboardingSkipText
                : '${context.l10n.visitedStartText} (${_selected.length})',
            busy: _saving,
            onTap: _finish,
          ),
        ),
      ],
    );
  }
}

/// Region search over the whole admin-1 index: type a name, tap a result to
/// mark it (and fly the map there). Results sit above the field since it lives
/// near the bottom of the screen.
class _RegionSearch extends StatefulWidget {
  const _RegionSearch({required this.selected, required this.onPicked});

  final Set<String> selected;
  final ValueChanged<String> onPicked;

  @override
  State<_RegionSearch> createState() => _RegionSearchState();
}

class _RegionSearchState extends State<_RegionSearch> {
  final _controller = TextEditingController();
  List<GeoRegion> _results = const [];

  static const _maxResults = 8;

  void _onChanged(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final matches = <GeoRegion>[];
    for (final region in GeoRegions.instance.allRegions) {
      if (region.name.toLowerCase().startsWith(query) ||
          region.countryName.toLowerCase().startsWith(query)) {
        matches.add(region);
        if (matches.length >= _maxResults) break;
      }
    }
    setState(() => _results = matches);
  }

  void _pick(GeoRegion region) {
    widget.onPicked(region.iso);
    _controller.clear();
    setState(() => _results = const []);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.inputSpace,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final region = _results[i];
                final selected = widget.selected.contains(region.iso);
                return ListTile(
                  dense: true,
                  onTap: () => _pick(region),
                  title: Text(
                    region.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  trailing: Text(
                    region.countryName,
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: context.l10n.searchText,
              hintStyle: const TextStyle(color: AppColors.grey),
              prefixIcon: const Icon(Icons.search, color: AppColors.grey),
              filled: true,
              fillColor: AppColors.inputSpace,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Tappable.scaled(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    label,
                    style: context.labelLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: AppFontWeight.semiBold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
