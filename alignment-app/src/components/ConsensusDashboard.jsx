import React from 'react';
import { 
  CheckCircle2, 
  AlertCircle, 
  HelpCircle, 
  Sparkles, 
  TrendingUp, 
  Vote, 
  ArrowRight,
  Flame
} from 'lucide-react';

export default function ConsensusDashboard({ state, analysis = {}, onSelectQuestion }) {
  const questions = state?.questions || [];
  const team = state?.team || [];

  const analysisEntries = Object.entries(analysis);
  const consensusList = analysisEntries.filter(([_, a]) => a.isConsensus);
  const tieList = analysisEntries.filter(([_, a]) => a.isTie);
  const openList = analysisEntries.filter(([_, a]) => !a.isConsensus && !a.isTie);

  return (
    <div className="space-y-6">
      {/* Header Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="glass-panel rounded-2xl p-5 border-l-4 border-l-emerald-500">
          <div className="flex items-center justify-between gap-2 mb-1">
            <span className="text-xs font-mono uppercase text-slate-400">Locked In (Consensus)</span>
            <CheckCircle2 className="w-5 h-5 text-emerald-400" />
          </div>
          <div className="text-3xl font-extrabold text-white font-mono">
            {consensusList.length} / {questions.length}
          </div>
          <p className="text-xs text-slate-400 mt-1">
            Squad has reached full majority alignment
          </p>
        </div>

        <div className="glass-panel rounded-2xl p-5 border-l-4 border-l-amber-500">
          <div className="flex items-center justify-between gap-2 mb-1">
            <span className="text-xs font-mono uppercase text-slate-400">Ties & Debate Items</span>
            <AlertCircle className="w-5 h-5 text-amber-400" />
          </div>
          <div className="text-3xl font-extrabold text-amber-400 font-mono">
            {tieList.length}
          </div>
          <p className="text-xs text-slate-400 mt-1">
            Even split between choices needing tie-breaking
          </p>
        </div>

        <div className="glass-panel rounded-2xl p-5 border-l-4 border-l-teal-500">
          <div className="flex items-center justify-between gap-2 mb-1">
            <span className="text-xs font-mono uppercase text-slate-400">Voter Turnout</span>
            <TrendingUp className="w-5 h-5 text-teal-400" />
          </div>
          <div className="text-3xl font-extrabold text-teal-300 font-mono">
            100%
          </div>
          <p className="text-xs text-slate-400 mt-1">
            All active squad members have cast ballots
          </p>
        </div>
      </div>

      {/* Breakdown List */}
      <div className="glass-panel rounded-2xl p-6">
        <div className="flex items-center justify-between gap-4 mb-4">
          <h3 className="text-lg font-bold text-white flex items-center gap-2">
            <span>🗳️ Decision Alignment Matrix</span>
          </h3>
          <span className="text-xs text-slate-400 font-mono">
            Click any row to jump to voting
          </span>
        </div>

        <div className="divide-y divide-slate-800">
          {questions.map((q) => {
            const data = analysis[q.id];
            if (!data) return null;

            const isConsensus = data.isConsensus;
            const isTie = data.isTie;
            const topPick = data.topPick;

            return (
              <div 
                key={q.id}
                onClick={() => onSelectQuestion && onSelectQuestion(q.id)}
                className="py-4 flex flex-col md:flex-row md:items-center justify-between gap-4 hover:bg-slate-850/40 px-3 rounded-xl transition cursor-pointer"
              >
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-[11px] font-mono px-2 py-0.5 rounded bg-slate-800 text-teal-400 border border-slate-700">
                      {q.categoryName}
                    </span>
                    {isConsensus && (
                      <span className="text-[11px] font-mono px-2 py-0.5 rounded bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 flex items-center gap-1">
                        <CheckCircle2 className="w-3 h-3" /> Consensus
                      </span>
                    )}
                    {isTie && (
                      <span className="text-[11px] font-mono px-2 py-0.5 rounded bg-amber-500/15 text-amber-300 border border-amber-500/30 flex items-center gap-1">
                        <AlertCircle className="w-3 h-3" /> Tie / Split
                      </span>
                    )}
                  </div>
                  <h4 className="text-base font-bold text-white">
                    {q.title}
                  </h4>
                  <div className="text-xs text-slate-300 mt-1 flex flex-wrap items-center gap-2">
                    <span className="text-slate-400">Stack Leader:</span>
                    <span className="font-bold text-cyan-300 bg-cyan-500/10 px-2 py-0.5 rounded border border-cyan-500/20">
                      {topPick?.title || 'None'}
                    </span>
                    <span className="text-amber-400 font-mono font-bold">
                      {topPick?.score || 0} pts
                    </span>
                    <span className="text-slate-500 text-[11px]">
                      ({topPick?.rankCounts?.[1] || 0}x #1 ranks)
                    </span>
                  </div>
                </div>

                {/* Voter Visuals */}
                <div className="flex items-center gap-3">
                  <div className="text-right hidden sm:block">
                    <span className="text-xs font-mono text-cyan-400 block font-bold">
                      {data.sortedOptions[0]?.score || 0} pts vs {data.sortedOptions[1]?.score || 0} pts
                    </span>
                  </div>

                  <div className="flex items-center -space-x-1">
                    {team.map((member) => {
                      const userRankCount = q.userRankings?.[member.id]?.length || 0;
                      const hasRanked = userRankCount > 0 || q.options.some(opt => opt.votes?.includes(member.id));
                      return (
                        <div
                          key={member.id}
                          title={`${member.name}: ${hasRanked ? `${userRankCount} options ranked` : 'Not yet ranked'}`}
                          className={`w-7 h-7 rounded-full flex items-center justify-center text-xs border ${
                            hasRanked 
                              ? 'border-cyan-500/80 bg-slate-800 ring-1 ring-cyan-500/40' 
                              : 'border-slate-800 bg-slate-900 opacity-40'
                          }`}
                        >
                          {member.avatar}
                        </div>
                      );
                    })}
                  </div>

                  <ArrowRight className="w-4 h-4 text-slate-500" />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Grounding Strategy Box */}
      <div className="glass-panel rounded-2xl p-6 bg-gradient-to-r from-teal-950/40 via-slate-900 to-indigo-950/40 border border-teal-500/20">
        <div className="flex items-start gap-4">
          <div className="p-3 rounded-xl bg-teal-500/10 text-teal-400 text-2xl border border-teal-500/30">
            🎯
          </div>
          <div>
            <h4 className="text-base font-bold text-white mb-1">
              Grounding Strategy for Team Discovery Channel
            </h4>
            <p className="text-xs text-slate-300 leading-relaxed">
              When there's a tie between a simpler option and a more complex option (e.g. 2-Week Prototype vs 1-Month Foundation), the <strong>simpler option always wins for Milestone 1</strong>. You can always expand to the more complex idea after the Friday night playtest succeeds!
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
