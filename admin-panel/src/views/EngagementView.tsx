import React from 'react';
import { 
  Heart, 
  MessageSquare, 
  Bookmark, 
  UserCheck
} from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { useAnalytics } from '../data/useAnalytics';
import { useLanguage } from '../context/LanguageContext';

export const EngagementView: React.FC = () => {
  const { t } = useLanguage();
  const { data } = useAnalytics();
  const e = data.engagementStats;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
        <div>
          <h1 className="text-xl font-semibold text-zinc-900 dark:text-white tracking-tight">{t.engagement.title}</h1>
          <p className="text-xs text-zinc-500 dark:text-zinc-400 mt-0.5">{t.engagement.subtitle}</p>
        </div>
        <div className="text-[11px] font-mono text-zinc-500 dark:text-zinc-400">
          {t.engagement.rateLabel} <span className="text-zinc-900 dark:text-white font-medium">{e.engagementRatePct}%</span>
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <StatCard
          title={t.engagement.likesToday}
          value={e.todayLikes}
          subtitle={`Total: ${(e.totalLikes / 1000000).toFixed(2)}M`}
          icon={Heart}
        />
        <StatCard
          title={t.engagement.commentsToday}
          value={e.todayComments}
          subtitle={`Total: ${(e.totalComments / 1000).toFixed(1)}k`}
          icon={MessageSquare}
        />
        <StatCard
          title={t.engagement.followsToday}
          value={e.followsToday}
          subtitle={`Total: ${(e.followsTotal / 1000).toFixed(1)}k`}
          icon={UserCheck}
        />
        <StatCard
          title={t.engagement.bookmarks}
          value={e.bookmarksCount}
          subtitle={t.engagement.bookmarksSub}
          icon={Bookmark}
        />
      </div>

      {/* Ratios */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between text-xs mb-1">
            <span className="text-zinc-500 dark:text-zinc-400 text-[11px]">{t.engagement.replyRatioTitle}</span>
            <span className="font-mono text-zinc-900 dark:text-zinc-200 text-xs font-medium">{e.replyCommentPct}%</span>
          </div>
          <div className="text-lg font-semibold text-zinc-900 dark:text-white tracking-tight">{t.engagement.replyRatioHeading}</div>
          <p className="text-[11px] text-zinc-500 mt-1">{t.engagement.replyRatioDesc}</p>
          <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1 rounded-full mt-3 overflow-hidden">
            <div className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full" style={{ width: `${e.replyCommentPct}%` }} />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between text-xs mb-1">
            <span className="text-zinc-500 dark:text-zinc-400 text-[11px]">{t.engagement.zeroFollowerTitle}</span>
            <span className="font-mono text-zinc-900 dark:text-zinc-200 text-xs font-medium">{e.zeroFollowerUsersPct}%</span>
          </div>
          <div className="text-lg font-semibold text-zinc-900 dark:text-white tracking-tight">{t.engagement.zeroFollowerHeading}</div>
          <p className="text-[11px] text-zinc-500 mt-1">{t.engagement.zeroFollowerDesc}</p>
          <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1 rounded-full mt-3 overflow-hidden">
            <div className="bg-zinc-800 dark:bg-zinc-300 h-full rounded-full" style={{ width: `${e.zeroFollowerUsersPct}%` }} />
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
          <div className="flex items-center justify-between text-xs mb-1">
            <span className="text-zinc-500 dark:text-zinc-400 text-[11px]">{t.engagement.pendingRequestsTitle}</span>
            <span className="font-mono text-zinc-900 dark:text-zinc-200 text-xs font-medium">3,240</span>
          </div>
          <div className="text-lg font-semibold text-zinc-900 dark:text-white tracking-tight">{t.engagement.pendingRequestsHeading}</div>
          <p className="text-[11px] text-zinc-500 mt-1">{t.engagement.pendingRequestsDesc}</p>
          <div className="w-full bg-zinc-100 dark:bg-zinc-800 h-1 rounded-full mt-3 overflow-hidden">
            <div className="bg-emerald-500 h-full rounded-full" style={{ width: '42%' }} />
          </div>
        </div>
      </div>

      {/* Top Followed */}
      <div className="p-4 rounded-xl bg-white dark:bg-zinc-900/50 border border-zinc-200/80 dark:border-white/[0.07] shadow-xs dark:shadow-none">
        <h2 className="text-xs font-medium text-zinc-800 dark:text-zinc-300 mb-3">{t.engagement.topFollowedTitle}</h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          {data.recentUsers.slice(0, 4).map((user) => (
            <div key={user.id} className="p-3 rounded-lg bg-zinc-50 dark:bg-zinc-950/60 border border-zinc-200/70 dark:border-white/[0.05] flex items-center justify-between">
              <div>
                <span className="font-mono text-zinc-900 dark:text-zinc-300 font-medium text-xs block">@{user.username}</span>
                <span className="text-[11px] text-zinc-500">{user.postsCount} {t.engagement.postsCount}</span>
              </div>
              <div className="text-right">
                <span className="font-mono text-xs text-zinc-900 dark:text-white font-medium block">{user.followersCount.toLocaleString()}</span>
                <span className="text-[10px] text-zinc-400 dark:text-zinc-500">{t.engagement.followers}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
