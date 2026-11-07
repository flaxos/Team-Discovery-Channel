// Stargate SG-1 & SG-3 Tactical Extraction Shooter - Compiler Engine
// Synthesizes votes, custom ideas, and squad roles into production-ready prompts and specs

function analyzeVotes(state) {
  const summary = {};
  
  state.questions.forEach((q) => {
    // Sort options by vote count descending
    const sortedOptions = [...q.options].map(opt => ({
      ...opt,
      voteCount: (opt.votes || []).length,
      voterNames: (opt.votes || []).map(vId => {
        const m = state.team.find(t => t.id === vId);
        return m ? m.name : vId;
      })
    })).sort((a, b) => b.voteCount - a.voteCount);

    const maxVotes = sortedOptions[0] ? sortedOptions[0].voteCount : 0;
    const winners = sortedOptions.filter(o => o.voteCount === maxVotes && o.voteCount > 0);
    const runnerUps = sortedOptions.filter(o => o.voteCount < maxVotes && o.voteCount > 0);

    summary[q.id] = {
      question: q,
      sortedOptions,
      topPick: winners[0] || sortedOptions[0],
      isConsensus: winners.length === 1 && (winners[0].voteCount >= Math.ceil(state.team.length / 2)),
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

  // Mission types
  const missions = (analysis['q_mission_types']?.winners?.length > 0 
    ? analysis['q_mission_types'].winners 
    : analysis['q_mission_types']?.sortedOptions?.slice(0, 2) || []
  ).map(m => `- **${m.title}**: ${m.description}`).join('\n');

  // Classes
  const classes = (analysis['q_class_archetypes']?.winners?.length > 0
    ? analysis['q_class_archetypes'].winners
    : analysis['q_class_archetypes']?.sortedOptions?.slice(0, 3) || []
  ).map(c => `- **${c.title}**: ${c.description}`).join('\n');

  // Mechanics
  const mechanics = (analysis['q_signature_mechanics']?.winners?.length > 0
    ? analysis['q_signature_mechanics'].winners
    : analysis['q_signature_mechanics']?.sortedOptions?.slice(0, 3) || []
  ).map(m => `- **${m.title}**: ${m.description}`).join('\n');

  // Division of labor
  const roles = analysis['q_division_of_labor']?.sortedOptions?.filter(o => o.voteCount > 0).map(r => {
    return `- **${r.title}**: Owned by ${r.voterNames.join(', ')} (${r.description})`;
  }).join('\n') || '- Core Architecture: Joint pair programming with AI agents (flaxos & Scotty)';

  const teamList = state.team.map(m => `- **${m.name}** [${m.avatar}] (${m.weeklyHours} hrs/wk): Roles: ${m.rolePreferences?.join(', ') || 'Developer'}`).join('\n');

  return `# AGENTIC GAME DEV BOOTSTRAP PROMPT: STARGATE SG-1 / SG-3 TACTICAL EXTRACTION
> Project: Team Discovery Channel // SGC Cheyenne Mountain Initiative
> Collaborators: ${state.team.map(m => m.name).join(', ')}
> Repository: https://github.com/flaxos/Team-Discovery-Channel

---

### INSTRUCTIONS FOR CODING AGENT (Antigravity / Claude Code / Codex):
You are the Lead Systems Architect and Pair Programmer for **Team Discovery Channel**.
We are building a militarized **Stargate SG-1 / SG-3 Co-op Tactical Extraction Shooter**.
Our primary failure mode in past projects has been over-scoping, bespoke netcode yak-shaving, and abandoning projects before a playable build.
Your mission is to **enforce strict grounding**, keep architecture modular and testable, and deliver our **Milestone 1 First Playable Prototype** with zero fluff.

---

### 1. HIGH-CONCEPT & LORE HOOK
* **Title**: Stargate: SG Extraction (Team Discovery Channel)
* **Core Loop**: ${loop}
* **Camera Perspective**: ${perspective}
* **Target Delivery Window**: ${timeframe}
* **Engine & Pipeline**: ${engine}
* **Visual Direction**: ${artStyle} (Focus visual budget on Stargate puddle shader, glowing staff blasts, Zat arcs, and transport ring beams over high-poly assets)

---

### 2. CORE GAMEPLAY MECHANICS & STARGATE CANON
${mechanics}

### 3. SQUAD CLASSES (SGC ARCHETYPES)
${classes}

### 4. PRIORITY MISSION MODES (MILESTONE 1 FOCUS)
${missions}

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
2. **Milestone 1 Deliverables**:
   - Step A: 2-player synchronized movement in a graybox desert compound.
   - Step B: Working Stargate event horizon portal transition (walk into puddle -> teleport to off-world gate).
   - Step C: 1 primary firearm (P90) + 1 alien weapon (Ma'Tok Staff weapon) with damage registration.
   - Step D: Functional DHD that requires entering a 7-glyph sequence under fire to open the return wormhole.

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

  const missions = (analysis['q_mission_types']?.sortedOptions || []).filter(o => o.voteCount > 0);
  const classes = (analysis['q_class_archetypes']?.sortedOptions || []).filter(o => o.voteCount > 0);
  const mechanics = (analysis['q_signature_mechanics']?.sortedOptions || []).filter(o => o.voteCount > 0);

  return `# GAME DESIGN DOCUMENT (GDD)
## Project SGC: Stargate SG-1 / SG-3 Tactical Extraction Shooter
> Team Discovery Channel Collaborative Initiative

---

### 1. Executive Summary & Core Hook
* **Tagline**: Step through the puddle. Sneak in. Plant the C4. Dial home under fire.
* **Genre**: Co-op Tactical Extraction Shooter & Wave Survival
* **Inspirations**: *Stargate SG-1*, *Helldivers 1*, *Door Kickers 2*, *Alien Swarm*, *GTFO*
* **Platform**: Desktop (Windows/Linux/Mac) via ${engine}
* **Camera Perspective**: ${perspective}
* **Target Delivery Window**: ${timeframe}

---

### 2. The Grounding Pact & Anti-Scope Creep Rules
> **To ensure this game is completed within our sprint window**:
1. **Rule of Low-Poly Assets**: Zero custom high-poly modeling or 4K PBR texture baking. We use clean stylized low-poly meshes (Synty style) and invest our visual budget into shaders (Stargate kawoosh, staff plasma glow, transport ring beams).
2. **Rule of Shared Prefabs**: Every mission mode (Outpost Sabotage, Iris Wave Defense, Ha'tak Infiltration) reuses the exact same Stargate, DHD, Jaffa AI, and weapon mechanics.
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

1. **Insertion**: Squad emerges from the off-world Stargate onto an alien planetary outpost.
2. **Silent Recon**: Use suppressed P90s, MP5s, and 1-shot Zat stuns to clear sentries without sounding alarms.
3. **The Sabotage**: Plant remote C4 on Naquadah generators or weapons stockpiles; plant distraction beacons.
4. **The Alarm & Ring Drops**: Once C4 detonates, alarm klaxons sound. Transport rings slam down from orbiting Ha'taks, deploying Horus and Serpent guard strike teams.
5. **The DHD Holdout**: The squad retreats to the Stargate. One player must punch the 7 chevrons on the DHD under heavy fire, transmit the IDC code, and the squad extracts!

---

### 4. SGC Squad Classes
${classes.length > 0 ? classes.map(c => `* **${c.title}** (${c.voteCount} votes): ${c.description}`).join('\n') : `
* **Pointman / Recon Leader (O'Neill archetype)**: Suppressed P90, tactical C4, flashbangs, sprint dodge.
* **Tech Specialist & Archaeologist (Carter/Daniel archetype)**: Fast DHD chevron dialer, GDO override, MALP/UAV scout drone.
* **Heavy Marine (SG-3 archetype)**: M249 SAW, claymore mines, deployable .50 cal tripod, rocket launcher.
* **Allied Jaffa / Tok'ra Infiltrator (Teal'c archetype)**: Ma'Tok Staff weapon, Zat'nik'tel (1-shot stun / 2-shot kill), symbiote resilience.
`}

---

### 5. Signature Stargate Mechanics
${mechanics.length > 0 ? mechanics.map(m => `* **${m.title}**: ${m.description}`).join('\n') : `
* **The 7-Chevron DHD Dialing**: Physically dialing under enemy fire; transmitting GDO IDC code to open SGC iris.
* **Authentic Zat Rules**: 1 shot stuns silently; 2nd shot vaporizes the corpse to prevent patrol detection.
* **Transport Rings**: Volumetric ring drops for enemy reinforcements and tactical player repositioning.
* **Remote C4 Distraction**: Luring Jaffa patrols away from objectives with remote detonators.
`}

---

### 6. Priority Mission Archetypes
${missions.length > 0 ? missions.map(m => `* **${m.title}**: ${m.description}`).join('\n') : `
* **Goa'uld Outpost Sabotage**: Infiltrate fortress, C4 Naquadah reactor, extract.
* **SGC Iris Foothold Defense**: Wave defense inside Cheyenne Mountain Gate Room against Jaffa breach.
* **Alpha Site Evacuation**: Hold defensive perimeter while civilians escape through the gate.
`}

---

### 7. Engine & Visual Polish
* **Engine**: ${engine}
* **Visual Direction**: ${artStyle}
* **Key Shaders**:
  - Event horizon water ripple & Kawoosh vortex.
  - Ma'Tok staff weapon glowing orange/blue plasma bolts.
  - Zat'nik'tel electrical arc particles with disintegration dissolve.
  - Transport ring cylindrical volumetric beam.
`;
}

function generateRoadmap(state, analysis) {
  const timeframe = analysis['q_grounding_timeframe']?.topPick?.title || 'The 2-Week SGC Vertical Slice';
  
  const squad = state.team.map(m => {
    return `* **${m.name}** [${m.avatar}]: ${m.rolePreferences?.join(', ') || 'Developer'} (${m.weeklyHours}h/week)`;
  }).join('\n');

  return `# SGC EXPEDITION ROADMAP & SPRINT SCHEDULE
## Project: Team Discovery Channel // Stargate SG-1 / SG-3

### Squad Roster & Commitment
${squad}

### Sacred Development Rhythms
* **Weekly Playtest**: Every Friday at 8:00 PM on Discord (Dialing the gate together).
* **Grounding Rule**: No bespoke art before graybox 2-player DHD dialing works.
* **Sprint Target**: ${timeframe}

---

### Sprints to Milestone 1 First Playable

#### 🚀 Sprint 0: Stargate Portal & Netcode Sync (Days 1 - 3)
* **Goal**: Two players connect, move synchronously, and walk through the Stargate event horizon.
* **Deliverables**:
  - [ ] Authoritative room server with client-side interpolation.
  - [ ] Stargate portal pair (Earth Gate Room <-> Alien Outpost).
  - [ ] Synchronized player movement with flashlight & aim direction.
  - [ ] Basic P90 firing and staff weapon hitscan/projectile raycast.
* **Lead Owners**: Stargate & Netcode Czar & AI Agent Orchestrator.

#### ⚔️ Sprint 1: Jaffa AI, Stealth, & The DHD Sequence (Days 4 - 8)
* **Goal**: Complete stealth infiltration, C4 plant, alarm, and DHD dialing extraction.
* **Deliverables**:
  - [ ] Jaffa patrol AI with vision cones and hearing radius for gunshots.
  - [ ] Zat'nik'tel 1-shot stun and 2-shot body disintegration logic.
  - [ ] Deployable C4 with remote detonator.
  - [ ] DHD dialing minigame (punching 7 chevrons to engage return wormhole).
  - [ ] First Friday Night SGC Playtest on Discord!
* **Lead Owners**: Tactical Combat Lead & Jaffa AI Scripter.

#### 💎 Sprint 2: Transport Rings, Iris Foothold, & Game Feel Polish (Days 9 - 14)
* **Goal**: Polished vertical slice ready for full group play and wave survival.
* **Deliverables**:
  - [ ] Transport ring drop pod spawns for Jaffa shock troops.
  - [ ] Cheyenne Mountain SGC Iris Foothold wave defense mode.
  - [ ] Stargate kawoosh shader, sound effects, and screenshake on staff weapon impacts.
  - [ ] GDO Iris transmitter code override mechanic.
  - [ ] Full squad celebration playtest!
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
