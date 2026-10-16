import React from 'react';
import { Menu, Moon, RefreshCw, Sun } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';
import { useData } from '../context/DataContext';
import type { Language } from '../i18n/translations';
import { PeriodPicker } from './PeriodPicker';
import { fmtDay, fmtNum, periodLabel } from '../lib/format';

export const Topbar: React.FC<{ title: string; onMenu: () => void }> = ({ title, onMenu }) => {
  const { t, lang, setLang } = useLanguage();
  const { darkMode, toggleDarkMode } = useTheme();
  const { data, loading, refresh, online } = useData();
  const p = data?.period;

  return (
    <header className="sticky top-0 z-30 border-b border-zinc-200/80 bg-white/85 backdrop-blur-md dark:border-white/[0.08] dark:bg-zinc-950/85">
      <div className="flex h-14 items-center gap-2 px-4 sm:px-6">
        <button type="button" onClick={onMenu} className="-ml-1 rounded-md p-1.5 text-zinc-500 hover:bg-zinc-100 dark:hover:bg-white/[0.06] lg:hidden" aria-label={t.common.menu}>
          <Menu className="h-5 w-5" />
        </button>
        <h1 className="min-w-0 truncate text-sm font-semibold text-zinc-900 dark:text-zinc-100">{title}</h1>

        <div className="ml-auto flex items-center gap-1.5">
          <div
            className="flex items-center gap-1.5 rounded-full border border-emerald-500/30 bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300"
            title={t.live.hint}
          >
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-60 motion-reduce:animate-none" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
            </span>
            <span className="tabular-nums">{online ? fmtNum(online.onlineNow) : '–'}</span>
            <span className="hidden sm:inline">{t.common.online}</span>
          </div>

          <button
            type="button"
            onClick={refresh}
            className="rounded-md p-1.5 text-zinc-500 hover:bg-zinc-100 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-white/[0.06] dark:hover:text-white"
            title={t.common.refresh}
            aria-label={t.common.refresh}
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          </button>

          <select
            value={lang}
            onChange={(e) => setLang(e.target.value as Language)}
            className="rounded-md border border-zinc-200 bg-white px-1.5 py-1 text-xs font-medium text-zinc-700 dark:border-white/[0.08] dark:bg-zinc-900 dark:text-zinc-300"
            aria-label="Language"
          >
            <option value="uz">UZ</option>
            <option value="ru">RU</option>
            <option value="en">EN</option>
          </select>

          <button
            type="button"
            onClick={toggleDarkMode}
            className="rounded-md p-1.5 text-zinc-500 hover:bg-zinc-100 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-white/[0.06] dark:hover:text-white"
            title={t.common.theme}
            aria-label={t.common.theme}
          >
            {darkMode ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </button>
        </div>
      </div>

      <div className="flex flex-col gap-2 border-t border-zinc-100 px-4 py-2 dark:border-white/[0.04] sm:px-6 xl:flex-row xl:items-center xl:justify-between">
        <PeriodPicker />
        {p && (
          <div className="text-[11px] text-zinc-500 dark:text-zinc-400">
            <span className="font-medium text-zinc-700 dark:text-zinc-300">{periodLabel(p.from, p.to, lang)}</span>
            {' · '}
            {p.days} {t.period.days}
            {p.unit !== 'day' && ` · ${p.unit === 'week' ? t.period.weekly : t.period.monthly}`}
            <span className="hidden sm:inline">
              {' · '}
              {t.period.prevWas}: {p.previousFrom === p.previousTo ? fmtDay(p.previousFrom, lang) : periodLabel(p.previousFrom, p.previousTo, lang)}
            </span>
          </div>
        )}
      </div>
    </header>
  );
};
