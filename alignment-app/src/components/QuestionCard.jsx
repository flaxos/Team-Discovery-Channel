import React, { useState } from 'react';
import { 
  Check, 
  Plus, 
  MessageSquare, 
  ShieldAlert, 
  Sparkles, 
  Flame, 
  Send, 
  UserCheck,
  ChevronDown,
  ChevronUp
} from 'lucide-react';

export default function QuestionCard({ 
  question, 
  team = [], 
  activeMemberId, 
  onVote, 
  onOpenAddOption, 
  onAddComment 
}) {
  const [showComments, setShowComments] = useState(false);
  const [commentInput, setCommentInput] = useState('');

  const totalVotesInQuestion = question.options.reduce((acc, opt) => acc + (opt.votes?.length || 0), 0);

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

  return (
    <div className="glass-panel rounded-2xl p-5 sm:p-6 mb-6 transition-all duration-200">
      {/* Question Header */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
        <div className="flex items-center gap-2">
          <span className="text-xs uppercase tracking-wider font-bold px-2.5 py-0.5 rounded-full bg-slate-800 border border-slate-700 text-teal-400 font-mono">
            {question.categoryName}
          </span>
          <span className="text-xs text-slate-400 font-mono">
            {question.allowMultiple ? 'Multi-select' : 'Single Choice'}
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
      <p className="text-sm text-slate-300 mb-5 leading-relaxed">
        {question.subtitle}
      </p>

      {/* Options Grid */}
      <div className="space-y-3.5">
        {question.options.map((opt) => {
          const votes = opt.votes || [];
          const hasVoted = votes.includes(activeMemberId);
          const votePercentage = totalVotesInQuestion > 0 
            ? Math.round((votes.length / Math.max(team.length, 1)) * 100) 
            : 0;

          return (
            <div
              key={opt.id}
              onClick={() => onVote(question.id, opt.id)}
              className={`relative rounded-xl p-4 sm:p-5 border cursor-pointer transition-all duration-150 ${
                hasVoted
                  ? 'bg-slate-900/90 border-teal-500/60 shadow-lg shadow-teal-500/10 ring-1 ring-teal-500/40'
                  : 'bg-slate-900/40 border-slate-800/80 hover:border-slate-700 hover:bg-slate-850/60'
              }`}
            >
              {/* Top row of Option */}
              <div className="flex items-start justify-between gap-3 mb-2">
                <div className="flex-1">
                  <div className="flex flex-wrap items-center gap-2 mb-1">
                    <span className="font-bold text-base text-white">
                      {opt.title}
                    </span>
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

                {/* Vote Action Button */}
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onVote(question.id, opt.id);
                  }}
                  className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold transition flex-shrink-0 ${
                    hasVoted
                      ? 'bg-teal-500 text-slate-950 shadow-md shadow-teal-500/20'
                      : 'bg-slate-800 text-slate-300 hover:bg-teal-500/20 hover:text-teal-300 border border-slate-700'
                  }`}
                >
                  {hasVoted ? (
                    <>
                      <Check className="w-3.5 h-3.5 stroke-[3]" />
                      <span>Voted</span>
                    </>
                  ) : (
                    <span>Vote</span>
                  )}
                </button>
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

              {/* Vote Bar & Voter Badges */}
              <div className="mt-3.5 flex items-center justify-between gap-3">
                <div className="flex-1">
                  <div className="h-1.5 w-full bg-slate-800 rounded-full overflow-hidden">
                    <div
                      className={`h-full transition-all duration-300 ${
                        hasVoted ? 'bg-gradient-to-r from-teal-500 to-emerald-400' : 'bg-slate-600'
                      }`}
                      style={{ width: `${Math.min(votePercentage, 100)}%` }}
                    />
                  </div>
                </div>

                <div className="flex items-center gap-2 flex-shrink-0">
                  <span className="text-xs font-mono text-slate-400">
                    {votes.length} {votes.length === 1 ? 'vote' : 'votes'}
                  </span>
                  
                  {/* Avatars */}
                  <div className="flex items-center -space-x-1.5">
                    {votes.map((voterId) => {
                      const member = team.find(t => t.id === voterId);
                      return (
                        <div
                          key={voterId}
                          title={member ? `${member.name} voted for this` : voterId}
                          className="w-6 h-6 rounded-full flex items-center justify-center text-xs border border-slate-900 bg-slate-800 shadow-sm"
                          style={{ borderColor: member?.color || '#14b8a6' }}
                        >
                          {member?.avatar || '👤'}
                        </div>
                      );
                    })}
                  </div>
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
                className="px-3 py-1.5 bg-teal-500 hover:bg-teal-400 disabled:opacity-40 text-slate-950 font-bold rounded-lg text-xs flex items-center gap-1 transition"
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
