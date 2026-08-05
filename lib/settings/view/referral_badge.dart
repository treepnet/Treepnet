import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// One of the five checkmark colours. Which one a traveller wears comes from
/// how densely they explore — locations per region — not from invites, which
/// only buy the time the checkmark is visible for.
///
/// Mirrors `inviteBadgeColorTier` in `database_client`; this adds the colours
/// and names.
class ReferralTier {
  const ReferralTier({
    required this.level,
    required this.color,
  });

  final int level;
  final Color color;
}

/// The colour ladder shown in the referral screen, dimmest to brightest.
const kReferralTiers = <ReferralTier>[
  ReferralTier(level: 1, color: Color(0xFF5BB8E8)),
  ReferralTier(level: 2, color: Color(0xFF1E7FE0)),
  ReferralTier(level: 3, color: Color(0xFFA020C7)),
  ReferralTier(level: 4, color: Color(0xFFED2A93)),
  ReferralTier(level: 5, color: Color(0xFFE01B24)),
];

/// A scalloped "burst" verification badge (like the reward galochkas): a filled
/// star-burst disc in [color] with a white check.
/// Reusable: drop it next to a display name once a tier is earned.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    required this.color,
    this.size = 56,
    super.key,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _BurstPainter(color: color),
          ),
          Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ],
      ),
    );
  }
}

/// Paints a scalloped disc by unioning a central circle with a ring of
/// overlapping lobe circles — the classic "sticker seal" verification shape.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.color});

  final Color color;

  static const _lobes = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final s = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    final d = s * 0.32;
    final rb = s * 0.135;
    for (var i = 0; i < _lobes; i++) {
      final a = (i / _lobes) * 2 * math.pi;
      final c = center + Offset(math.cos(a) * d, math.sin(a) * d);
      canvas.drawCircle(c, rb, paint);
    }
    canvas.drawCircle(center, s * 0.36, paint);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.color != color;
}

/// The verification checkmark shown next to a display name across the app —
/// story cards, the chat inbox, post headers. Streams the user's live tier, so
/// a person who has invited nobody simply shows nothing.
///
/// Tier comes from `travelTierOf`: invites buy the months it stays visible for,
/// and the colour reflects how densely the person explores. It disappears once
/// the bought time runs out.
class TravelTierBadge extends StatelessWidget {
  const TravelTierBadge({required this.userId, this.size = 14, super.key});

  final String userId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: context.read<UserRepository>().travelTierOf(userId: userId),
      builder: (context, snapshot) {
        final tier = snapshot.data ?? 0;
        if (tier <= 0) return const SizedBox.shrink();
        final t = kReferralTiers[(tier - 1).clamp(0, kReferralTiers.length - 1)];
        return VerificationBadge(color: t.color, size: size);
      },
    );
  }
}
