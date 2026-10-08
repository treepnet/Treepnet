import React from 'react';
import { 
  Gift, 
  TrendingUp, 
  Crown, 
  CheckCircle2 
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { useAnalytics } from '../data/useAnalytics';
import { useLanguage } from '../context/LanguageContext';

export const ReferralView: React.FC = () => {
  const { t } = useLanguage();
  const { data } = useAnalytics();
  const r = data.referralStats;
  const platinumCount = r.tiers.find((x) => x.key === 'Platinum')?.count ?? 0;
  const avgConversion = r.leaderboard.length
    ? Math.round((r.leaderboard.reduce((s, x) => s + x.conversionRate, 0) / r.leaderboard.length) * 10) / 10
    : 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.referral.title}</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.referral.subtitle}</p>
        </div>
        <div className="text-[11px] font-mono text-zinc-500 dark:text-zinc-400">
          {t.referral.shareLabel} <span className="text-zinc-900 dark:text-white font-medium">{r.referralUserSharePct}%</span>
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.referral.totalReferrals}
          value={r.totalReferrals}
          change={18.2}
          icon={Gift}
        />
        <StatCard
          title={t.referral.todayReferrals}
          value={r.referralsToday}
          change={9.5}
          icon={TrendingUp}
        />
        <StatCard
          title={t.referral.platinumUsers}
          value={platinumCount}
          subtitle={t.referral.platinumSub}
          icon={Crown}
        />
        <StatCard
          title={t.referral.avgConversion}
          value={`${avgConversion}%`}
          subtitle={t.referral.avgConversionSub}
          icon={CheckCircle2}
        />
      </div>

      {/* Tier Breakdown */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-3">{t.referral.tierTitle}</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {r.tiers.map((tier) => (
            <div key={tier.key} className="p-3 rounded-lg bg-zinc-50 dark:bg-zinc-950/60 border border-zinc-200/70 dark:border-white/[0.05]">
              <div className="flex items-center justify-between text-xs">
                <span className="text-zinc-500 dark:text-zinc-400 text-[11px]">{tier.key}</span>
                <span className="font-mono text-zinc-900 dark:text-zinc-200 text-[11px]">{tier.pct}%</span>
              </div>
              <div className="mt-1 text-lg font-semibold text-zinc-900 dark:text-white font-mono">{tier.count.toLocaleString()}</div>
              <div className="w-full bg-zinc-200 dark:bg-zinc-800 h-1 rounded-full mt-2 overflow-hidden">
                <div className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full" style={{ width: `${tier.pct}%` }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Leaderboard */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-3">{t.referral.leaderboardTitle}</h2>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-zinc-200 dark:border-white/[0.06] text-zinc-400 dark:text-zinc-500 font-medium text-[11px]">
                <th className="py-2.5 px-2">{t.referral.rank}</th>
                <th className="py-2.5 px-2">Username</th>
                <th className="py-2.5 px-2">Tier</th>
                <th className="py-2.5 px-2 font-mono">{t.referral.invited}</th>
                <th className="py-2.5 px-2 font-mono">{t.referral.active}</th>
                <th className="py-2.5 px-2 font-mono">{t.referral.conversion}</th>
                <th className="py-2.5 px-2 text-right font-mono">{t.referral.reward}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
              {r.leaderboard.map((item, idx) => (
                <tr key={item.userId} className="hover:bg-zinc-50/80 dark:hover:bg-white/[0.02] transition-colors">
                  <td className="py-2 px-2 font-mono text-zinc-400 dark:text-zinc-500 text-[11px]">{idx + 1}</td>
                  <td className="py-2 px-2 font-mono text-zinc-900 dark:text-zinc-200 font-medium">@{item.username}</td>
                  <td className="py-2 px-2 text-zinc-600 dark:text-zinc-400 font-mono text-[11px]">{item.tier}</td>
                  <td className="py-2 px-2 font-mono text-zinc-900 dark:text-zinc-200">{item.invitedCount}</td>
                  <td className="py-2 px-2 font-mono text-zinc-500 dark:text-zinc-400">{item.activeReferralsCount}</td>
                  <td className="py-2 px-2 font-mono text-emerald-600 dark:text-emerald-400">{item.conversionRate}%</td>
                  <td className="py-2 px-2 text-right font-mono text-zinc-900 dark:text-zinc-200 font-medium">{item.rewardEarned}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
