# AGENTIC GAME DEV BOOTSTRAP PROMPT: STARGATE SG-1 / SG-3 TACTICAL EXTRACTION
> Project: Team Discovery Channel // SGC Cheyenne Mountain Initiative
> Collaborators: flaxos, Scotty
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
* **Core Loop**: Full Recon -> C4 Sabotage -> Transport Ring Alarm -> DHD Dial Under Fire
* **Camera Perspective**: Isometric / Top-Down 3D Tactical (Helldivers 1, Alien Swarm, Synthetik)
* **Target Delivery Window**: The 2-Week SGC Vertical Slice (Recommended)
* **Engine & Pipeline**: Godot 4.x (GDScript) + Low-Poly Asset Packs (Synty FBX/glTF)
* **Visual Direction**: Stylized Low-Poly 3D + Next-Gen Dynamic Lighting (Synty × Deep Rock Galactic) (Focus visual budget on Stargate puddle shader, glowing staff blasts, Zat arcs, and transport ring beams over high-poly assets)

---

### 2. CORE GAMEPLAY MECHANICS & STARGATE CANON
- **The 7-Chevron DHD Dialing Mini-Game Under Fire**: Dialing isn't a simple button press! One player must punch the 7 glyph chevrons on the DHD (or hold a sequence like a Helldivers Stratagem) while teammates form a defensive firing arc. Transmit the IDC code before diving into the event horizon!
- **Authentic Zat'nik'tel Rules (1-Shot Stun, 2-Shot Kill/Disintegrate)**: 1st shot silently incapacitates Jaffa guards for 20 seconds. 2nd shot kills and vaporizes the body completely, preventing patrols from discovering corpses and triggering alarms!
- **Transport Rings (Enemy Spawns & Tactical Flanking)**: Five glowing metallic rings slam down with iconic audio. Enemies arrive in drop waves, but clever players can throw grenades into descending rings or step inside to teleport across the compound.

### 3. SQUAD CLASSES (SGC ARCHETYPES)
- **Pointman / Recon Leader (The O'Neill / Mitchell)**: Suppressed P90, tactical C4 satchel, flashbangs, sprint dodge. Can tag enemies through walls and set remote detonators.
- **Tech Specialist & Archaeologist (The Carter / Daniel)**: Armed with MP5. Fast DHD chevron dialer (cuts dial time in half), carries GDO transmitter for Iris override, deploys MALP/UAV scout drones, hacks Ancient terminals.
- **Heavy Support Marine (SG-3 Marine)**: M249 SAW light machine gun, claymore anti-personnel mines, deployable Browning .50 cal tripod, shoulder-fired rocket launcher for turret busting.

### 4. PRIORITY MISSION MODES (MILESTONE 1 FOCUS)
- **Goa'uld Outpost Sabotage & Extraction**: Infiltrate a planetary fortress, plant C4 on a Naquadah power core or Tel'tak cargo ship, trigger a distraction, and fight back to the Stargate.
- **SGC Gate Room Foothold / Iris Defense (Horde Mode)**: A foothold situation in Cheyenne Mountain! The Iris is breached. Defend the Gate Room from waves of incoming Jaffa, seal blast doors, set up Browning .50 cals, and hold until techs force-dial out.

---

### 5. SQUAD ROSTER & PILLAR STEWARDSHIP
- **flaxos** [🚀] (6 hrs/wk): Roles: AI Agent Orchestrator, Core Gameplay & Systems, Combat Feel & Juice
- **Scotty** [⚡] (6 hrs/wk): Roles: Multiplayer & Netcode, Game Feel & Combat, Weapons & Perks Scripter

**Pillar Ownership**:
- Core Architecture: Joint pair programming with AI agents (flaxos & Scotty)

---

### 6. TECHNICAL ARCHITECTURE SPECIFICATION
1. **Network Topology**:
   - Authoritative room server (or Godot high-level multiplayer / Node.js WebSocket relay).
   - Server validates DHD chevron inputs, weapon hitscan/projectile raycasts, and Jaffa aggro states.
   - Client prediction and interpolation for snappy player movement.
2. **Stargate & DHD State Machine**:
   - States: `IDLE` -> `DIALING (Chevrons 1-7)` -> `KAWOOSH (Vortex FX)` -> `ACTIVE_WORMHOLE (38-min max / 60s extraction timer)` -> `DISENGAGED`.
   - The Iris: SGC Gate receives GDO transmitter signal to open Iris before squad dives in.
3. **Zat'nik'tel State Rule**:
   - Hit 1: Stun target for 20s (silent, zero alert).
   - Hit 2 on stunned target: Vaporize / disintegrate corpse completely (removes body from patrol detection).

---

### 7. EXECUTION PROTOCOL (PHASE 1 - SPRINT 1 PLAYABLE DELIVERABLE)
Execute step-by-step:
1. **Scaffold Directory Layout**:
   ```
   /
   ├── client/           # Game client (Godot 4 project)
   │   ├── scenes/       # GateRoom.tscn, AlienOutpost.tscn, Stargate.tscn, DHD.tscn
   │   ├── scripts/      # PlayerController, WeaponManager, JaffaAI, DHDDialer
   │   └── shaders/      # StargateEventHorizon.gdshader, TransportRing.gdshader
   ├── server/           # Room server & state validation
   ├── shared/           # Protocol constants, chevron codes, weapon stats
   └── docs/             # GDD.md, ROADMAP.md, NETCODE_SPEC.md
   ```
2. **Milestone 1 Deliverables**:
   - Step A: 2-player synchronized movement in a graybox desert compound.
   - Step B: Working Stargate event horizon portal transition (walk into puddle -> teleport to off-world gate).
   - Step C: 1 primary firearm (P90) + 1 alien weapon (Ma'Tok Staff weapon) with damage registration.
   - Step D: Functional DHD that requires entering a 7-glyph sequence under fire to open the return wormhole.

---
*Chevron 7 is locked! Let's build and finish this game.*
