import React, { useState } from 'react';
import { Gift, UserPlus, Users } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useDashboard } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, Td, Th } from '../components/ui';
import { fmtNum, pct } from '../lib/format';

const TIER_CLS: Record<string, string> = {
  Bronze: 'bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-300',
  Silver: 'bg-zinc-200 text-zinc-700 dark:bg-white/[0.08] dark:text-zinc-300',
  Gold: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-500/15 dark:text-yellow-300',
  Platinum: 'bg-cyan-100 text-cyan-800 dark:bg-cyan-500/15 dark:text-cyan-300',
};
const TIER_BAR: Record<string, string> = {
  Bronze: 'bg-amber-600', Silver: 'bg-zinc-400', Gold: 'bg-yellow-500', Platinum: 'bg-cyan-500',
};

export const ReferralView: React.FC = () => {
  const { t } = useLanguage();
  const d = useDashboard();
  const r = d.referrals;
  const [tab, setTab] = useState<'period' | 'all'>('period');
  const rows = tab === 'period' ? r.leaderboardPeriod : r.leaderboardAllTime;
  const tierTotal = Object.values(r.tiers).reduce((s, v) => s + v, 0);

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
                    <Th>{t.referral.colTier}</Th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                  {rows.map((x, i) => (
                    <tr key={x.username}>
                      <Td className="font-mono text-zinc-400">{i + 1}</Td>
                      <Td className="font-medium text-zinc-800 dark:text-zinc-200">@{x.username}</Td>
                      <Td right>{x.invited}</Td>
                      <Td right>{x.active} <span className="text-zinc-400">({x.activePct}%)</span></Td>
                      <Td><span className={`rounded px-1.5 py-0.5 text-[10px] font-semibold ${TIER_CLS[x.tier]}`}>{x.tier}</span></Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
        <Card title={t.referral.tiers} scope="allTime" subtitle={t.referral.tierHint}>
          {tierTotal === 0 ? (
            <Empty />
          ) : (
            <div className="space-y-3">
              {(['Bronze', 'Silver', 'Gold', 'Platinum'] as const).map((k) => (
                <BarRow key={k} label={k} count={r.tiers[k]} pct={pct(r.tiers[k], tierTotal)} color={TIER_BAR[k]} />
              ))}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
};
