import React from 'react';
import { Users, Clock, Shield, CheckCircle, AlertTriangle, Plus, Code, Network, Sparkles, Gamepad2, Wrench } from 'lucide-react';

const CORE_DOMAINS = [
  { id: 'ai_orchestrator', name: 'AI Agent Orchestrator', icon: Code, desc: 'Prompts agents, maintains system prompts, and reviews code structure' },
  { id: 'netcode', name: 'Multiplayer & Netcode', icon: Network, desc: 'Manages room state, socket ticks, interpolation, and connectivity' },
  { id: 'combat_feel', name: 'Game Feel & Combat Juice', icon: Gamepad2, desc: 'Weapon recoil, screenshake, hitstop, responsiveness, and physics' },
  { id: 'content', name: 'Weapons, Perks & Scripter', icon: Sparkles, desc: 'Designs classes, enemy behaviors, upgrade synergies, and drop tables' },
  { id: 'qa_host', name: 'Playtest Host & QA Czar', icon: Wrench, desc: 'Hosts Friday playtests, verifies builds, and logs priority bugs' }
];

export default function SquadRoster({ team = [], onOpenAddMember }) {
  const totalHours = team.reduce((sum, m) => sum + (m.weeklyHours || 0), 0);

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="glass-panel rounded-2xl p-6 flex flex-wrap items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xl">🛸</span>
            <h2 className="text-xl font-bold text-white">Squad Roster & Division of Labor</h2>
          </div>
          <p className="text-sm text-slate-300">
            Clear ownership eliminates the bystander effect. Everyone has an assigned domain while pairing with AI agents.
          </p>
        </div>

        <div className="flex items-center gap-4">
          <div className="bg-slate-900 border border-slate-800 px-4 py-2 rounded-xl text-center">
            <span className="text-xs text-slate-400 block font-mono">Total Squad Capacity</span>
            <span className="text-lg font-bold text-teal-400 font-mono">{totalHours} hrs / week</span>
          </div>

          <button
            onClick={onOpenAddMember}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-bold text-sm transition shadow-lg shadow-teal-500/20"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            <span>Add Friend to Crew</span>
          </button>
        </div>
      </div>

      {/* Team Member Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {team.map((member) => (
          <div 
            key={member.id} 
            className="glass-panel rounded-xl p-5 border border-slate-800 hover:border-slate-700 transition"
          >
            <div className="flex items-start justify-between gap-3 mb-3">
              <div className="flex items-center gap-3">
                <div 
                  className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl shadow-md"
                  style={{ backgroundColor: `${member.color}20`, border: `1px solid ${member.color}60` }}
                >
                  {member.avatar}
                </div>
                <div>
                  <h3 className="font-bold text-lg text-white flex items-center gap-2">
                    <span>{member.name}</span>
                    <span 
                      className="w-2.5 h-2.5 rounded-full" 
                      style={{ backgroundColor: member.color }}
                      title="Status: Active"
                    />
                  </h3>
                  <div className="flex items-center gap-2 text-xs text-slate-400 mt-0.5">
                    <Clock className="w-3.5 h-3.5 text-teal-400" />
                    <span>{member.weeklyHours} hours committed / week</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Role Preferences */}
            <div className="mb-3">
              <span className="text-xs font-mono text-slate-400 block mb-1.5 uppercase">Primary Domains:</span>
              <div className="flex flex-wrap gap-1.5">
                {member.rolePreferences && member.rolePreferences.map((role, idx) => (
                  <span 
                    key={idx}
                    className="text-xs px-2.5 py-1 rounded-md bg-slate-800 text-teal-300 border border-slate-700/80 font-medium"
                  >
                    {role}
                  </span>
                ))}
              </div>
            </div>

            {/* Notes / Rationale */}
            {member.notes && (
              <p className="text-xs text-slate-400 bg-slate-950/60 p-2.5 rounded-lg border border-slate-800/80 italic">
                "{member.notes}"
              </p>
            )}
          </div>
        ))}
      </div>

      {/* Domain Coverage Matrix */}
      <div className="glass-panel rounded-2xl p-6">
        <h3 className="text-lg font-bold text-white mb-2 flex items-center gap-2">
          <Shield className="w-5 h-5 text-teal-400" />
          <span>Core Development Pillars Coverage</span>
        </h3>
        <p className="text-xs text-slate-400 mb-4">
          A successful multiplayer game requires someone actively stewarding each of these 5 pillars.
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {CORE_DOMAINS.map((domain) => {
            const Icon = domain.icon;
            // Find which members cover this domain
            const assignedMembers = team.filter(m => 
              m.rolePreferences?.some(r => r.toLowerCase().includes(domain.name.toLowerCase().split(' ')[0]))
            );
            const isCovered = assignedMembers.length > 0;

            return (
              <div 
                key={domain.id} 
                className={`p-4 rounded-xl border ${
                  isCovered 
                    ? 'bg-slate-900/60 border-slate-800' 
                    : 'bg-amber-500/5 border-amber-500/30'
                }`}
              >
                <div className="flex items-start justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2">
                    <Icon className="w-4 h-4 text-teal-400" />
                    <span className="font-bold text-sm text-white">{domain.name}</span>
                  </div>
                  {isCovered ? (
                    <CheckCircle className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                  ) : (
                    <AlertTriangle className="w-4 h-4 text-amber-400 flex-shrink-0" />
                  )}
                </div>
                <p className="text-xs text-slate-400 mb-3 leading-snug">
                  {domain.desc}
                </p>

                <div className="flex items-center gap-1.5 pt-2 border-t border-slate-800/80">
                  <span className="text-[11px] font-mono text-slate-400">Assigned:</span>
                  {assignedMembers.length > 0 ? (
                    <div className="flex items-center gap-1">
                      {assignedMembers.map(m => (
                        <span key={m.id} className="text-xs font-semibold px-2 py-0.5 rounded bg-teal-500/15 text-teal-300 border border-teal-500/30">
                          {m.avatar} {m.name}
                        </span>
                      ))}
                    </div>
                  ) : (
                    <span className="text-xs text-amber-400 italic">Needs owner!</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
