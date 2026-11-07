# SGC EXPEDITION ROADMAP & SPRINT SCHEDULE
## Project: Team Discovery Channel // Stargate SG-1 / SG-3

### Squad Roster & Commitment
* **flaxos** [🚀]: AI Agent Orchestrator, Core Gameplay & Systems, Combat Feel & Juice (6h/week)
* **Scotty** [⚡]: Multiplayer & Netcode, Game Feel & Combat, Weapons & Perks Scripter (6h/week)

### Sacred Development Rhythms
* **Weekly Playtest**: Every Friday at 8:00 PM on Discord (Dialing the gate together).
* **Grounding Rule**: No bespoke art before graybox 2-player co-op loop works.
* **Sprint Target**: The 2-Week SGC Vertical Slice (Recommended)

---

### Sprints to Milestone 1 First Playable

#### 🚀 Sprint 0: Stargate Portal & Netcode Sync (COMPLETED ✅)
* **Goal**: Two players connect, move synchronously in graybox **SGC Gate Room Foothold / Iris Defense (Horde Mode)**, and walk through the event horizon.
* **Deliverables**:
  - [x] Authoritative room server with client-side interpolation (`SGCNetworkManager.gd`).
  - [x] Stargate portal with dynamic event horizon shader & sequential chevrons.
  - [x] Synchronized player movement with twin-stick aiming and camera smoothing.
  - [x] Basic weapon firing with damage registration and health components.

#### ⚔️ Sprint 1: Jaffa AI, Heavy Support Marine (SG-3 Marine), & Remote C4 (COMPLETED ✅)
* **Goal**: Working squad classes, Jaffa AI, and primary tactical mechanics.
* **Deliverables**:
  - [x] Jaffa patrol AI with Stargate ramp advance, Ma'Tok staff plasma fire, and melee strikes.
  - [x] Implement **Heavy Support Marine (SG-3 Marine)** loadout and 4 squad classes.
  - [x] Deployable Browning .50 Cal Tripod Turret and Remote C4 Satchels.
  - [x] DHD dialing sequence (Helldivers-style 7 chevrons under fire + 4-beat GDO Iris code).
  - [x] Full Tactical In-Game HUD (Vitals, Ammo, Wave Status, DHD Prompts).
  - [x] 9-Track Authentic Audio Soundbank (`client/audio/`).
  - [x] **UAT Fix**: Sequence reset on wrong DHD glyph or GDO beat with error buzzer SFX.

#### 💎 Sprint 2: Transport Rings, Balance & Combat Juice (Active)
* **Goal**: Polished vertical slice ready for full group play.
* **Deliverables**:
  - [x] Transport ring drop pod spawns for Jaffa shock troops.
  - [x] Full round completion (Wave Defense -> DHD Dial -> Extraction).
  - [x] Stargate kawoosh shader, sound effects, and forward vaporization.
  - [x] GDO Iris transmitter code override mechanic.
  - [ ] **Combat Juice & Balance (UAT-02)**: Deployable turret cooldown (30s, max 1 active) and C4 inventory limit (max 2).
  - [ ] Camera screenshake on Kawoosh eruption and Transport Ring slams.
  - [ ] Squad celebration playtest on Friday Night!
