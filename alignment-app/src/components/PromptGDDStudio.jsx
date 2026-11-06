import React, { useState } from 'react';
import { 
  Terminal, 
  Copy, 
  Check, 
  Download, 
  GitCommit, 
  FileText, 
  RefreshCw, 
  Share2, 
  CheckCircle2, 
  AlertCircle,
  ExternalLink,
  Sparkles
} from 'lucide-react';

export default function PromptGDDStudio({ 
  compiled = {}, 
  onRefreshCompile, 
  onExportToRepo, 
  exportStatus 
}) {
  const [activeDocTab, setActiveDocTab] = useState('prompt'); // 'prompt', 'gdd', 'roadmap', 'contract'
  const [copied, setCopied] = useState(false);
  const [gitCommitMsg, setGitCommitMsg] = useState('feat: align on game dev specs, GDD, and bootstrap prompt');
  const [shouldGitCommit, setShouldGitCommit] = useState(true);
  const [isExporting, setIsExporting] = useState(false);

  const getDocContent = () => {
    switch (activeDocTab) {
      case 'prompt':
        return compiled.bootstrapPrompt || 'Compiling prompt...';
      case 'gdd':
        return compiled.gdd || 'Compiling GDD...';
      case 'roadmap':
        return compiled.roadmap || 'Compiling roadmap...';
      case 'contract':
        return compiled.contract || 'Compiling contract...';
      default:
        return '';
    }
  };

  const getDocFilename = () => {
    switch (activeDocTab) {
      case 'prompt': return 'BOOTSTRAP_PROMPT.md';
      case 'gdd': return 'GDD.md';
      case 'roadmap': return 'ROADMAP.md';
      case 'contract': return 'TEAM_CONTRACT.md';
      default: return 'doc.md';
    }
  };

  const handleCopy = () => {
    const text = getDocContent();
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const text = getDocContent();
    const filename = getDocFilename();
    const blob = new Blob([text], { type: 'text/markdown;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExport = async () => {
    setIsExporting(true);
    try {
      await onExportToRepo({
        gitCommit: shouldGitCommit,
        commitMessage: gitCommitMsg
      });
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Banner & Control Station */}
      <div className="glass-panel rounded-2xl p-6 border-teal-500/30">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div>
            <div className="flex items-center gap-2 mb-1.5">
              <span className="p-2 rounded-xl bg-teal-500/20 text-teal-400">
                <Terminal className="w-5 h-5" />
              </span>
              <h2 className="text-xl font-bold text-white">
                Agentic Prompt & Project Bootstrap Studio
              </h2>
            </div>
            <p className="text-sm text-slate-300 max-w-2xl leading-relaxed">
              Synthesized from your team's voting and custom ideas. Copy the prompt directly into your AI coding assistant (Antigravity, Claude Code, or Codex), or export the full specification right into your GitHub repository!
            </p>
          </div>

          {/* Quick Action Buttons */}
          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={handleCopy}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-bold text-xs sm:text-sm transition shadow-lg shadow-teal-500/20"
            >
              {copied ? (
                <>
                  <Check className="w-4 h-4 stroke-[3]" />
                  <span>Copied to Clipboard!</span>
                </>
              ) : (
                <>
                  <Copy className="w-4 h-4 stroke-[2.5]" />
                  <span>Copy Active Document</span>
                </>
              )}
            </button>

            <button
              onClick={handleDownload}
              className="flex items-center gap-2 px-3.5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs sm:text-sm font-semibold transition"
            >
              <Download className="w-4 h-4" />
              <span>Download .md</span>
            </button>

            <button
              onClick={onRefreshCompile}
              title="Refresh compilation"
              className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white border border-slate-700 transition"
            >
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* GitHub Export Drawer */}
        <div className="mt-5 pt-4 border-t border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-950/40 p-4 rounded-xl border border-slate-800">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
              <GitCommit className="w-4 h-4" />
            </div>
            <div>
              <span className="text-xs font-bold text-white block">
                Direct Repository Sync (flaxos/Team-Discovery-Channel)
              </span>
              <span className="text-[11px] text-slate-400">
                Writes BOOTSTRAP_PROMPT.md, GDD.md, ROADMAP.md, and TEAM_CONTRACT.md to root
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <label className="flex items-center gap-1.5 text-xs text-slate-300 cursor-pointer">
              <input
                type="checkbox"
                checked={shouldGitCommit}
                onChange={(e) => setShouldGitCommit(e.target.checked)}
                className="rounded bg-slate-800 border-slate-700 text-teal-500 focus:ring-teal-500"
              />
              <span>Commit & push to GitHub</span>
            </label>

            <button
              onClick={handleExport}
              disabled={isExporting}
              className="flex items-center gap-1.5 px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-bold text-xs transition shadow-md shadow-indigo-600/20"
            >
              <Share2 className="w-3.5 h-3.5" />
              <span>{isExporting ? 'Exporting...' : 'Export to Repo'}</span>
            </button>
          </div>
        </div>

        {/* Export Status Banner */}
        {exportStatus && (
          <div className={`mt-3 p-3 rounded-xl border text-xs flex items-center justify-between gap-2 ${
            exportStatus.success 
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300' 
              : 'bg-rose-500/10 border-rose-500/30 text-rose-300'
          }`}>
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
              <span>{exportStatus.message}</span>
              {exportStatus.gitPushed && (
                <span className="font-bold underline ml-2">Pushed to GitHub main branch!</span>
              )}
            </div>
            <a 
              href="https://github.com/flaxos/Team-Discovery-Channel" 
              target="_blank" 
              rel="noopener noreferrer"
              className="flex items-center gap-1 text-[11px] font-mono hover:underline"
            >
              <span>View on GitHub</span>
              <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        )}
      </div>

      {/* Document Selector Tabs */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1">
        <button
          onClick={() => setActiveDocTab('prompt')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition flex-shrink-0 ${
            activeDocTab === 'prompt'
              ? 'bg-teal-500 text-slate-950 shadow-md shadow-teal-500/20'
              : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
          }`}
        >
          <Sparkles className="w-3.5 h-3.5" />
          <span>🤖 AI Bootstrap Prompt</span>
        </button>

        <button
          onClick={() => setActiveDocTab('gdd')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition flex-shrink-0 ${
            activeDocTab === 'gdd'
              ? 'bg-teal-500 text-slate-950 shadow-md shadow-teal-500/20'
              : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
          }`}
        >
          <FileText className="w-3.5 h-3.5" />
          <span>📜 Game Design Doc (GDD.md)</span>
        </button>

        <button
          onClick={() => setActiveDocTab('roadmap')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition flex-shrink-0 ${
            activeDocTab === 'roadmap'
              ? 'bg-teal-500 text-slate-950 shadow-md shadow-teal-500/20'
              : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
          }`}
        >
          <FileText className="w-3.5 h-3.5" />
          <span>🗺️ Roadmap & Labor (ROADMAP.md)</span>
        </button>

        <button
          onClick={() => setActiveDocTab('contract')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition flex-shrink-0 ${
            activeDocTab === 'contract'
              ? 'bg-teal-500 text-slate-950 shadow-md shadow-teal-500/20'
              : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
          }`}
        >
          <FileText className="w-3.5 h-3.5" />
          <span>🤝 Grounding Pact (TEAM_CONTRACT.md)</span>
        </button>
      </div>

      {/* Document Content Monospace Viewer */}
      <div className="glass-panel rounded-2xl overflow-hidden border border-slate-800">
        <div className="bg-slate-950/80 px-4 py-2.5 border-b border-slate-800 flex items-center justify-between text-xs font-mono text-slate-400">
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-rose-500/80"></span>
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500/80"></span>
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500/80"></span>
            <span className="ml-2 text-slate-300 font-bold">{getDocFilename()}</span>
          </div>
          <button
            onClick={handleCopy}
            className="hover:text-teal-300 transition flex items-center gap-1"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
            <span>{copied ? 'Copied' : 'Copy'}</span>
          </button>
        </div>

        <pre className="p-6 text-xs sm:text-sm font-mono text-slate-200 overflow-x-auto leading-relaxed whitespace-pre-wrap max-h-[600px] overflow-y-auto selection:bg-teal-600 selection:text-white">
          {getDocContent()}
        </pre>
      </div>
    </div>
  );
}
