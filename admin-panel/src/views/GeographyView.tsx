import React from 'react';
import { 
  MapPin, 
  Compass, 
  Plane, 
  Award 
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { useAnalytics } from '../data/useAnalytics';
import { useLanguage } from '../context/LanguageContext';

export const GeographyView: React.FC = () => {
  const { t, lang } = useLanguage();
  const { data } = useAnalytics();
  const totalVisits = data.geographyStats.reduce((s, r) => s + r.postsCount, 0);
  const topTraveler = data.topTravelers[0];

  const regionLabels: Record<string, { en: string; ru: string }> = {
    'UZ-TO': { en: 'Uzbekistan (Tashkent)', ru: 'Узбекистан (Ташкент)' },
    'UZ-SA': { en: 'Uzbekistan (Samarkand)', ru: 'Узбекистан (Самарканд)' },
    'UZ-BU': { en: 'Uzbekistan (Bukhara)', ru: 'Узбекистан (Бухара)' },
    'UZ-VA': { en: 'Uzbekistan (Fergana Valley)', ru: 'Узбекистан (Ферганская долина)' },
    'KZ-ALA': { en: 'Kazakhstan (Almaty)', ru: 'Казахстан (Алматы)' },
    'TR': { en: 'Turkey (Istanbul / Antalya)', ru: 'Турция (Стамбул / Анталья)' },
    'AE-DU': { en: 'UAE (Dubai)', ru: 'ОАЭ (Дубай)' },
    'RU': { en: 'Russia (Moscow / SPB)', ru: 'Россия (Москва / СПб)' },
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.geography.title}</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.geography.subtitle}</p>
        </div>
        <div className="text-[11px] font-mono text-zinc-500 dark:text-zinc-400">
          {t.geography.intlShare} <span className="text-zinc-900 dark:text-white font-medium">24.8%</span>
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.geography.coveredRegions}
          value={data.geographyStats.length}
          subtitle={t.geography.coveredRegionsSub}
          icon={MapPin}
        />
        <StatCard
          title={t.geography.totalVisits}
          value={totalVisits.toLocaleString()}
          subtitle={t.geography.totalVisitsSub}
          icon={Compass}
        />
        <StatCard
          title={t.geography.internationalTravel}
          value={`${data.topTravelers.length}`}
          subtitle={t.geography.topTravelersTitle}
          icon={Plane}
        />
        <StatCard
          title={t.geography.topTraveler}
          value={topTraveler ? `${topTraveler.visitedRegionsCount}` : '0'}
          subtitle={topTraveler ? `@${topTraveler.username}` : t.geography.topTravelerSub}
          icon={Award}
        />
      </div>

      {/* Regions Table & Top Travelers */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Regions table */}
        <div className="lg:col-span-2 p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-3">{t.geography.topRegionsTitle}</h2>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-zinc-200 dark:border-white/[0.06] text-zinc-400 dark:text-zinc-500 font-medium text-[11px]">
                  <th className="py-2.5 px-2">{t.geography.region}</th>
                  <th className="py-2.5 px-2">{t.geography.code}</th>
                  <th className="py-2.5 px-2 font-mono">{t.geography.visits}</th>
                  <th className="py-2.5 px-2 font-mono">{t.geography.posts}</th>
                  <th className="py-2.5 px-2 text-right font-mono">{t.geography.share}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100 dark:divide-white/[0.04]">
                {data.geographyStats.map((item, idx) => {
                  const translatedName = regionLabels[item.code]?.[lang] || item.country;
                  return (
                    <tr key={idx} className="hover:bg-zinc-50/80 dark:hover:bg-white/[0.02] transition-colors">
                      <td className="py-2 px-2 text-zinc-900 dark:text-zinc-200 font-medium text-[11px] flex items-center gap-1.5">
                        <MapPin className="w-2.5 h-2.5 text-zinc-400 dark:text-zinc-500" />
                        {translatedName}
                      </td>
                      <td className="py-2 px-2 font-mono text-zinc-400 dark:text-zinc-500 text-[11px]">{item.code}</td>
                      <td className="py-2 px-2 font-mono text-zinc-800 dark:text-zinc-300 text-[11px]">{item.visitorsCount.toLocaleString()}</td>
                      <td className="py-2 px-2 font-mono text-zinc-600 dark:text-zinc-400 text-[11px]">{item.postsCount.toLocaleString()}</td>
                      <td className="py-2 px-2 text-right font-mono text-zinc-900 dark:text-zinc-200 text-[11px] font-medium">
                        {item.percentage}%
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Top Travelers */}
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none flex flex-col justify-between">
          <div>
            <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-1">{t.geography.topTravelersTitle}</h2>
            <p className="text-[11px] text-zinc-500 mb-3">{t.geography.topTravelersSub}</p>

            <div className="space-y-2">
              {data.topTravelers.map((traveler, idx) => (
                <div key={traveler.username} className="p-2.5 rounded-lg bg-zinc-50 dark:bg-zinc-950/60 border border-zinc-200/70 dark:border-white/[0.04] flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-zinc-400 dark:text-zinc-500 text-[11px]">{idx + 1}</span>
                    <div>
                      <span className="font-mono text-zinc-900 dark:text-zinc-200 font-medium text-[11px] block">@{traveler.username}</span>
                      <span className="text-[10px] text-zinc-500">{traveler.totalPosts} {lang === 'ru' ? 'постов' : 'posts'}</span>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className="font-mono text-zinc-900 dark:text-zinc-200 font-medium text-[11px] block">{traveler.visitedRegionsCount} {lang === 'ru' ? 'регионов' : 'regions'}</span>
                    <span className="text-[10px] text-zinc-400 dark:text-zinc-500 font-mono">{traveler.points} {t.geography.points}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
