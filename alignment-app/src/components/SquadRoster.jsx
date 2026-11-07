import React from 'react';
import { 
  Users, 
  Clock, 
  Shield, 
  CheckCircle, 
  AlertTriangle, 
  Plus, 
  Code, 
  Network, 
  Sparkles, 
  Gamepad2, 
  Wrench,
  Edit2,
  Trash2,
  UserCheck,
  UserX,
  X
} from 'lucide-react';

const CORE_DOMAINS = [
  { id: 'gate_netcode', name: 'Stargate & Netcode Czar', roleKey: 'Multiplayer & Netcode', icon: Network, desc: 'Manages Stargate event horizon transitions, DHD chevron sync, and netcode interpolation' },
  { id: 'combat_feel', name: 'Combat & Weapon Juice Lead', roleKey: 'Combat Feel & Juice', icon: Gamepad2, desc: 'P90 recoil, Ma\'Tok staff plasma blasts, Zat stun/kill arcs, and C4 detonations' },
  { id: 'ai_orchestrator', name: 'AI Agent Orchestrator', roleKey: 'AI Agent Orchestrator', icon: Code, desc: 'Prompts AI agents, maintains architecture rules, and conducts code reviews' },
  { id: 'jaffa_ai', name: 'Jaffa AI & Stealth Scripter', roleKey: 'Weapons & Perks Scripter', icon: Sparkles, desc: 'Patrol paths, vision cones, alarm radios, and transport ring drop waves' },
  { id: 'qa_host', name: 'Friday SGC Playtest Host', roleKey: 'QA & Playtest Host', icon: Wrench, desc: 'Hosts weekly Friday playtests on Discord, verifies builds, and logs priority bugs' }
];

export default function SquadRoster({ 
  team = [], 
  onOpenAddMember, 
  onOpenEditMember, 
  onDeleteMember, 
  onToggleStewardRole 
}) {
  const totalHours = team.reduce((sum, m) => sum + (m.weeklyHours || 0), 0);

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="glass-panel rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xl">🛸</span>
            <h2 className="text-xl font-bold text-white">Squad Roster & Division of Labor</h2>
          </div>
          <p className="text-sm text-slate-300">
            Clear ownership eliminates the bystander effect. Adjust stewards or click below to assign domains.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="bg-slate-900 border border-slate-800 px-4 py-2 rounded-xl text-center">
            <span className="text-[11px] text-slate-400 block font-mono">Total Squad Capacity</span>
            <span className="text-lg font-bold text-teal-400 font-mono">{totalHours} hrs / week</span>
          </div>

          <button
            onClick={onOpenAddMember}
            className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-bold text-xs sm:text-sm transition shadow-lg shadow-teal-500/20"
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
            className="glass-panel rounded-xl p-5 border border-slate-800 hover:border-slate-700 transition relative group"
          >
            <div className="flex items-start justify-between gap-3 mb-3">
              <div className="flex items-center gap-3">
                <div 
                  className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl shadow-md flex-shrink-0"
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
                      title="Status: Active Steward"
                    />
                  </h3>
                  <div className="flex items-center gap-2 text-xs text-slate-400 mt-0.5">
                    <Clock className="w-3.5 h-3.5 text-teal-400" />
                    <span>{member.weeklyHours} hours committed / week</span>
                  </div>
                </div>
              </div>

              {/* Adjust / Edit / Remove Action Buttons */}
              <div className="flex items-center gap-1">
                <button
                  onClick={() => onOpenEditMember(member)}
                  title="Adjust steward details & hours"
                  className="p-1.5 rounded-lg text-slate-400 hover:text-teal-300 hover:bg-slate-800 border border-transparent hover:border-slate-700 transition"
                >
                  <Edit2 className="w-4 h-4" />
                </button>
                <button
                  onClick={() => {
                    if (window.confirm(`Remove ${member.name} from the squad roster?`)) {
                      onDeleteMember(member.id);
                    }
                  }}
                  title="Remove from squad"
                  className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 border border-transparent hover:border-rose-500/20 transition"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Stewarded Roles */}
            <div className="mb-3">
              <span className="text-[11px] font-mono text-slate-400 block mb-1.5 uppercase tracking-wider">
                Stewarded Domains:
              </span>
              <div className="flex flex-wrap gap-1.5">
                {member.rolePreferences && member.rolePreferences.length > 0 ? (
                  member.rolePreferences.map((role, idx) => (
                    <span 
                      key={idx}
                      className="text-xs px-2.5 py-1 rounded-md bg-slate-800 text-teal-300 border border-slate-700/80 font-medium flex items-center gap-1.5"
                    >
                      <span>{role}</span>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          onToggleStewardRole(member.id, role);
                        }}
                        title={`Remove ${role} from ${member.name}`}
                        className="hover:text-rose-400 transition"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </span>
                  ))
                ) : (
                  <span className="text-xs text-slate-500 italic">No specific domains assigned yet.</span>
                )}
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

      {/* Interactive Core Development Pillars Coverage Matrix */}
      <div className="glass-panel rounded-2xl p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-2">
          <h3 className="text-lg font-bold text-white flex items-center gap-2">
            <Shield className="w-5 h-5 text-teal-400" />
            <span>Core Development Pillars Coverage (Direct Steward Assignment)</span>
          </h3>
          <span className="text-xs font-mono text-slate-400">
            Click any member badge to assign or unassign
          </span>
        </div>
        <p className="text-xs text-slate-400 mb-5">
          Each pillar must have at least one designated steward. Click any squad member's button under a pillar to toggle their stewardship on or off with 1 click!
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {CORE_DOMAINS.map((domain) => {
            const Icon = domain.icon;
            
            // Check which members are actively stewarding this pillar
            const assignedMembers = team.filter(m => 
              m.rolePreferences?.some(r => 
                r.toLowerCase().includes(domain.roleKey.toLowerCase().split(' ')[0]) ||
                domain.roleKey.toLowerCase().includes(r.toLowerCase().split(' ')[0])
              )
            );
            const isCovered = assignedMembers.length > 0;

            return (
              <div 
                key={domain.id} 
                className={`p-4 rounded-xl border flex flex-col justify-between transition ${
                  isCovered 
                    ? 'bg-slate-900/60 border-slate-800' 
                    : 'bg-amber-500/5 border-amber-500/30'
                }`}
              >
                <div>
                  <div className="flex items-start justify-between gap-2 mb-1.5">
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
                  <p className="text-xs text-slate-400 mb-4 leading-snug">
                    {domain.desc}
                  </p>
                </div>

                {/* Direct Steward Toggles */}
                <div className="pt-3 border-t border-slate-800/80">
                  <span className="text-[11px] font-mono text-slate-400 block mb-1.5 uppercase">
                    Assign Stewards:
                  </span>
                  <div className="flex flex-wrap gap-1.5">
                    {team.map((member) => {
                      const isAssigned = member.rolePreferences?.some(r => 
                        r.toLowerCase().includes(domain.roleKey.toLowerCase().split(' ')[0]) ||
                        domain.roleKey.toLowerCase().includes(r.toLowerCase().split(' ')[0])
                      );

                      return (
                        <button
                          key={member.id}
                          type="button"
                          onClick={() => onToggleStewardRole(member.id, domain.roleKey)}
                          title={isAssigned ? `Click to remove ${member.name} from this pillar` : `Click to assign ${member.name} to this pillar`}
                          className={`text-xs px-2.5 py-1 rounded-lg font-medium transition flex items-center gap-1.5 ${
                            isAssigned
                              ? 'bg-teal-500/20 text-teal-300 border border-teal-500/50 shadow-sm'
                              : 'bg-slate-900/80 text-slate-400 border border-dashed border-slate-700 hover:text-white hover:border-slate-500'
                          }`}
                        >
                          <span>{member.avatar}</span>
                          <span>{member.name}</span>
                          {isAssigned ? (
                            <X className="w-3 h-3 text-teal-400 hover:text-rose-400 ml-0.5" />
                          ) : (
                            <Plus className="w-3 h-3 text-slate-500 ml-0.5" />
                          )}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
