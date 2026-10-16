// Types + fetchers for the read-only analytics API (oci-backend/functions/analytics-api).

export type Preset = 'today' | 'yesterday' | '7d' | '30d' | '90d' | 'all';
export type PeriodSel = { kind: 'preset'; preset: Preset } | { kind: 'range'; from: string; to: string };

export interface Metric {
  value: number;
  previous: number;
}

export interface DashboardData {
  generatedAt: string;
  timezone: string;
  period: {
    preset: Preset | 'custom';
    from: string;
    to: string;
    days: number;
    previousFrom: string;
    previousTo: string;
    unit: 'day' | 'week' | 'month';
    today: string;
  };
  snapshot: {
    totalUsers: number;
    onlineNow: number;
    online15m: number;
    trackingSince: string | null;
    dau: number;
    wau: number;
    mau: number;
    stickiness: number;
    totals: {
      posts: number;
      stories: number;
      activeStories: number;
      highlights: number;
      likes: number;
      comments: number;
      follows: number;
      pendingFollows: number;
      referrals: number;
      saves: number;
    };
  };
  totals: {
    signup: Metric;
    post: Metric;
    story: Metric;
    like: Metric;
    comment: Metric;
    follow: Metric;
    save: Metric;
    referral: Metric;
    storyview: Metric;
    highlight: Metric;
    active: Metric;
    creators: number;
    engagers: number;
  };
  series: {
    date: string;
    signups: number;
    posts: number;
    stories: number;
    likes: number;
    comments: number;
    follows: number;
    active: number;
    estimated: boolean;
  }[];
  sessions: null | {
    sessions: number;
    users: number;
    avgMinutes: number;
    medianMinutes: number;
    sessionsPerUserDay: number;
    minutesPerUserDay: number;
  };
  hourly: { hour: number; users: number; events: number }[];
  audience: {
    segments: { key: string; count: number; pct: number }[];
    completeness: { key: string; count: number; pct: number }[];
    birthYears: { key: string; count: number; pct: number }[];
  };
  content: {
    storiesPhoto: number;
    storiesVideo: number;
    geoTaggedPct: number;
    topPosts: { id: string; username: string; createdAt: string; place: string | null; likes: number; comments: number; saves: number }[];
    topCreators: { username: string; posts: number; likes: number }[];
  };
  engagement: {
    replies: number;
    push: { sent: number; failed: number; pending: number; successPct: number };
    topLiked: { username: string; likes: number }[];
  };
  referrals: {
    leaderboardPeriod: ReferralRow[];
    leaderboardAllTime: ReferralRow[];
    inviters: number;
    tiers: Record<'Bronze' | 'Silver' | 'Gold' | 'Platinum', number>;
  };
  geography: {
    countries: { country: string; posts: number; authors: number; pct: number }[];
    regions: { country: string; region: string; posts: number; authors: number }[];
    regionMarks: number;
    regionMarkUsers: number;
    topTravelers: { username: string; regions: number; posts: number }[];
  };
  recentSignups: { username: string; signupAt: string | null; signupEstimated: boolean; lastSeenAt: string | null; online: boolean }[];
}

export interface ReferralRow {
  username: string;
  invited: number;
  active: number;
  activePct: number;
  tier: 'Bronze' | 'Silver' | 'Gold' | 'Platinum';
}

export interface UserRow {
  id: string;
  username: string;
  hasAvatar: boolean;
  hasBio: boolean;
  isPrivate: boolean;
  hasPush: boolean;
  birthYear: number | null;
  signupAt: string | null;
  signupEstimated: boolean;
  lastSeenAt: string | null;
  online: boolean;
  status: 'today' | 'week' | 'month' | 'dormant';
  posts: number;
  stories: number;
  followers: number;
  following: number;
  invited: number;
  regions: number;
}

export interface OnlineData {
  asOf: string;
  onlineNow: number;
  online15m: number;
  online60m: number;
  trackingSince: string | null;
}

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(`/api${path}`, { credentials: 'same-origin', headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<T>;
}

export function periodQuery(p: PeriodSel): string {
  return p.kind === 'preset'
    ? `preset=${p.preset}`
    : `from=${encodeURIComponent(p.from)}&to=${encodeURIComponent(p.to)}`;
}

export const fetchDashboard = (p: PeriodSel) => getJson<DashboardData>(`/dashboard?${periodQuery(p)}`);
export const fetchUsers = () => getJson<{ generatedAt: string; users: UserRow[] }>('/users');
export const fetchOnline = () => getJson<OnlineData>('/online');
