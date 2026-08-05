import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/travel_map.dart';
import 'package:treepnet/map/travel_stats.dart';

/// {@template travel_passport_page}
/// Treepnet's signature "Travel Passport" — a gamified, shareable summary of
/// everywhere a user has posted from: their level, % of the world explored,
/// an interactive map, achievement badges, continents, and passport-style
/// country stamps. Built entirely from the regions already stored on posts, so
/// it's additive and needs no backend changes.
/// {@endtemplate}
class TravelPassportPage extends StatelessWidget {
  /// {@macro travel_passport_page}
  const TravelPassportPage({required this.userId, super.key});

  final String userId;

  static const _accent = Color(0xFF2ED573);
  static const _gold = Color(0xFFF5C451);

  @override
  Widget build(BuildContext context) {
    final postsRepository = context.read<PostsRepository>();
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.passportTitle,
            style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        body: FutureBuilder<void>(
          future: GeoRegions.instance.load(),
          builder: (context, geoSnapshot) {
            if (geoSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<Map<String, int>>(
              stream: postsRepository.visitedRegionCountsOf(userId: userId),
              builder: (context, snapshot) {
                final visited = snapshot.data ?? const <String, int>{};
                return _PassportBody(visitedCounts: visited);
              },
            );
          },
        ),
      ),
    );
  }
}

class _PassportBody extends StatelessWidget {
  const _PassportBody({required this.visitedCounts});

  final Map<String, int> visitedCounts;

  @override
  Widget build(BuildContext context) {
    final visited = visitedCounts.keys.toSet();
    final stats = TravelStats.fromVisited(visited);

    // Regions per visited country, for the stamps section.
    final byCountry = <String, ({String name, int count})>{};
    for (final iso in visited) {
      final region = GeoRegions.instance.regionByIso(iso);
      if (region == null || region.countryCode.isEmpty) continue;
      final prev = byCountry[region.countryCode];
      byCountry[region.countryCode] = (
        name: region.countryName,
        count: (prev?.count ?? 0) + 1,
      );
    }
    final continentsVisited = <String>{
      for (final cc in byCountry.keys)
        if (countryContinents[cc] != null) countryContinents[cc]!,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxlg),
      children: [
        _HeroCard(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        _StatsRow(stats: stats),
        const SizedBox(height: AppSpacing.xlg),
        _sectionTitle(context.l10n.passportMapSection),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 230,
            child: TravelMap(visitedCounts: visitedCounts, height: 230),
          ),
        ),
        const SizedBox(height: 22),
        _sectionTitle(context.l10n.passportAchievementsSection),
        const SizedBox(height: 12),
        _AchievementsGrid(stats: stats),
        const SizedBox(height: 22),
        _sectionTitle(
          context.l10n.passportContinentsSection(continentsVisited.length),
        ),
        const SizedBox(height: 12),
        _ContinentsWrap(visited: continentsVisited),
        const SizedBox(height: 22),
        if (byCountry.isNotEmpty) ...[
          _sectionTitle(context.l10n.passportStampsSection(byCountry.length)),
          const SizedBox(height: 12),
          _StampsWrap(byCountry: byCountry),
        ] else
          const _EmptyHint(),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.white,
      fontSize: 17,
      fontWeight: FontWeight.bold,
    ),
  );
}

/// [TravelStats.level] is a key; this turns it into the reader's language.
String _levelLabel(BuildContext context, String key) => switch (key) {
  'legendary' => context.l10n.travelLevelLegendary,
  'worldWanderer' => context.l10n.travelLevelWorldWanderer,
  'globetrotter' => context.l10n.travelLevelGlobetrotter,
  'experienced' => context.l10n.travelLevelExperienced,
  'explorer' => context.l10n.travelLevelExplorer,
  'new' => context.l10n.travelLevelNew,
  _ => context.l10n.travelLevelStart,
};

/// Big gradient hero card: level badge, % of world, animated progress to next.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final TravelStats stats;

  @override
  Widget build(BuildContext context) {
    final maxed = stats.nextLevelAt == 0;
    final progress = maxed
        ? 1.0
        : (stats.countries / stats.nextLevelAt).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF16301F), Color(0xFF122A44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: TravelPassportPage._accent.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: TravelPassportPage._accent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: TravelPassportPage._gold.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Text(
                  stats.levelEmoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.passportLevelLabel.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.38),
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _levelLabel(context, stats.level),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.worldPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: TravelPassportPage._accent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'dunyo',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation(
                  TravelPassportPage._accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              maxed
                  ? context.l10n.passportMaxedText
                  : context.l10n.passportNextLevelText(
                      stats.nextLevelAt - stats.countries,
                    ),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final TravelStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: stats.regions,
            label: context.l10n.passportRegionsLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: stats.countries,
            label: context.l10n.passportCountriesLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: stats.continents,
            label: context.l10n.passportContinentsLabel,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.white.withValues(alpha: 0.54), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A milestone badge with its unlock rule.
typedef _Badge = ({String emoji, String title, bool unlocked, String need});

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.stats});

  final TravelStats stats;

  List<_Badge> _badges(BuildContext context) {
    final r = stats.regions;
    final c = stats.countries;
    final k = stats.continents;
    final l10n = context.l10n;
    return [
      (
        emoji: '📍',
        title: l10n.badgeFirstStep,
        unlocked: r >= 1,
        need: l10n.passportNeedRegions(1),
      ),
      (
        emoji: '🗺️',
        title: l10n.badgeTraveller,
        unlocked: r >= 5,
        need: l10n.passportNeedRegions(5),
      ),
      (
        emoji: '🌟',
        title: l10n.badgeExperienced,
        unlocked: r >= 15,
        need: l10n.passportNeedRegions(15),
      ),
      (
        emoji: '🧭',
        title: l10n.badgeExplorer,
        unlocked: c >= 2,
        need: l10n.passportNeedCountries(2),
      ),
      (
        emoji: '✈️',
        title: l10n.badgeBorderCrosser,
        unlocked: c >= 5,
        need: l10n.passportNeedCountries(5),
      ),
      (
        emoji: '🌍',
        title: l10n.badgeGlobetrotter,
        unlocked: c >= 10,
        need: l10n.passportNeedCountries(10),
      ),
      (
        emoji: '🌏',
        title: l10n.badgeWorldWanderer,
        unlocked: c >= 20,
        need: l10n.passportNeedCountries(20),
      ),
      (
        emoji: '👑',
        title: l10n.badgeLegendary,
        unlocked: c >= 30,
        need: l10n.passportNeedCountries(30),
      ),
      (
        emoji: '🌐',
        title: l10n.badgeTwoContinents,
        unlocked: k >= 2,
        need: l10n.passportNeedContinents(2),
      ),
      (
        emoji: '🏔️',
        title: l10n.badgeThreeContinents,
        unlocked: k >= 3,
        need: l10n.passportNeedContinents(3),
      ),
      (
        emoji: '🚀',
        title: l10n.badgeWholeWorld,
        unlocked: k >= 5,
        need: l10n.passportNeedContinents(5),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badges(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: badges.length,
      itemBuilder: (context, i) => _BadgeTile(badge: badges[i]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.unlocked;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: unlocked
            ? const LinearGradient(
                colors: [Color(0xFF23351F), Color(0xFF1B2E22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: unlocked ? null : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: unlocked
              ? TravelPassportPage._gold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.35,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 6),
          Text(
            badge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unlocked ? context.l10n.passportUnlockedText : badge.need,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked
                  ? TravelPassportPage._accent
                  : Colors.white30,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinentsWrap extends StatelessWidget {
  const _ContinentsWrap({required this.visited});

  final Set<String> visited;

  static const _all = <({String key, String emoji})>[
    (key: 'Asia', emoji: '🌏'),
    (key: 'Europe', emoji: '🌍'),
    (key: 'Africa', emoji: '🌍'),
    (key: 'North America', emoji: '🌎'),
    (key: 'South America', emoji: '🌎'),
    (key: 'Oceania', emoji: '🏝️'),
    (key: 'Antarctica', emoji: '🧊'),
  ];

  /// The map data keys continents in English; only the label is localised.
  static String _labelOf(BuildContext context, String key) => switch (key) {
    'Asia' => context.l10n.continentAsia,
    'Europe' => context.l10n.continentEurope,
    'Africa' => context.l10n.continentAfrica,
    'North America' => context.l10n.continentNorthAmerica,
    'South America' => context.l10n.continentSouthAmerica,
    'Oceania' => context.l10n.continentOceania,
    _ => context.l10n.continentAntarctica,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in _all)
          _Chip(
            label: '${c.emoji}  ${_labelOf(context, c.key)}',
            active: visited.contains(c.key),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: active
            ? TravelPassportPage._accent.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: active
              ? TravelPassportPage._accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white38,
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Passport-style country stamps: a dashed-ink circle per visited country.
class _StampsWrap extends StatelessWidget {
  const _StampsWrap({required this.byCountry});

  final Map<String, ({String name, int count})> byCountry;

  @override
  Widget build(BuildContext context) {
    final entries = byCountry.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < entries.length; i++)
          _Stamp(
            code: entries[i].key,
            count: entries[i].value.count,
            // Alternate a slight tilt so they read like real passport stamps.
            angle: (i.isEven ? -0.09 : 0.08),
          ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.code, required this.count, required this.angle});

  final String code;
  final int count;
  final double angle;

  static const _inks = <Color>[
    Color(0xFF64C4DE),
    Color(0xFFE0509C),
    Color(0xFF9B5DE5),
    Color(0xFF00BB8F),
    Color(0xFFF7935B),
  ];

  Color get _ink {
    var h = 0;
    for (final c in code.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _inks[h % _inks.length];
  }

  @override
  Widget build(BuildContext context) {
    final ink = _ink;
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 78,
        height: 78,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ink.withValues(alpha: 0.10),
          border: Border.all(color: ink.withValues(alpha: 0.7), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              code,
              style: TextStyle(
                color: ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Text(
              context.l10n.passportNeedRegions(count),
              style: TextStyle(
                color: ink.withValues(alpha: 0.85),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          const Text('🧳', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            context.l10n.passportEmptyTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.passportEmptySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
