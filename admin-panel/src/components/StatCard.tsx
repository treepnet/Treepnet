import React from 'react';
import { LucideIcon, ArrowUpRight, ArrowDownRight } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string | number;
  change?: number;
  changeLabel?: string;
  icon?: LucideIcon;
  subtitle?: string;
}

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  change,
  changeLabel = 'vs previous',
  icon: Icon,
  subtitle,
}) => {
  const isPositive = (change ?? 0) >= 0;

  return (
    <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] hover:border-zinc-300 dark:hover:border-white/[0.14] shadow-xs dark:shadow-none transition-all flex flex-col justify-between">
      <div>
        <div className="flex items-center justify-between">
          <span className="text-xs font-medium text-zinc-500 dark:text-zinc-400">{title}</span>
          {Icon && <Icon className="w-3.5 h-3.5 text-zinc-400 dark:text-zinc-500 stroke-[1.75]" />}
        </div>
        <div className="mt-2 text-2xl font-semibold tracking-tight text-zinc-900 dark:text-white tabular-nums">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>
      </div>

      {(change !== undefined || subtitle) && (
        <div className="mt-3 flex items-center gap-1.5 text-[11px]">
          {change !== undefined ? (
            <>
              <span className={`inline-flex items-center font-mono font-medium ${
                isPositive ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'
              }`}>
                {isPositive ? <ArrowUpRight className="w-3 h-3 mr-0.5 inline" /> : <ArrowDownRight className="w-3 h-3 mr-0.5 inline" />}
                {isPositive ? `+${change}%` : `${change}%`}
              </span>
              <span className="text-zinc-400 dark:text-zinc-500 truncate">{changeLabel}</span>
            </>
          ) : (
            <span className="text-zinc-500 dark:text-zinc-500 truncate">{subtitle}</span>
          )}
        </div>
      )}
    </div>
  );
};
