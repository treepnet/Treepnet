import React from 'react';
import {
  Activity, ChevronLeft, ChevronRight, Gift, Heart, Image as ImageIcon, LayoutDashboard, MapPin, TreePine, Users, X,
} from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';

export type TabType = 'overview' | 'users' | 'activity' | 'content' | 'engagement' | 'referral' | 'geography';

export const TABS: { id: TabType; icon: typeof LayoutDashboard }[] = [
  { id: 'overview', icon: LayoutDashboard },
  { id: 'users', icon: Users },
  { id: 'activity', icon: Activity },
  { id: 'content', icon: ImageIcon },
  { id: 'engagement', icon: Heart },
  { id: 'referral', icon: Gift },
  { id: 'geography', icon: MapPin },
];

interface Props {
  current: TabType;
  onSelect: (t: TabType) => void;
  collapsed: boolean;
  onToggleCollapsed: () => void;
  mobileOpen: boolean;
  onCloseMobile: () => void;
}

const NavList: React.FC<{ current: TabType; onSelect: (t: TabType) => void; collapsed: boolean }> = ({ current, onSelect, collapsed }) => {
  const { t } = useLanguage();
  return (
    <nav className="flex-1 space-y-0.5 overflow-y-auto px-2 py-3">
      {!collapsed && (
        <div className="px-2.5 pb-1.5 text-[11px] font-medium uppercase tracking-wider text-zinc-400 dark:text-zinc-500">
          {t.nav.section}
        </div>
      )}
      {TABS.map(({ id, icon: Icon }) => {
        const active = current === id;
        return (
          <button
            key={id}
            type="button"
            onClick={() => onSelect(id)}
            title={collapsed ? t.nav[id] : undefined}
            aria-current={active ? 'page' : undefined}
            className={`flex w-full items-center gap-2.5 rounded-md px-2.5 py-2 text-[13px] transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 ${
              collapsed ? 'justify-center' : ''
            } ${
              active
                ? 'bg-zinc-100 font-medium text-zinc-900 dark:bg-white/[0.08] dark:text-white'
                : 'text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-white/[0.04] dark:hover:text-zinc-200'
            }`}
          >
            <Icon className={`h-4 w-4 shrink-0 ${active ? 'text-emerald-600 dark:text-emerald-400' : 'text-zinc-400'}`} />
            {!collapsed && <span className="truncate">{t.nav[id]}</span>}
          </button>
        );
      })}
    </nav>
  );
};

const Brand: React.FC<{ collapsed?: boolean }> = ({ collapsed }) => (
  <div className="flex items-center gap-2.5">
    <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-emerald-600 text-white">
      <TreePine className="h-4 w-4" />
    </div>
    {!collapsed && (
      <div className="leading-tight">
        <div className="text-sm font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">Treepnet</div>
        <div className="font-mono text-[10px] text-zinc-400 dark:text-zinc-500">admin</div>
      </div>
    )}
  </div>
);

export const Sidebar: React.FC<Props> = ({ current, onSelect, collapsed, onToggleCollapsed, mobileOpen, onCloseMobile }) => {
  const { t } = useLanguage();
  return (
    <>
      {/* Desktop: an in-flow sticky column, so it pushes the content instead of covering it. */}
      <aside
        className={`sticky top-0 hidden h-screen shrink-0 flex-col border-r border-zinc-200/80 bg-white transition-[width] duration-200 dark:border-white/[0.08] dark:bg-zinc-950 lg:flex ${
          collapsed ? 'w-16' : 'w-60'
        }`}
      >
        <div className={`flex h-14 items-center border-b border-zinc-200/80 px-3 dark:border-white/[0.08] ${collapsed ? 'justify-center' : 'justify-between'}`}>
          <Brand collapsed={collapsed} />
          {!collapsed && (
            <button type="button" onClick={onToggleCollapsed} className="rounded p-1 text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200" aria-label="collapse">
              <ChevronLeft className="h-4 w-4" />
            </button>
          )}
        </div>
        <NavList current={current} onSelect={onSelect} collapsed={collapsed} />
        <div className="border-t border-zinc-200/80 p-3 dark:border-white/[0.08]">
          {collapsed ? (
            <button type="button" onClick={onToggleCollapsed} className="mx-auto flex rounded p-1 text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200" aria-label="expand">
              <ChevronRight className="h-4 w-4" />
            </button>
          ) : (
            <div className="flex items-center gap-1.5 text-[11px] text-zinc-500 dark:text-zinc-400">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
              {t.nav.readOnly}
            </div>
          )}
        </div>
      </aside>

      {/* Mobile / tablet: an off-canvas drawer over a dimmed backdrop. */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true">
          <button type="button" className="absolute inset-0 bg-black/40" onClick={onCloseMobile} aria-label="close" />
          <aside className="absolute inset-y-0 left-0 flex w-64 max-w-[80vw] flex-col bg-white shadow-xl dark:bg-zinc-950">
            <div className="flex h-14 items-center justify-between border-b border-zinc-200/80 px-3 dark:border-white/[0.08]">
              <Brand />
              <button type="button" onClick={onCloseMobile} className="rounded p-1 text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200" aria-label="close">
                <X className="h-4 w-4" />
              </button>
            </div>
            <NavList current={current} onSelect={(tab) => { onSelect(tab); onCloseMobile(); }} collapsed={false} />
          </aside>
        </div>
      )}
    </>
  );
};
