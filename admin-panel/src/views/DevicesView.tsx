import React, { useEffect, useMemo, useState } from 'react';
import { ArrowDown, ArrowUp, Download, Search, Smartphone } from 'lucide-react';
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useLanguage } from '../context/LanguageContext';
import { useData } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, Td, Th, useChartColors } from '../components/ui';
import { fmtAgo, fmtDate, fmtDay, fmtNum } from '../lib/format';
import type { DeviceUserRow, DevicesData, PlatformCount } from '../lib/api';

/** A table row: an account, or an install with no account on it (username null). */
interface Row extends Omit<DeviceUserRow, 'id' | 'username' | 'lastSeenAt' | 'deviceFirstSeen'> {
  key: string;
  username: string | null;
}

const rowsOf = (d: DevicesData): Row[] => [
  ...d.users.map(({ id, username, lastSeenAt: _l, deviceFirstSeen: _f, ...rest }) => ({ ...rest, key: id, username })),
  ...d.unregistered.map((x) => ({
    key: x.id,
    username: null,
    signupAt: null,
    platform: x.platform,
    platformSource: 'app' as const,
    appVersion: x.appVersion,
    build: x.build,
    osVersion: x.osVersion,
    model: x.model,
    deviceLastSeen: x.lastSeen,
    devices: 0,
  })),
];

// Every account with its phone as far as it is known, and every install no
// one has signed up on, in one table (analytics-api /devices). What isn't
// known yet stays an empty cell: from 1.0.9 the app reports its phone,
// version and OS; for older builds only the platform is known (from the chat
// service).

type SortKey = 'username' | 'platform' | 'build' | 'osVersion' | 'model' | 'devices' | 'deviceLastSeen' | 'signupAt';
const PAGE = 25;

const pct = (a: number, b: number) => (b > 0 ? Math.round((a / b) * 1000) / 10 : 0);
const osLabel = (u: Pick<Row, 'platform' | 'osVersion'>) =>
  u.osVersion ? `${u.platform === 'ios' ? 'iOS' : 'Android'} ${u.osVersion}` : '';
const versionLabel = (v: string | null, b: number | null) => (v ? `${v}${b != null ? ` (${b})` : ''}` : '');

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

const PlatformPill: React.FC<{ platform: Row['platform']; fromChat: boolean }> = ({ platform, fromChat }) => {
  const { t } = useLanguage();
  if (!platform) return null;
  const cls =
    platform === 'ios'
      ? 'bg-sky-50 text-sky-700 dark:bg-sky-500/10 dark:text-sky-300'
      : 'bg-emerald-50 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300';
  return (
    <span className={`rounded px-1.5 py-0.5 text-[10px] font-medium ${cls}`} title={fromChat ? t.devices.fromChat : undefined}>
      {platform === 'ios' ? t.devices.ios : t.devices.android}
      {fromChat && ' *'}
    </span>
  );
};

/** A list of counts split iPhone · Android, as bars of the largest share. */
const SplitList: React.FC<{ rows: (PlatformCount & { label: string })[]; total: number }> = ({ rows, total }) => {
  if (rows.length === 0) return <Empty />;
  return (
    <div className="space-y-3">
      {rows.map((r) => (
        <BarRow
          key={r.label}
          label={r.label}
          count={r.total}
          pct={pct(r.total, total)}
          color="bg-sky-500"
          right={`${fmtNum(r.total)} · ${fmtNum(r.ios)} / ${fmtNum(r.android)}`}
        />
      ))}
    </div>
  );
};

const DevicesTable: React.FC<{ data: DevicesData }> = ({ data }) => {
  const { t, lang } = useLanguage();
  const [query, setQuery] = useState('');
  const [platform, setPlatform] = useState<'all' | 'ios' | 'android' | 'unknown'>('all');
  const [version, setVersion] = useState<'all' | 'known' | 'unknown'>('all');
  const [account, setAccount] = useState<'all' | 'registered' | 'unregistered'>('all');
  const all = useMemo(() => rowsOf(data), [data]);
  const [sort, setSort] = useState<{ key: SortKey; dir: 'asc' | 'desc' }>({ key: 'signupAt', dir: 'desc' });
  const [page, setPage] = useState(0);

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase().replace(/^@/, '');
    const list = all.filter((u) => {
      if (q && !(u.username ?? '').toLowerCase().includes(q) && !(u.model ?? '').toLowerCase().includes(q)) return false;
      if (account === 'registered' && u.username == null) return false;
      if (account === 'unregistered' && u.username != null) return false;
      if (platform === 'unknown' ? u.platform != null : platform !== 'all' && u.platform !== platform) return false;
      if (version === 'known' && !u.appVersion) return false;
      if (version === 'unknown' && u.appVersion) return false;
      return true;
    });
    const dir = sort.dir === 'asc' ? 1 : -1;
    list.sort((a, b) => {
      const av = sort.key === 'devices' ? a.devices || null : a[sort.key];
      const bv = sort.key === 'devices' ? b.devices || null : b[sort.key];
      if (av == null && bv == null) return 0;
      if (av == null) return 1; // unknowns last, either way
      if (bv == null) return -1;
      return (av < bv ? -1 : av > bv ? 1 : 0) * dir;
    });
    return list;
  }, [all, query, platform, version, account, sort]);

  useEffect(() => setPage(0), [query, platform, version, account, sort]);
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

  const exportCsv = () =>
    downloadCsv(`treepnet_devices_${new Date().toISOString().slice(0, 10)}.csv`, [
      ['username', 'signed_up', 'platform', 'platform_source', 'app_version', 'build', 'os', 'model', 'devices', 'device_last_seen', 'signup_at'],
      ...rows.map((u) => [
        u.username ?? '', u.username != null ? 'yes' : 'no', u.platform ?? '', u.platformSource ?? '', u.appVersion ?? '', u.build ?? '', osLabel(u), u.model ?? '',
        u.devices || '', u.deviceLastSeen ?? '', u.signupAt ?? '',
      ]),
    ]);

  const select = 'rounded-md border border-zinc-200 bg-white px-2 py-1.5 text-xs text-zinc-700 dark:border-white/[0.08] dark:bg-zinc-900 dark:text-zinc-300';

  return (
    <Card
      title={t.devices.table}
      subtitle={t.devices.tableSub}
      scope="now"
      right={
        <button type="button" onClick={exportCsv} className="inline-flex items-center gap-1 rounded-md border border-zinc-200 px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 dark:border-white/[0.08] dark:text-zinc-300 dark:hover:bg-white/[0.04]">
          <Download className="h-3.5 w-3.5" /> {t.common.export}
        </button>
      }
    >
      <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-zinc-400" />
          <input
            id="device-search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.common.search}
            className="w-full rounded-md border border-zinc-200 bg-white py-1.5 pl-8 pr-3 text-xs text-zinc-900 placeholder-zinc-400 focus:border-emerald-500 focus:outline-none dark:border-white/[0.08] dark:bg-zinc-900 dark:text-zinc-100"
          />
        </div>
        <select id="device-account" value={account} onChange={(e) => setAccount(e.target.value as typeof account)} className={select}>
          <option value="all">{t.devices.allAccounts}</option>
          <option value="registered">{t.devices.onlyRegistered}</option>
          <option value="unregistered">{t.devices.onlyUnregistered}</option>
        </select>
        <select id="device-platform" value={platform} onChange={(e) => setPlatform(e.target.value as typeof platform)} className={select}>
          <option value="all">{t.devices.allPlatforms}</option>
          <option value="ios">{t.devices.ios}</option>
          <option value="android">{t.devices.android}</option>
          <option value="unknown">{t.devices.unknown}</option>
        </select>
        <select id="device-version" value={version} onChange={(e) => setVersion(e.target.value as typeof version)} className={select}>
          <option value="all">{t.devices.allVersions}</option>
          <option value="known">{t.devices.withVersion}</option>
          <option value="unknown">{t.devices.withoutVersion}</option>
        </select>
        <span className="text-[11px] text-zinc-500 dark:text-zinc-400">
          {fmtNum(rows.length)} {t.users.found}
        </span>
      </div>

      {rows.length === 0 ? (
        <Empty />
      ) : (
        <>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-zinc-100 dark:border-white/[0.06]">
                  {head('username', t.devices.colUser)}
                  {head('platform', t.devices.colPlatform)}
                  {head('build', t.devices.colVersion)}
                  {head('osVersion', t.devices.colOs)}
                  {head('model', t.devices.colModel)}
                  {head('devices', t.devices.colDevices, true)}
                  {head('deviceLastSeen', t.devices.colDeviceSeen)}
                  {head('signupAt', t.devices.colSignup)}
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                {view.map((u) => (
                  <tr key={u.key} className="hover:bg-zinc-50/70 dark:hover:bg-white/[0.02]">
                    <Td className="font-medium text-zinc-800 dark:text-zinc-200">
                      {u.username != null ? (
                        `@${u.username}`
                      ) : (
                        <span className="rounded bg-amber-50 px-1.5 py-0.5 text-[10px] font-medium text-amber-700 dark:bg-amber-500/10 dark:text-amber-300">
                          {t.devices.unregistered}
                        </span>
                      )}
                    </Td>
                    <Td><PlatformPill platform={u.platform} fromChat={u.platformSource === 'chat'} /></Td>
                    <Td className="font-mono tabular-nums text-zinc-700 dark:text-zinc-300">{versionLabel(u.appVersion, u.build)}</Td>
                    <Td className="text-zinc-600 dark:text-zinc-400">{osLabel(u)}</Td>
                    <Td className="text-zinc-600 dark:text-zinc-400">{u.model ?? ''}</Td>
                    <Td right>{u.devices || ''}</Td>
                    <Td className="text-zinc-500">{u.deviceLastSeen ? fmtAgo(u.deviceLastSeen, lang) : ''}</Td>
                    <Td className="text-zinc-600 dark:text-zinc-400">{u.signupAt ? fmtDate(u.signupAt, lang) : ''}</Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-3 flex items-center justify-between gap-3 text-xs text-zinc-500 dark:text-zinc-400">
            <span>* {t.devices.fromChat}</span>
            {pages > 1 && (
              <div className="flex shrink-0 items-center gap-2">
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

export const DevicesView: React.FC = () => {
  const { t, lang } = useLanguage();
  const { devices: data, devicesLoading, devicesError, loadDevices } = useData();
  const c = useChartColors();

  useEffect(() => {
    if (!data && !devicesLoading) loadDevices();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!data) {
    return (
      <div className="space-y-5">
        <PageHeader title={t.devices.title} subtitle={t.devices.subtitle} />
        {devicesError ? (
          <div className="py-8 text-center text-xs text-rose-600">
            {t.common.loadError} · <button type="button" className="underline" onClick={loadDevices}>{t.common.retry}</button>
          </div>
        ) : (
          <Empty text={t.common.loading} />
        )}
      </div>
    );
  }

  const s = data.summary;
  const reportedNone = s.devices === 0;
  // Users on a build older than 1.0.9, split by the platform known for them.
  const noVersion = data.users.filter((u) => !u.appVersion);
  const versions = [
    ...data.versions.map((v) => ({ ...v, label: versionLabel(v.version, v.build) })),
    ...(noVersion.length > 0
      ? [{
          label: t.devices.versionUnknown,
          ios: noVersion.filter((u) => u.platform === 'ios').length,
          android: noVersion.filter((u) => u.platform === 'android').length,
          total: noVersion.length,
        }]
      : []),
  ];
  const versionsTotal = versions.reduce((a, v) => a + v.total, 0);

  return (
    <div className="space-y-5">
      <PageHeader title={t.devices.title} subtitle={t.devices.subtitle} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard title={t.devices.usersTotal} value={s.users} sub={t.scope.now} icon={Smartphone} />
        <StatCard title={t.devices.ios} value={s.usersIos} sub={`${pct(s.usersIos, s.users)}%`} accent="sky" />
        <StatCard title={t.devices.android} value={s.usersAndroid} sub={`${pct(s.usersAndroid, s.users)}%`} accent="emerald" />
        <StatCard
          title={t.devices.versionKnown}
          value={s.usersWithVersion}
          sub={`${pct(s.usersWithVersion, s.users)}% · ${fmtNum(s.usersWithVersion)} / ${fmtNum(s.users)}`}
          hint={t.devices.versionKnownHint}
        />
      </div>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard
          title={t.devices.reported}
          value={s.devices}
          sub={`${t.devices.ios} ${fmtNum(s.devicesIos)} · ${t.devices.android} ${fmtNum(s.devicesAndroid)}`}
          hint={t.devices.reportedHint}
        />
        <StatCard
          title={t.devices.unregistered}
          value={s.devicesUnregistered}
          sub={`${t.devices.registeredShare}: ${fmtNum(s.devicesRegistered)} (${pct(s.devicesRegistered, s.devices)}%)`}
          hint={t.devices.unregisteredHint}
          accent="amber"
        />
        <StatCard title={t.devices.active7} value={s.active7d} hint={t.devices.activeHint} />
        <StatCard title={t.devices.active30} value={s.active30d} hint={t.devices.activeHint} />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card title={t.devices.platformTitle} subtitle={t.devices.platformSub} scope="now">
          <div className="space-y-3">
            <BarRow label={t.devices.ios} count={s.usersIos} pct={pct(s.usersIos, s.users)} color="bg-sky-500" />
            <BarRow label={t.devices.android} count={s.usersAndroid} pct={pct(s.usersAndroid, s.users)} color="bg-emerald-500" />
            {s.usersUnknown > 0 && (
              <BarRow label={t.devices.unknown} count={s.usersUnknown} pct={pct(s.usersUnknown, s.users)} color="bg-zinc-400" />
            )}
          </div>
        </Card>
        <Card title={t.devices.versionsTitle} subtitle={t.devices.versionsSub} scope="now">
          <SplitList rows={versions} total={versionsTotal} />
        </Card>
        <Card title={t.devices.osTitle} subtitle={t.devices.versionsSub} scope="now">
          {reportedNone ? <Empty text={t.devices.noReports} /> : <SplitList rows={data.os.map((o) => ({ ...o, label: o.os }))} total={s.devices} />}
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card
          title={t.devices.dailyTitle}
          subtitle={`${t.devices.since}: ${s.firstReportAt ? fmtDate(s.firstReportAt, lang) : t.devices.notYet}`}
          scope="now"
          className="lg:col-span-2"
        >
          {reportedNone ? (
            <Empty text={t.devices.noReports} />
          ) : (
            <div className="h-56">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.daily.map((r) => ({ ...r, label: fmtDay(r.date, lang) }))} margin={{ top: 5, right: 8, left: -18, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={c.grid} vertical={false} />
                  <XAxis dataKey="label" stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} minTickGap={18} />
                  <YAxis stroke={c.axis} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} allowDecimals={false} />
                  <Tooltip {...c.tooltip} />
                  <Legend wrapperStyle={{ fontSize: 11 }} />
                  <Bar dataKey="ios" name={t.devices.ios} stackId="d" fill={c.sky} maxBarSize={22} />
                  <Bar dataKey="android" name={t.devices.android} stackId="d" fill={c.emerald} radius={[3, 3, 0, 0]} maxBarSize={22} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
        <Card title={t.devices.modelsTitle} scope="now">
          {reportedNone ? (
            <Empty text={t.devices.noReports} />
          ) : (
            <SplitList rows={data.models.map((m) => ({ ...m, label: m.model }))} total={s.devices} />
          )}
        </Card>
      </div>

      <DevicesTable data={data} />
    </div>
  );
};
