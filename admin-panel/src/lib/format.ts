import type { Language } from '../i18n/translations';

export const TZ = 'Asia/Tashkent';

const MONTHS: Record<Language, string[]> = {
  uz: ['yan', 'fev', 'mar', 'apr', 'may', 'iyun', 'iyul', 'avg', 'sen', 'okt', 'noy', 'dek'],
  ru: ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'],
  en: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
};

export const MONTHS_LONG: Record<Language, string[]> = {
  uz: ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun', 'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'],
  ru: ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
  en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
};

export const WEEKDAYS: Record<Language, string[]> = {
  uz: ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'],
  ru: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  en: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
};

const numberFmt = new Intl.NumberFormat('ru-RU');
export const fmtNum = (v: number) => numberFmt.format(v);

/** "YYYY-MM-DD" -> "16 okt" (+ year when asked). */
export function fmtDay(ymd: string, lang: Language, withYear = false): string {
  const [y, m, d] = ymd.split('-').map(Number);
  if (!y || !m || !d) return ymd;
  return `${d} ${MONTHS[lang][m - 1]}${withYear ? ` ${y}` : ''}`;
}

function tzParts(iso: string) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TZ, year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(new Date(iso));
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  return { y: get('year'), m: get('month'), d: get('day'), hh: get('hour'), mm: get('minute') };
}

/** ISO instant -> "16 okt 2026, 14:05" in Tashkent time. */
export function fmtDateTime(iso: string | null | undefined, lang: Language): string {
  if (!iso || isNaN(new Date(iso).getTime())) return '—';
  const p = tzParts(iso);
  const pad = (x: number) => String(x).padStart(2, '0');
  return `${p.d} ${MONTHS[lang][p.m - 1]} ${p.y}, ${pad(p.hh)}:${pad(p.mm)}`;
}

/** ISO instant -> "16 okt 2026" in Tashkent time. */
export function fmtDate(iso: string | null | undefined, lang: Language): string {
  if (!iso || isNaN(new Date(iso).getTime())) return '—';
  const p = tzParts(iso);
  return `${p.d} ${MONTHS[lang][p.m - 1]} ${p.y}`;
}

/** ISO instant -> "3 daq oldin" / "5 soat oldin" / "4 kun oldin". */
export function fmtAgo(iso: string | null | undefined, lang: Language): string {
  if (!iso) return '—';
  const t = new Date(iso).getTime();
  if (isNaN(t)) return '—';
  const sec = Math.max(0, Math.floor((Date.now() - t) / 1000));
  const min = Math.floor(sec / 60);
  const hr = Math.floor(min / 60);
  const day = Math.floor(hr / 24);
  const L = {
    uz: { now: 'hozirgina', m: 'daq oldin', h: 'soat oldin', d: 'kun oldin' },
    ru: { now: 'только что', m: 'мин назад', h: 'ч назад', d: 'дн. назад' },
    en: { now: 'just now', m: 'min ago', h: 'h ago', d: 'd ago' },
  }[lang];
  if (min < 1) return L.now;
  if (min < 60) return `${min} ${L.m}`;
  if (hr < 24) return `${hr} ${L.h}`;
  return `${day} ${L.d}`;
}

/** Change vs previous: { pct, label } — label is "+25%", "−10%", "new" or "—". */
export function delta(value: number, previous: number): { dir: 'up' | 'down' | 'flat'; label: string; isNew: boolean } {
  if (previous === 0 && value === 0) return { dir: 'flat', label: '—', isNew: false };
  if (previous === 0) return { dir: 'up', label: '', isNew: true };
  const p = Math.round(((value - previous) / previous) * 1000) / 10;
  if (p === 0) return { dir: 'flat', label: '0%', isNew: false };
  return { dir: p > 0 ? 'up' : 'down', label: `${p > 0 ? '+' : '−'}${Math.abs(p)}%`, isNew: false };
}

export const pct = (a: number, b: number) => (b > 0 ? Math.round((a / b) * 1000) / 10 : 0);

/** Today's date in Tashkent as "YYYY-MM-DD". */
export function todayTashkent(): string {
  const p = tzParts(new Date().toISOString());
  const pad = (x: number) => String(x).padStart(2, '0');
  return `${p.y}-${pad(p.m)}-${pad(p.d)}`;
}

/** Human label for a resolved period. */
export function periodLabel(from: string, to: string, lang: Language): string {
  if (from === to) return fmtDay(from, lang, true);
  const sameYear = from.slice(0, 4) === to.slice(0, 4);
  return `${fmtDay(from, lang, !sameYear)} – ${fmtDay(to, lang, true)}`;
}
