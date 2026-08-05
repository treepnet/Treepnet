import 'package:app_ui/app_ui.dart';
import 'package:treepnet/referral/referral_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:user_repository/user_repository.dart';

/// {@template referral_page}
/// "Invite friends" — shows the signed-in user's personal invite code and a
/// ready-to-send message they can share anywhere.
///
/// The code is their handle, which whoever they invite types into the redeem
/// dialog. A clickable `https://` invite link needs a domain we own (so it can
/// serve `assetlinks.json`); until then the code is the thing that actually
/// works everywhere. `treepnet://invite/<handle>` still opens the app for
/// people who already have it.
/// {@endtemplate}
class ReferralPage extends StatelessWidget {
  /// {@macro referral_page}
  const ReferralPage({super.key});

  String _handleOf(BuildContext context) {
    final user = context.read<AppBloc>().state.user;
    final handle = (user.username != null && user.username!.isNotEmpty)
        ? user.username!
        : user.id;
    return handle;
  }

  @override
  Widget build(BuildContext context) {
    final code = _handleOf(context);
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.inviteFriendsText,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xlg,
            ),
            children: [
              Text(
                context.l10n.inviteIntroText,
                style: context.bodyMedium?.copyWith(color: AppColors.white),
              ),
              const Gap.v(AppSpacing.sm),
              Text(
                context.l10n.inviteRewardRuleText,
                style: context.bodyMedium?.copyWith(color: AppColors.white),
              ),
              const Gap.v(AppSpacing.lg),
              Text(
                context.l10n.inviteYourLinkText,
                style: context.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Gap.v(AppSpacing.xs),
              _CodeField(code: ReferralConfig.inviteUrl(code)),
              const Gap.v(AppSpacing.lg),
              // One stream feeds the counters, the progress bar and the
              // ladder, so they can never disagree about where you stand.
              StreamBuilder<InviteBadgeStatus>(
                stream: context.read<UserRepository>().inviteBadgeStatusOf(
                  userId: context.read<AppBloc>().state.user.id,
                ),
                builder: (context, snap) {
                  final status = snap.data ?? InviteBadgeStatus.empty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InviteStats(status: status),
                      const Gap.v(AppSpacing.lg),
                      _InviteProgress(status: status),
                      if (!status.hasLocatedPost) ...[
                        const Gap.v(AppSpacing.sm),
                        const _NeedPostNotice(),
                      ],
                      const Gap.v(AppSpacing.lg),
                      _TierLadder(status: status),
                    ],
                  );
                },
              ),
              const Gap.v(AppSpacing.md),
              Text(
                context.l10n.inviteTierExplainText,
                style: context.bodyMedium?.copyWith(color: AppColors.white),
              ),
              const Gap.v(AppSpacing.xlg),
              // The whole feature is not live yet — a non-interactive badge.
              const Center(child: _ComingSoonBadge()),
            ],
          ),
        ),
      ),
    );
  }

}

/// A button-shaped "Coming soon" badge: white fill, black text, deliberately
/// not tappable (the referral feature is disabled for now).
class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xlg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        context.l10n.comingSoonText,
        style: context.titleMedium?.copyWith(
          color: AppColors.black,
          fontWeight: AppFontWeight.bold,
        ),
      ),
    );
  }
}

/// The invite link. Copy is disabled while the feature is not live — the copy
/// icon is replaced with a white "blocked" icon and the field is not tappable.
class _CodeField extends StatelessWidget {
  const _CodeField({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.link,
              color: Colors.white54,
              size: 20,
            ),
            const Gap.h(AppSpacing.sm),
            Expanded(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Gap.h(AppSpacing.sm),
            // Copy disabled (feature not live) — white blocked icon.
            const Icon(
              Icons.block,
              color: AppColors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// How many people joined through the link — the only counter on this screen.
///
/// The design had two more boxes beside it: "downloaded by your link", which
/// the app has no install attribution to fill, and a badge countdown. Both are
/// gone, so this one takes the full width.
class _InviteStats extends StatelessWidget {
  const _InviteStats({required this.status});

  final InviteBadgeStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatBox(
      label: context.l10n.inviteRegisteredText,
      value: Text(
        '${status.invites}',
        style: context.titleMedium?.copyWith(
          color: AppColors.white,
          fontWeight: AppFontWeight.semiBold,
        ),
      ),
    );
  }
}

/// Shown while the user has invites but no located post — the one thing still
/// standing between them and a visible badge.
class _NeedPostNotice extends StatelessWidget {
  const _NeedPostNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const Gap.h(AppSpacing.sm),
        Expanded(
          child: Text(
            context.l10n.inviteNeedPostText,
            style: context.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        const Gap.v(AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.inputSpace,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Center(child: value),
        ),
      ],
    );
  }
}

/// Progress toward the next rung of the ladder, and what it is worth.
///
/// Progress toward the next free month of premium.
///
/// The bar only measures the current block of five, so each month reads as a
/// fresh, finishable stretch instead of a fraction of some distant total.
class _InviteProgress extends StatelessWidget {
  const _InviteProgress({required this.status});

  final InviteBadgeStatus status;

  @override
  Widget build(BuildContext context) {
    final tint = status.tier > 0
        ? kReferralTiers[(status.tier - 1).clamp(0, kReferralTiers.length - 1)]
              .color
        : AppColors.white;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.borderOutline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.inviteProgressTitle,
                style: context.bodyLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
              const Gap.h(AppSpacing.xs),
              if (status.tier > 0)
                VerificationBadge(color: tint, size: 18)
              else
                const Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const Gap.v(AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${status.invitesInCycle}/$kInvitesPerPremiumMonth '
                '${context.l10n.inviteFriendsUnit}',
                style: context.bodySmall?.copyWith(color: AppColors.white),
              ),
              Text(
                context.l10n.invitePlusOneMonthText,
                style: context.bodySmall?.copyWith(color: AppColors.white),
              ),
            ],
          ),
          const Gap.v(AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.invitesInCycle / kInvitesPerPremiumMonth,
              minHeight: 6,
              backgroundColor: AppColors.inputSpace,
              valueColor: AlwaysStoppedAnimation(tint),
            ),
          ),
          // Once any premium is banked, say how much of it is left — that is
          // the number people actually care about.
          if (status.isActive) ...[
            const Gap.v(AppSpacing.sm),
            Text(
              '${context.l10n.inviteMonthsText(status.monthsEarned)} · '
              '${context.l10n.inviteDaysLeftText(status.daysLeft)}',
              style: context.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The five checkmark colours, dimmest to brightest, with the one this
/// traveller has earned lit up. Colours come from [kReferralTiers] so every
/// checkmark in the app is the same palette.
///
/// Deliberately unlabelled: the numbers underneath used to describe the old
/// rule, and the paragraph below the row explains the current one.
class _TierLadder extends StatelessWidget {
  const _TierLadder({required this.status});

  final InviteBadgeStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < kReferralTiers.length; i++)
          // Highlights the colour the map has earned, whether or not premium
          // is currently paying for it to be visible.
          Opacity(
            opacity: status.colorTier == i + 1 ? 1 : 0.45,
            child: VerificationBadge(
              color: kReferralTiers[i].color,
              size: 26,
            ),
          ),
      ],
    );
  }
}
