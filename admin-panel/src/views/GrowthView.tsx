import React, { useState } from 'react';
import { 
  UserPlus, 
  Search,
  Shield,
  Bell,
  TrendingUp
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
  CartesianGrid 
} from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';

export const GrowthView: React.FC = () => {
  const { t, lang } = useLanguage();
  const { darkMode } = useTheme();
  const { data } = useAnalytics();
  const kpi = data.kpiOverview;
  const [userSearch, setUserSearch] = useState('');
  const [tierFilter, setTierFilter] = useState('all');

  const pc = (key: string) => data.profileCompleteness.find((p) => p.key === key)?.pct ?? 0;
  const weekSignups = data.activityTrends.reduce((s, d) => s + d.signups, 0);

  const filteredUsers = data.recentUsers.filter((user) => {
    const matchesSearch = user.username.toLowerCase().includes(userSearch.toLowerCase()) ||
                          user.id.toLowerCase().includes(userSearch.toLowerCase());
    const matchesTier = tierFilter === 'all' || user.referralTier.toLowerCase() === tierFilter.toLowerCase();
    return matchesSearch && matchesTier;
  });

  const profileLabels: Record<string, { en: string; ru: string }> = {
    avatar: { en: 'Avatar uploaded', ru: 'Аватар загружен' },
    bio: { en: 'Bio filled', ru: 'Био заполнено' },
    public: { en: 'Public profiles', ru: 'Открытые профили' },
    private: { en: 'Private profiles', ru: 'Закрытые профили' },
    push: { en: 'Push token connected', ru: 'Push токен подключен' },
  };

  const ageLabels: Record<string, { en: string; ru: string }> = {
    lt1990: { en: '< 1990 (Age 35+)', ru: '< 1990 (35+ лет)' },
    '1990_1995': { en: '1990-1995 (30-35)', ru: '1990-1995 (30-35)' },
    '1996_2000': { en: '1996-2000 (25-29)', ru: '1996-2000 (25-29)' },
    '2001_2005': { en: '2001-2005 (20-24)', ru: '2001-2005 (20-24)' },
    gte2006: { en: '2006+ (16-19)', ru: '2006+ (16-19)' },
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.growth.title}</h1>
        <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.growth.subtitle}</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.growth.signupsToday}
          value={kpi.newUsersToday}
          change={kpi.changes.users}
          icon={UserPlus}
        />
        <StatCard
          title={t.growth.signupsWeek}
          value={weekSignups}
          icon={TrendingUp}
        />
        <StatCard
          title={t.growth.pushCoverage}
          value={`${pc('push')}%`}
          subtitle={t.growth.pushConnected}
          icon={Bell}
        />
        <StatCard
          title={t.growth.publicProfiles}
          value={`${pc('public')}%`}
          subtitle={t.growth.privateShare}
          icon={Shield}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Daily Signups Bar */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.growth.dailySignupsTitle}</h2>
            <span className="text-[10px] font-mono text-zinc-400 dark:text-zinc-500">auth_credentials</span>
          </div>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data.activityTrends}>
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
                  cursor={{ fill: darkMode ? 'rgba(255,255,255,0.03)' : 'rgba(0,0,0,0.03)' }}
                />
                <Bar dataKey="signups" fill="#10b981" radius={[3, 3, 0, 0]} name={t.growth.signupsToday} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Age distribution */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.growth.ageTitle}</h2>
            <span className="text-[10px] font-mono text-zinc-400 dark:text-zinc-500">birth_year</span>
          </div>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart 
                data={data.birthYearDistribution.map(d => ({
                  ...d,
                  range: ageLabels[d.key]?.[lang] || d.key
                }))}
                layout="vertical"
              >
                <CartesianGrid strokeDasharray="2 2" stroke={darkMode ? '#27272a' : '#e4e4e7'} horizontal={false} />
                <XAxis type="number" stroke={darkMode ? '#52525b' : '#a1a1aa'} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} />
                <YAxis dataKey="range" type="category" stroke={darkMode ? '#52525b' : '#a1a1aa'} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} width={110} />
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
                <Bar dataKey="count" fill={darkMode ? '#71717a' : '#94a3b8'} radius={[0, 3, 3, 0]} name="Users" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Profile Completeness */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-3">{t.growth.completenessTitle}</h2>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          {data.profileCompleteness.map((item) => {
            const translatedTitle = profileLabels[item.key]?.[lang] || item.key;
            return (
              <div key={item.key} className="p-3 rounded-lg bg-zinc-50 dark:bg-zinc-950/60 border border-zinc-200/70 dark:border-white/[0.05]">
                <div className="text-[11px] text-zinc-500 dark:text-zinc-400 truncate">{translatedTitle}</div>
                <div className="mt-1 text-lg font-semibold text-zinc-900 dark:text-white font-mono">{item.pct}%</div>
                <div className="w-full bg-zinc-200 dark:bg-zinc-800 h-1 rounded-full mt-2 overflow-hidden">
                  <div className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full" style={{ width: `${item.pct}%` }} />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Users Table */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-4">
          <div>
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.growth.usersTableTitle}</h2>
            <p className="text-[11px] text-zinc-500">{t.growth.usersTableSub}</p>
          </div>

          <div className="flex items-center gap-2">
            <div className="relative">
              <Search className="w-3 h-3 text-zinc-400 dark:text-zinc-500 absolute left-2.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder={t.growth.searchUser}
                value={userSearch}
                onChange={(e) => setUserSearch(e.target.value)}
                className="pl-7 pr-2.5 py-1 text-xs bg-zinc-50 dark:bg-zinc-950 border border-zinc-200 dark:border-white/[0.08] rounded-md text-zinc-900 dark:text-zinc-200 placeholder-zinc-400 dark:placeholder-zinc-500 focus:outline-none focus:border-zinc-400 dark:focus:border-zinc-500"
              />
            </div>

            <select
              value={tierFilter}
              onChange={(e) => setTierFilter(e.target.value)}
              className="px-2 py-1 text-xs bg-zinc-50 dark:bg-zinc-950 border border-zinc-200 dark:border-white/[0.08] rounded-md text-zinc-700 dark:text-zinc-300 outline-none cursor-pointer"
            >
              <option value="all">{t.growth.allTiers}</option>
              <option value="bronze">Bronze</option>
              <option value="silver">Silver</option>
              <option value="gold">Gold</option>
              <option value="platinum">Platinum</option>
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-zinc-200 dark:border-white/[0.06] text-zinc-400 dark:text-zinc-500 font-medium text-[11px]">
                <th className="py-2.5 px-2">{t.growth.id}</th>
                <th className="py-2.5 px-2">{t.growth.username}</th>
                <th className="py-2.5 px-2">{t.growth.profile}</th>
                <th className="py-2.5 px-2">{t.growth.privacy}</th>
                <th className="py-2.5 px-2">{t.growth.tier}</th>
                <th className="py-2.5 px-2">{t.growth.birthYear}</th>
                <th className="py-2.5 px-2">{t.growth.postFollower}</th>
                <th className="py-2.5 px-2 text-right">{t.growth.registeredAt}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
              {filteredUsers.map((u) => (
                <tr key={u.id} className="hover:bg-zinc-50/80 dark:hover:bg-white/[0.02] transition-colors">
                  <td className="py-2 px-2 font-mono text-zinc-400 dark:text-zinc-500 text-[11px]">{u.id}</td>
                  <td className="py-2 px-2 font-mono text-zinc-900 dark:text-zinc-200 font-medium">@{u.username}</td>
                  <td className="py-2 px-2 text-zinc-600 dark:text-zinc-400 text-[11px]">
                    {u.hasAvatar ? 'Avatar ✓' : '—'} {u.hasBio ? 'Bio ✓' : ''}
                  </td>
                  <td className="py-2 px-2">
                    <span className="text-[11px] font-mono text-zinc-600 dark:text-zinc-400">
                      {u.isPrivate ? 'Private' : 'Public'}
                    </span>
                  </td>
                  <td className="py-2 px-2 text-zinc-800 dark:text-zinc-300 font-mono text-[11px]">{u.referralTier}</td>
                  <td className="py-2 px-2 text-zinc-500 dark:text-zinc-400 font-mono text-[11px]">{u.birthYear}</td>
                  <td className="py-2 px-2 text-zinc-600 dark:text-zinc-400 font-mono text-[11px]">
                    {u.postsCount} / {u.followersCount}
                  </td>
                  <td className="py-2 px-2 text-right text-zinc-400 dark:text-zinc-500 font-mono text-[11px]">{fmtDateTime(u.signupAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
