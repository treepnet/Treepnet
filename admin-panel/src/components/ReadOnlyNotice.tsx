import React from 'react';
import { useLanguage } from '../context/LanguageContext';

export const ReadOnlyNotice: React.FC = () => {
  const { t } = useLanguage();

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 py-2 px-3.5 rounded-lg bg-white dark:bg-zinc-900/60 border border-zinc-200/80 dark:border-white/[0.06] shadow-xs dark:shadow-none text-xs">
      <div className="flex items-center gap-2 text-zinc-600 dark:text-zinc-400">
        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
        <span className="font-medium text-zinc-900 dark:text-zinc-300">{t.notice.readOnly}</span>
        <span className="text-zinc-300 dark:text-zinc-600">•</span>
        <span>{t.notice.roleLabel}: <code className="font-mono text-zinc-700 dark:text-zinc-400">analytics_ro</code></span>
        <span className="text-zinc-300 dark:text-zinc-600">•</span>
        <span className="hidden sm:inline">{t.notice.masked}</span>
      </div>

      <div className="flex items-center gap-3 text-zinc-400 dark:text-zinc-500 font-mono text-[11px]">
        <span>{t.notice.timeout}</span>
        <span className="text-zinc-300 dark:text-zinc-700">|</span>
        <span className="text-emerald-600 dark:text-emerald-500/90 font-sans font-medium">{t.notice.syncSafe}</span>
      </div>
    </div>
  );
};
