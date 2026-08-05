/// The verification checkmark ("galochka") rules, kept free of any database or
/// PowerSync import so they stay directly testable.
///
/// Two independent halves: invites buy the TIME the checkmark is visible for,
/// and travel decides its COLOUR.
library;

/// Invites needed for one month of premium. Every block of this many tops the
/// subscription up by another month, so 50 invites is 10 months.
///
/// Inviting is the only way to get the badge — posting never grants it. How
/// many people you brought in decides HOW LONG it lasts, never which colour it
/// is; that comes from [inviteBadgeColorTier].
const kInvitesPerPremiumMonth = 5;

/// Which of the five checkmark colours a traveller wears, from how densely
/// they explore: locations added per region visited.
///
///     < 10 → blue   20-29 → violet   40+ → red
///    10-19 → dark blue   30-39 → pink
///
/// A single region has no spread to measure, so its locations are halved
/// instead — otherwise one busy city would read as deep exploration.
///
/// Returns 0 when there is nothing on the map yet.
int inviteBadgeColorTier({required int locations, required int regions}) {
  if (locations <= 0 || regions <= 0) return 0;
  final ratio = regions >= 2 ? locations / regions : locations / 2;
  if (ratio < 10) return 1;
  if (ratio < 20) return 2;
  if (ratio < 30) return 3;
  if (ratio < 40) return 4;
  return 5;
}

/// Premium runs out this long after the invite that paid for it — and each
/// further block of [kInvitesPerPremiumMonth] stacks another month on the end
/// rather than restarting the clock.
DateTime? premiumEndFromInvites(List<DateTime> sortedInviteDates) {
  DateTime? end;
  for (var i = kInvitesPerPremiumMonth - 1;
      i < sortedInviteDates.length;
      i += kInvitesPerPremiumMonth) {
    final paidAt = sortedInviteDates[i];
    // Top up from whichever is later: the running balance, or now-ish.
    final base = (end == null || end.isBefore(paidAt)) ? paidAt : end;
    end = DateTime(
      base.year,
      base.month + 1,
      base.day,
      base.hour,
      base.minute,
    );
  }
  return end;
}

/// Everything the invite screen needs to explain the badge in one snapshot:
/// how many people you brought in, whether the badge is actually showing, and
/// when it lapses.
class InviteBadgeStatus {
  const InviteBadgeStatus({
    required this.invites,
    required this.locations,
    required this.regions,
    required this.colorTier,
    this.expiresAt,
  });

  /// Nothing invited, nothing posted — the state every account starts in.
  static const empty = InviteBadgeStatus(
    invites: 0,
    locations: 0,
    regions: 0,
    colorTier: 0,
  );

  /// Accepted invites, all-time.
  final int invites;

  /// Posts carrying a picked location.
  final int locations;

  /// Distinct regions those locations fall in.
  final int regions;

  /// Which colour this traveller has earned, 1-5, or 0 with an empty map.
  /// Independent of [invites] — see [inviteBadgeColorTier].
  final int colorTier;

  /// When premium runs out; null when none was ever bought.
  final DateTime? expiresAt;

  /// The badge stays hidden until at least one post carries a location.
  bool get hasLocatedPost => locations > 0;

  /// Whether a checkmark is showing right now: bought with invites, still in
  /// date, and backed by something on the map.
  bool get isActive {
    final at = expiresAt;
    return at != null && hasLocatedPost && DateTime.now().isBefore(at);
  }

  /// The colour actually on display, or 0 while premium is not running.
  int get tier => isActive ? colorTier : 0;

  /// Whole months of premium bought so far.
  int get monthsEarned => invites ~/ kInvitesPerPremiumMonth;

  /// Invites banked toward the next month, 0..[kInvitesPerPremiumMonth) - 1.
  int get invitesInCycle => invites % kInvitesPerPremiumMonth;

  /// Invites still needed to add another month.
  int get invitesToNextMonth => kInvitesPerPremiumMonth - invitesInCycle;

  /// Whole days left on the subscription, floored at 0.
  int get daysLeft {
    final at = expiresAt;
    if (at == null) return 0;
    return at.difference(DateTime.now()).inDays.clamp(0, 1 << 31);
  }
}
