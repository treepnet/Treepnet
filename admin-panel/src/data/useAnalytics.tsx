import React, { createContext, useContext, useCallback, useEffect, useState } from 'react';
import {
  KPIOverview,
  ActivityPoint,
  UserAnalyticsItem,
  PostAnalyticsItem,
  ReferralLeaderboardItem,
  RegionAnalyticsItem,
} from '../types/analytics';

// Shape returned by GET /api/dashboard (see oci-backend/functions/analytics-api).
// Every field is a real aggregate from the analytics_ro views — no PII.
export interface DashboardData {
  generatedAt: string;
  range: string;
  kpiOverview: KPIOverview & { totalFollows: number };
  activityTrends: ActivityPoint[];
  hourlyActivity: { hour: string; active: number }[];
  userSegments: { key: string; count: number; percentage: number; color: string }[];
  profileCompleteness: { key: string; withFeature: number; total: number; pct: number }[];
  birthYearDistribution: { key: string; count: number; pct: number }[];
  contentStats: {
    postsTotal: number;
    postsToday: number;
    creatorsCount: number;
    creatorsPct: number;
    avgPostsPerCreator: number;
    geoTaggedPct: number;
    storiesTotal: number;
    storiesActive: number;
    storiesPhotoPct: number;
    storiesVideoPct: number;
    highlightsCount: number;
    dailyPostTrends: { day: string; iso: string; posts: number; stories: number }[];
  };
  engagementStats: {
    totalLikes: number;
    todayLikes: number;
    totalComments: number;
    todayComments: number;
    replyCommentPct: number;
    bookmarksCount: number;
    avgLikesPerPost: number;
    engagementRatePct: number;
    followsTotal: number;
    followsToday: number;
    zeroFollowerUsersPct: number;
  };
  referralStats: {
    totalReferrals: number;
    referralsToday: number;
    referralUserSharePct: number;
    tiers: { key: string; count: number; pct: number; color: string }[];
    leaderboard: ReferralLeaderboardItem[];
  };
  geographyStats: RegionAnalyticsItem[];
  topTravelers: { username: string; visitedRegionsCount: number; totalPosts: number; points: number }[];
  recentUsers: UserAnalyticsItem[];
  topPosts: PostAnalyticsItem[];
}

export async function fetchDashboard(range: string): Promise<DashboardData> {
  const res = await fetch(`/api/dashboard?range=${encodeURIComponent(range)}`, {
    credentials: 'same-origin',
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

interface AnalyticsContextValue {
  data: DashboardData | null;
  loading: boolean;
  error: string | null;
  range: string;
  setRange: (r: string) => void;
  refresh: () => void;
}

const AnalyticsContext = createContext<AnalyticsContextValue | undefined>(undefined);

export const AnalyticsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [range, setRange] = useState('7d');
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (r: string) => {
    setLoading(true);
    setError(null);
    try {
      const d = await fetchDashboard(r);
      setData(d);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load(range);
  }, [range, load]);

  return (
    <AnalyticsContext.Provider
      value={{ data, loading, error, range, setRange, refresh: () => load(range) }}
    >
      {children}
    </AnalyticsContext.Provider>
  );
};

// Views call this; `data` is guaranteed non-null because the dashboard shell
// only renders the views once the first load has succeeded.
export function useAnalytics(): AnalyticsContextValue & { data: DashboardData } {
  const ctx = useContext(AnalyticsContext);
  if (!ctx) throw new Error('useAnalytics must be used within AnalyticsProvider');
  return ctx as AnalyticsContextValue & { data: DashboardData };
}

// --- formatting helpers -----------------------------------------------------

/** ISO -> "YYYY-MM-DD HH:mm" (local), or "—" when null. */
export function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  const p = (x: number) => String(x).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** ISO -> relative "2m / 3h / 4d ago" in EN/RU, or "—" when null. */
export function fmtRelative(iso: string | null | undefined, lang: string): string {
  if (!iso) return '—';
  const t = new Date(iso).getTime();
  if (isNaN(t)) return '—';
  const sec = Math.max(0, Math.floor((Date.now() - t) / 1000));
  const ru = lang === 'ru';
  if (sec < 60) return ru ? 'только что' : 'just now';
  const min = Math.floor(sec / 60);
  if (min < 60) return ru ? `${min} мин назад` : `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return ru ? `${hr} ч назад` : `${hr}h ago`;
  const day = Math.floor(hr / 24);
  return ru ? `${day} дн назад` : `${day}d ago`;
}
