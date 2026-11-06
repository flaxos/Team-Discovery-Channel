import React, { useState, useEffect } from 'react';
import Header from './components/Header';
import QuestionCard from './components/QuestionCard';
import SquadRoster from './components/SquadRoster';
import ConsensusDashboard from './components/ConsensusDashboard';
import PromptGDDStudio from './components/PromptGDDStudio';
import AddOptionModal from './components/AddOptionModal';
import AddMemberModal from './components/AddMemberModal';
import { 
  Filter, 
  RotateCcw, 
  Sparkles, 
  ShieldCheck, 
  CheckCircle,
  Clock,
  Compass,
  ArrowRight
} from 'lucide-react';

const CATEGORIES = [
  { id: 'all', name: 'All Questions' },
  { id: 'grounding', name: 'Grounding & Scope' },
  { id: 'genre', name: 'Genre & Core Loop' },
  { id: 'engine', name: 'Tech & Engine' },
  { id: 'netcode', name: 'Multiplayer Netcode' },
  { id: 'art', name: 'Art Direction' },
  { id: 'mechanics', name: 'Core Mechanics' },
  { id: 'theme', name: 'Theme & Lore' },
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
  const [isAddMemberOpen, setIsAddMemberOpen] = useState(false);
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

  // Handle vote toggle
  const handleVote = async (questionId, optionId) => {
    try {
      const res = await fetch('/api/vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ questionId, optionId, memberId: activeMemberId })
      });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Vote error:', err);
    }
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

  // Handle adding team member
  const handleAddMember = async (memberData) => {
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
      console.error('Add member error:', err);
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

  // Handle reset
  const handleReset = async () => {
    if (!window.confirm('Reset all questions and votes back to default template?')) return;
    try {
      const res = await fetch('/api/reset', { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setState(data.state);
        setAnalysis(data.analysis);
        fetchCompiled();
      }
    } catch (err) {
      console.error('Reset error:', err);
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
        onAddMemberClick={() => setIsAddMemberOpen(true)}
      />

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Tab 1: Alignment Polls */}
        {activeTab === 'poll' && (
          <div className="space-y-6">
            {/* Mission Hero Banner */}
            <div className="glass-panel rounded-2xl p-6 bg-gradient-to-r from-teal-950/40 via-slate-900 to-slate-900/60 border border-teal-500/20 flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-2 text-xs font-mono text-teal-400 mb-1">
                  <ShieldCheck className="w-4 h-4" />
                  <span>MISSION DIRECTIVE: DEFEAT UNFINISHED GAME SYNDROME</span>
                </div>
                <h2 className="text-xl sm:text-2xl font-extrabold text-white">
                  Vote, Align, and Lock In Our Game Direction
                </h2>
                <p className="text-sm text-slate-300 mt-1 max-w-2xl">
                  Cast votes as <strong>{activeMemberId}</strong>. If you have a different vision, click <strong>"Propose Custom Idea (Other)"</strong> on any category!
                </p>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setActiveTab('compiler')}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-bold text-xs sm:text-sm transition shadow-lg shadow-teal-500/20"
                >
                  <span>Compile Bootstrap Prompt</span>
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
            onOpenAddMember={() => setIsAddMemberOpen(true)}
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
              onClick={handleReset}
              className="text-slate-400 hover:text-amber-400 transition flex items-center gap-1"
            >
              <RotateCcw className="w-3 h-3" />
              <span>Reset Votes to Default</span>
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

      <AddMemberModal
        isOpen={isAddMemberOpen}
        onClose={() => setIsAddMemberOpen(false)}
        onAddMember={handleAddMember}
      />
    </div>
  );
}
