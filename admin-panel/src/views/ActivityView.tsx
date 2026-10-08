import React from 'react';
import { 
  Activity, 
  Flame, 
  Moon, 
  Sparkles, 
  Zap
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { useAnalytics } from '../data/useAnalytics';
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

export const ActivityView: React.FC = () => {
  const { t, lang } = useLanguage();
  const { darkMode } = useTheme();
  const { data } = useAnalytics();
  const kpi = data.kpiOverview;
  const dormant = data.userSegments.find((s) => s.key === 'dormant');

  const segLabels: Record<string, { en: string; ru: string }> = {
    '0': { en: 'Last 24 hours', ru: 'Последние 24 часа' },
    '1': { en: '1 - 7 days', ru: '1 - 7 дней' },
    '2': { en: '8 - 30 days', ru: '8 - 30 дней' },
    '3': { en: '30+ days (Dormant)', ru: '30+ дней (Уснувшие)' },
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.activity.title}</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.activity.subtitle}</p>
        </div>
        <div className="text-[11px] font-mono text-zinc-500 dark:text-zinc-400">
          {t.activity.stickinessLabel} <span className="text-zinc-900 dark:text-white font-medium">{kpi.stickiness}%</span>
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.activity.dau}
          value={kpi.dau}
          change={kpi.changes.dau}
          icon={Flame}
        />
        <StatCard
          title={t.activity.wau}
          value={kpi.wau}
          icon={Zap}
        />
        <StatCard
          title={t.activity.mau}
          value={kpi.mau}
          icon={Sparkles}
        />
        <StatCard
          title={t.activity.dormant}
          value={dormant ? dormant.count : 0}
          subtitle={t.activity.dormantSub}
          icon={Moon}
        />
      </div>

      {/* Hourly Chart & Cohorts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Hourly Chart */}
        <div className="lg:col-span-2 p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300">{t.activity.hourlyTitle}</h2>
            <span className="text-[11px] font-mono text-zinc-500 dark:text-zinc-400">{t.activity.hourlyPeak}</span>
          </div>

          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data.hourlyActivity}>
                <defs>
                  <linearGradient id="hourlyGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#10b981" stopOpacity={0.15}/>
                    <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="2 2" stroke={darkMode ? '#27272a' : '#e4e4e7'} vertical={false} />
                <XAxis dataKey="hour" stroke={darkMode ? '#52525b' : '#a1a1aa'} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} />
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
                  formatter={(val: any) => [`${Number(val).toLocaleString()} users`, 'Active']}
                />
                <Area type="monotone" dataKey="active" stroke="#10b981" strokeWidth={1.5} fill="url(#hourlyGrad)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* User Segments */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none flex flex-col justify-between">
          <div>
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-1">{t.activity.cohortTitle}</h2>
            <p className="text-[11px] text-zinc-500 mb-4">{t.activity.cohortSub}</p>

            <div className="space-y-3.5">
              {data.userSegments.map((segment, idx) => {
                const label = segLabels[String(idx)]?.[lang] || segment.key;
                return (
                  <div key={segment.key} className="space-y-1">
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-zinc-600 dark:text-zinc-400 text-[11px]">{label}</span>
                      <span className="font-mono text-zinc-900 dark:text-zinc-200 text-[11px]">{segment.percentage}%</span>
                    </div>
                    <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1 rounded-full overflow-hidden">
                      <div 
                        className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full"
                        style={{ width: `${segment.percentage}%` }}
                      />
                    </div>
                    <div className="text-[10px] text-zinc-400 dark:text-zinc-500 font-mono text-right">
                      {segment.count.toLocaleString()}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {/* Implementation details */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-2">{t.activity.techTitle}</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs text-zinc-500 dark:text-zinc-400">
          <div>
            <span className="font-medium text-zinc-800 dark:text-zinc-300 block mb-0.5">{t.activity.skewTitle}</span>
            <p className="text-[11px] leading-relaxed text-zinc-500">{t.activity.skewDesc}</p>
          </div>
          <div>
            <span className="font-medium text-zinc-800 dark:text-zinc-300 block mb-0.5">{t.activity.heartbeatTitle}</span>
            <p className="text-[11px] leading-relaxed text-zinc-500">{t.activity.heartbeatDesc}</p>
          </div>
          <div>
            <span className="font-medium text-zinc-800 dark:text-zinc-300 block mb-0.5">{t.activity.queryTitle}</span>
            <p className="text-[11px] leading-relaxed text-zinc-500">{t.activity.queryDesc}</p>
          </div>
        </div>
      </div>
    </div>
  );
};
