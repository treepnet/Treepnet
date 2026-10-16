import React, { useEffect, useState } from 'react';
import { Sidebar, TabType, TABS } from './components/Sidebar';
import { Topbar } from './components/Topbar';
import { LanguageProvider, useLanguage } from './context/LanguageContext';
import { ThemeProvider } from './context/ThemeContext';
import { DataProvider, useData } from './context/DataContext';
import { OverviewView } from './views/OverviewView';
import { UsersView } from './views/UsersView';
import { ActivityView } from './views/ActivityView';
import { ContentView } from './views/ContentView';
import { EngagementView } from './views/EngagementView';
import { ReferralView } from './views/ReferralView';
import { GeographyView } from './views/GeographyView';

function readTab(): TabType {
  const h = window.location.hash.replace('#', '') as TabType;
  return TABS.some((x) => x.id === h) ? h : 'overview';
}

const Shell: React.FC = () => {
  const { t } = useLanguage();
  const { data, loading, error, refresh } = useData();
  const [tab, setTab] = useState<TabType>(readTab);
  const [collapsed, setCollapsed] = useState(() => {
    try {
      return localStorage.getItem('treepnet_sidebar') === 'collapsed';
    } catch {
      return false;
    }
  });
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const onHash = () => setTab(readTab());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  const select = (next: TabType) => {
    setTab(next);
    if (window.location.hash !== `#${next}`) window.history.replaceState(null, '', `#${next}`);
    window.scrollTo({ top: 0 });
  };

  const toggleCollapsed = () => {
    setCollapsed((c) => {
      try {
        localStorage.setItem('treepnet_sidebar', c ? 'open' : 'collapsed');
      } catch {
        /* ignore */
      }
      return !c;
    });
  };

  const body = () => {
    if (!data) {
      if (error) {
        return (
          <div className="flex flex-col items-center gap-3 py-24 text-center">
            <p className="text-sm text-zinc-700 dark:text-zinc-300">{t.common.loadError}</p>
            <p className="font-mono text-[11px] text-zinc-400">{error}</p>
            <button type="button" onClick={refresh} className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700">
              {t.common.retry}
            </button>
          </div>
        );
      }
      return (
        <div className="flex flex-col items-center gap-3 py-24 text-zinc-400">
          <span className="h-5 w-5 animate-spin rounded-full border-2 border-zinc-300 border-t-transparent dark:border-zinc-600" />
          <span className="text-xs">{t.common.loading}</span>
        </div>
      );
    }
    switch (tab) {
      case 'users': return <UsersView />;
      case 'activity': return <ActivityView />;
      case 'content': return <ContentView />;
      case 'engagement': return <EngagementView />;
      case 'referral': return <ReferralView />;
      case 'geography': return <GeographyView />;
      default: return <OverviewView onNavigate={select} />;
    }
  };

  return (
    <div className="min-h-screen bg-zinc-50 text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100 lg:flex">
      <Sidebar
        current={tab}
        onSelect={select}
        collapsed={collapsed}
        onToggleCollapsed={toggleCollapsed}
        mobileOpen={mobileOpen}
        onCloseMobile={() => setMobileOpen(false)}
      />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar title={t.nav[tab]} onMenu={() => setMobileOpen(true)} />
        <main className="flex-1 px-4 py-5 sm:px-6 lg:px-8 lg:py-7">
          <div className="mx-auto max-w-7xl space-y-5">
            {error && data && (
              <div className="flex items-center justify-between rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-xs text-rose-700 dark:border-rose-500/30 dark:bg-rose-500/10 dark:text-rose-300">
                <span>{t.common.loadError}: {error}</span>
                <button type="button" onClick={refresh} className="font-medium underline">{t.common.retry}</button>
              </div>
            )}
            <div className={loading && data ? 'opacity-60 transition-opacity' : 'transition-opacity'}>{body()}</div>
          </div>
        </main>
      </div>
    </div>
  );
};

export const App: React.FC = () => (
  <ThemeProvider>
    <LanguageProvider>
      <DataProvider>
        <Shell />
      </DataProvider>
    </LanguageProvider>
  </ThemeProvider>
);

export default App;
