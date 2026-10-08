import React, { useState } from 'react';
import { 
  Search, 
  Download, 
  RefreshCw, 
  Sun, 
  Moon, 
  Check 
} from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';

interface NavbarProps {
  sidebarCollapsed: boolean;
  searchQuery: string;
  onSearchChange: (q: string) => void;
  dateRange: string;
  onDateRangeChange: (range: string) => void;
  onExportReport: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  sidebarCollapsed,
  searchQuery,
  onSearchChange,
  dateRange,
  onDateRangeChange,
  onExportReport,
}) => {
  const { lang, setLang, t } = useLanguage();
  const { darkMode, toggleDarkMode } = useTheme();
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [copied, setCopied] = useState(false);

  const handleRefresh = () => {
    setIsRefreshing(true);
    setTimeout(() => setIsRefreshing(false), 500);
  };

  const handleExport = () => {
    onExportReport();
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const dates = [
    { id: 'today', label: t.header.today },
    { id: '7d', label: t.header['7d'] },
    { id: '30d', label: t.header['30d'] },
    { id: '90d', label: t.header['90d'] },
    { id: 'all', label: t.header.all },
  ];

  return (
    <header className={`sticky top-0 z-30 h-14 transition-all duration-200 border-b border-zinc-200/80 dark:border-white/[0.08] bg-white/80 dark:bg-zinc-950/80 backdrop-blur-md flex items-center justify-between px-4 sm:px-6 ${
      sidebarCollapsed ? 'pl-20' : 'pl-64'
    }`}>
      {/* Search Input */}
      <div className="flex items-center gap-2 flex-1 max-w-sm">
        <div className="relative w-full">
          <Search className="w-3.5 h-3.5 text-zinc-400 dark:text-zinc-500 absolute left-2.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder={t.header.searchPlaceholder}
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            className="w-full pl-8 pr-3 py-1 text-xs bg-zinc-50 dark:bg-zinc-900/60 border border-zinc-200 dark:border-white/[0.08] rounded-md text-zinc-900 dark:text-zinc-200 placeholder-zinc-400 dark:placeholder-zinc-500 focus:outline-none focus:border-zinc-400 dark:focus:border-zinc-500 transition-colors"
          />
        </div>
      </div>

      {/* Controls */}
      <div className="flex items-center gap-2">
        {/* Date Filter Pills */}
        <div className="hidden sm:flex items-center bg-zinc-100 dark:bg-zinc-900/80 p-0.5 rounded-md border border-zinc-200 dark:border-white/[0.08] text-xs">
          {dates.map((d) => (
            <button
              key={d.id}
              onClick={() => onDateRangeChange(d.id)}
              className={`px-2 py-0.5 rounded text-[11px] font-medium transition-colors ${
                dateRange === d.id
                  ? 'bg-white text-zinc-900 shadow-xs dark:bg-white/[0.12] dark:text-white'
                  : 'text-zinc-500 dark:text-zinc-400 hover:text-zinc-800 dark:hover:text-zinc-200'
              }`}
            >
              {d.label}
            </button>
          ))}
        </div>

        {/* Language Switcher: EN | RU */}
        <div className="flex items-center bg-zinc-100 dark:bg-zinc-900/80 p-0.5 rounded-md border border-zinc-200 dark:border-white/[0.08] text-xs">
          <button
            onClick={() => setLang('en')}
            className={`px-1.5 py-0.5 rounded text-[11px] font-mono font-medium transition-colors ${
              lang === 'en'
                ? 'bg-white text-zinc-900 shadow-xs dark:bg-white/[0.15] dark:text-white'
                : 'text-zinc-500 hover:text-zinc-800 dark:text-zinc-400 dark:hover:text-zinc-200'
            }`}
          >
            EN
          </button>
          <span className="text-zinc-300 dark:text-zinc-700 text-[10px] px-0.5">/</span>
          <button
            onClick={() => setLang('ru')}
            className={`px-1.5 py-0.5 rounded text-[11px] font-mono font-medium transition-colors ${
              lang === 'ru'
                ? 'bg-white text-zinc-900 shadow-xs dark:bg-white/[0.15] dark:text-white'
                : 'text-zinc-500 hover:text-zinc-800 dark:text-zinc-400 dark:hover:text-zinc-200'
            }`}
          >
            RU
          </button>
        </div>

        {/* Refresh */}
        <button
          onClick={handleRefresh}
          className="p-1.5 text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-white rounded-md transition-colors"
          title="Refresh"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin text-zinc-900 dark:text-white' : ''}`} />
        </button>

        {/* Export */}
        <button
          onClick={handleExport}
          className="flex items-center gap-1 px-2.5 py-1 text-[11px] font-medium bg-white hover:bg-zinc-50 dark:bg-zinc-900 dark:hover:bg-zinc-800 text-zinc-700 dark:text-zinc-300 hover:text-zinc-900 dark:hover:text-white rounded-md border border-zinc-200 dark:border-white/[0.08] shadow-xs transition-colors"
        >
          {copied ? <Check className="w-3 h-3 text-emerald-600 dark:text-emerald-400" /> : <Download className="w-3 h-3" />}
          <span>{copied ? t.header.downloaded : t.header.export}</span>
        </button>

        {/* Theme Toggle */}
        <button
          onClick={toggleDarkMode}
          className="p-1.5 text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-white rounded-md transition-colors"
          title={t.header.theme}
        >
          {darkMode ? <Sun className="w-3.5 h-3.5" /> : <Moon className="w-3.5 h-3.5" />}
        </button>

        {/* User Pill */}
        <div className="ml-1 pl-2 border-l border-zinc-200 dark:border-white/[0.08] flex items-center gap-2">
          <div className="w-6 h-6 rounded-full bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-white/[0.12] flex items-center justify-center text-[10px] font-mono text-zinc-600 dark:text-zinc-300 font-semibold">
            {t.header.role}
          </div>
        </div>
      </div>
    </header>
  );
};
