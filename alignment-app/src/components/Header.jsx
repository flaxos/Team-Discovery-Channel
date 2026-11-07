import React from 'react';
import { 
  Compass, 
  Users, 
  Vote, 
  Terminal, 
  BarChart3, 
  CheckCircle2, 
  AlertCircle, 
  ExternalLink,
  Plus
} from 'lucide-react';

export default function Header({ 
  activeTab, 
  setActiveTab, 
  activeMemberId, 
  setActiveMemberId, 
  team = [], 
  analysis = {}, 
  onAddMemberClick 
}) {
  const activeMember = team.find(m => m.id === activeMemberId) || team[0];
  
  // Calculate consensus stats
  const totalQuestions = Object.keys(analysis).length;
  const agreedCount = Object.values(analysis).filter(a => a.isConsensus).length;
  const tiesCount = Object.values(analysis).filter(a => a.isTie).length;
  const consensusPercentage = totalQuestions > 0 ? Math.round((agreedCount / totalQuestions) * 100) : 0;

  return (
    <header className="border-b border-slate-800 bg-[#070a13]/90 backdrop-blur-md sticky top-0 z-40">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Top Info Bar */}
        <div className="py-3 flex flex-wrap items-center justify-between gap-4 border-b border-slate-800/60">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-sky-500 via-teal-500 to-indigo-600 flex items-center justify-center text-xl shadow-lg shadow-teal-500/25 border border-teal-400/30">
              🌀
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="font-extrabold text-lg sm:text-xl tracking-tight text-white flex items-center gap-1.5">
                  <span>Project SGC</span>
                  <span className="text-slate-500 font-mono text-sm">•</span>
                  <span className="text-sm sm:text-base text-slate-300 font-semibold">Team Discovery Channel</span>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-cyan-500/10 text-cyan-300 border border-cyan-500/30 font-mono tracking-wide">
                    STARGATE SG-1 / SG-3
                  </span>
                </h1>
              </div>
              <p className="text-xs text-slate-400">
                Militarized Tactical Extraction & Iris Defense • Grounded Alignment Engine
              </p>
            </div>
          </div>

          {/* Active Voter Switcher */}
          <div className="flex items-center gap-2 bg-slate-900/80 p-1.5 rounded-xl border border-slate-800">
            <span className="text-xs font-medium text-slate-400 px-2 flex items-center gap-1">
              <Vote className="w-3.5 h-3.5 text-teal-400" />
              <span>Voting as:</span>
            </span>
            <div className="flex items-center gap-1.5">
              {team.map((member) => {
                const isActive = member.id === activeMemberId;
                return (
                  <button
                    key={member.id}
                    onClick={() => setActiveMemberId(member.id)}
                    className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold transition-all ${
                      isActive 
                        ? 'bg-teal-500 text-slate-950 font-bold shadow-md shadow-teal-500/20' 
                        : 'text-slate-300 hover:bg-slate-800/80 hover:text-white'
                    }`}
                  >
                    <span>{member.avatar}</span>
                    <span>{member.name}</span>
                  </button>
                );
              })}
              <button
                onClick={onAddMemberClick}
                title="Add squad friend"
                className="flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium text-slate-400 hover:text-teal-300 hover:bg-teal-500/10 border border-dashed border-slate-700 transition"
              >
                <Plus className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Friend</span>
              </button>
            </div>
          </div>

          <a 
            href="https://github.com/flaxos/Team-Discovery-Channel" 
            target="_blank" 
            rel="noopener noreferrer"
            className="hidden md:flex items-center gap-1.5 text-xs text-slate-400 hover:text-teal-400 transition font-mono"
          >
            <span>flaxos/Team-Discovery-Channel</span>
            <ExternalLink className="w-3 h-3" />
          </a>
        </div>

        {/* Status Metrics & Navigation Tabs */}
        <div className="py-2.5 flex flex-wrap items-center justify-between gap-4">
          {/* Tabs */}
          <nav className="flex items-center gap-1 sm:gap-2">
            <button
              onClick={() => setActiveTab('poll')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-medium transition ${
                activeTab === 'poll'
                  ? 'bg-teal-500/15 text-teal-300 border border-teal-500/30'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
              }`}
            >
              <Vote className="w-4 h-4" />
              <span>Alignment Polls</span>
            </button>

            <button
              onClick={() => setActiveTab('roster')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-medium transition ${
                activeTab === 'roster'
                  ? 'bg-teal-500/15 text-teal-300 border border-teal-500/30'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
              }`}
            >
              <Users className="w-4 h-4" />
              <span>Squad & Roles ({team.length})</span>
            </button>

            <button
              onClick={() => setActiveTab('consensus')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-medium transition ${
                activeTab === 'consensus'
                  ? 'bg-teal-500/15 text-teal-300 border border-teal-500/30'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
              }`}
            >
              <BarChart3 className="w-4 h-4" />
              <span>Consensus & Heatmap</span>
            </button>

            <button
              onClick={() => setActiveTab('compiler')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-sm font-semibold transition ${
                activeTab === 'compiler'
                  ? 'bg-gradient-to-r from-teal-500 to-emerald-500 text-slate-950 shadow-md shadow-teal-500/25'
                  : 'text-amber-400 hover:bg-amber-400/10 border border-amber-500/30'
              }`}
            >
              <Terminal className="w-4 h-4" />
              <span>Bootstrap Studio & GDD</span>
            </button>
          </nav>

          {/* Quick Metrics Bar */}
          <div className="flex items-center gap-3 text-xs font-mono">
            <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-900 border border-slate-800 text-slate-300">
              <span className="text-slate-400">Consensus:</span>
              <span className={`font-bold ${consensusPercentage >= 70 ? 'text-emerald-400' : 'text-amber-400'}`}>
                {consensusPercentage}%
              </span>
            </div>
            {tiesCount > 0 && (
              <div className="flex items-center gap-1 px-2.5 py-1 rounded-md bg-amber-500/10 border border-amber-500/20 text-amber-300">
                <AlertCircle className="w-3.5 h-3.5" />
                <span>{tiesCount} Tie{tiesCount > 1 ? 's' : ''} to resolve</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
