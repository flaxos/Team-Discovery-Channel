// Stargate SG-1 & SG-3 Tactical Extraction Shooter - Compiler Engine
// Synthesizes preferential stack-ranked votes, custom ideas, and squad roles

function getRankPoints(rank) {
  switch (rank) {
    case 1: return 3; // 1st Preference = 3 points
    case 2: return 2; // 2nd Preference = 2 points
    case 3: return 1; // 3rd Preference = 1 point
    default: return 1;
  }
}

function analyzeVotes(state) {
  const summary = {};
  
  state.questions.forEach((q) => {
    const userRankings = q.userRankings || {};

    // Build voter ranks map for each option
    const optionStats = {};
    q.options.forEach((opt) => {
      optionStats[opt.id] = {
        score: 0,
        rankCounts: { 1: 0, 2: 0, 3: 0 },
        voterRanks: []
      };
    });

    // Process explicit userRankings: { [memberId]: [optId1, optId2, optId3] }
    Object.entries(userRankings).forEach(([memberId, rankedList]) => {
      if (!Array.isArray(rankedList)) return;
      const member = state.team.find(t => t.id === memberId);
      const memberName = member ? member.name : memberId;
      const memberAvatar = member ? member.avatar : '👤';
      const memberColor = member ? member.color : '#14b8a6';

      rankedList.forEach((optId, idx) => {
        const rank = idx + 1;
        const pts = getRankPoints(rank);
        if (optionStats[optId]) {
          optionStats[optId].score += pts;
          if (optionStats[optId].rankCounts[rank] !== undefined) {
            optionStats[optId].rankCounts[rank] += 1;
          }
          optionStats[optId].voterRanks.push({
            memberId,
            memberName,
            memberAvatar,
            memberColor,
            rank,
            points: pts
          });
        }
      });
    });

    // Fallback: If no userRankings exist yet but legacy opt.votes exist, treat as Rank 1
    if (Object.keys(userRankings).length === 0) {
      q.options.forEach((opt) => {
        if (Array.isArray(opt.votes)) {
          opt.votes.forEach((memberId) => {
            const member = state.team.find(t => t.id === memberId);
            optionStats[opt.id].score += 3;
            optionStats[opt.id].rankCounts[1] += 1;
            optionStats[opt.id].voterRanks.push({
              memberId,
              memberName: member ? member.name : memberId,
              memberAvatar: member ? member.avatar : '👤',
              memberColor: member ? member.color : '#14b8a6',
              rank: 1,
              points: 3
            });
          });
        }
      });
    }

    // Sort options by score descending; tiebreak on #1 ranks, then #2 ranks
    const sortedOptions = [...q.options].map(opt => {
      const stats = optionStats[opt.id] || { score: 0, rankCounts: { 1: 0, 2: 0, 3: 0 }, voterRanks: [] };
      return {
        ...opt,
        score: stats.score,
        rankCounts: stats.rankCounts,
        voterRanks: stats.voterRanks.sort((a, b) => a.rank - b.rank),
        voteCount: stats.voterRanks.length,
        voterNames: stats.voterRanks.map(v => `${v.memberName} (#${v.rank})`)
      };
    }).sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if ((b.rankCounts[1] || 0) !== (a.rankCounts[1] || 0)) {
        return (b.rankCounts[1] || 0) - (a.rankCounts[1] || 0);
      }
      return (b.rankCounts[2] || 0) - (a.rankCounts[2] || 0);
    });

    const maxScore = sortedOptions[0] ? sortedOptions[0].score : 0;
    const winners = sortedOptions.filter(o => o.score === maxScore && o.score > 0);
    const runnerUps = sortedOptions.filter(o => o.score < maxScore && o.score > 0);

    const totalVoters = Object.keys(userRankings).length || Math.max(state.team.length, 1);
    const isConsensus = winners.length === 1 && (winners[0].score >= totalVoters * 2);

    summary[q.id] = {
      question: q,
      userRankings,
      sortedOptions,
      topPick: winners[0] || sortedOptions[0],
      isConsensus,
      isTie: winners.length > 1,
      winners,
      runnerUps
    };
  });

  return summary;
}

function generateBootstrapPrompt(state, analysis) {
  const perspective = analysis['q_camera_perspective']?.topPick?.title || 'Isometric / Top-Down 3D Tactical';
  const loop = analysis['q_stealth_to_loud_loop']?.topPick?.title || 'Full Recon -> C4 Sabotage -> Transport Ring Alarm -> DHD Dial Under Fire';
  const engine = analysis['q_engine_choice']?.topPick?.title || 'Godot 4.x (GDScript) + Low-Poly Asset Packs (Synty FBX/glTF)';
  const artStyle = analysis['q_visual_art_style']?.topPick?.title || 'Stylized Low-Poly 3D + Next-Gen Dynamic Lighting';
  const timeframe = analysis['q_grounding_timeframe']?.topPick?.title || 'The 2-Week SGC Vertical Slice';

  // Mission types: collect all ranked choices in order of preferential score
  const rankedMissions = (analysis['q_mission_types']?.sortedOptions || []).filter(o => o.score > 0);
  const missionsList = (rankedMissions.length > 0 ? rankedMissions : (analysis['q_mission_types']?.sortedOptions?.slice(0, 3) || []))
    .map((m, idx) => `- **#${idx + 1} Priority: ${m.title}** (${m.score > 0 ? `${m.score} pts` : 'Default'}${m.voterNames?.length > 0 ? ` • Ranked by: ${m.voterNames.join(', ')}` : ''})\n  ${m.description}`)
    .join('\n');

  // Classes: collect all ranked archetypes in order of preferential score
  const rankedClasses = (analysis['q_class_archetypes']?.sortedOptions || []).filter(o => o.score > 0);
  const classesList = (rankedClasses.length > 0 ? rankedClasses : (analysis['q_class_archetypes']?.sortedOptions?.slice(0, 4) || []))
    .map((c, idx) => `- **#${idx + 1} Core Class: ${c.title}** (${c.score > 0 ? `${c.score} pts` : 'Default'}${c.voterNames?.length > 0 ? ` • Ranked by: ${c.voterNames.join(', ')}` : ''})\n  ${c.description}`)
    .join('\n');

  // Mechanics: collect all ranked signature mechanics in order of preferential score
  const rankedMechanics = (analysis['q_signature_mechanics']?.sortedOptions || []).filter(o => o.score > 0);
  const mechanicsList = (rankedMechanics.length > 0 ? rankedMechanics : (analysis['q_signature_mechanics']?.sortedOptions?.slice(0, 4) || []))
    .map((m, idx) => `- **#${idx + 1} Mechanic: ${m.title}** (${m.score > 0 ? `${m.score} pts` : 'Default'}${m.voterNames?.length > 0 ? ` • Ranked by: ${m.voterNames.join(', ')}` : ''})\n  ${m.description}`)
    .join('\n');

  // Division of labor
  const roles = analysis['q_division_of_labor']?.sortedOptions?.filter(o => o.voteCount > 0 || o.score > 0).map(r => {
    return `- **${r.title}**: Owned by ${r.voterNames.join(', ')} (${r.description})`;
  }).join('\n') || '- Core Architecture: Joint pair programming with AI agents (flaxos & Scotty)';

  const teamList = state.team.map(m => `- **${m.name}** [${m.avatar}] (${m.weeklyHours} hrs/wk): Roles: ${m.rolePreferences?.join(', ') || 'Developer'}`).join('\n');

  // Dynamic values for Execution Protocol
  const topMission = analysis['q_mission_types']?.topPick?.title || 'SGC Gate Room Foothold / Iris Defense';
  const topClass = analysis['q_class_archetypes']?.topPick?.title || 'Heavy Support Marine (SG-3)';
  const secondClass = analysis['q_class_archetypes']?.sortedOptions?.[1]?.title || 'Tech Specialist & Archaeologist';
  const topMechanic = analysis['q_signature_mechanics']?.topPick?.title || 'Remote C4 & Beacon Distractions';
  const secondMechanic = analysis['q_signature_mechanics']?.sortedOptions?.[1]?.title || 'Transport Rings';

  return `# AGENTIC GAME DEV BOOTSTRAP PROMPT: STARGATE SG-1 / SG-3 TACTICAL EXTRACTION
> Project: Team Discovery Channel // SGC Cheyenne Mountain Initiative
> Collaborators: ${state.team.map(m => m.name).join(', ')}
> Repository: https://github.com/flaxos/Team-Discovery-Channel
> Status: Live Synced with Preferential Stack-Ranked Voting

---

### INSTRUCTIONS FOR CODING AGENT (Antigravity / Claude Code / Codex):
You are the Lead Systems Architect and Pair Programmer for **Team Discovery Channel**.
We are building a militarized **Stargate SG-1 / SG-3 Co-op Tactical Extraction Shooter**.
Our primary failure mode in past projects has been over-scoping, bespoke netcode yak-shaving, and abandoning projects before a playable build.
Your mission is to **enforce strict grounding**, keep architecture modular and testable, and deliver our **Milestone 1 First Playable Prototype** with zero fluff.

---

### 1. HIGH-CONCEPT & LORE HOOK
* **Title**: Stargate: SG Extraction (Team Discovery Channel)
* **Camera Perspective (Voted #1)**: ${perspective}
* **Core Tactical Loop (Voted #1)**: ${loop}
* **Engine & Pipeline (Voted #1)**: ${engine}
* **Visual Direction (Voted #1)**: ${artStyle} (Focus visual budget on Stargate puddle shader, glowing staff blasts, Zat arcs, and transport ring beams over high-poly assets)
* **Target Delivery Window (Voted #1)**: ${timeframe}

---

### 2. SQUAD-RANKED SIGNATURE MECHANICS (STACK RANKED)
${mechanicsList}

---

### 3. SQUAD-RANKED CLASSES & ARCHETYPES (STACK RANKED)
${classesList}

---

### 4. PRIORITY MISSION MODES (STACK RANKED)
${missionsList}

---

### 5. SQUAD ROSTER & PILLAR STEWARDSHIP
${teamList}

**Pillar Ownership**:
${roles}

---

### 6. TECHNICAL ARCHITECTURE SPECIFICATION
1. **Network Topology**:
   - Authoritative room server (or Godot high-level multiplayer / Node.js WebSocket relay).
   - Server validates DHD chevron inputs, weapon hitscan/projectile raycasts, and Jaffa aggro states.
   - Client prediction and interpolation for snappy player movement.
2. **Stargate & DHD State Machine**:
   - States: \`IDLE\` -> \`DIALING (Chevrons 1-7)\` -> \`KAWOOSH (Vortex FX)\` -> \`ACTIVE_WORMHOLE (38-min max / 60s extraction timer)\` -> \`DISENGAGED\`.
   - The Iris: SGC Gate receives GDO transmitter signal to open Iris before squad dives in.
3. **Zat'nik'tel State Rule**:
   - Hit 1: Stun target for 20s (silent, zero alert).
   - Hit 2 on stunned target: Vaporize / disintegrate corpse completely (removes body from patrol detection).

---

### 7. EXECUTION PROTOCOL (PHASE 1 - SPRINT 1 PLAYABLE DELIVERABLE)
Execute step-by-step:
1. **Scaffold Directory Layout**:
   \`\`\`
   /
   ├── client/           # Game client (${engine.includes('Godot') ? 'Godot 4 project' : 'Game client'})
   │   ├── scenes/       # GateRoom.tscn, AlienOutpost.tscn, Stargate.tscn, DHD.tscn
   │   ├── scripts/      # PlayerController, WeaponManager, JaffaAI, DHDDialer
   │   └── shaders/      # StargateEventHorizon.gdshader, TransportRing.gdshader
   ├── server/           # Room server & state validation
   ├── shared/           # Protocol constants, chevron codes, weapon stats
   └── docs/             # GDD.md, ROADMAP.md, NETCODE_SPEC.md
   \`\`\`
2. **Milestone 1 Deliverables (Tailored to Voted Stack)**:
   - **Step A (Environment & Netcode)**: 2-player synchronized movement in graybox environment focused on: **${topMission}**.
   - **Step B (Stargate Portal & Dialing)**: Working Stargate event horizon portal transition and DHD dialing sequence under fire.
   - **Step C (Voted Classes)**: Implement **${topClass}** (primary weapons & kit) and **${secondClass}** with damage registration and recoil.
   - **Step D (Voted Mechanics)**: Scaffold **${topMechanic}** and **${secondMechanic}**.
   - **Step E (Verification)**: Headless simulated bot test script asserting zero desync over 60 ticks.

---
*Chevron 7 is locked! Let's build and finish this game.*
`;
}

function generateGDD(state, analysis) {
  const perspective = analysis['q_camera_perspective']?.topPick?.title || 'Isometric / Top-Down 3D Tactical';
  const loop = analysis['q_stealth_to_loud_loop']?.topPick?.title || 'Full Recon -> C4 Sabotage -> Transport Ring Alarm -> DHD Dial Under Fire';
  const engine = analysis['q_engine_choice']?.topPick?.title || 'Godot 4.x (GDScript) + Low-Poly Asset Packs (Synty FBX/glTF)';
  const artStyle = analysis['q_visual_art_style']?.topPick?.title || 'Stylized Low-Poly 3D + Next-Gen Dynamic Lighting';
  const timeframe = analysis['q_grounding_timeframe']?.topPick?.title || 'The 2-Week SGC Vertical Slice';

  const missions = (analysis['q_mission_types']?.sortedOptions || []).filter(o => o.score > 0);
  const classes = (analysis['q_class_archetypes']?.sortedOptions || []).filter(o => o.score > 0);
  const mechanics = (analysis['q_signature_mechanics']?.sortedOptions || []).filter(o => o.score > 0);

  return `# GAME DESIGN DOCUMENT (GDD)
## Project SGC: Stargate SG-1 / SG-3 Tactical Extraction Shooter
> Team Discovery Channel Collaborative Initiative
> Stack-Ranked Consensus Outcome

---

### 1. Executive Summary & Core Hook
* **Tagline**: Step through the puddle. Sneak in. Plant the C4. Dial home under fire.
* **Genre**: Co-op Tactical Extraction Shooter & Wave Survival
* **Inspirations**: *Stargate SG-1*, *Helldivers 1*, *Door Kickers 2*, *Alien Swarm*, *GTFO*
* **Platform**: Desktop via ${engine}
* **Camera Perspective**: ${perspective}
* **Target Delivery Window**: ${timeframe}

---

### 2. The Grounding Pact & Anti-Scope Creep Rules
> **To ensure this game is completed within our sprint window**:
1. **Rule of Low-Poly Assets**: Zero custom high-poly modeling or 4K PBR texture baking. We use clean stylized low-poly meshes (Synty style) and invest our visual budget into shaders (Stargate kawoosh, staff plasma glow, transport ring beams).
2. **Rule of Shared Prefabs**: Every mission mode reuses the exact same Stargate, DHD, Jaffa AI, and weapon mechanics.
3. **The 2-Week Vertical Slice Gate**: No expanded lore or galaxy map before 2 players can connect, shoot Jaffa, dial the DHD, and extract through the puddle.

---

### 3. The Stealth-to-Loud Extraction Loop
\`\`\`mermaid
flowchart TD
    A["Cheyenne Mountain SGC Briefing Room"] --> B["Step Through Event Horizon (Wormhole Insertion)"]
    B --> C["Phase 1: Silent Recon & MALP Drone Scouting"]
    C --> D["Phase 2: Infiltration & Planting C4 on Goa'uld Objective"]
    D --> E["Phase 3: Alarm Tripped / C4 Detonation (Go Loud!)"]
    E --> F["Jaffa Transport Rings Drop from Orbiting Ha'tak"]
    F --> G["Running Gunfight Retreat to the Stargate"]
    G --> H["7-Chevron DHD Dialing Sequence Under Fire"]
    H --> I["Transmit SGC IDC Code to Open Iris"]
    I --> J["Dive Through Event Horizon Back to Earth!"]
\`\`\`

---

### 4. SGC Squad Classes (Stack-Ranked)
${classes.length > 0 ? classes.map((c, i) => `* **#${i + 1} ${c.title}** (${c.score} pts • Ranked by: ${c.voterNames?.join(', ') || 'Squad'}): ${c.description}`).join('\n') : `
* **Heavy Support Marine (SG-3 archetype)**: M249 SAW, claymore mines, deployable .50 cal tripod, rocket launcher.
* **Tech Specialist & Archaeologist (Carter/Daniel archetype)**: Fast DHD chevron dialer, GDO override, MALP/UAV scout drone.
* **Pointman / Recon Leader (O'Neill archetype)**: Suppressed P90, tactical C4, flashbangs, sprint dodge.
* **Allied Jaffa / Tok'ra Infiltrator (Teal'c archetype)**: Ma'Tok Staff weapon, Zat'nik'tel (1-shot stun / 2-shot kill), symbiote resilience.
`}

---

### 5. Signature Stargate Mechanics (Stack-Ranked)
${mechanics.length > 0 ? mechanics.map((m, i) => `* **#${i + 1} ${m.title}** (${m.score} pts • Ranked by: ${m.voterNames?.join(', ') || 'Squad'}): ${m.description}`).join('\n') : `
* **Remote C4 & Beacon Distractions**: Luring Jaffa patrols away from objectives with remote detonators.
* **Transport Rings**: Volumetric ring drops for enemy reinforcements and tactical player repositioning.
* **Authentic Zat Rules**: 1 shot stuns silently; 2nd shot vaporizes the corpse to prevent patrol detection.
* **The 7-Chevron DHD Dialing**: Physically dialing under enemy fire; transmitting GDO IDC code to open SGC iris.
`}

---

### 6. Priority Mission Archetypes (Stack-Ranked)
${missions.length > 0 ? missions.map((m, i) => `* **#${i + 1} ${m.title}** (${m.score} pts • Ranked by: ${m.voterNames?.join(', ') || 'Squad'}): ${m.description}`).join('\n') : `
* **SGC Iris Foothold Defense**: Wave defense inside Cheyenne Mountain Gate Room against Jaffa breach.
* **Goa'uld Outpost Sabotage**: Infiltrate fortress, C4 Naquadah reactor, extract.
* **Alpha Site Evacuation**: Hold defensive perimeter while civilians escape through the gate.
`}

---

### 7. Engine & Visual Polish
* **Engine**: ${engine}
* **Visual Direction**: ${artStyle}
`;
}

function generateRoadmap(state, analysis) {
  const timeframe = analysis['q_grounding_timeframe']?.topPick?.title || 'The 2-Week SGC Vertical Slice';
  const topMission = analysis['q_mission_types']?.topPick?.title || 'SGC Gate Room Foothold / Iris Defense';
  const topClass = analysis['q_class_archetypes']?.topPick?.title || 'Heavy Support Marine (SG-3)';
  const topMechanic = analysis['q_signature_mechanics']?.topPick?.title || 'Remote C4 & Beacon Distractions';
  
  const squad = state.team.map(m => {
    return `* **${m.name}** [${m.avatar}]: ${m.rolePreferences?.join(', ') || 'Developer'} (${m.weeklyHours}h/week)`;
  }).join('\n');

  return `# SGC EXPEDITION ROADMAP & SPRINT SCHEDULE
## Project: Team Discovery Channel // Stargate SG-1 / SG-3

### Squad Roster & Commitment
${squad}

### Sacred Development Rhythms
* **Weekly Playtest**: Every Friday at 8:00 PM on Discord (Dialing the gate together).
* **Grounding Rule**: No bespoke art before graybox 2-player co-op loop works.
* **Sprint Target**: ${timeframe}

---

### Sprints to Milestone 1 First Playable

#### 🚀 Sprint 0: Stargate Portal & Netcode Sync (Days 1 - 3)
* **Goal**: Two players connect, move synchronously in graybox **${topMission}**, and walk through the event horizon.
* **Deliverables**:
  - [ ] Authoritative room server with client-side interpolation.
  - [ ] Stargate portal pair (Earth Gate Room <-> Off-world).
  - [ ] Synchronized player movement with flashlight & aim direction.
  - [ ] Basic weapon firing with damage registration.
* **Lead Owners**: Stargate & Netcode Czar & AI Agent Orchestrator.

#### ⚔️ Sprint 1: Jaffa AI, ${topClass}, & ${topMechanic} (Days 4 - 8)
* **Goal**: Working squad classes, Jaffa patrol AI, and primary tactical mechanics.
* **Deliverables**:
  - [ ] Jaffa patrol AI with vision cones and gunshot audio radius.
  - [ ] Implement **${topClass}** loadout and second voted class.
  - [ ] Deployable **${topMechanic}** with remote detonation.
  - [ ] DHD dialing sequence (punching 7 chevrons to engage return wormhole).
  - [ ] First Friday Night SGC Playtest on Discord!
* **Lead Owners**: Tactical Combat Lead & Jaffa AI Scripter.

#### 💎 Sprint 2: Transport Rings, Polish & Complete Round (Days 9 - 14)
* **Goal**: Polished vertical slice ready for full group play.
* **Deliverables**:
  - [ ] Transport ring drop pod spawns for Jaffa shock troops.
  - [ ] Full round completion (Infiltration -> Objective -> DHD Dial -> Extraction).
  - [ ] Stargate kawoosh shader, sound effects, and screenshake on heavy impacts.
  - [ ] GDO Iris transmitter code override mechanic.
  - [ ] Squad celebration playtest!
* **Lead Owners**: Full Squad.
`;
}

function generateContract(state, analysis) {
  const timeframe = analysis['q_grounding_timeframe']?.topPick?.title || 'The 2-Week SGC Vertical Slice';

  return `# THE SGC GROUNDING PACT: ANTI-ABANDONMENT COVENANT
### Team Discovery Channel // Cheyenne Mountain Complex

We, the founding crew of **Team Discovery Channel**:
${state.team.map(m => `* **${m.name}** (${m.avatar})`).join('\n')}

solemnly pledge on this date to uphold this pact so that we **ship and enjoy our Stargate co-op game** rather than leaving another idea in the dev graveyard.

---

### Article I: The Core Covenant
> **"Gameplay & Stargate Feel Before Bespoke Art"**
We agree that all decisions bend to this rule. No asset, no refactor, and no clever feature shall delay having 2 players walk through the gate, shoot Jaffa, and dial home under fire.

### Article II: Target Timeframe
We commit to delivering Milestone 1 within **${timeframe}**. If a feature threatens this timeline, the feature is cut, not the deadline.

### Article III: The Scope Creep Defense
1. **The Shared Prefab Rule**: All mission types must share the exact same Stargate, DHD, weapons, and Jaffa AI components.
2. **The Fun Test**: If an idea cannot be prototyped with graybox primitives in under 2 hours with our coding agents, it waits for Milestone 2.
3. **No 2 AM Netcode Rewrites**: We stick to simple, rock-solid networking. No writing bespoke rollback netcode from scratch.

### Article IV: The Friday SGC Playtest
Every Friday at 8:00 PM, we hop on Discord, dial the gate, play whatever build exists, log bugs, and have fun.

---
**Signed by the Squad:**
${state.team.map(m => `- [x] ${m.name}`).join('\n')}
`;
}

module.exports = {
  analyzeVotes,
  generateBootstrapPrompt,
  generateGDD,
  generateRoadmap,
  generateContract
};
