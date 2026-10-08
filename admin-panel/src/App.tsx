import React, { useState } from 'react';
import { Sidebar, TabType } from './components/Sidebar';
import { Navbar } from './components/Navbar';
import { ReadOnlyNotice } from './components/ReadOnlyNotice';
import { OverviewView } from './views/OverviewView';
import { GrowthView } from './views/GrowthView';
import { ActivityView } from './views/ActivityView';
import { ContentView } from './views/ContentView';
import { EngagementView } from './views/EngagementView';
import { ReferralView } from './views/ReferralView';
import { GeographyView } from './views/GeographyView';
import { LanguageProvider, useLanguage } from './context/LanguageContext';
import { ThemeProvider } from './context/ThemeContext';
import { AnalyticsProvider, useAnalytics } from './data/useAnalytics';

const DashboardContent: React.FC = () => {
  const { t, lang } = useLanguage();
  const { data, loading, error, range, setRange, refresh } = useAnalytics();
  const [currentTab, setCurrentTab] = useState<TabType>('overview');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const handleExportReport = () => {
    if (!data) return;
    const kpi = data.kpiOverview;
    const headers = lang === 'ru'
      ? ['Метрика', 'Значение'].join(',')
      : ['Metric', 'Value'].join(',');

    const csvContent = [
      headers,
      [lang === 'ru' ? 'Всего пользователей' : 'Total Users', kpi.totalUsers].join(','),
      [lang === 'ru' ? 'DAU (День)' : 'DAU', kpi.dau].join(','),
      [lang === 'ru' ? 'WAU (Неделя)' : 'WAU', kpi.wau].join(','),
      [lang === 'ru' ? 'MAU (Месяц)' : 'MAU', kpi.mau].join(','),
      [lang === 'ru' ? 'Stickiness (DAU/MAU)' : 'Stickiness', `${kpi.stickiness}%`].join(','),
      [lang === 'ru' ? 'Регистраций сегодня' : 'Signups Today', kpi.newUsersToday].join(','),
      [lang === 'ru' ? 'Всего постов' : 'Total Posts', kpi.totalPosts].join(','),
      [lang === 'ru' ? 'Всего историй' : 'Total Stories', kpi.totalStories].join(','),
      [lang === 'ru' ? 'Всего комментариев' : 'Total Comments', kpi.totalComments].join(','),
      [lang === 'ru' ? 'Всего лайков' : 'Total Likes', kpi.totalLikes].join(','),
      [lang === 'ru' ? 'Всего рефералов' : 'Total Referrals', kpi.totalReferrals].join(','),
    ].join('\n');

    const blob = new Blob(['﻿' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `treepnet_analytics_${lang}_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const renderActiveView = () => {
    // First load (or a reload with no cached data) — show a spinner / error
    // instead of the views, which assume data is present.
    if (!data) {
      if (error) {
        return (
          <div className="py-24 flex flex-col items-center gap-3 text-center">
            <p className="text-sm text-zinc-700 dark:text-zinc-300">{t.state.loadError}</p>
            <p className="text-[11px] font-mono text-zinc-400 dark:text-zinc-500">{error}</p>
            <button
              onClick={refresh}
              className="mt-1 px-3 py-1.5 text-xs rounded-md bg-zinc-900 text-white dark:bg-white dark:text-zinc-900 font-medium"
            >
              {t.state.retry}
            </button>
          </div>
        );
      }
      return (
        <div className="py-24 flex flex-col items-center gap-3 text-zinc-400 dark:text-zinc-500">
          <span className="w-5 h-5 rounded-full border-2 border-zinc-300 dark:border-zinc-600 border-t-transparent animate-spin" />
          <span className="text-xs">{t.state.loading}</span>
        </div>
      );
    }

    switch (currentTab) {
      case 'overview':
        return <OverviewView onNavigateTab={(tab) => setCurrentTab(tab)} />;
      case 'growth':
        return <GrowthView />;
      case 'activity':
        return <ActivityView />;
      case 'content':
        return <ContentView />;
      case 'engagement':
        return <EngagementView />;
      case 'referral':
        return <ReferralView />;
      case 'geography':
        return <GeographyView />;
      default:
        return <OverviewView onNavigateTab={(tab) => setCurrentTab(tab)} />;
    }
  };

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 flex flex-col font-sans selection:bg-zinc-200 dark:selection:bg-zinc-800 selection:text-zinc-900 dark:selection:text-white transition-colors duration-150">
      <Sidebar
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        collapsed={sidebarCollapsed}
        setCollapsed={setSidebarCollapsed}
      />

      <Navbar
        sidebarCollapsed={sidebarCollapsed}
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        dateRange={range}
        onDateRangeChange={setRange}
        onExportReport={handleExportReport}
      />

      <main className={`flex-1 transition-all duration-200 p-4 sm:p-6 lg:p-8 ${
        sidebarCollapsed ? 'pl-20' : 'pl-64'
      }`}>
        <div className="max-w-6xl mx-auto space-y-6">
          <ReadOnlyNotice />
          {loading && data && (
            <div className="text-[11px] font-mono text-zinc-400 dark:text-zinc-500">{t.state.refreshing}</div>
          )}
          {renderActiveView()}
        </div>
      </main>

      <footer className={`py-4 px-6 border-t border-zinc-200/80 dark:border-white/[0.06] transition-all duration-200 text-[11px] text-zinc-400 dark:text-zinc-500 flex flex-col sm:flex-row items-center justify-between gap-2 ${
        sidebarCollapsed ? 'pl-20' : 'pl-64'
      }`}>
        <div className="flex items-center gap-2">
          <span className="font-medium text-zinc-700 dark:text-zinc-400">{t.footer.adminTitle}</span>
          <span className="text-zinc-300 dark:text-zinc-700">•</span>
          <span>admin.treepnet.com</span>
        </div>
        <div className="font-mono text-zinc-400 dark:text-zinc-600">
          {t.footer.pgTitle}
        </div>
      </footer>
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <ThemeProvider>
      <LanguageProvider>
        <AnalyticsProvider>
          <DashboardContent />
        </AnalyticsProvider>
      </LanguageProvider>
    </ThemeProvider>
  );
};

export default App;
