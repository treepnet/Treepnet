import React from 'react';
import { 
  Users, 
  Activity, 
  UserCheck, 
  Sparkles, 
  Image as ImageIcon, 
  Heart, 
  Gift, 
  Clock, 
  ArrowUpRight,
  Compass
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { useAnalytics, fmtDateTime } from '../data/useAnalytics';
import {
  ResponsiveContainer, 
  AreaChart, 
  Area, 
  XAxis, 
  YAxis, 
  Tooltip, 
  CartesianGrid 
} from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';

interface OverviewViewProps {
  onNavigateTab: (tab: any) => void;
}

export const OverviewView: React.FC<OverviewViewProps> = ({ onNavigateTab }) => {
  const { t, lang } = useLanguage();
  const { darkMode } = useTheme();
  const { data } = useAnalytics();
  const kpi = data.kpiOverview;
  const activeIn30dPct = kpi.totalUsers > 0 ? ((kpi.mau / kpi.totalUsers) * 100).toFixed(1) : '0';

  return (
    <div className="space-y-6">
      {/* Page Title */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.overview.title}</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.overview.subtitle}</p>
        </div>
        <div className="text-[11px] font-mono text-zinc-400 dark:text-zinc-500">
          {t.overview.refreshRate}
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.overview.totalUsers}
          value={kpi.totalUsers}
          change={kpi.changes.users}
          icon={Users}
        />
        <StatCard
          title={t.overview.dau}
          value={kpi.dau}
          change={kpi.changes.dau}
          icon={Activity}
        />
        <StatCard
          title={t.overview.stickiness}
          value={`${kpi.stickiness}%`}
          subtitle={`MAU: ${kpi.mau.toLocaleString()}`}
          icon={Sparkles}
        />
        <StatCard
          title={t.overview.newSignupsToday}
          value={kpi.newUsersToday}
          icon={UserCheck}
        />
      </div>

      {/* Secondary Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.overview.totalPosts}
          value={kpi.totalPosts}
          change={kpi.changes.posts}
          icon={ImageIcon}
        />
        <StatCard
          title={t.overview.activeStories}
          value={kpi.totalStories}
          change={kpi.changes.stories}
          icon={Clock}
        />
        <StatCard
          title={t.overview.engagement}
          value={(kpi.totalLikes + kpi.totalComments).toLocaleString()}
          change={kpi.changes.engagement}
          icon={Heart}
        />
        <StatCard
          title={t.overview.referrals}
          value={kpi.totalReferrals}
          change={kpi.changes.referrals}
          icon={Gift}
        />
      </div>

      {/* Charts: DAU / WAU / MAU & Cohorts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Trend Area */}
        <div className="lg:col-span-2 p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.overview.trendTitle}</h2>
              <p className="text-[11px] text-zinc-500">{t.overview.trendSub}</p>
            </div>
            <div className="flex items-center gap-3 text-[11px] font-mono text-zinc-500 dark:text-zinc-400">
              <span className="flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> DAU
              </span>
              <span className="flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-zinc-400"></span> WAU
              </span>
              <span className="flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-zinc-300 dark:bg-zinc-600"></span> MAU
              </span>
            </div>
          </div>

          <div className="h-60 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data.activityTrends}>
                <defs>
                  <linearGradient id="dauGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10b981" stopOpacity={0.15}/>
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="2 2" stroke={darkMode ? '#27272a' : '#e4e4e7'} vertical={false} />
                <XAxis dataKey="date" stroke={darkMode ? '#52525b' : '#a1a1aa'} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} />
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
                />
                <Area type="monotone" dataKey="mau" stroke={darkMode ? '#52525b' : '#a1a1aa'} strokeWidth={1} fill="none" name="MAU" />
                <Area type="monotone" dataKey="wau" stroke={darkMode ? '#a1a1aa' : '#71717a'} strokeWidth={1} fill="none" name="WAU" />
                <Area type="monotone" dataKey="dau" stroke="#10b981" strokeWidth={1.5} fill="url(#dauGrad)" name="DAU" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* User Cohorts */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-1">
              <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.overview.cohortsTitle}</h2>
              <button 
                onClick={() => onNavigateTab('activity')}
                className="text-[11px] text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-white flex items-center gap-0.5 transition-colors"
              >
                {t.overview.viewAll} <ArrowUpRight className="w-3 h-3" />
              </button>
            </div>
            <p className="text-[11px] text-zinc-500 mb-4">{t.overview.cohortsSub}</p>

            <div className="space-y-3">
              {data.userSegments.map((seg, idx) => {
                const segLabels: Record<string, { en: string; ru: string }> = {
                  '0': { en: 'Last 24 hours', ru: 'Последние 24 часа' },
                  '1': { en: '1 - 7 days', ru: '1 - 7 дней' },
                  '2': { en: '8 - 30 days', ru: '8 - 30 дней' },
                  '3': { en: '30+ days (Dormant)', ru: '30+ дней (Уснувшие)' },
                };
                const label = segLabels[String(idx)]?.[lang] || seg.key;
                return (
                  <div key={seg.key} className="space-y-1">
                    <div className="flex items-center justify-between text-[11px]">
                      <span className="text-zinc-600 dark:text-zinc-400">{label}</span>
                      <span className="font-mono text-zinc-900 dark:text-zinc-200">{seg.percentage}%</span>
                    </div>
                    <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1.5 rounded-full overflow-hidden">
                      <div 
                        className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full transition-all"
                        style={{ width: `${seg.percentage}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="pt-3 border-t border-zinc-100 dark:border-white/[0.06] text-[11px] text-zinc-500 flex justify-between">
            <span>{t.overview.activeIn30d}</span>
            <span className="font-mono text-zinc-800 dark:text-zinc-300 font-medium">{activeIn30dPct}%</span>
          </div>
        </div>
      </div>

      {/* Tables Row: Top Posts & Recent Users */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Top Posts */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.overview.topPostsTitle}</h2>
            <button 
              onClick={() => onNavigateTab('content')}
              className="text-[11px] text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-white flex items-center gap-0.5 transition-colors"
            >
              {t.overview.viewAll} <ArrowUpRight className="w-3 h-3" />
            </button>
          </div>

          <div className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
            {data.topPosts.slice(0, 4).map((post) => (
              <div key={post.id} className="py-2.5 flex items-center justify-between gap-3 text-xs">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-zinc-900 dark:text-zinc-300 font-medium">@{post.username}</span>
                    <span className="text-zinc-400 dark:text-zinc-500 text-[11px]">{fmtDateTime(post.createdAt)}</span>
                    {post.hasLocation && (
                      <span className="text-[10px] text-zinc-500 dark:text-zinc-400 flex items-center gap-0.5 truncate">
                        <Compass className="w-2.5 h-2.5 text-zinc-400 dark:text-zinc-500 shrink-0" /> {post.region}
                      </span>
                    )}
                  </div>
                  <p className="text-zinc-500 dark:text-zinc-400 text-[11px] truncate mt-0.5">{post.placeName || 'Post'}</p>
                </div>
                <div className="flex items-center gap-3 font-mono text-[11px] text-zinc-500 dark:text-zinc-400 shrink-0">
                  <span>{post.likesCount.toLocaleString()} {t.overview.likes}</span>
                  <span className="text-zinc-300 dark:text-zinc-500">•</span>
                  <span>{post.commentsCount} {t.overview.comments}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Recent Users */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.overview.recentSignupsTitle}</h2>
            <button 
              onClick={() => onNavigateTab('growth')}
              className="text-[11px] text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-white flex items-center gap-0.5 transition-colors"
            >
              {t.overview.viewAll} <ArrowUpRight className="w-3 h-3" />
            </button>
          </div>

          <div className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
            {data.recentUsers.slice(0, 4).map((user) => (
              <div key={user.id} className="py-2.5 flex items-center justify-between gap-3 text-xs">
                <div className="min-w-0">
                  <span className="font-mono text-zinc-900 dark:text-zinc-300 font-medium block">@{user.username}</span>
                  <span className="text-[11px] text-zinc-400 dark:text-zinc-500">{fmtDateTime(user.signupAt)}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[11px] text-zinc-500 dark:text-zinc-400 font-mono">{user.referralTier}</span>
                  <span className="text-[11px] text-emerald-600 dark:text-emerald-400 font-mono">{user.status}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
