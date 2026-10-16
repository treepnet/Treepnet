import React from 'react';
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Image as ImageIcon, MapPin, Users, Zap } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useDashboard } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, Td, Th, useChartColors } from '../components/ui';
import { fmtDate, fmtDay, fmtNum, pct } from '../lib/format';

export const ContentView: React.FC = () => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const c = useChartColors();
  const tt = d.totals;
  const storiesInPeriod = d.content.storiesPhoto + d.content.storiesVideo;
  const rows = d.series.map((r) => ({ ...r, label: fmtDay(r.date, lang) }));

  return (
    <div className="space-y-5">
      <PageHeader title={t.content.title} subtitle={t.content.subtitle} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard title={t.kpi.posts} value={tt.post.value} metric={tt.post} icon={ImageIcon} accent="violet" />
        <StatCard title={t.kpi.stories} value={tt.story.value} metric={tt.story} icon={Zap} accent="amber" />
        <StatCard
          title={t.content.creators}
          value={tt.creators}
          hint={t.content.creatorsHint}
          icon={Users}
          sub={`${t.content.perCreator}: ${tt.creators ? Math.round((tt.post.value / tt.creators) * 10) / 10 : 0}`}
        />
        <StatCard title={t.content.geoTagged} value={`${d.content.geoTaggedPct}%`} icon={MapPin} sub={t.scope.period} />
        <StatCard title={t.kpi.highlights} value={tt.highlight.value} metric={tt.highlight} />
        <StatCard title={t.content.activeStories} value={d.snapshot.totals.activeStories} sub={t.scope.now} accent="emerald" />
        <StatCard title={t.content.highlightsTotal} value={d.snapshot.totals.highlights} sub={t.scope.allTime} />
        <StatCard title={t.kpi.storyViews} value={tt.storyview.value} metric={tt.storyview} />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card title={t.content.chart} scope="period" className="lg:col-span-2">
          {tt.post.value + tt.story.value === 0 ? (
            <Empty />
          ) : (
            <div className="h-60">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={rows} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
                  <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} minTickGap={18} />
                  <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
                  <Tooltip {...c.tooltip} />
                  <Legend wrapperStyle={{ fontSize: 11 }} />
                  <Bar dataKey="posts" name={t.common.posts} fill={c.violet} radius={[3, 3, 0, 0]} maxBarSize={18} />
                  <Bar dataKey="stories" name={t.kpi.stories} fill={c.amber} radius={[3, 3, 0, 0]} maxBarSize={18} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
        <Card title={t.content.storyFormat} scope="period">
          {storiesInPeriod === 0 ? (
            <Empty />
          ) : (
            <div className="space-y-3">
              <BarRow label={t.content.photo} count={d.content.storiesPhoto} pct={pct(d.content.storiesPhoto, storiesInPeriod)} color="bg-amber-500" />
              <BarRow label={t.content.video} count={d.content.storiesVideo} pct={pct(d.content.storiesVideo, storiesInPeriod)} color="bg-rose-500" />
            </div>
          )}
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card title={t.content.topPosts} scope="period" className="lg:col-span-2">
          {d.content.topPosts.length === 0 ? (
            <Empty />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-zinc-100 dark:border-white/[0.06]">
                    <Th>{t.content.colAuthor}</Th>
                    <Th>{t.content.colPlace}</Th>
                    <Th>{t.content.colDate}</Th>
                    <Th right>{t.common.likes}</Th>
                    <Th right>{t.common.comments}</Th>
                    <Th right>{t.common.saves}</Th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                  {d.content.topPosts.map((p) => (
                    <tr key={p.id}>
                      <Td className="font-medium text-zinc-800 dark:text-zinc-200">@{p.username}</Td>
                      <Td className="max-w-[16rem] truncate text-zinc-600 dark:text-zinc-400">{p.place ?? '—'}</Td>
                      <Td className="text-zinc-500">{fmtDate(p.createdAt, lang)}</Td>
                      <Td right>{p.likes}</Td>
                      <Td right>{p.comments}</Td>
                      <Td right>{p.saves}</Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
        <Card title={t.content.topCreators} scope="period">
          {d.content.topCreators.length === 0 ? (
            <Empty />
          ) : (
            <ul className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
              {d.content.topCreators.map((x, i) => (
                <li key={x.username} className="flex items-center justify-between py-2 text-xs">
                  <span className="truncate text-zinc-800 dark:text-zinc-200">
                    <span className="mr-2 font-mono text-zinc-400">{i + 1}</span>@{x.username}
                  </span>
                  <span className="shrink-0 font-mono tabular-nums text-zinc-500">
                    {fmtNum(x.posts)} {t.common.posts.toLowerCase()} · ♥ {fmtNum(x.likes)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
};
