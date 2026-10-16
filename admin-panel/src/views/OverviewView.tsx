import React from 'react';
import {
  Bookmark, Eye, Gift, Heart, Image as ImageIcon, MessageCircle, UserCheck, UserPlus, Users, Zap,
} from 'lucide-react';
import {
  Bar, CartesianGrid, ComposedChart, Line, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useData, useDashboard } from '../context/DataContext';
import { Card, Empty, PageHeader, StatCard, Td, Th, useChartColors } from '../components/ui';
import { fmtAgo, fmtDate, fmtDateTime, fmtDay, fmtNum } from '../lib/format';
import type { TabType } from '../components/Sidebar';

export const LiveCard: React.FC = () => {
  const { t, lang } = useLanguage();
  const { online } = useData();
  const d = useDashboard();
  const since = online?.trackingSince ?? d.snapshot.trackingSince;
  return (
    <Card title={t.live.title} scope="now" hint={t.live.hint}>
      <div className="flex items-end gap-2">
        <span className="text-4xl font-semibold tabular-nums text-emerald-600 dark:text-emerald-400">
          {fmtNum(online?.onlineNow ?? d.snapshot.onlineNow)}
        </span>
        <span className="pb-1.5 text-xs text-zinc-500 dark:text-zinc-400">{t.live.now}</span>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-3 border-t border-zinc-100 pt-3 dark:border-white/[0.06]">
        {[
          { label: t.live.m15, value: online?.online15m ?? d.snapshot.online15m },
          { label: t.live.m60, value: online?.online60m ?? 0 },
        ].map((x) => (
          <div key={x.label} className="min-w-0">
            <div className="text-lg font-semibold tabular-nums text-zinc-900 dark:text-white">{fmtNum(x.value)}</div>
            <div className="text-[11px] leading-snug text-zinc-500 dark:text-zinc-400">{x.label}</div>
          </div>
        ))}
      </div>
      <p className="mt-3 text-[11px] text-zinc-400 dark:text-zinc-500">
        {since ? `${t.live.since}: ${fmtDateTime(since, lang)}` : t.live.notYet}
      </p>
    </Card>
  );
};

export const TrendChart: React.FC = () => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const c = useChartColors();
  const rows = d.series.map((r) => ({
    ...r,
    label: fmtDay(r.date, lang),
    activeReal: r.estimated ? null : r.active,
    activeEst: r.estimated ? r.active : null,
  }));
  // Connect the estimated segment to the first real point so the line is continuous.
  const firstReal = rows.findIndex((r) => r.activeReal != null);
  if (firstReal > 0) rows[firstReal].activeEst = rows[firstReal].activeReal;
  const hasEstimated = d.series.some((r) => r.estimated);
  return (
    <Card title={t.overview.trendTitle} scope="period" subtitle={hasEstimated ? t.overview.estimatedNote : undefined}>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={rows} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
            <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} minTickGap={18} />
            <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
            <Tooltip {...c.tooltip} />
            <Bar dataKey="signups" name={t.overview.trendSignups} fill={c.sky} radius={[3, 3, 0, 0]} maxBarSize={18} />
            <Line type="monotone" dataKey="activeReal" name={t.overview.trendActive} stroke={c.emerald} strokeWidth={2} dot={false} connectNulls />
            <Line type="monotone" dataKey="activeEst" name={`${t.overview.trendActive} (${t.common.estimated})`} stroke={c.emerald} strokeWidth={2} strokeDasharray="4 4" dot={false} connectNulls />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
};

export const OverviewView: React.FC<{ onNavigate: (t: TabType) => void }> = ({ onNavigate }) => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const tt = d.totals;
  return (
    <div className="space-y-5">
      <PageHeader title={t.overview.title} subtitle={t.overview.subtitle} />

      <div className="grid gap-4 lg:grid-cols-3">
        <LiveCard />
        <Card title={t.overview.totalsTitle} scope="now" className="lg:col-span-2">
          <div className="grid grid-cols-2 gap-x-4 gap-y-3 sm:grid-cols-4">
            {[
              { label: t.kpi.totalUsers, v: d.snapshot.totalUsers },
              { label: t.kpi.dau, v: d.snapshot.dau, hint: t.kpi.dauHint },
              { label: t.kpi.wau, v: d.snapshot.wau, hint: t.kpi.wauHint },
              { label: t.kpi.mau, v: d.snapshot.mau, hint: t.kpi.mauHint },
              { label: t.common.posts, v: d.snapshot.totals.posts },
              { label: t.kpi.storiesTotal, v: d.snapshot.totals.stories },
              { label: t.common.likes, v: d.snapshot.totals.likes },
              { label: t.kpi.invites, v: d.snapshot.totals.referrals },
            ].map((x) => (
              <div key={x.label} className="min-w-0" title={x.hint}>
                <div className="text-lg font-semibold tabular-nums text-zinc-900 dark:text-white">{fmtNum(x.v)}</div>
                <div className="truncate text-[11px] text-zinc-500 dark:text-zinc-400">{x.label}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <StatCard title={t.kpi.newUsers} value={tt.signup.value} metric={tt.signup} icon={UserPlus} accent="sky" />
        <StatCard title={t.kpi.activeUsers} value={tt.active.value} metric={tt.active} icon={Users} accent="emerald" hint={t.kpi.activeHint} />
        <StatCard title={t.kpi.posts} value={tt.post.value} metric={tt.post} icon={ImageIcon} accent="violet" />
        <StatCard title={t.kpi.stories} value={tt.story.value} metric={tt.story} icon={Zap} accent="amber" />
        <StatCard title={t.kpi.likes} value={tt.like.value} metric={tt.like} icon={Heart} accent="rose" />
        <StatCard title={t.kpi.comments} value={tt.comment.value} metric={tt.comment} icon={MessageCircle} />
        <StatCard title={t.kpi.follows} value={tt.follow.value} metric={tt.follow} icon={UserCheck} />
        <StatCard title={t.kpi.invites} value={tt.referral.value} metric={tt.referral} icon={Gift} />
        <StatCard title={t.kpi.saves} value={tt.save.value} metric={tt.save} icon={Bookmark} />
        <StatCard title={t.kpi.storyViews} value={tt.storyview.value} metric={tt.storyview} icon={Eye} />
      </div>

      <TrendChart />

      <div className="grid gap-4 lg:grid-cols-2">
        <Card
          title={t.overview.recentSignups}
          scope="period"
          right={
            <button type="button" onClick={() => onNavigate('users')} className="text-xs font-medium text-emerald-700 hover:underline dark:text-emerald-400">
              {t.common.showAll} →
            </button>
          }
        >
          {d.recentSignups.length === 0 ? (
            <Empty text={t.overview.noSignups} />
          ) : (
            <div className="max-h-80 overflow-auto">
              <table className="w-full">
                <thead className="sticky top-0 bg-white dark:bg-zinc-900">
                  <tr className="border-b border-zinc-100 dark:border-white/[0.06]">
                    <Th>{t.users.colUser}</Th>
                    <Th>{t.users.colSignup}</Th>
                    <Th right>{t.users.colLastSeen}</Th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                  {d.recentSignups.map((u) => (
                    <tr key={u.username}>
                      <Td className="font-medium text-zinc-800 dark:text-zinc-200">
                        <span className="inline-flex items-center gap-1.5">
                          {u.online && <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" title={t.common.online} />}@{u.username}
                        </span>
                      </Td>
                      <Td className="text-zinc-600 dark:text-zinc-400">
                        {fmtDateTime(u.signupAt, lang)}
                        {u.signupEstimated && <span title={t.users.estimatedSignup}> *</span>}
                      </Td>
                      <Td right className="text-zinc-500">{fmtAgo(u.lastSeenAt, lang)}</Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <Card
          title={t.overview.topPosts}
          scope="period"
          right={
            <button type="button" onClick={() => onNavigate('content')} className="text-xs font-medium text-emerald-700 hover:underline dark:text-emerald-400">
              {t.common.showAll} →
            </button>
          }
        >
          {d.content.topPosts.length === 0 ? (
            <Empty />
          ) : (
            <ul className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
              {d.content.topPosts.slice(0, 6).map((p) => (
                <li key={p.id} className="flex items-center justify-between gap-3 py-2 text-xs">
                  <div className="min-w-0">
                    <div className="font-medium text-zinc-800 dark:text-zinc-200">@{p.username}</div>
                    <div className="truncate text-zinc-500 dark:text-zinc-400">{p.place ?? '—'} · {fmtDate(p.createdAt, lang)}</div>
                  </div>
                  <div className="flex shrink-0 items-center gap-3 font-mono tabular-nums text-zinc-600 dark:text-zinc-400">
                    <span className="inline-flex items-center gap-1" title={t.common.likes}><Heart className="h-3 w-3 text-rose-500" />{p.likes}</span>
                    <span className="inline-flex items-center gap-1" title={t.common.comments}><MessageCircle className="h-3 w-3" />{p.comments}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
};
