import React from 'react';
import { 
  Image as ImageIcon, 
  MapPin, 
  Clock, 
  Bookmark, 
  Sparkles
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { useAnalytics, fmtDateTime } from '../data/useAnalytics';
import {
  ResponsiveContainer, 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  Tooltip, 
  CartesianGrid, 
  Legend 
} from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';

export const ContentView: React.FC = () => {
  const { t, lang } = useLanguage();
  const { darkMode } = useTheme();
  const { data } = useAnalytics();
  const c = data.contentStats;

  const dayLabels: Record<string, { en: string; ru: string }> = {
    'Dush': { en: 'Mon', ru: 'Пн' },
    'Sesh': { en: 'Tue', ru: 'Вт' },
    'Chor': { en: 'Wed', ru: 'Ср' },
    'Pay': { en: 'Thu', ru: 'Чт' },
    'Juma': { en: 'Fri', ru: 'Пт' },
    'Shan': { en: 'Sat', ru: 'Сб' },
    'Yak': { en: 'Sun', ru: 'Вс' },
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.content.title}</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.content.subtitle}</p>
        </div>
        <div className="text-[11px] font-mono text-zinc-500 dark:text-zinc-400">
          {t.content.geoShare} <span className="text-zinc-900 dark:text-white font-medium">{c.geoTaggedPct}%</span>
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.content.postsToday}
          value={c.postsToday}
          change={15.3}
          icon={ImageIcon}
        />
        <StatCard
          title={t.content.creators}
          value={c.creatorsCount}
          subtitle={t.content.creatorsSub}
          icon={Sparkles}
        />
        <StatCard
          title={t.content.activeStories}
          value={c.storiesActive}
          subtitle={t.content.activeStoriesSub}
          icon={Clock}
        />
        <StatCard
          title={t.content.highlights}
          value={c.highlightsCount}
          subtitle={t.content.highlightsSub}
          icon={Bookmark}
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Weekly trends */}
        <div className="lg:col-span-2 p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.content.weeklyTrendTitle}</h2>
          </div>

          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={c.dailyPostTrends.map(d => ({ ...d, day: dayLabels[d.day]?.[lang] || d.day }))}>
                <CartesianGrid strokeDasharray="2 2" stroke={darkMode ? '#27272a' : '#e4e4e7'} vertical={false} />
                <XAxis dataKey="day" stroke={darkMode ? '#52525b' : '#a1a1aa'} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} />
                <YAxis stroke={darkMode ? '#52525b' : '#a1a1aa'} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} />
                <Tooltip
                  contentStyle={{ 
                    backgroundColor: darkMode ? '#18181b' : '#ffffff', 
                    borderColor: darkMode ? '#27272a' : '#e4e4e7', 
                    borderRadius: '0.5rem', 
                    fontSize: '11px', 
                    color: darkMode ? '#e4e4e7' : '#18181b',
                    boxShadow: darkMode ? 'none' : '0 4px 6px -1px rgba(0, 0, 0, 0.05)'
                  }}
                  cursor={{ fill: darkMode ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.03)' }}
                />
                <Legend wrapperStyle={{ fontSize: '11px', paddingTop: '8px' }} />
                <Bar dataKey="posts" fill="#10b981" radius={[3, 3, 0, 0]} name={lang === 'ru' ? 'Посты' : 'Posts'} />
                <Bar dataKey="stories" fill={darkMode ? '#71717a' : '#94a3b8'} radius={[3, 3, 0, 0]} name={lang === 'ru' ? 'Истории' : 'Stories'} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Content formats */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none flex flex-col justify-between">
          <div>
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-1">{t.content.formatTitle}</h2>
            <p className="text-[11px] text-zinc-500 mb-4">{t.content.formatSub}</p>

            <div className="space-y-4">
              <div className="space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-zinc-600 dark:text-zinc-400 text-[11px]">{t.content.photoStories}</span>
                  <span className="font-mono text-zinc-900 dark:text-zinc-200 text-[11px]">{c.storiesPhotoPct}%</span>
                </div>
                <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1.5 rounded-full overflow-hidden">
                  <div className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full" style={{ width: `${c.storiesPhotoPct}%` }} />
                </div>
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-zinc-600 dark:text-zinc-400 text-[11px]">{t.content.videoStories}</span>
                  <span className="font-mono text-zinc-900 dark:text-zinc-200 text-[11px]">{c.storiesVideoPct}%</span>
                </div>
                <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1.5 rounded-full overflow-hidden">
                  <div className="bg-zinc-500 h-full rounded-full" style={{ width: `${c.storiesVideoPct}%` }} />
                </div>
              </div>

              <div className="space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-zinc-600 dark:text-zinc-400 text-[11px]">{t.content.geoTaggedShare}</span>
                  <span className="font-mono text-zinc-900 dark:text-zinc-200 text-[11px]">{c.geoTaggedPct}%</span>
                </div>
                <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1.5 rounded-full overflow-hidden">
                  <div className="bg-emerald-500 h-full rounded-full" style={{ width: `${c.geoTaggedPct}%` }} />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Top Posts Table */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-3">{t.content.topPostsTitle}</h2>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-zinc-200 dark:border-white/[0.06] text-zinc-400 dark:text-zinc-500 font-medium text-[11px]">
                <th className="py-2.5 px-2">ID</th>
                <th className="py-2.5 px-2">{t.content.author}</th>
                <th className="py-2.5 px-2">{t.content.type}</th>
                <th className="py-2.5 px-2">{t.content.location}</th>
                <th className="py-2.5 px-2">{t.content.date}</th>
                <th className="py-2.5 px-2 font-mono">Like</th>
                <th className="py-2.5 px-2 font-mono">{lang === 'ru' ? 'Коммент.' : 'Comments'}</th>
                <th className="py-2.5 px-2 text-right font-mono">{lang === 'ru' ? 'Репосты' : 'Shares'}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
              {data.topPosts.map((p) => (
                <tr key={p.id} className="hover:bg-zinc-50/80 dark:hover:bg-white/[0.02] transition-colors">
                  <td className="py-2 px-2 font-mono text-zinc-400 dark:text-zinc-500 text-[11px]">{p.id}</td>
                  <td className="py-2 px-2 font-mono text-zinc-900 dark:text-zinc-200 font-medium">@{p.username}</td>
                  <td className="py-2 px-2 text-zinc-600 dark:text-zinc-400 text-[11px] capitalize">{p.contentType}</td>
                  <td className="py-2 px-2 text-zinc-800 dark:text-zinc-300 text-[11px]">
                    {p.hasLocation ? (
                      <span className="flex items-center gap-1">
                        <MapPin className="w-2.5 h-2.5 text-zinc-400 dark:text-zinc-500" />
                        {p.placeName || p.region}
                      </span>
                    ) : (
                      <span className="text-zinc-400 dark:text-zinc-600">—</span>
                    )}
                  </td>
                  <td className="py-2 px-2 text-zinc-400 dark:text-zinc-500 text-[11px]">{fmtDateTime(p.createdAt)}</td>
                  <td className="py-2 px-2 font-mono text-zinc-900 dark:text-zinc-200">{p.likesCount.toLocaleString()}</td>
                  <td className="py-2 px-2 font-mono text-zinc-500 dark:text-zinc-400">{p.commentsCount}</td>
                  <td className="py-2 px-2 text-right font-mono text-zinc-500 dark:text-zinc-400">{p.sharesCount}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
