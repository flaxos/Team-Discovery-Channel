import React, { useState, useEffect } from 'react';
import { X, Sparkles, PlusCircle } from 'lucide-react';

export default function AddOptionModal({ isOpen, onClose, question, activeMemberId, onSubmit }) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [feasibility, setFeasibility] = useState('High');
  const [pros, setPros] = useState('');
  const [caution, setCaution] = useState('');

  useEffect(() => {
    if (isOpen) {
      setTitle('');
      setDescription('');
      setFeasibility('High');
      setPros('');
      setCaution('');
    }
  }, [isOpen]);

  if (!isOpen || !question) return null;

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!title.trim() || !description.trim()) return;

    onSubmit({
      questionId: question.id,
      title: title.trim(),
      description: description.trim(),
      feasibility,
      pros: pros.trim() ? pros.split(',').map(p => p.trim()) : ['Community Idea'],
      caution: caution.trim() || 'Requires team validation.',
      memberId: activeMemberId
    });

    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-in fade-in duration-150">
      <div 
        className="glass-panel w-full max-w-lg rounded-2xl p-6 border border-teal-500/40 shadow-2xl relative bg-[#0b1120]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-4 mb-4">
          <div>
            <div className="flex items-center gap-1.5 text-xs text-teal-400 font-mono mb-1">
              <Sparkles className="w-3.5 h-3.5" />
              <span>PROPOSE CUSTOM OPTION (OTHER)</span>
            </div>
            <h3 className="text-lg font-bold text-white">
              {question.title}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 text-xs sm:text-sm">
          <div>
            <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
              Option Title *
            </label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Asynchronous Turn-Based Raid Battler"
              className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-teal-500"
            />
          </div>

          <div>
            <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
              Description & How It Works *
            </label>
            <textarea
              required
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Describe the gameplay loop, why it's fun, and how it works for 2-4 friends..."
              className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-teal-500 resize-none leading-relaxed"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
                Feasibility for Milestone 1
              </label>
              <select
                value={feasibility}
                onChange={(e) => setFeasibility(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2 text-white focus:outline-none focus:border-teal-500"
              >
                <option value="Very High">Very High (Trivial / Weekend)</option>
                <option value="High">High (Proven 2-Week MVP)</option>
                <option value="Medium">Medium (Requires care)</option>
                <option value="Experimental">Experimental (High risk/reward)</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
                Key Pros (comma separated)
              </label>
              <input
                type="text"
                value={pros}
                onChange={(e) => setPros(e.target.value)}
                placeholder="e.g. Zero netcode, fast turns, hilarity"
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-teal-500"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
              Risk / Scope Caution
            </label>
            <input
              type="text"
              value={caution}
              onChange={(e) => setCaution(e.target.value)}
              placeholder="e.g. Needs disciplined turn timer to prevent stalling"
              className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-teal-500"
            />
          </div>

          <div className="pt-2 flex items-center justify-end gap-2 border-t border-slate-800">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-slate-400 hover:text-white transition font-semibold"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-5 py-2 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-bold transition shadow-lg shadow-teal-500/20 flex items-center gap-1.5"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Submit & Cast Vote</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
