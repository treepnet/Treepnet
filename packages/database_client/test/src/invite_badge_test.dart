import 'package:database_client/src/invite_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inviteBadgeColorTier', () {
    test('is blue below a ratio of 10', () {
      expect(inviteBadgeColorTier(locations: 9, regions: 1), 1); // 9/2 = 4.5
      expect(inviteBadgeColorTier(locations: 36, regions: 4), 1); // 9
    });

    test('climbs a colour every 10 locations per region', () {
      expect(inviteBadgeColorTier(locations: 40, regions: 4), 2); // 10
      expect(inviteBadgeColorTier(locations: 80, regions: 4), 3); // 20
      expect(inviteBadgeColorTier(locations: 120, regions: 4), 4); // 30
      expect(inviteBadgeColorTier(locations: 160, regions: 4), 5); // 40
    });

    test('matches the worked example: 70 locations over 4 regions', () {
      // 17.5 → dark blue.
      expect(inviteBadgeColorTier(locations: 70, regions: 4), 2);
    });

    test('halves the count when there is only one region', () {
      // 40 in a single region is 20, not 40 — violet, not red.
      expect(inviteBadgeColorTier(locations: 40, regions: 1), 3);
      expect(inviteBadgeColorTier(locations: 80, regions: 1), 5);
    });

    test('is nothing at all with an empty map', () {
      expect(inviteBadgeColorTier(locations: 0, regions: 0), 0);
      expect(inviteBadgeColorTier(locations: 5, regions: 0), 0);
    });
  });

  group('premiumEndFromInvites', () {
    final day = DateTime(2026, 1, 10);
    List<DateTime> sameDay(int n) => List.filled(n, day);

    test('buys nothing below five invites', () {
      expect(premiumEndFromInvites(const []), isNull);
      expect(premiumEndFromInvites(sameDay(4)), isNull);
    });

    test('five invites buy one month from that fifth invite', () {
      expect(premiumEndFromInvites(sameDay(5)), DateTime(2026, 2, 10));
    });

    test('a sixth invite adds nothing until the next block of five', () {
      expect(premiumEndFromInvites(sameDay(9)), DateTime(2026, 2, 10));
      expect(premiumEndFromInvites(sameDay(10)), DateTime(2026, 3, 10));
    });

    test('fifty invites at once buy ten months', () {
      expect(premiumEndFromInvites(sameDay(50)), DateTime(2026, 11, 10));
    });

    test('a later block stacks on the balance, it does not restart it', () {
      // Five invites in January, five more two weeks later: the second month
      // is added to the end of the first, so premium runs to mid-March.
      final dates = [
        ...List.filled(5, DateTime(2026, 1, 10)),
        ...List.filled(5, DateTime(2026, 1, 24)),
      ];
      expect(premiumEndFromInvites(dates), DateTime(2026, 3, 10));
    });

    test('a block bought after a lapse starts from that invite', () {
      // First month ran out in February; the next five arrive in June.
      final dates = [
        ...List.filled(5, DateTime(2026, 1, 10)),
        ...List.filled(5, DateTime(2026, 6, 1)),
      ];
      expect(premiumEndFromInvites(dates), DateTime(2026, 7, 1));
    });
  });

  group('InviteBadgeStatus', () {
    test('shows no checkmark without a located post', () {
      final status = InviteBadgeStatus(
        invites: 10,
        locations: 0,
        regions: 0,
        colorTier: 0,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(status.isActive, isFalse);
      expect(status.tier, 0);
    });

    test('shows no checkmark without invites, however well travelled', () {
      const status = InviteBadgeStatus(
        invites: 0,
        locations: 200,
        regions: 5,
        colorTier: 5,
      );
      expect(status.isActive, isFalse);
      expect(status.tier, 0);
    });

    test('hides the checkmark once premium has lapsed', () {
      final status = InviteBadgeStatus(
        invites: 5,
        locations: 12,
        regions: 2,
        colorTier: 1,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(status.isActive, isFalse);
      expect(status.tier, 0);
    });

    test('wears its travel colour while premium is running', () {
      final status = InviteBadgeStatus(
        invites: 5,
        locations: 70,
        regions: 4,
        colorTier: 2,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(status.isActive, isTrue);
      expect(status.tier, 2);
    });

    test('counts months earned and progress toward the next', () {
      const status = InviteBadgeStatus(
        invites: 12,
        locations: 1,
        regions: 1,
        colorTier: 1,
      );
      expect(status.monthsEarned, 2);
      expect(status.invitesInCycle, 2);
      expect(status.invitesToNextMonth, 3);
    });
  });
}
