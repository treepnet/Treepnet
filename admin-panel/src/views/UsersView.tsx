import React, { useEffect, useMemo, useState } from 'react';
import { ArrowDown, ArrowUp, Download, Lock, Search } from 'lucide-react';
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useData, useDashboard } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, Td, Th, useChartColors } from '../components/ui';
import { fmtAgo, fmtDate, fmtDay, fmtNum } from '../lib/format';
import type { UserRow } from '../lib/api';

type SortKey = 'username' | 'signupAt' | 'lastSeenAt' | 'posts' | 'stories' | 'followers' | 'following' | 'invited' | 'regions';
const PAGE = 25;

function downloadCsv(name: string, rows: (string | number)[][]) {
  const esc = (v: string | number) => {
    const s = String(v ?? '');
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const blob = new Blob(['﻿' + rows.map((r) => r.map(esc).join(',')).join('\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

const UsersTable: React.FC = () => {
  const { t, lang } = useLanguage();
  const { users, usersLoading, usersError, loadUsers } = useData();
  const [query, setQuery] = useState('');
  const [status, setStatus] = useState<'all' | 'online' | UserRow['status']>('all');
  const [sort, setSort] = useState<{ key: SortKey; dir: 'asc' | 'desc' }>({ key: 'signupAt', dir: 'desc' });
  const [page, setPage] = useState(0);

  useEffect(() => {
    if (!users && !usersLoading) loadUsers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const rows = useMemo(() => {
    const list = (users ?? []).filter((u) => {
      if (query && !u.username.toLowerCase().includes(query.trim().toLowerCase().replace(/^@/, ''))) return false;
      if (status === 'online') return u.online;
      if (status !== 'all' && u.status !== status) return false;
      return true;
    });
    const dir = sort.dir === 'asc' ? 1 : -1;
    list.sort((a, b) => {
      const av = a[sort.key];
      const bv = b[sort.key];
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      return (av < bv ? -1 : av > bv ? 1 : 0) * dir;
    });
    return list;
  }, [users, query, status, sort]);

  useEffect(() => setPage(0), [query, status, sort]);
  const pages = Math.max(1, Math.ceil(rows.length / PAGE));
  const view = rows.slice(page * PAGE, page * PAGE + PAGE);

  const head = (key: SortKey, label: string, right = false) => (
    <Th right={right}>
      <button
        type="button"
        onClick={() => setSort((s) => ({ key, dir: s.key === key && s.dir === 'desc' ? 'asc' : 'desc' }))}
        className={`inline-flex items-center gap-0.5 hover:text-zinc-900 dark:hover:text-zinc-100 ${sort.key === key ? 'text-zinc-900 dark:text-zinc-100' : ''}`}
      >
        {label}
        {sort.key === key && (sort.dir === 'desc' ? <ArrowDown className="h-3 w-3" /> : <ArrowUp className="h-3 w-3" />)}
      </button>
    </Th>
  );

  const statusLabel: Record<UserRow['status'], string> = {
    today: t.users.statusToday, week: t.users.statusWeek, month: t.users.statusMonth, dormant: t.users.statusDormant,
  };
  const statusCls: Record<UserRow['status'], string> = {
    today: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300',
    week: 'bg-sky-50 text-sky-700 dark:bg-sky-500/10 dark:text-sky-300',
    month: 'bg-violet-50 text-violet-700 dark:bg-violet-500/10 dark:text-violet-300',
    dormant: 'bg-zinc-100 text-zinc-500 dark:bg-white/[0.06] dark:text-zinc-400',
  };

  const exportCsv = () =>
    downloadCsv(`treepnet_users_${new Date().toISOString().slice(0, 10)}.csv`, [
      ['username', 'signup_at', 'signup_estimated', 'last_seen_at', 'status', 'online', 'posts', 'stories', 'followers', 'following', 'invited', 'regions', 'private', 'birth_year'],
      ...rows.map((u) => [
        u.username, u.signupAt ?? '', u.signupEstimated ? 'yes' : 'no', u.lastSeenAt ?? '', u.status, u.online ? 'yes' : 'no',
        u.posts, u.stories, u.followers, u.following, u.invited, u.regions, u.isPrivate ? 'yes' : 'no', u.birthYear ?? '',
      ]),
    ]);

  return (
    <Card
      title={t.users.table}
      subtitle={t.users.tableSub}
      scope="now"
      right={
        <button type="button" onClick={exportCsv} disabled={!users} className="inline-flex items-center gap-1 rounded-md border border-zinc-200 px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-40 dark:border-white/[0.08] dark:text-zinc-300 dark:hover:bg-white/[0.04]">
          <Download className="h-3.5 w-3.5" /> {t.common.export}
        </button>
      }
    >
      <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-zinc-400" />
          <input
            id="user-search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.common.search}
            className="w-full rounded-md border border-zinc-200 bg-white py-1.5 pl-8 pr-3 text-xs text-zinc-900 placeholder-zinc-400 focus:border-emerald-500 focus:outline-none dark:border-white/[0.08] dark:bg-zinc-900 dark:text-zinc-100"
          />
        </div>
        <select
          id="user-status"
          value={status}
          onChange={(e) => setStatus(e.target.value as typeof status)}
          className="rounded-md border border-zinc-200 bg-white px-2 py-1.5 text-xs text-zinc-700 dark:border-white/[0.08] dark:bg-zinc-900 dark:text-zinc-300"
        >
          <option value="all">{t.users.allStatuses}</option>
          <option value="online">{t.users.onlineOnly}</option>
          <option value="today">{t.users.segToday}</option>
          <option value="week">{t.users.segWeek}</option>
          <option value="month">{t.users.segMonth}</option>
          <option value="dormant">{t.users.segDormant}</option>
        </select>
        <span className="text-[11px] text-zinc-500 dark:text-zinc-400">
          {fmtNum(rows.length)} {t.users.found}
        </span>
      </div>

      {usersError && !users ? (
        <div className="py-8 text-center text-xs text-rose-600">
          {t.common.loadError} · <button type="button" className="underline" onClick={loadUsers}>{t.common.retry}</button>
        </div>
      ) : !users ? (
        <Empty text={t.common.loading} />
      ) : rows.length === 0 ? (
        <Empty />
      ) : (
        <>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-zinc-100 dark:border-white/[0.06]">
                  {head('username', t.users.colUser)}
                  {head('signupAt', t.users.colSignup)}
                  {head('lastSeenAt', t.users.colLastSeen)}
                  {head('posts', t.users.colPosts, true)}
                  {head('stories', t.users.colStories, true)}
                  {head('followers', t.users.colFollowers, true)}
                  {head('following', t.users.colFollowing, true)}
                  {head('invited', t.users.colInvited, true)}
                  {head('regions', t.users.colRegions, true)}
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                {view.map((u) => (
                  <tr key={u.id} className="hover:bg-zinc-50/70 dark:hover:bg-white/[0.02]">
                    <Td>
                      <span className="inline-flex items-center gap-1.5 font-medium text-zinc-800 dark:text-zinc-200">
                        <span className={`h-1.5 w-1.5 rounded-full ${u.online ? 'bg-emerald-500' : 'bg-transparent'}`} title={u.online ? t.common.online : undefined} />
                        @{u.username}
                        {u.isPrivate && <Lock className="h-3 w-3 text-zinc-400" aria-label={t.users.privateBadge} />}
                      </span>
                    </Td>
                    <Td className="text-zinc-600 dark:text-zinc-400">
                      {u.signupAt ? fmtDate(u.signupAt, lang) : t.users.noSignupDate}
                      {u.signupEstimated && u.signupAt && <span title={t.users.estimatedSignup} className="cursor-help"> *</span>}
                    </Td>
                    <Td>
                      <span className={`mr-1.5 rounded px-1.5 py-0.5 text-[10px] font-medium ${statusCls[u.status]}`}>{statusLabel[u.status]}</span>
                      <span className="text-zinc-500">{fmtAgo(u.lastSeenAt, lang)}</span>
                    </Td>
                    <Td right>{u.posts}</Td>
                    <Td right>{u.stories}</Td>
                    <Td right>{u.followers}</Td>
                    <Td right>{u.following}</Td>
                    <Td right>{u.invited}</Td>
                    <Td right>{u.regions}</Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-3 flex items-center justify-between text-xs text-zinc-500 dark:text-zinc-400">
            <span>* {t.users.estimatedSignup}</span>
            {pages > 1 && (
              <div className="flex items-center gap-2">
                <button type="button" disabled={page === 0} onClick={() => setPage((p) => p - 1)} className="rounded border border-zinc-200 px-2 py-1 disabled:opacity-40 dark:border-white/[0.08]">
                  {t.common.prev}
                </button>
                <span className="tabular-nums">{t.common.page} {page + 1} / {pages}</span>
                <button type="button" disabled={page >= pages - 1} onClick={() => setPage((p) => p + 1)} className="rounded border border-zinc-200 px-2 py-1 disabled:opacity-40 dark:border-white/[0.08]">
                  {t.common.next}
                </button>
              </div>
            )}
          </div>
        </>
      )}
    </Card>
  );
};

export const UsersView: React.FC = () => {
  const { t, lang } = useLanguage();
  const d = useDashboard();
  const c = useChartColors();
  const seg = Object.fromEntries(d.audience.segments.map((s) => [s.key, s]));
  const comp = Object.fromEntries(d.audience.completeness.map((s) => [s.key, s]));
  const segColors: Record<string, string> = { today: 'bg-emerald-500', week: 'bg-sky-500', month: 'bg-violet-500', dormant: 'bg-zinc-400' };
  const segLabels: Record<string, string> = { today: t.users.segToday, week: t.users.segWeek, month: t.users.segMonth, dormant: t.users.segDormant };
  const compLabels: Record<string, string> = { avatar: t.users.avatar, bio: t.users.bio, onboarded: t.users.onboarded, push: t.users.push, private: t.users.private };
  const birthLabels = t.birth as Record<string, string>;
  const signupsSum = d.series.reduce((s, r) => s + r.signups, 0);

  return (
    <div className="space-y-5">
      <PageHeader title={t.users.title} subtitle={t.users.subtitle} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard title={t.kpi.newUsers} value={d.totals.signup.value} metric={d.totals.signup} />
        <StatCard title={t.kpi.totalUsers} value={d.snapshot.totalUsers} sub={t.scope.now} />
        <StatCard title={t.users.push} value={`${comp.push?.pct ?? 0}%`} sub={`${fmtNum(comp.push?.count ?? 0)} / ${fmtNum(d.snapshot.totalUsers)}`} />
        <StatCard title={t.users.private} value={`${comp.private?.pct ?? 0}%`} sub={`${fmtNum(comp.private?.count ?? 0)} / ${fmtNum(d.snapshot.totalUsers)}`} />
      </div>

      <Card title={t.users.signupsChart} scope="period" subtitle={`${t.common.total}: ${fmtNum(signupsSum)}`}>
        {signupsSum === 0 ? (
          <Empty text={t.overview.noSignups} />
        ) : (
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={d.series.map((r) => ({ ...r, label: fmtDay(r.date, lang) }))} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
                <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} minTickGap={18} />
                <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <Tooltip {...c.tooltip} />
                <Bar dataKey="signups" name={t.overview.trendSignups} fill={c.sky} radius={[3, 3, 0, 0]} maxBarSize={22} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card title={t.users.segments} scope="now">
          <div className="space-y-3">
            {['today', 'week', 'month', 'dormant'].map((k) => (
              <BarRow key={k} label={segLabels[k]} count={seg[k]?.count ?? 0} pct={seg[k]?.pct ?? 0} color={segColors[k]} />
            ))}
          </div>
        </Card>
        <Card title={t.users.completeness} scope="now">
          <div className="space-y-3">
            {['avatar', 'bio', 'onboarded', 'push', 'private'].map((k) => (
              <BarRow key={k} label={compLabels[k]} count={comp[k]?.count ?? 0} pct={comp[k]?.pct ?? 0} color="bg-sky-500" />
            ))}
          </div>
        </Card>
        <Card title={t.users.birthYears} scope="now">
          <div className="space-y-3">
            {d.audience.birthYears.map((b) => (
              <BarRow key={b.key} label={birthLabels[b.key] ?? b.key} count={b.count} pct={b.pct} color="bg-violet-500" />
            ))}
          </div>
        </Card>
      </div>

      <UsersTable />
    </div>
  );
};
