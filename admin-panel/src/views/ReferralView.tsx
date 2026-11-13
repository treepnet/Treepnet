import React, { useState } from 'react';
import { Gift, UserPlus, Users } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useDashboard } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, Td, Th } from '../components/ui';
import { fmtDate, fmtNum, pct } from '../lib/format';

// The app's badge colours, level 1-5 (lib/settings/view/referral_badge.dart).
const BADGE_COLOUR: Record<number, string> = {
  1: '#5BB8E8',
  2: '#1E7FE0',
  3: '#A020C7',
  4: '#ED2A93',
  5: '#E01B24',
};

export const ReferralView: React.FC = () => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const r = d.referrals;
  const [tab, setTab] = useState<'period' | 'all'>('period');
  const rows = tab === 'period' ? r.leaderboardPeriod : r.leaderboardAllTime;
  const colourTotal = r.colourTiers.reduce((s, c) => s + c.users, 0);

  return (
    <div className="space-y-5">
      <PageHeader title={t.referral.title} subtitle={t.referral.subtitle} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard title={t.referral.invites} value={d.totals.referral.value} metric={d.totals.referral} icon={Gift} accent="emerald" />
        <StatCard
          title={t.referral.viaInviteShare}
          value={`${pct(d.totals.referral.value, d.totals.signup.value)}%`}
          hint={t.referral.viaInviteHint}
          icon={UserPlus}
          sub={`${fmtNum(d.totals.referral.value)} / ${fmtNum(d.totals.signup.value)}`}
        />
        <StatCard title={t.referral.inviters} value={r.inviters} icon={Users} sub={t.scope.allTime} />
        <StatCard title={t.common.total} value={d.snapshot.totals.referrals} sub={t.scope.allTime} />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card
          title={t.referral.leaderboard}
          scope={tab === 'period' ? 'period' : 'allTime'}
          className="lg:col-span-2"
          right={
            <div className="flex rounded-lg bg-zinc-100 p-0.5 text-xs dark:bg-white/[0.06]">
              {(['period', 'all'] as const).map((k) => (
                <button
                  key={k}
                  type="button"
                  onClick={() => setTab(k)}
                  className={`rounded-md px-2.5 py-1 font-medium ${tab === k ? 'bg-white text-zinc-900 shadow-sm dark:bg-white/[0.12] dark:text-white' : 'text-zinc-500 dark:text-zinc-400'}`}
                >
                  {k === 'period' ? t.referral.periodTab : t.referral.allTimeTab}
                </button>
              ))}
            </div>
          }
        >
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-zinc-100 dark:border-white/[0.06]">
                    <Th>#</Th>
                    <Th>{t.users.colUser}</Th>
                    <Th right>{t.referral.colInvited}</Th>
                    <Th right>{t.referral.colActive}</Th>
                    <Th>{t.referral.colPremium}</Th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                  {rows.map((x, i) => (
                    <tr key={x.username}>
                      <Td className="font-mono text-zinc-400">{i + 1}</Td>
                      <Td className="font-medium text-zinc-800 dark:text-zinc-200">@{x.username}</Td>
                      <Td right>{x.invited}</Td>
                      <Td right>{x.active} <span className="text-zinc-400">({x.activePct}%)</span></Td>
                      <Td>
                        <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
                          {x.colourTier > 0 && (
                            <span
                              className="inline-block h-2.5 w-2.5 rounded-full"
                              style={{ background: BADGE_COLOUR[x.colourTier] }}
                              title={`${t.referral.colourLevel} ${x.colourTier}`}
                            />
                          )}
                          <span className="text-zinc-700 dark:text-zinc-300">
                            {x.premiumMonths} {t.referral.months}
                          </span>
                          {x.premiumUntil && (
                            <span className="text-zinc-400">
                              · {lang === 'uz' ? `${fmtDate(x.premiumUntil, lang)} ${t.referral.until}` : `${t.referral.until} ${fmtDate(x.premiumUntil, lang)}`}
                            </span>
                          )}
                        </span>
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
        <div className="space-y-4">
          <Card title={t.referral.premium} scope="allTime" subtitle={t.referral.premiumHint}>
            <div className="grid grid-cols-3 gap-2 text-center">
              {[
                [t.referral.premiumEarned, r.premium.earned],
                [t.referral.premiumMonths, r.premium.months],
                [t.referral.premiumActive, r.premium.activeNow],
              ].map(([label, value]) => (
                <div key={String(label)} className="rounded-lg bg-zinc-50 px-2 py-3 dark:bg-white/[0.04]">
                  <div className="text-lg font-semibold tabular-nums text-zinc-900 dark:text-white">{fmtNum(Number(value))}</div>
                  <div className="mt-0.5 text-[11px] leading-tight text-zinc-500">{label}</div>
                </div>
              ))}
            </div>
          </Card>
          <Card title={t.referral.colours} scope="now" subtitle={t.referral.coloursHint}>
            {colourTotal === 0 ? (
              <Empty />
            ) : (
              <div className="space-y-3">
                {r.colourTiers.map((c) => (
                  <BarRow
                    key={c.tier}
                    label={`${t.referral.colourLevel} ${c.tier} (${fmtNum(c.showing)})`}
                    count={c.users}
                    pct={pct(c.users, colourTotal)}
                    fill={BADGE_COLOUR[c.tier]}
                  />
                ))}
              </div>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
};
