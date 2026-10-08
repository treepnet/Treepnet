import React from 'react';
import {
  LayoutDashboard,
  UserPlus,
  Activity,
  Image as ImageIcon,
  Heart,
  Gift,
  MapPin,
  TreePine,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';

export type TabType =
  | 'overview'
  | 'growth'
  | 'activity'
  | 'content'
  | 'engagement'
  | 'referral'
  | 'geography';

interface SidebarProps {
  currentTab: TabType;
  onSelectTab: (tab: TabType) => void;
  collapsed: boolean;
  setCollapsed: (val: boolean) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  collapsed,
  setCollapsed,
}) => {
  const { t } = useLanguage();

  const navItems = [
    { id: 'overview' as TabType, label: t.nav.overview, icon: LayoutDashboard },
    { id: 'growth' as TabType, label: t.nav.growth, icon: UserPlus },
    { id: 'activity' as TabType, label: t.nav.activity, icon: Activity },
    { id: 'content' as TabType, label: t.nav.content, icon: ImageIcon },
    { id: 'engagement' as TabType, label: t.nav.engagement, icon: Heart },
    { id: 'referral' as TabType, label: t.nav.referral, icon: Gift },
    { id: 'geography' as TabType, label: t.nav.geography, icon: MapPin },
  ];

  return (
    <aside className={`fixed left-0 top-0 bottom-0 z-40 flex flex-col transition-all duration-200 ${
      collapsed ? 'w-16' : 'w-60'
    } bg-white dark:bg-zinc-950 border-r border-zinc-200/80 dark:border-white/[0.08]`}>
      {/* Brand */}
      <div className="h-14 flex items-center justify-between px-4 border-b border-zinc-200/80 dark:border-white/[0.08]">
        <div 
          onClick={() => onSelectTab('overview')}
          className="flex items-center gap-2.5 cursor-pointer select-none"
        >
          <div className="w-6 h-6 rounded-md bg-zinc-900 text-white dark:bg-white dark:text-zinc-950 flex items-center justify-center font-bold">
            <TreePine className="w-4 h-4 stroke-[2.2]" />
          </div>
          {!collapsed && (
            <div className="flex items-center gap-1.5">
              <span className="font-semibold text-sm text-zinc-900 dark:text-zinc-100 tracking-tight">Treepnet</span>
              <span className="text-[10px] text-zinc-400 dark:text-zinc-500 font-mono">admin</span>
            </div>
          )}
        </div>

        <button
          onClick={() => setCollapsed(!collapsed)}
          className="text-zinc-400 hover:text-zinc-700 dark:text-zinc-500 dark:hover:text-zinc-300 p-1 rounded transition-colors"
          title={collapsed ? 'Expand' : 'Collapse'}
        >
          {collapsed ? <ChevronRight className="w-3.5 h-3.5" /> : <ChevronLeft className="w-3.5 h-3.5" />}
        </button>
      </div>

      {/* Nav items */}
      <nav className="flex-1 py-3 px-2 space-y-0.5 overflow-y-auto">
        {!collapsed && (
          <div className="px-2.5 py-1.5 text-[11px] font-medium text-zinc-400 dark:text-zinc-500 uppercase tracking-wider">
            {t.nav.analytics}
          </div>
        )}

        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onSelectTab(item.id)}
              title={collapsed ? item.label : undefined}
              className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-md text-[13px] transition-colors ${
                isActive
                  ? 'bg-zinc-100 text-zinc-900 dark:bg-white/[0.08] dark:text-white font-medium'
                  : 'text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-200 hover:bg-zinc-50 dark:hover:bg-white/[0.04]'
              }`}
            >
              <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-zinc-900 dark:text-white' : 'text-zinc-400 dark:text-zinc-400'}`} />
              {!collapsed && (
                <span className="truncate">{item.label}</span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Bottom Status */}
      <div className="p-3 border-t border-zinc-200/80 dark:border-white/[0.08]">
        {!collapsed ? (
          <div className="flex items-center justify-between text-xs text-zinc-500 dark:text-zinc-400">
            <div className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
              <span className="text-[11px] text-zinc-600 dark:text-zinc-400">{t.nav.systemActive}</span>
            </div>
            <span className="font-mono text-[11px] text-zinc-400 dark:text-zinc-500">{t.nav.version}</span>
          </div>
        ) : (
          <div className="flex justify-center">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
          </div>
        )}
      </div>
    </aside>
  );
};
