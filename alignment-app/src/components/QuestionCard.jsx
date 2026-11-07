import React, { useState } from 'react';
import { 
  Check, 
  Plus, 
  MessageSquare, 
  ShieldAlert, 
  Sparkles, 
  Flame, 
  Send, 
  ChevronUp,
  ChevronDown,
  X,
  Award,
  ListOrdered,
  ArrowUp,
  ArrowDown
} from 'lucide-react';

export default function QuestionCard({ 
  question, 
  team = [], 
  activeMemberId, 
  analysis = {}, 
  onRank, 
  onOpenAddOption, 
  onAddComment 
}) {
  const [showComments, setShowComments] = useState(false);
  const [commentInput, setCommentInput] = useState('');

  const qAnalysis = analysis[question.id] || {};
  const userStack = question.userRankings?.[activeMemberId] || [];

  // Find max score among options for progress bar calculation
  const maxScore = Math.max(...(qAnalysis.sortedOptions || []).map(o => o.score || 0), 1);

  const handleCommentSubmit = (e) => {
    e.preventDefault();
    if (!commentInput.trim()) return;
    onAddComment(question.id, commentInput.trim());
    setCommentInput('');
  };

  const getFeasibilityBadge = (level) => {
    switch (level) {
      case 'Very High':
      case 'Maximum':
        return 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';
      case 'High':
      case 'Essential':
        return 'bg-teal-500/10 text-teal-300 border-teal-500/20';
      case 'Medium':
      case 'High Impact':
        return 'bg-sky-500/10 text-sky-400 border-sky-500/20';
      default:
        return 'bg-amber-500/10 text-amber-400 border-amber-500/20';
    }
  };

  const getRankBadgeStyle = (rank) => {
    switch (rank) {
      case 1:
        return 'bg-amber-500/20 text-amber-300 border-amber-500/50 shadow-sm shadow-amber-500/20';
      case 2:
        return 'bg-slate-300/20 text-slate-200 border-slate-400/50';
      case 3:
        return 'bg-orange-500/20 text-orange-300 border-orange-500/40';
      default:
        return 'bg-teal-500/15 text-teal-300 border-teal-500/30';
    }
  };

  const getRankLabel = (rank) => {
    switch (rank) {
      case 1: return '🥇 #1 Preference (3 pts)';
      case 2: return '🥈 #2 Preference (2 pts)';
      case 3: return '🥉 #3 Preference (1 pt)';
      default: return `#${rank} Preference (1 pt)`;
    }
  };

  return (
    <div className="glass-panel rounded-2xl p-5 sm:p-6 mb-6 transition-all duration-200 border-slate-800">
      {/* Question Header */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
        <div className="flex items-center gap-2">
          <span className="text-xs uppercase tracking-wider font-bold px-2.5 py-0.5 rounded-full bg-slate-800 border border-slate-700 text-cyan-400 font-mono">
            {question.categoryName}
          </span>
          <span className="text-xs px-2.5 py-0.5 rounded-full bg-cyan-500/10 text-cyan-300 border border-cyan-500/25 font-mono flex items-center gap-1 font-semibold">
            <ListOrdered className="w-3 h-3" />
            <span>Stack-Ranked Preferences</span>
          </span>
        </div>

        <button
          onClick={() => onOpenAddOption(question)}
          className="flex items-center gap-1.5 text-xs font-semibold px-3 py-1 rounded-lg bg-teal-500/10 hover:bg-teal-500/20 text-teal-300 border border-teal-500/30 transition shadow-sm"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Propose Custom Idea (Other)</span>
        </button>
      </div>

      <h3 className="text-lg sm:text-xl font-bold text-white mb-1.5">
        {question.title}
      </h3>
      <p className="text-sm text-slate-300 mb-4 leading-relaxed">
        {question.subtitle}
      </p>

      {/* Active Voter's Preference Stack Bar */}
      <div className="mb-5 p-3 rounded-xl bg-slate-950/70 border border-slate-800/90 text-xs">
        <div className="flex flex-wrap items-center justify-between gap-2 mb-1.5">
          <span className="font-mono text-slate-400 flex items-center gap-1.5 font-bold">
            <Award className="w-3.5 h-3.5 text-amber-400" />
            <span>Your Preference Stack ({userStack.length} ranked):</span>
          </span>
          <span className="text-[11px] text-slate-500 font-mono">
            1st = 3 pts • 2nd = 2 pts • 3rd = 1 pt
          </span>
        </div>

        {userStack.length > 0 ? (
          <div className="flex flex-wrap items-center gap-2">
            {userStack.map((optId, idx) => {
              const opt = question.options.find(o => o.id === optId);
              if (!opt) return null;
              const rank = idx + 1;
              return (
                <div 
                  key={optId} 
                  className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg border font-medium ${getRankBadgeStyle(rank)}`}
                >
                  <span className="font-bold">{rank === 1 ? '🥇' : rank === 2 ? '🥈' : '🥉'} #{rank}</span>
                  <span className="truncate max-w-[140px] sm:max-w-[200px] text-white">{opt.title}</span>
                  <button
                    onClick={() => onRank(question.id, optId, 'remove')}
                    title="Remove from stack"
                    className="hover:text-rose-400 transition ml-1"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              );
            })}
          </div>
        ) : (
          <p className="text-slate-400 italic">
            No options ranked yet. Click <strong>"Rank #1"</strong> or <strong>"+ Add to Stack"</strong> on the choices below to build your preferential stack!
          </p>
        )}
      </div>

      {/* Options Grid */}
      <div className="space-y-3.5">
        {question.options.map((opt) => {
          const userRank = userStack.indexOf(opt.id) + 1; // 0 if unranked
          const isRankedByUser = userRank > 0;

          // Find stats from analysis
          const optStats = qAnalysis.sortedOptions?.find(o => o.id === opt.id);
          const score = optStats?.score || 0;
          const voterRanks = optStats?.voterRanks || [];
          const isLeader = qAnalysis.topPick?.id === opt.id && score > 0;
          const scorePercent = maxScore > 0 ? Math.round((score / (Math.max(team.length, 1) * 3)) * 100) : 0;

          return (
            <div
              key={opt.id}
              className={`relative rounded-xl p-4 sm:p-5 border transition-all duration-150 ${
                isRankedByUser
                  ? 'bg-slate-900/90 border-cyan-500/60 shadow-lg shadow-cyan-500/10 ring-1 ring-cyan-500/30'
                  : 'bg-slate-900/40 border-slate-800/80 hover:border-slate-700 hover:bg-slate-850/60'
              }`}
            >
              {/* Top row of Option */}
              <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-3 mb-2">
                <div className="flex-1">
                  <div className="flex flex-wrap items-center gap-2 mb-1">
                    <span className="font-bold text-base text-white">
                      {opt.title}
                    </span>
                    {isLeader && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/40 font-bold flex items-center gap-1">
                        <span>👑 Squad #1 Leader</span>
                      </span>
                    )}
                    {opt.isCustom && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-purple-500/15 text-purple-300 border border-purple-500/30 font-medium">
                        💡 Community Idea
                      </span>
                    )}
                    {opt.feasibility && (
                      <span className={`text-[11px] font-mono px-2 py-0.5 rounded border ${getFeasibilityBadge(opt.feasibility)}`}>
                        Feasibility: {opt.feasibility}
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-slate-300 leading-relaxed">
                    {opt.description}
                  </p>
                </div>

                {/* Stack Ranking Action Controls */}
                <div className="flex items-center gap-1.5 flex-shrink-0 self-start sm:self-auto">
                  {isRankedByUser ? (
                    <div className="flex items-center gap-1.5 bg-slate-950/80 p-1 rounded-xl border border-cyan-500/40">
                      <span className={`text-xs px-2.5 py-1 rounded-lg font-bold border ${getRankBadgeStyle(userRank)}`}>
                        {getRankLabel(userRank)}
                      </span>

                      {/* Move Up/Down Controls */}
                      <button
                        type="button"
                        onClick={() => onRank(question.id, opt.id, 'move_up')}
                        disabled={userRank <= 1}
                        title="Bump up in your preference stack"
                        className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 disabled:opacity-30 transition"
                      >
                        <ArrowUp className="w-3.5 h-3.5" />
                      </button>

                      <button
                        type="button"
                        onClick={() => onRank(question.id, opt.id, 'move_down')}
                        disabled={userRank >= userStack.length}
                        title="Bump down in your preference stack"
                        className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 disabled:opacity-30 transition"
                      >
                        <ArrowDown className="w-3.5 h-3.5" />
                      </button>

                      <button
                        type="button"
                        onClick={() => onRank(question.id, opt.id, 'remove')}
                        title="Remove from your stack"
                        className="p-1 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition"
                      >
                        <X className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ) : (
                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() => onRank(question.id, opt.id, 'set_rank', 1)}
                        className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-bold bg-amber-500/15 hover:bg-amber-500/25 text-amber-300 border border-amber-500/30 transition shadow-sm"
                      >
                        <span>🥇 Rank #1</span>
                      </button>

                      <button
                        type="button"
                        onClick={() => onRank(question.id, opt.id, 'add')}
                        className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-bold bg-slate-800 text-slate-300 hover:bg-cyan-500/20 hover:text-cyan-300 border border-slate-700 transition"
                      >
                        <Plus className="w-3 h-3" />
                        <span>Add to Stack</span>
                      </button>
                    </div>
                  )}
                </div>
              </div>

              {/* Pros & Caution details */}
              {(opt.pros?.length > 0 || opt.caution) && (
                <div className="mt-3 pt-2.5 border-t border-slate-800/60 flex flex-wrap items-center gap-y-1.5 gap-x-4 text-xs text-slate-400">
                  {opt.pros && opt.pros.length > 0 && (
                    <div className="flex items-center gap-1 text-emerald-400">
                      <Sparkles className="w-3.5 h-3.5 flex-shrink-0" />
                      <span>{opt.pros.join(' • ')}</span>
                    </div>
                  )}
                  {opt.caution && (
                    <div className="flex items-center gap-1 text-amber-400/90">
                      <ShieldAlert className="w-3.5 h-3.5 flex-shrink-0" />
                      <span>{opt.caution}</span>
                    </div>
                  )}
                </div>
              )}

              {/* Squad Preferential Score Bar & Voter Rank Badges */}
              <div className="mt-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 pt-2 border-t border-slate-800/40">
                <div className="flex-1">
                  <div className="flex items-center justify-between text-xs font-mono text-slate-400 mb-1">
                    <span className="flex items-center gap-1 font-bold text-slate-200">
                      <span>Squad Score:</span>
                      <span className="text-cyan-400 font-bold">{score} pts</span>
                    </span>
                    <span className="text-[11px] text-slate-500">
                      {voterRanks.length} {voterRanks.length === 1 ? 'squad member ranked' : 'squad members ranked'}
                    </span>
                  </div>
                  <div className="h-1.5 w-full bg-slate-800 rounded-full overflow-hidden">
                    <div
                      className={`h-full transition-all duration-300 ${
                        isLeader 
                          ? 'bg-gradient-to-r from-amber-400 via-cyan-400 to-teal-300' 
                          : isRankedByUser 
                            ? 'bg-gradient-to-r from-cyan-500 to-teal-400' 
                            : 'bg-slate-600'
                      }`}
                      style={{ width: `${Math.min(scorePercent, 100)}%` }}
                    />
                  </div>
                </div>

                {/* Squad Members who ranked this */}
                <div className="flex items-center gap-1.5 flex-wrap">
                  {voterRanks.map((vr) => (
                    <div
                      key={vr.memberId}
                      title={`${vr.memberName} ranked this #${vr.rank} (${vr.points} pts)`}
                      className="flex items-center gap-1 px-2 py-0.5 rounded-md bg-slate-800/80 border border-slate-700/80 text-[11px] font-mono shadow-sm"
                    >
                      <span>{vr.memberAvatar}</span>
                      <span style={{ color: vr.memberColor }}>{vr.memberName}</span>
                      <span className="font-bold text-amber-400">#{vr.rank}</span>
                    </div>
                  ))}
                  {voterRanks.length === 0 && (
                    <span className="text-[11px] font-mono text-slate-600 italic">Unranked</span>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Discussion / Comments Toggle */}
      <div className="mt-5 pt-3 border-t border-slate-800/70">
        <button
          onClick={() => setShowComments(!showComments)}
          className="flex items-center gap-2 text-xs font-medium text-slate-400 hover:text-slate-200 transition"
        >
          <MessageSquare className="w-3.5 h-3.5" />
          <span>
            Crew Banter & Discussion ({question.comments?.length || 0})
          </span>
          {showComments ? (
            <ChevronUp className="w-3.5 h-3.5 ml-1" />
          ) : (
            <ChevronDown className="w-3.5 h-3.5 ml-1" />
          )}
        </button>

        {showComments && (
          <div className="mt-3 space-y-2.5">
            {question.comments && question.comments.length > 0 ? (
              question.comments.map((comment) => {
                const author = team.find(t => t.id === comment.memberId);
                return (
                  <div key={comment.id} className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 text-xs">
                    <div className="flex items-center justify-between gap-2 mb-1">
                      <div className="flex items-center gap-1.5 font-bold text-slate-200">
                        <span>{author?.avatar || '👾'}</span>
                        <span style={{ color: author?.color || '#2dd4bf' }}>{author?.name || comment.memberId}</span>
                      </div>
                      <span className="text-[10px] text-slate-500 font-mono">
                        {new Date(comment.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>
                    <p className="text-slate-300 leading-normal pl-5">
                      {comment.text}
                    </p>
                  </div>
                );
              })
            ) : (
              <p className="text-xs text-slate-500 italic py-1">No notes yet. Share a thought or trade-off.</p>
            )}

            {/* Quick Comment Input */}
            <form onSubmit={handleCommentSubmit} className="flex gap-2 pt-1">
              <input
                type="text"
                value={commentInput}
                onChange={(e) => setCommentInput(e.target.value)}
                placeholder="Add your take or trade-off note..."
                className="flex-1 bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-1.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-teal-500"
              />
              <button
                type="submit"
                disabled={!commentInput.trim()}
                className="px-3 py-1.5 bg-cyan-500 hover:bg-cyan-400 disabled:opacity-40 text-slate-950 font-bold rounded-lg text-xs flex items-center gap-1 transition"
              >
                <Send className="w-3 h-3" />
                <span>Post</span>
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}
