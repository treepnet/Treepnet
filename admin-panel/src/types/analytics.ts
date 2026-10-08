export interface KPIOverview {
  totalUsers: number;
  dau: number;
  wau: number;
  mau: number;
  stickiness: number; // DAU / MAU %
  newUsersToday: number;
  totalPosts: number;
  totalStories: number;
  totalComments: number;
  totalLikes: number;
  totalReferrals: number;
  totalConversations: number;
  totalMessages: number;
  changes: {
    users: number;
    dau: number;
    posts: number;
    stories: number;
    engagement: number;
    referrals: number;
  };
}

export interface ActivityPoint {
  date: string;
  dau: number;
  wau: number;
  mau: number;
  signups: number;
}

export interface UserAnalyticsItem {
  id: string;
  username: string;
  hasAvatar: boolean;
  hasBio: boolean;
  isPrivate: boolean;
  referralTier: 'Bronze' | 'Silver' | 'Gold' | 'Platinum';
  birthYear: number;
  lastSeenAt: string;
  signupAt: string;
  status: 'active' | 'inactive' | 'dormant';
  postsCount: number;
  followersCount: number;
}

export interface PostAnalyticsItem {
  id: string;
  userId: string;
  username: string;
  createdAt: string;
  hasLocation: boolean;
  country?: string;
  region?: string;
  placeName?: string;
  likesCount: number;
  commentsCount: number;
  sharesCount: number;
  contentType: 'image' | 'video' | 'text';
}

export interface StoryAnalyticsItem {
  id: string;
  userId: string;
  createdAt: string;
  expiresAt: string;
  contentType: 'photo' | 'video';
  isHighlight: boolean;
  viewsCount: number;
}

export interface ReferralLeaderboardItem {
  userId: string;
  username: string;
  tier: 'Bronze' | 'Silver' | 'Gold' | 'Platinum';
  invitedCount: number;
  activeReferralsCount: number;
  conversionRate: number;
  rewardEarned: string;
}

export interface RegionAnalyticsItem {
  country: string;
  code: string;
  visitorsCount: number;
  postsCount: number;
  percentage: number;
}

export interface PushQueueStatus {
  totalQueued: number;
  sentToday: number;
  failedToday: number;
  successRate: number;
  queueLatencyMs: number;
}

export interface SystemHealthMetrics {
  serverCpuCores: number;
  cpuUsagePct: number;
  totalRamGb: number;
  usedRamGb: number;
  freeRamGb: number;
  metabaseRamMb: number;
  diskFreeGb: number;
  dbConnectionsActive: number;
  dbConnectionsMax: number;
  statementTimeoutSec: number;
  readonlyModeActive: boolean;
  schemaVersion: string;
  uptime: string;
}
