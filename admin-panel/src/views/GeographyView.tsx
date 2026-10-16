import React from 'react';
import { Globe2, MapPin, Users } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useDashboard } from '../context/DataContext';
import { BarRow, Card, Empty, PageHeader, StatCard, Td, Th } from '../components/ui';
import { fmtNum, pct } from '../lib/format';

export const GeographyView: React.FC = () => {
  const { t } = useLanguage();
  const d = useDashboard();
  const g = d.geography;
  const maxRegions = g.topTravelers[0]?.regions ?? 0;

  return (
    <div className="space-y-5">
      <PageHeader title={t.geography.title} subtitle={t.geography.subtitle} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard title={t.geography.countries} value={g.countries.length} icon={Globe2} accent="sky" sub={t.scope.period} />
        <StatCard title={t.content.geoTagged} value={`${d.content.geoTaggedPct}%`} icon={MapPin} sub={t.scope.period} />
        <StatCard title={t.geography.marks} value={g.regionMarks} hint={t.geography.marksHint} accent="emerald" sub={t.scope.period} />
        <StatCard title={t.geography.markUsers} value={g.regionMarkUsers} icon={Users} sub={t.scope.period} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card title={t.geography.countries} scope="period">
          {g.countries.length === 0 ? (
            <Empty />
          ) : (
            <div className="space-y-3">
              {g.countries.map((c) => (
                <BarRow
                  key={c.country}
                  label={c.country}
                  count={c.posts}
                  pct={c.pct}
                  color="bg-sky-500"
                  right={`${fmtNum(c.posts)} ${t.common.posts.toLowerCase()} · ${fmtNum(c.authors)} ${t.geography.colAuthors.toLowerCase()}`}
                />
              ))}
            </div>
          )}
        </Card>
        <Card title={t.geography.regions} scope="period">
          {g.regions.length === 0 ? (
            <Empty />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-zinc-100 dark:border-white/[0.06]">
                    <Th>{t.geography.colRegion}</Th>
                    <Th>{t.geography.colCountry}</Th>
                    <Th right>{t.common.posts}</Th>
                    <Th right>{t.geography.colAuthors}</Th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                  {g.regions.map((r) => (
                    <tr key={`${r.country}-${r.region}`}>
                      <Td className="font-medium text-zinc-800 dark:text-zinc-200">{r.region}</Td>
                      <Td className="text-zinc-500">{r.country}</Td>
                      <Td right>{r.posts}</Td>
                      <Td right>{r.authors}</Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>

      <Card title={t.geography.travelers} scope="allTime">
        {g.topTravelers.length === 0 ? (
          <Empty />
        ) : (
          <div className="grid gap-x-8 gap-y-3 md:grid-cols-2">
            {g.topTravelers.map((x) => (
              <BarRow
                key={x.username}
                label={`@${x.username}`}
                count={x.regions}
                pct={pct(x.regions, maxRegions)}
                color="bg-emerald-500"
                right={`${fmtNum(x.regions)} ${t.geography.colRegions.toLowerCase()} · ${fmtNum(x.posts)} ${t.common.posts.toLowerCase()}`}
              />
            ))}
          </div>
        )}
      </Card>
    </div>
  );
};
