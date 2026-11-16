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
    /** Inviters with at least one premium month earned, months earned in all, premium running now. */
    premium: { earned: number; months: number; activeNow: number };
    /** Users per badge colour 1-5; `showing`: of them, with premium running (the badge is visible). */
    colourTiers: { tier: number; users: number; showing: number }[];
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
  /** A premium month per 5 invites, all time. */
  premiumMonths: number;
  /** When the running premium ends; null when none is running. */
  premiumUntil: string | null;
  /** Badge colour 1-5 (0: nothing on the map yet). */
  colourTier: number;
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

/** One account with its phone as far as it is known; null: not known yet. */
export interface DeviceUserRow {
  id: string;
  username: string;
  signupAt: string | null;
  lastSeenAt: string | null;
  platform: 'ios' | 'android' | null;
  /** `app`: the app reported it (1.0.9+); `chat`: the chat service's last one (older builds). */
  platformSource: 'app' | 'chat' | null;
  appVersion: string | null;
  build: number | null;
  osVersion: string | null;
  model: string | null;
  deviceFirstSeen: string | null;
  deviceLastSeen: string | null;
  /** Installs this account reported from (1.0.9+). */
  devices: number;
}

export interface UnregisteredDeviceRow {
  id: string;
  platform: 'ios' | 'android';
  appVersion: string;
  build: number;
  osVersion: string | null;
  model: string | null;
  firstSeen: string | null;
  lastSeen: string | null;
}

export interface PlatformCount {
  ios: number;
  android: number;
  total: number;
}

export interface DevicesData {
  generatedAt: string;
  summary: {
    users: number;
    usersIos: number;
    usersAndroid: number;
    usersUnknown: number;
    usersWithVersion: number;
    devices: number;
    devicesIos: number;
    devicesAndroid: number;
    /** Installs someone has signed in on, and those no one has. */
    devicesRegistered: number;
    devicesUnregistered: number;
    active7d: number;
    active30d: number;
    firstReportAt: string | null;
  };
  versions: (PlatformCount & { version: string; build: number })[];
  os: (PlatformCount & { os: string })[];
  models: (PlatformCount & { model: string })[];
  daily: { date: string; ios: number; android: number }[];
  /** Installs no one has signed in on yet (1.0.9+). */
  unregistered: UnregisteredDeviceRow[];
  users: DeviceUserRow[];
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
export const fetchDevices = () => getJson<DevicesData>('/devices');
