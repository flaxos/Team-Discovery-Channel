import React, { useState, useEffect } from 'react';
import Header from './components/Header';
import QuestionCard from './components/QuestionCard';
import SquadRoster from './components/SquadRoster';
import ConsensusDashboard from './components/ConsensusDashboard';
import PromptGDDStudio from './components/PromptGDDStudio';
import AddOptionModal from './components/AddOptionModal';
import MemberModal from './components/MemberModal';
import { 
  Filter, 
  RotateCcw, 
  Sparkles, 
  ShieldCheck, 
  CheckCircle,
  Clock,
  Compass,
  ArrowRight,
  Vote
} from 'lucide-react';

const CATEGORIES = [
  { id: 'all', name: 'All Directives' },
  { id: 'perspective', name: 'Camera & Scope' },
  { id: 'core_loop', name: 'Stealth-to-Loud Loop' },
  { id: 'missions', name: 'Mission Modes' },
  { id: 'classes', name: 'Squad Classes' },
  { id: 'mechanics', name: 'Signature Mechanics' },
  { id: 'engine', name: 'Engine & Pipeline' },
  { id: 'art', name: 'Visual Direction' },
  { id: 'grounding', name: 'Grounding & Sprints' },
  { id: 'roles', name: 'Division of Labor' }
];

export default function App() {
  const [activeTab, setActiveTab] = useState('poll'); // 'poll', 'roster', 'consensus', 'compiler'
  const [activeCategory, setActiveCategory] = useState('all');
  const [state, setState] = useState(null);
  const [analysis, setAnalysis] = useState({});
  const [compiled, setCompiled] = useState({});
  const [activeMemberId, setActiveMemberId] = useState('flaxos');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Modals state
  const [addOptionTargetQuestion, setAddOptionTargetQuestion] = useState(null);
  const [memberModalTarget, setMemberModalTarget] = useState(null); // null = closed, 'new' = add, member = edit
  const [exportStatus, setExportStatus] = useState(null);

  // Fetch state on mount
  const fetchState = async () => {
    try {
      setIsLoading(true);
      const res = await fetch('/api/state');
      if (!res.ok) throw new Error('Failed to load state');
      const data = await res.json();
      setState(data.state);
      setAnalysis(data.analysis || {});
      
      // Auto fetch compiled documents
      fetchCompiled();
    } catch (err) {
      console.error(err);
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchCompiled = async () => {
    try {
      const res = await fetch('/api/compile', { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setCompiled(data.compiled);
        if (data.analysis) setAnalysis(data.analysis);
      }
    } catch (err) {
      console.error('Compile error:', err);
    }
  };

  useEffect(() => {
    fetchState();
  }, []);

  // Handle preferential stack ranking
  const handleRank = async (questionId, optionId, action, targetRank) => {
    try {
      const res = await fetch('/api/rank', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          questionId,
          optionId,
          action,
          targetRank,
          memberId: activeMemberId
        })
      });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Rank error:', err);
    }
  };

  // Handle vote toggle (fallback)
  const handleVote = async (questionId, optionId) => {
    handleRank(questionId, optionId, 'toggle');
  };

  // Handle proposing custom option ("Other")
  const handleAddOption = async (optionData) => {
    try {
      const res = await fetch('/api/option', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(optionData)
      });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Add option error:', err);
    }
  };

  // Handle saving team member (create or update)
  const handleSaveMember = async (memberData) => {
    try {
      const res = await fetch('/api/member', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(memberData)
      });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        if (data.member?.id) {
          setActiveMemberId(data.member.id);
        }
        fetchCompiled();
      }
    } catch (err) {
      console.error('Save member error:', err);
    }
  };

  // Handle deleting team member
  const handleDeleteMember = async (memberId) => {
    try {
      const res = await fetch('/api/member/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: memberId })
      });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        // If the active voter was deleted, switch to the first remaining member
        if (activeMemberId === memberId && data.state.team?.length > 0) {
          setActiveMemberId(data.state.team[0].id);
        }
        fetchCompiled();
      }
    } catch (err) {
      console.error('Delete member error:', err);
    }
  };

  // Handle toggling steward role for a member directly
  const handleToggleStewardRole = async (memberId, roleKey) => {
    try {
      const res = await fetch('/api/member/toggle-role', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ memberId, roleName: roleKey })
      });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Toggle steward role error:', err);
    }
  };

  // Handle adding comment
  const handleAddComment = async (questionId, text) => {
    try {
      const res = await fetch('/api/comment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ questionId, memberId: activeMemberId, text })
      });
      if (res.ok) {
        const data = await res.json();
        setState((prev) => {
          const updatedQuestions = prev.questions.map((q) => 
            q.id === questionId ? data.question : q
          );
          return { ...prev, questions: updatedQuestions };
        });
      }
    } catch (err) {
      console.error('Add comment error:', err);
    }
  };

  // Handle exporting to repository root
  const handleExportToRepo = async (options = {}) => {
    try {
      setExportStatus({ success: true, message: 'Exporting files to repository...' });
      const res = await fetch('/api/export-to-repo', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(options)
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setExportStatus({
          success: true,
          message: data.message,
          gitPushed: data.gitPushed,
          gitCommitted: data.gitCommitted
        });
      } else {
        setExportStatus({
          success: false,
          message: data.error || 'Export failed'
        });
      }
    } catch (err) {
      setExportStatus({
        success: false,
        message: err.message
      });
    }
  };

  // Handle resetting ONLY votes to zero
  const handleResetVotes = async () => {
    if (!window.confirm('Reset all cast votes to 0? Your questions, custom options, and stewards will remain intact.')) return;
    try {
      const res = await fetch('/api/reset-votes', { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Reset votes error:', err);
    }
  };

  // Handle full reset back to default template
  const handleFullReset = async () => {
    if (!window.confirm('Warning: Reset everything (questions, options, members) back to factory default?')) return;
    try {
      const res = await fetch('/api/reset', { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Full reset error:', err);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#070a13] flex flex-col items-center justify-center text-teal-400 font-mono">
        <div className="w-12 h-12 border-4 border-teal-500/20 border-t-teal-400 rounded-full animate-spin mb-4" />
        <p className="text-sm">Initiating Team Discovery Channel Alignment Engine...</p>
      </div>
    );
  }

  if (error || !state) {
    return (
      <div className="min-h-screen bg-[#070a13] flex flex-col items-center justify-center p-6 text-center">
        <div className="glass-panel p-8 rounded-2xl max-w-md">
          <p className="text-rose-400 font-mono mb-4">Error loading state: {error}</p>
          <button 
            onClick={fetchState}
            className="px-4 py-2 bg-teal-500 text-slate-950 font-bold rounded-xl text-sm"
          >
            Retry Connection
          </button>
        </div>
      </div>
    );
  }

  const filteredQuestions = activeCategory === 'all'
    ? state.questions
    : state.questions.filter(q => q.category === activeCategory);

  return (
    <div className="min-h-screen bg-[#070a13] text-slate-100 flex flex-col">
      {/* Top Header */}
      <Header
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        activeMemberId={activeMemberId}
        setActiveMemberId={setActiveMemberId}
        team={state.team}
        analysis={analysis}
        onAddMemberClick={() => setMemberModalTarget('new')}
      />

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Tab 1: Alignment Polls */}
        {activeTab === 'poll' && (
          <div className="space-y-6">
            {/* Mission Hero Banner */}
            <div className="glass-panel rounded-2xl p-6 bg-gradient-to-r from-sky-950/40 via-slate-900 to-indigo-950/40 border border-cyan-500/30 flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-2 text-xs font-mono text-cyan-400 mb-1">
                  <ShieldCheck className="w-4 h-4 text-cyan-400" />
                  <span>SGC DIRECTIVE: STARGATE SG-1 / SG-3 TACTICAL EXTRACTION</span>
                </div>
                <h2 className="text-xl sm:text-2xl font-extrabold text-white">
                  Vote, Align, and Lock In Our Stargate Co-op Shooter
                </h2>
                <p className="text-sm text-slate-300 mt-1 max-w-2xl">
                  Step through the puddle, scout the AO, plant C4, and dial home under Jaffa fire! Cast votes as <strong>{activeMemberId}</strong> or click <strong>"Propose Custom Idea (Other)"</strong>.
                </p>
              </div>

              <div className="flex items-center gap-2 flex-wrap">
                <button
                  onClick={handleResetVotes}
                  className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800 hover:bg-amber-500/10 text-slate-300 hover:text-amber-400 border border-slate-700 text-xs font-semibold transition"
                >
                  <RotateCcw className="w-3.5 h-3.5" />
                  <span>Reset Votes to 0</span>
                </button>
                <button
                  onClick={() => setActiveTab('compiler')}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-400 hover:from-cyan-400 hover:to-teal-300 text-slate-950 font-bold text-xs sm:text-sm transition shadow-lg shadow-cyan-500/20"
                >
                  <span>Compile SGC Bootstrap Spec</span>
                  <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Category Filter Pills */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-2 scrollbar-none">
              <span className="text-xs text-slate-400 font-mono flex items-center gap-1 mr-1">
                <Filter className="w-3.5 h-3.5" />
                <span>Filter:</span>
              </span>
              {CATEGORIES.map((cat) => (
                <button
                  key={cat.id}
                  onClick={() => setActiveCategory(cat.id)}
                  className={`text-xs px-3 py-1.5 rounded-xl font-medium transition flex-shrink-0 ${
                    activeCategory === cat.id
                      ? 'bg-teal-500 text-slate-950 font-bold shadow-sm'
                      : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
                  }`}
                >
                  {cat.name}
                </button>
              ))}
            </div>

            {/* Questions List */}
            <div className="space-y-6">
              {filteredQuestions.map((q) => (
                <QuestionCard
                  key={q.id}
                  question={q}
                  team={state.team}
                  activeMemberId={activeMemberId}
                  analysis={analysis}
                  onRank={handleRank}
                  onVote={handleVote}
                  onOpenAddOption={(question) => setAddOptionTargetQuestion(question)}
                  onAddComment={handleAddComment}
                />
              ))}
            </div>
          </div>
        )}

        {/* Tab 2: Squad Roster */}
        {activeTab === 'roster' && (
          <SquadRoster
            team={state.team}
            onOpenAddMember={() => setMemberModalTarget('new')}
            onOpenEditMember={(member) => setMemberModalTarget(member)}
            onDeleteMember={handleDeleteMember}
            onToggleStewardRole={handleToggleStewardRole}
          />
        )}

        {/* Tab 3: Consensus & Insights */}
        {activeTab === 'consensus' && (
          <ConsensusDashboard
            state={state}
            analysis={analysis}
            onSelectQuestion={(qId) => {
              const q = state.questions.find(x => x.id === qId);
              if (q) {
                setActiveCategory(q.category);
                setActiveTab('poll');
              }
            }}
          />
        )}

        {/* Tab 4: Prompt & GDD Studio */}
        {activeTab === 'compiler' && (
          <PromptGDDStudio
            compiled={compiled}
            onRefreshCompile={fetchCompiled}
            onExportToRepo={handleExportToRepo}
            exportStatus={exportStatus}
          />
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800/80 py-6 text-center text-xs text-slate-500 font-mono">
        <div className="max-w-7xl mx-auto px-4 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span>🚀</span>
            <span>Team Discovery Channel • Grounded Game Dev Initiative</span>
          </div>

          <div className="flex items-center gap-4">
            <button
              onClick={handleResetVotes}
              className="text-slate-400 hover:text-amber-400 transition flex items-center gap-1"
            >
              <RotateCcw className="w-3 h-3" />
              <span>Reset All Votes to 0</span>
            </button>
            <button
              onClick={handleFullReset}
              className="text-slate-500 hover:text-rose-400 transition flex items-center gap-1"
            >
              <span>Factory Reset</span>
            </button>
            <a
              href="https://github.com/flaxos/Team-Discovery-Channel"
              target="_blank"
              rel="noopener noreferrer"
              className="text-slate-400 hover:text-teal-400 transition"
            >
              GitHub Repo
            </a>
          </div>
        </div>
      </footer>

      {/* Modals */}
      <AddOptionModal
        isOpen={Boolean(addOptionTargetQuestion)}
        question={addOptionTargetQuestion}
        activeMemberId={activeMemberId}
        onClose={() => setAddOptionTargetQuestion(null)}
        onSubmit={handleAddOption}
      />

      <MemberModal
        isOpen={Boolean(memberModalTarget)}
        member={memberModalTarget && memberModalTarget !== 'new' ? memberModalTarget : null}
        onClose={() => setMemberModalTarget(null)}
        onSaveMember={handleSaveMember}
        onDeleteMember={handleDeleteMember}
      />
    </div>
  );
}
