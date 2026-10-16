import React from 'react';
import { ArrowDownRight, ArrowUpRight, Info, LucideIcon, Minus } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';
import { delta, fmtNum } from '../lib/format';
import type { Metric } from '../lib/api';

export type Scope = 'period' | 'now' | 'allTime';

export const ScopeBadge: React.FC<{ scope: Scope }> = ({ scope }) => {
  const { t } = useLanguage();
  const cls = {
    period: 'bg-sky-50 text-sky-700 dark:bg-sky-500/10 dark:text-sky-300',
    now: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300',
    allTime: 'bg-zinc-100 text-zinc-600 dark:bg-white/[0.06] dark:text-zinc-400',
  }[scope];
  return (
    <span className={`inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${cls}`}>
      {t.scope[scope]}
    </span>
  );
};

export const Hint: React.FC<{ text: string }> = ({ text }) => (
  <span className="group relative inline-flex align-middle">
    <Info className="h-3.5 w-3.5 cursor-help text-zinc-400 dark:text-zinc-500" aria-label={text} tabIndex={0} />
    <span
      role="tooltip"
      className="pointer-events-none absolute left-1/2 top-5 z-50 hidden w-60 -translate-x-1/2 rounded-md border border-zinc-200 bg-white p-2 text-[11px] font-normal normal-case leading-snug tracking-normal text-zinc-700 shadow-lg group-hover:block group-focus-within:block dark:border-white/10 dark:bg-zinc-900 dark:text-zinc-300"
    >
      {text}
    </span>
  </span>
);

export const Card: React.FC<{
  title?: string;
  subtitle?: string;
  scope?: Scope;
  hint?: string;
  right?: React.ReactNode;
  className?: string;
  children: React.ReactNode;
}> = ({ title, subtitle, scope, hint, right, className = '', children }) => (
  <section
    className={`min-w-0 rounded-xl border border-zinc-200/80 bg-white p-4 dark:border-white/[0.07] dark:bg-zinc-900/50 ${className}`}
  >
    {(title || right) && (
      <header className="mb-3 flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            {title && <h2 className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">{title}</h2>}
            {hint && <Hint text={hint} />}
            {scope && <ScopeBadge scope={scope} />}
          </div>
          {subtitle && <p className="mt-0.5 text-xs text-zinc-500 dark:text-zinc-400">{subtitle}</p>}
        </div>
        {right}
      </header>
    )}
    {children}
  </section>
);

export const DeltaChip: React.FC<{ metric: Metric }> = ({ metric }) => {
  const { t } = useLanguage();
  const d = delta(metric.value, metric.previous);
  if (d.label === '—') return null;
  if (d.isNew) {
    return <span className="font-mono text-[11px] font-medium text-emerald-600 dark:text-emerald-400">↑ {t.common.new}</span>;
  }
  const Icon = d.dir === 'up' ? ArrowUpRight : d.dir === 'down' ? ArrowDownRight : Minus;
  const color =
    d.dir === 'up' ? 'text-emerald-600 dark:text-emerald-400' : d.dir === 'down' ? 'text-rose-600 dark:text-rose-400' : 'text-zinc-400';
  return (
    <span className={`inline-flex items-center font-mono text-[11px] font-medium ${color}`}>
      <Icon className="mr-0.5 h-3 w-3" />
      {d.label}
    </span>
  );
};

export const StatCard: React.FC<{
  title: string;
  value: number | string;
  metric?: Metric;
  hint?: string;
  icon?: LucideIcon;
  sub?: string;
  accent?: 'emerald' | 'sky' | 'violet' | 'amber' | 'rose' | 'zinc';
}> = ({ title, value, metric, hint, icon: Icon, sub, accent = 'zinc' }) => {
  const { t } = useLanguage();
  const iconCls = {
    emerald: 'text-emerald-500', sky: 'text-sky-500', violet: 'text-violet-500',
    amber: 'text-amber-500', rose: 'text-rose-500', zinc: 'text-zinc-400 dark:text-zinc-500',
  }[accent];
  return (
    <div className="flex min-w-0 flex-col justify-between rounded-xl border border-zinc-200/80 bg-white p-4 dark:border-white/[0.07] dark:bg-zinc-900/50">
      <div className="flex items-start justify-between gap-2">
        <span className="min-w-0 text-xs font-medium leading-snug text-zinc-500 dark:text-zinc-400">
          {title}
          {hint && (
            <span className="ml-1 inline-block align-[-2px]">
              <Hint text={hint} />
            </span>
          )}
        </span>
        {Icon && <Icon className={`h-4 w-4 shrink-0 ${iconCls}`} />}
      </div>
      <div className="mt-2 text-2xl font-semibold tabular-nums tracking-tight text-zinc-900 dark:text-white">
        {typeof value === 'number' ? fmtNum(value) : value}
      </div>
      {(metric || sub) && (
        <div className="mt-2 flex min-w-0 flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px] text-zinc-400 dark:text-zinc-500">
          {metric && (
            <>
              <DeltaChip metric={metric} />
              <span className="truncate">
                {t.period.prevWas}: {fmtNum(metric.previous)}
              </span>
            </>
          )}
          {!metric && sub && <span className="truncate">{sub}</span>}
        </div>
      )}
    </div>
  );
};

export const BarRow: React.FC<{ label: string; count: number; pct: number; color?: string; right?: string }> = ({
  label, count, pct, color = 'bg-emerald-500', right,
}) => (
  <div className="space-y-1">
    <div className="flex items-baseline justify-between gap-3 text-xs">
      <span className="truncate text-zinc-700 dark:text-zinc-300">{label}</span>
      <span className="shrink-0 font-mono tabular-nums text-zinc-500 dark:text-zinc-400">
        {right ?? `${fmtNum(count)} · ${pct}%`}
      </span>
    </div>
    <div className="h-1.5 overflow-hidden rounded-full bg-zinc-100 dark:bg-white/[0.06]">
      <div className={`h-full rounded-full ${color}`} style={{ width: `${Math.min(100, Math.max(0, pct))}%` }} />
    </div>
  </div>
);

export const Empty: React.FC<{ text?: string }> = ({ text }) => {
  const { t } = useLanguage();
  return <p className="py-8 text-center text-xs text-zinc-400 dark:text-zinc-500">{text ?? t.common.noData}</p>;
};

export const PageHeader: React.FC<{ title: string; subtitle: string }> = ({ title, subtitle }) => (
  <div>
    <h1 className="text-xl font-semibold tracking-tight text-zinc-900 dark:text-white">{title}</h1>
    <p className="mt-0.5 text-sm text-zinc-500 dark:text-zinc-400">{subtitle}</p>
  </div>
);

export function useChartColors() {
  const { darkMode } = useTheme();
  return {
    grid: darkMode ? '#27272a' : '#f0f0f2',
    axis: darkMode ? '#71717a' : '#a1a1aa',
    tooltip: {
      contentStyle: {
        background: darkMode ? '#18181b' : '#ffffff',
        border: `1px solid ${darkMode ? '#3f3f46' : '#e4e4e7'}`,
        borderRadius: 8,
        fontSize: 12,
        color: darkMode ? '#e4e4e7' : '#27272a',
      },
      labelStyle: { color: darkMode ? '#a1a1aa' : '#71717a', marginBottom: 4 },
      cursor: { fill: darkMode ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.04)' },
    },
    emerald: '#10b981',
    sky: '#0ea5e9',
    violet: '#8b5cf6',
    amber: '#f59e0b',
    rose: '#f43f5e',
  };
}

export const Th: React.FC<{ children?: React.ReactNode; right?: boolean; className?: string }> = ({ children, right, className = '' }) => (
  <th className={`whitespace-nowrap px-2 py-2 text-[11px] font-medium text-zinc-500 dark:text-zinc-400 ${right ? 'text-right' : 'text-left'} ${className}`}>
    {children}
  </th>
);

export const Td: React.FC<{ children?: React.ReactNode; right?: boolean; className?: string }> = ({ children, right, className = '' }) => (
  <td className={`whitespace-nowrap px-2 py-2 text-xs ${right ? 'text-right font-mono tabular-nums' : ''} ${className}`}>{children}</td>
);
