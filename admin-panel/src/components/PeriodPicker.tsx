import React, { useEffect, useMemo, useRef, useState } from 'react';
import { CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useData } from '../context/DataContext';
import type { Preset } from '../lib/api';
import { MONTHS_LONG, WEEKDAYS, periodLabel, todayTashkent } from '../lib/format';

const PRESETS: Preset[] = ['today', 'yesterday', '7d', '30d', '90d', 'all'];

const pad = (x: number) => String(x).padStart(2, '0');
const ymd = (y: number, m: number, d: number) => `${y}-${pad(m)}-${pad(d)}`;

const Calendar: React.FC<{
  year: number;
  month: number; // 1-12
  start: string | null;
  end: string | null;
  max: string;
  onPick: (day: string) => void;
}> = ({ year, month, start, end, max, onPick }) => {
  const { lang } = useLanguage();
  const cells = useMemo(() => {
    const first = new Date(Date.UTC(year, month - 1, 1));
    const lead = (first.getUTCDay() + 6) % 7; // Monday-first
    const count = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const out: (string | null)[] = Array(lead).fill(null);
    for (let d = 1; d <= count; d++) out.push(ymd(year, month, d));
    while (out.length % 7) out.push(null);
    return out;
  }, [year, month]);
  const lo = start && end ? (start < end ? start : end) : start;
  const hi = start && end ? (start < end ? end : start) : start;
  return (
    <div>
      <div className="mb-1 grid grid-cols-7 text-center text-[10px] font-medium uppercase text-zinc-400">
        {WEEKDAYS[lang].map((w) => <div key={w} className="py-1">{w}</div>)}
      </div>
      <div className="grid grid-cols-7 gap-0.5">
        {cells.map((day, i) => {
          if (!day) return <div key={i} />;
          const disabled = day > max;
          const isEdge = day === lo || day === hi;
          const inRange = lo && hi && day > lo && day < hi;
          const isToday = day === max;
          return (
            <button
              key={day}
              type="button"
              disabled={disabled}
              onClick={() => onPick(day)}
              className={`h-8 rounded-md text-xs tabular-nums transition-colors ${
                disabled
                  ? 'cursor-not-allowed text-zinc-300 dark:text-zinc-700'
                  : isEdge
                    ? 'bg-emerald-600 font-semibold text-white'
                    : inRange
                      ? 'bg-emerald-50 text-emerald-800 dark:bg-emerald-500/15 dark:text-emerald-200'
                      : 'text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-white/[0.06]'
              } ${isToday && !isEdge ? 'ring-1 ring-inset ring-emerald-500/60' : ''} focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500`}
            >
              {Number(day.slice(8))}
            </button>
          );
        })}
      </div>
    </div>
  );
};

export const PeriodPicker: React.FC = () => {
  const { t, lang } = useLanguage();
  const { period, setPeriod, data } = useData();
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState<'day' | 'range'>('day');
  const today = todayTashkent();
  const [view, setView] = useState(() => ({ y: Number(today.slice(0, 4)), m: Number(today.slice(5, 7)) }));
  const [start, setStart] = useState<string | null>(null);
  const [end, setEnd] = useState<string | null>(null);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDoc);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDoc);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const openCalendar = () => {
    const base = period.kind === 'range' ? period.from : data?.period.to ?? today;
    setView({ y: Number(base.slice(0, 4)), m: Number(base.slice(5, 7)) });
    setStart(period.kind === 'range' ? period.from : null);
    setEnd(period.kind === 'range' ? period.to : null);
    setMode(period.kind === 'range' && period.from !== period.to ? 'range' : 'day');
    setOpen(true);
  };

  const pick = (day: string) => {
    if (mode === 'day') {
      setPeriod({ kind: 'range', from: day, to: day });
      setOpen(false);
      return;
    }
    if (!start || end) {
      setStart(day);
      setEnd(null);
    } else {
      setEnd(day);
    }
  };

  const applyRange = () => {
    if (!start) return;
    const e = end ?? start;
    setPeriod({ kind: 'range', from: start < e ? start : e, to: start < e ? e : start });
    setOpen(false);
  };

  const shift = (k: number) => {
    setView((v) => {
      const m = v.m + k;
      return { y: v.y + Math.floor((m - 1) / 12), m: ((m - 1 + 120) % 12) + 1 };
    });
  };
  const atMax = `${view.y}-${pad(view.m)}` >= today.slice(0, 7);

  const customActive = period.kind === 'range';
  const customLabel = customActive ? periodLabel(period.from, period.to, lang) : t.period.calendar;

  return (
    <div className="relative flex min-w-0 items-center gap-2" ref={ref}>
      <div className="flex min-w-0 items-center overflow-x-auto rounded-lg border border-zinc-200 bg-zinc-100 p-0.5 dark:border-white/[0.08] dark:bg-zinc-900/80">
        {PRESETS.map((p) => {
          const active = period.kind === 'preset' && period.preset === p;
          return (
            <button
              key={p}
              type="button"
              onClick={() => setPeriod({ kind: 'preset', preset: p })}
              className={`shrink-0 rounded-md px-2.5 py-1 text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 ${
                active
                  ? 'bg-white text-zinc-900 shadow-sm dark:bg-white/[0.12] dark:text-white'
                  : 'text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100'
              }`}
            >
              {t.period[p]}
            </button>
          );
        })}
      </div>
      <button
        type="button"
        onClick={() => (open ? setOpen(false) : openCalendar())}
        aria-expanded={open}
        className={`flex shrink-0 items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 ${
          customActive
            ? 'border-emerald-500/50 bg-emerald-50 text-emerald-800 dark:bg-emerald-500/10 dark:text-emerald-200'
            : 'border-zinc-200 bg-white text-zinc-700 hover:bg-zinc-50 dark:border-white/[0.08] dark:bg-zinc-900 dark:text-zinc-300 dark:hover:bg-zinc-800'
        }`}
      >
        <CalendarDays className="h-3.5 w-3.5" />
        <span className="max-w-[11rem] truncate">{customLabel}</span>
      </button>

      {open && (
        <div className="absolute right-0 top-full z-50 mt-2 w-[19rem] max-w-[calc(100vw-2rem)] rounded-xl border border-zinc-200 bg-white p-3 shadow-xl dark:border-white/10 dark:bg-zinc-900">
          <div className="mb-3 flex rounded-lg bg-zinc-100 p-0.5 text-xs dark:bg-white/[0.06]">
            {(['day', 'range'] as const).map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => { setMode(m); setStart(null); setEnd(null); }}
                className={`flex-1 rounded-md py-1 font-medium ${
                  mode === m ? 'bg-white text-zinc-900 shadow-sm dark:bg-white/[0.12] dark:text-white' : 'text-zinc-500 dark:text-zinc-400'
                }`}
              >
                {m === 'day' ? t.period.singleDay : t.period.range}
              </button>
            ))}
          </div>
          <div className="mb-2 flex items-center justify-between">
            <button type="button" onClick={() => shift(-1)} className="rounded p-1 text-zinc-500 hover:bg-zinc-100 dark:hover:bg-white/[0.06]" aria-label="prev">
              <ChevronLeft className="h-4 w-4" />
            </button>
            <span className="text-sm font-semibold text-zinc-800 dark:text-zinc-200">
              {MONTHS_LONG[lang][view.m - 1]} {view.y}
            </span>
            <button type="button" disabled={atMax} onClick={() => shift(1)} className="rounded p-1 text-zinc-500 hover:bg-zinc-100 disabled:opacity-30 dark:hover:bg-white/[0.06]" aria-label="next">
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
          <Calendar year={view.y} month={view.m} start={start} end={end} max={today} onPick={pick} />
          <p className="mt-2 text-[11px] text-zinc-500 dark:text-zinc-400">
            {mode === 'day'
              ? t.period.pickDay
              : !start
                ? t.period.pickStart
                : !end
                  ? `${periodLabel(start, start, lang)} → ${t.period.pickEnd}`
                  : periodLabel(start < end ? start : end, start < end ? end : start, lang)}
          </p>
          {mode === 'range' && (
            <div className="mt-3 flex justify-end gap-2">
              <button type="button" onClick={() => setOpen(false)} className="rounded-md px-3 py-1.5 text-xs text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-white/[0.06]">
                {t.period.cancel}
              </button>
              <button type="button" disabled={!start} onClick={applyRange} className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-40">
                {t.period.apply}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
