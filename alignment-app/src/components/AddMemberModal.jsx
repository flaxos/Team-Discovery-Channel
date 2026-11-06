import React, { useState } from 'react';
import { X, UserPlus, Sparkles } from 'lucide-react';

const AVATAR_OPTIONS = ['🚀', '⚡', '🛸', '👾', '🕹️', '🛡️', '🧙‍♂️', '🤖', '💀', '🔥', '🧬', '🎯'];
const COLOR_OPTIONS = ['#14b8a6', '#f59e0b', '#38bdf8', '#a855f7', '#ec4899', '#10b981', '#f43f5e', '#6366f1'];
const ROLE_SUGGESTIONS = [
  'AI Agent Orchestrator',
  'Multiplayer & Netcode',
  'Core Gameplay & Systems',
  'Combat Feel & Juice',
  'Weapons & Perks Scripter',
  'Art & Visual Polish',
  'Audio & SFX',
  'QA & Playtest Host'
];

export default function AddMemberModal({ isOpen, onClose, onAddMember }) {
  const [name, setName] = useState('');
  const [avatar, setAvatar] = useState('🛸');
  const [color, setColor] = useState('#38bdf8');
  const [weeklyHours, setWeeklyHours] = useState(5);
  const [selectedRoles, setSelectedRoles] = useState(['Core Gameplay & Systems']);
  const [notes, setNotes] = useState('');

  if (!isOpen) return null;

  const toggleRole = (role) => {
    if (selectedRoles.includes(role)) {
      setSelectedRoles(selectedRoles.filter(r => r !== role));
    } else {
      setSelectedRoles([...selectedRoles, role]);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!name.trim()) return;

    onAddMember({
      name: name.trim(),
      avatar,
      color,
      weeklyHours: Number(weeklyHours) || 5,
      rolePreferences: selectedRoles.length > 0 ? selectedRoles : ['Core Gameplay'],
      notes: notes.trim()
    });

    setName('');
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-in fade-in duration-150">
      <div 
        className="glass-panel w-full max-w-md rounded-2xl p-6 border border-teal-500/40 shadow-2xl relative bg-[#0b1120]"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-4 mb-4">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 rounded-xl bg-teal-500/20 text-teal-300 flex items-center justify-center">
              <UserPlus className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white">
                Add Friend to Crew
              </h3>
              <p className="text-xs text-slate-400">
                Join the Team Discovery Channel dev squad
              </p>
            </div>
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
              Friend's Name / Handle *
            </label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Dave, Sam, Rex..."
              className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3.5 py-2 text-white placeholder-slate-500 focus:outline-none focus:border-teal-500"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
                Avatar Emoji
              </label>
              <div className="flex flex-wrap gap-1 p-1.5 bg-slate-900 border border-slate-700 rounded-xl">
                {AVATAR_OPTIONS.map((emoji) => (
                  <button
                    key={emoji}
                    type="button"
                    onClick={() => setAvatar(emoji)}
                    className={`w-7 h-7 rounded-lg text-sm flex items-center justify-center transition ${
                      avatar === emoji ? 'bg-teal-500/30 border border-teal-400' : 'hover:bg-slate-800'
                    }`}
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
                Squad Color
              </label>
              <div className="flex flex-wrap gap-1.5 p-2 bg-slate-900 border border-slate-700 rounded-xl">
                {COLOR_OPTIONS.map((c) => (
                  <button
                    key={c}
                    type="button"
                    onClick={() => setColor(c)}
                    className={`w-6 h-6 rounded-full transition ${
                      color === c ? 'ring-2 ring-white scale-110' : 'opacity-80 hover:opacity-100'
                    }`}
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>
            </div>
          </div>

          <div>
            <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
              Weekly Hours Commitment
            </label>
            <div className="flex items-center gap-3">
              <input
                type="range"
                min="2"
                max="20"
                step="1"
                value={weeklyHours}
                onChange={(e) => setWeeklyHours(e.target.value)}
                className="flex-1 accent-teal-400"
              />
              <span className="font-mono text-sm font-bold text-teal-400 w-16 text-right">
                {weeklyHours} hrs/wk
              </span>
            </div>
          </div>

          <div>
            <label className="block text-xs font-mono text-slate-300 mb-1.5 font-semibold">
              Preferred Domains / Passions:
            </label>
            <div className="flex flex-wrap gap-1.5">
              {ROLE_SUGGESTIONS.map((role) => {
                const isSelected = selectedRoles.includes(role);
                return (
                  <button
                    key={role}
                    type="button"
                    onClick={() => toggleRole(role)}
                    className={`text-xs px-2.5 py-1 rounded-lg border transition ${
                      isSelected
                        ? 'bg-teal-500/20 text-teal-300 border-teal-500/50 font-bold'
                        : 'bg-slate-900 text-slate-400 border-slate-800 hover:text-white hover:border-slate-700'
                    }`}
                  >
                    {role}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <label className="block text-xs font-mono text-slate-300 mb-1 font-semibold">
              Friend's Motto / Note
            </label>
            <input
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g. Excited to build ridiculous boss fights!"
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
              className="px-5 py-2 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-bold transition shadow-lg shadow-teal-500/20"
            >
              Add Friend
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
