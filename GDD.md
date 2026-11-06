# GAME DESIGN DOCUMENT (GDD)
## Team Discovery Channel: The Expedition

### 1. Executive Summary & High Concept
* **Tagline**: Scavenge, coordinate, survive the cosmic derelicts.
* **Genre**: Co-op Horde Survival (Vampire Survivors × Risk of Rain)
* **Tone**: Team Discovery: Derelict Deep Space Expeditions
* **Target Audience**: Our friend squad (2-4 simultaneous players) jumping into Discord for quick 15-minute adrenaline sessions.
* **Platform**: Cross-platform desktop/browser (Godot 4.x (GDScript)).

---

### 2. The Grounding Pact: Anti-Abandonment Framework
> **Why this game will actually finish**:
1. **Delivery Window**: The 48-Hour Weekend Jam Sprint.
2. **Guiding Covenant**: The 'Graybox First' Covenant.
3. **The Out-of-Scope Blacklist for v0.1**:
   - ❌ No complex persistent MMO database or inventory auction house.
   - ❌ No bespoke rollback netcode written from scratch.
   - ❌ No final bespoke character animations before graybox mechanics are proven fun.
   - ❌ No more than 3 enemy types in Sprint 1.

---

### 3. Core Gameplay Loop
```mermaid
flowchart LR
    A["Lobby / Drop Pod"] --> B["Hostile Sector Entry"]
    B --> C["Survive Waves / Secure Salvage"]
    C --> D["Synergy Combos & Super Meter"]
    D --> E["Clutch Extraction / Boss Encounter"]
    E --> F["Vault Upgrades in Hub"]
    F --> A
```

1. **Deployment**: Squad enters an abandoned deep space derelict with standard sidearms.
2. **Escalation**: Hostile sector swarms grow in density; hazards trigger environmental pressure.
3. **Team Synergy**: Players trigger elemental fusions and fill the shared team super meter.
4. **Extraction / Climax**: Call down the extraction beacon; hold out for 60 seconds of frantic survival.
5. **Debrief**: Review stats, unlock 1 new synergy module for the next expedition.

---

### 4. Gameplay Mechanics Matrix
#### 4.opt_mech_elemental_combos Synergistic Elemental Combos (Spell / Tech Fusing) (Votes: 2)
* **Description**: Player A lays down a Cryo Field or Oil Slick, Player B fires Lightning or Plasma into it to cause an Overload explosion. Teammates must coordinate!
* **Feasibility Rating**: `High`
* **Squad Rationale**: Approved by flaxos, Scotty.

#### 4.opt_mech_physics_chaos Physics Havoc & Hilarious Ragdolls / Knockback (Votes: 1)
* **Description**: Shockwaves knock enemies into environmental hazard pits, explosive barrels chain-react, bouncy shields reflect lasers.
* **Feasibility Rating**: `High`
* **Squad Rationale**: Approved by Scotty.

#### 4.opt_mech_shared_super Shared 'Discovery Super' Meter (Votes: 1)
* **Description**: The squad shares one giant energy gauge. When maxed, both players must simultaneously hit a button to trigger an epic screen-clearing super weapon.
* **Feasibility Rating**: `Very High`
* **Squad Rationale**: Approved by flaxos.

#### 4.opt_custom_1794003974716 Clutch Defibrillator & Friendly Revive Dome (Votes: 1)
* **Description**: When a teammate goes down, they enter a crawling beacon state. A surviving player can deploy a temporary shield dome to channel a 4-second revive.
* **Feasibility Rating**: `High`
* **Squad Rationale**: Approved by Scotty.


---

### 5. Technical & Multiplayer Architecture
* **Engine**: Godot 4.x (GDScript)
* **Networking Topology**: Authoritative WebSocket / Node.js Server (Colyseus or Custom Room State)
* **Tick Rate**: 30Hz or 60Hz server tick with snapshot interpolation.
* **Target Ping Resilience**: Smooth play up to 150ms ping via client prediction.

---

### 6. Art & Audio Direction
* **Visual Style**: 16-Bit Crisp Pixel Art (Retro Sci-Fi)
* **Color Palette**: High-contrast sci-fi dark space backgrounds with punchy saturated neon accents (cyan shield shields, amber lasers, emerald healing fields).
* **Game Feel & Juice**: Screenshake on critical impacts, subtle hitstop (freeze frames for 50ms on heavy blows), and dynamic camera zoom during team ultimates.
