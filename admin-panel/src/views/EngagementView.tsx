import React from 'react';
import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Bell, Bookmark, Heart, MessageCircle, Reply, UserCheck } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useDashboard } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, useChartColors } from '../components/ui';
import { fmtDay, fmtNum, pct } from '../lib/format';

export const EngagementView: React.FC = () => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const c = useChartColors();
  const tt = d.totals;
  const e = d.engagement;
  const rows = d.series.map((r) => ({ ...r, label: fmtDay(r.date, lang) }));
  const pushTotal = e.push.sent + e.push.failed + e.push.pending;
  const maxLiked = e.topLiked[0]?.likes ?? 0;

  return (
    <div className="space-y-5">
      <PageHeader title={t.engagement.title} subtitle={t.engagement.subtitle} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard title={t.kpi.likes} value={tt.like.value} metric={tt.like} icon={Heart} accent="rose" />
        <StatCard title={t.kpi.comments} value={tt.comment.value} metric={tt.comment} icon={MessageCircle} accent="sky" />
        <StatCard
          title={t.engagement.replies}
          value={e.replies}
          icon={Reply}
          sub={`${pct(e.replies, tt.comment.value)}% · ${t.scope.period}`}
        />
        <StatCard title={t.kpi.follows} value={tt.follow.value} metric={tt.follow} icon={UserCheck} accent="emerald" />
        <StatCard title={t.kpi.saves} value={tt.save.value} metric={tt.save} icon={Bookmark} />
        <StatCard
          title={t.engagement.engagementRate}
          value={`${pct(tt.engagers, tt.active.value)}%`}
          hint={t.engagement.engagementHint}
          sub={`${fmtNum(tt.engagers)} / ${fmtNum(tt.active.value)}`}
        />
        <StatCard
          title={t.engagement.likesPerPost}
          value={tt.post.value ? Math.round((tt.like.value / tt.post.value) * 10) / 10 : 0}
          sub={t.scope.period}
        />
        <StatCard title={t.engagement.pendingFollows} value={d.snapshot.totals.pendingFollows} sub={t.scope.now} />
      </div>

      <Card title={t.engagement.chart} scope="period">
        {tt.like.value + tt.comment.value + tt.follow.value === 0 ? (
          <Empty />
        ) : (
          <div className="h-60">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={rows} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
                <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} minTickGap={18} />
                <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <Tooltip {...c.tooltip} />
                <Legend wrapperStyle={{ fontSize: 11 }} />
                <Line type="monotone" dataKey="likes" name={t.common.likes} stroke={c.rose} strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="comments" name={t.common.comments} stroke={c.sky} strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="follows" name={t.kpi.follows} stroke={c.emerald} strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card title={t.engagement.topLiked} scope="period">
          {e.topLiked.length === 0 ? (
            <Empty />
          ) : (
            <div className="space-y-3">
              {e.topLiked.map((x) => (
                <BarRow key={x.username} label={`@${x.username}`} count={x.likes} pct={pct(x.likes, maxLiked)} color="bg-rose-500" right={`♥ ${fmtNum(x.likes)}`} />
              ))}
            </div>
          )}
        </Card>
        <Card title={t.engagement.push} scope="period" right={<Bell className="h-4 w-4 text-zinc-400" />}>
          {pushTotal === 0 ? (
            <Empty />
          ) : (
            <div className="space-y-3">
              <div className="text-2xl font-semibold tabular-nums text-zinc-900 dark:text-white">
                {e.push.successPct}% <span className="text-xs font-normal text-zinc-500">{t.engagement.pushSuccess}</span>
              </div>
              <BarRow label={t.engagement.pushSent} count={e.push.sent} pct={pct(e.push.sent, pushTotal)} color="bg-emerald-500" />
              <BarRow label={t.engagement.pushFailed} count={e.push.failed} pct={pct(e.push.failed, pushTotal)} color="bg-rose-500" />
              <BarRow label={t.engagement.pushPending} count={e.push.pending} pct={pct(e.push.pending, pushTotal)} color="bg-amber-500" />
            </div>
          )}
        </Card>
      </div>
    </div>
  );
};
