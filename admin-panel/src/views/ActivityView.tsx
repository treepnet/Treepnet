import React from 'react';
import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useDashboard } from '../context/DataContext';
import { Card, Empty, PageHeader, StatCard, useChartColors } from '../components/ui';
import { fmtDay, fmtNum } from '../lib/format';
import { LiveCard } from './OverviewView';

export const ActivityView: React.FC = () => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const c = useChartColors();
  const s = d.sessions;
  const daily = d.series.map((r) => ({ ...r, label: fmtDay(r.date, lang) }));
  const hours = d.hourly.map((h) => ({ ...h, label: `${String(h.hour).padStart(2, '0')}:00` }));
  const peak = hours.reduce((m, h) => (h.users > m ? h.users : m), 0);
  const hasEstimated = d.series.some((r) => r.estimated);

  return (
    <div className="space-y-5">
      <PageHeader title={t.activity.title} subtitle={t.activity.subtitle} />

      <div className="grid gap-4 lg:grid-cols-3">
        <LiveCard />
        <div className="grid grid-cols-2 gap-3 lg:col-span-2">
          <StatCard title={t.kpi.dau} value={d.snapshot.dau} hint={t.kpi.dauHint} sub={t.scope.now} accent="emerald" />
          <StatCard title={t.kpi.wau} value={d.snapshot.wau} hint={t.kpi.wauHint} sub={t.scope.now} />
          <StatCard title={t.kpi.mau} value={d.snapshot.mau} hint={t.kpi.mauHint} sub={t.scope.now} />
          <StatCard title={t.kpi.stickiness} value={`${d.snapshot.stickiness}%`} hint={t.kpi.stickinessHint} sub={t.scope.now} />
        </div>
      </div>

      <Card title={t.activity.dailyActive} scope="period" hint={t.kpi.activeHint} subtitle={hasEstimated ? t.overview.estimatedNote : undefined}>
        <div className="h-56">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={daily} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
              <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} minTickGap={18} />
              <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
              <Tooltip {...c.tooltip} />
              <Bar dataKey="active" name={t.kpi.activeUsers} radius={[3, 3, 0, 0]} maxBarSize={22}>
                {daily.map((r) => (
                  <Cell key={r.date} fill={c.emerald} fillOpacity={r.estimated ? 0.35 : 1} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </Card>

      <Card title={t.activity.sessions} scope="period" hint={t.activity.sessionsHint}>
        {!s ? (
          <Empty text={t.activity.sessionsEmpty} />
        ) : (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
            {[
              { label: t.activity.avgSession, v: `${s.avgMinutes} ${t.activity.minutes}` },
              { label: t.activity.medianSession, v: `${s.medianMinutes} ${t.activity.minutes}` },
              { label: t.activity.sessionsPerDay, v: String(s.sessionsPerUserDay) },
              { label: t.activity.minutesPerDay, v: `${s.minutesPerUserDay} ${t.activity.minutes}` },
              { label: t.activity.sessionsCount, v: fmtNum(s.sessions) },
            ].map((x) => (
              <div key={x.label} className="min-w-0 rounded-lg bg-zinc-50 p-3 dark:bg-white/[0.03]">
                <div className="text-lg font-semibold tabular-nums text-zinc-900 dark:text-white">{x.v}</div>
                <div className="text-[11px] text-zinc-500 dark:text-zinc-400">{x.label}</div>
              </div>
            ))}
          </div>
        )}
      </Card>

      <Card title={t.activity.hourly} scope="period">
        {peak === 0 ? (
          <Empty />
        ) : (
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={hours} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
                <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} interval={1} />
                <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <Tooltip {...c.tooltip} />
                <Bar dataKey="users" name={t.activity.hourlyUsers} radius={[3, 3, 0, 0]}>
                  {hours.map((h) => (
                    <Cell key={h.hour} fill={h.users === peak ? c.amber : c.violet} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>
    </div>
  );
};
