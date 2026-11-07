# AGENTIC GAME DEV BOOTSTRAP PROMPT: STARGATE SG-1 / SG-3 TACTICAL EXTRACTION
> Project: Team Discovery Channel // SGC Cheyenne Mountain Initiative
> Collaborators: flaxos, Scotty
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
* **Camera Perspective (Voted #1)**: Isometric / Top-Down 3D Tactical (Helldivers 1, Alien Swarm, Synthetik)
* **Core Tactical Loop (Voted #1)**: Full Recon -> C4 Sabotage -> Transport Ring Alarm -> DHD Dial Under Fire
* **Engine & Pipeline (Voted #1)**: Godot 4.x (GDScript) + Low-Poly Asset Packs (Synty FBX/glTF)
* **Visual Direction (Voted #1)**: Stylized Low-Poly 3D + Next-Gen Dynamic Lighting (Synty × Deep Rock Galactic) (Focus visual budget on Stargate puddle shader, glowing staff blasts, Zat arcs, and transport ring beams over high-poly assets)
* **Target Delivery Window (Voted #1)**: The 2-Week SGC Vertical Slice (Recommended)

---

### 2. SQUAD-RANKED SIGNATURE MECHANICS (STACK RANKED)
- **#1 Mechanic: Remote C4 & Beacon Distractions** (3 pts • Ranked by: flaxos (#1))
  Plant C4 on a fuel depot on a far ridge. Trigger detonation to pull Jaffa patrols away from the central temple entrance, opening a silent infiltration window.
- **#2 Mechanic: Transport Rings (Enemy Spawns & Tactical Flanking)** (2 pts • Ranked by: flaxos (#2))
  Five glowing metallic rings slam down with iconic audio. Enemies arrive in drop waves, but clever players can throw grenades into descending rings or step inside to teleport across the compound.
- **#3 Mechanic: The 7-Chevron DHD Dialing Mini-Game Under Fire** (1 pts • Ranked by: flaxos (#4))
  Dialing isn't a simple button press! One player must punch the 7 glyph chevrons on the DHD (or hold a sequence like a Helldivers Stratagem) while teammates form a defensive firing arc. Transmit the IDC code before diving into the event horizon!
- **#4 Mechanic: Authentic Zat'nik'tel Rules (1-Shot Stun, 2-Shot Kill/Disintegrate)** (1 pts • Ranked by: flaxos (#3))
  1st shot silently incapacitates Jaffa guards for 20 seconds. 2nd shot kills and vaporizes the body completely, preventing patrols from discovering corpses and triggering alarms!
- **#5 Mechanic: MALP / UAV Scout Drone Recon** (1 pts • Ranked by: flaxos (#5))
  Pilot a wheeled MALP probe or miniature UAV drone through the Stargate first to map out Jaffa sentries, alarm horns, and Naquadah deposits on the squad's HUD.

---

### 3. SQUAD-RANKED CLASSES & ARCHETYPES (STACK RANKED)
- **#1 Core Class: Heavy Support Marine (SG-3 Marine)** (3 pts • Ranked by: flaxos (#1))
  M249 SAW light machine gun, claymore anti-personnel mines, deployable Browning .50 cal tripod, shoulder-fired rocket launcher for turret busting.
- **#2 Core Class: Tech Specialist & Archaeologist (The Carter / Daniel)** (2 pts • Ranked by: flaxos (#2))
  Armed with MP5. Fast DHD chevron dialer (cuts dial time in half), carries GDO transmitter for Iris override, deploys MALP/UAV scout drones, hacks Ancient terminals.
- **#3 Core Class: Pointman / Recon Leader (The O'Neill / Mitchell)** (1 pts • Ranked by: flaxos (#3))
  Suppressed P90, tactical C4 satchel, flashbangs, sprint dodge. Can tag enemies through walls and set remote detonators.
- **#4 Core Class: Allied Jaffa / Tok'ra Infiltrator (The Teal'c / Bra'tac)** (1 pts • Ranked by: flaxos (#4))
  Ma'Tok Staff weapon (heavy plasma blasts and melee parry), Zat'nik'tel (silent 1-shot stun / 2-shot kill), healing ribbon device, symbiote regeneration.

---

### 4. PRIORITY MISSION MODES (STACK RANKED)
- **#1 Priority: SGC Gate Room Foothold / Iris Defense (Horde Mode)** (3 pts • Ranked by: flaxos (#1))
  A foothold situation in Cheyenne Mountain! The Iris is breached. Defend the Gate Room from waves of incoming Jaffa, seal blast doors, set up Browning .50 cals, and hold until techs force-dial out.
- **#2 Priority: Goa'uld Outpost Sabotage & Extraction** (2 pts • Ranked by: flaxos (#2))
  Infiltrate a planetary fortress, plant C4 on a Naquadah power core or Tel'tak cargo ship, trigger a distraction, and fight back to the Stargate.
- **#3 Priority: Alpha Site / Village Evacuation Defense** (1 pts • Ranked by: flaxos (#3))
  Protect a human settlement or off-world Alpha Site from swarms of Jaffa landing via transport rings while civilians escape through the dialed Stargate.
- **#4 Priority: Ha'tak Mothership Infiltration (via Transport Rings)** (1 pts • Ranked by: flaxos (#4))
  Locate hidden transport rings on a planet surface, beam up into an orbiting Goa'uld Ha'tak, plant C4 on the hyperdrive crystal room, and ring back down before detonation.

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
2. **Milestone 1 Deliverables (Tailored to Voted Stack)**:
   - **Step A (Environment & Netcode)**: 2-player synchronized movement in graybox environment focused on: **SGC Gate Room Foothold / Iris Defense (Horde Mode)**.
   - **Step B (Stargate Portal & Dialing)**: Working Stargate event horizon portal transition and DHD dialing sequence under fire.
   - **Step C (Voted Classes)**: Implement **Heavy Support Marine (SG-3 Marine)** (primary weapons & kit) and **Tech Specialist & Archaeologist (The Carter / Daniel)** with damage registration and recoil.
   - **Step D (Voted Mechanics)**: Scaffold **Remote C4 & Beacon Distractions** and **Transport Rings (Enemy Spawns & Tactical Flanking)**.
   - **Step E (Verification)**: Headless simulated bot test script asserting zero desync over 60 ticks.

---
*Chevron 7 is locked! Let's build and finish this game.*
