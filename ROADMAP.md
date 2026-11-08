# SGC EXPEDITION ROADMAP & SPRINT SCHEDULE
## Project: Team Discovery Channel // Stargate SG-1 / SG-3 Tactical Extraction
**Target Engine:** Godot 4.4.1 (Strict Static GDScript, Native ENet Multiplayer)

---

### Squad Roster & Commitment
* **flaxos** [🚀]: Lead AI Agent Orchestrator, Core Gameplay & Systems, Combat Feel & Juice
* **Scotty** [⚡]: Multiplayer & Netcode, Game Feel & Combat, Weapons & Perks Scripter

---

### Sprint History & Completed Milestones

#### 🚀 Sprint 0: Stargate Portal & Netcode Sync (COMPLETED ✅)
* Authoritative listen server with client-side interpolation (`SGCNetworkManager.gd`).
* Stargate portal with dynamic event horizon shader & sequential chevrons.
* Synchronized player movement with twin-stick aiming and camera smoothing.
* Basic weapon firing with damage registration and health components.

#### ⚔️ Sprint 1: Jaffa AI, SG-3 Marine & Remote C4 (COMPLETED ✅)
* Jaffa patrol AI with Stargate ramp advance, Ma'Tok staff plasma fire, and melee strikes.
* SG-3 Heavy Support Marine loadout and 4 squad classes.
* Deployable Browning .50 Cal Tripod Turret and Remote C4 Satchels.
* DHD dialing sequence (Helldivers-style 7 chevrons under fire + 4-beat GDO Iris code).
* Tactical HUD (Vitals, Ammo, Wave Status, DHD Prompts) & 9-Track Audio Soundbank.

#### 💎 Sprint 2: Transport Rings, Combat Juice & Fallback Hallway (COMPLETED ✅)
* 2-Way Goa'uld Transport Rings network between Gate Room and Fallback Hallway.
* Sliding steel blast doors with interactive `[E]` console toggle and hydraulic audio.
* 20m Fallback Security Hallway with heavy sandbags and pre-mounted .50 Cal tripod.
* M18A1 Directional Claymore Mines with 120-degree lethal forward blast.
* Option C Dynamic Aim-Lead Camera & Multi-Ray Wall Occlusion Transparency.

#### 🛡️ Sprint 3: Multi-Sector Assault & Shock Guard Variant (COMPLETED ✅)
* Heavy Jaffa Shock Guard variant (140 HP, armor spark deflection, rapid double burst).
* Multi-sector wave escalation: Ramp assault, ring flanks, and overwhelming fallback climax.
* Dynamic low-health red vignette & native 4-channel audio bus layout.

#### 💉 Sprint 4: Co-op Bleedout, Squadmate Revive & In-Game Settings (COMPLETED ✅)
* Operative downed/bleedout state (20s countdown, prone crawl, M9 Last Stand sidearm).
* Squadmate hold-`[E]` revive channel (2.5s) with real-time HUD progress bar.
* Squad wipe defeat condition & SGC Tactical After Action Debriefing Report.
* In-game pause menu with real-time Master/SFX/Ambience audio volume sliders.

#### 🔒 Sprint 5: Production Hardening & Dedicated Server Mode (COMPLETED ✅)
* Dedicated headless server mode with CLI argument parser (`--server`, `--port`, `--name`).
* In-world 3D nameplates with callsigns and high-visibility through-wall bleedout beacons.
* Dynamic SGC emergency strobe lighting and bloom during wave climax.
* Dynamic 3D weapon meshes and muzzle flash anchors.
* Client auto-reconnection and graceful disconnect recovery.

#### 🗺️ Sprint 6: Cheyenne Mountain Level 28 Full Map Expansion (COMPLETED ✅)
* Built out Sublevel 28 bunker sectors: Armory, Munitions Depot, Elevator Lobby, Connector Tunnel, Round Hallway Rotunda, and Offworld Research Lab.
* Multi-point navigation mesh and void boundary safety nets.

#### 🎯 Sprint 7: Tactical Cover Stance & Peeking Mechanics (COMPLETED ✅)
* Dynamic cover detection behind sandbags and low walls (`groups=["cover"]`).
* Auto-crouch and peek-to-shoot mechanics with reduced hitbox profile.
* Staff weapon rebalancing: reduced fire rate, increased plasma bolt speed and damage.
* Canonical Zat'nik'tel 1-2-3 rule: 1 shot stun, 2 shots kill, 3 shots vaporize corpse.

#### 🏢 Sprint 8: Level 27 Mezzanine & Multi-Floor Ballistic Combat (COMPLETED ✅)
* Level 27 Briefing Room & General's Office with observation overlook windows.
* Multi-floor vertical ballistics: downward sniper fire and upward plasma counter-attacks.
* Dynamic camera elevation controller (12m on L28 <-> 17.5m on L27).
* Jaffa spiral staircase flanking route between sublevels.

#### 🧰 Sprint 9: SGC Interactive Complex & Climax Incursion (COMPLETED ✅)
* Armory ammo resupply crates and weapon racks for real-time loadout swapping.
* General's Emergency Defense Terminal with automated sentry deployment and blast door lockdown.
* Security Station CCTV multi-monitor surveillance switching.
* Foothold Climax Incursion: multi-sector assault across Gate Room, Armory, and Level 27.

#### 🎮 Sprint 10: UAT Controls, Ghost Recon ADS & SGC Layout Polish (COMPLETED ✅)
* Ghost Recon Wildlands style over-the-shoulder ADS camera zoom.
* Camera-relative WASD strafing in both isometric and ADS views.
* Centered Stargate spawns facing the gate with twin flanking .50 Cal turrets.
* Defeat/Victory HUD navigation with mission retry and return to briefing buttons.

#### 💻 Sprint 11: Lore Consolidation & Control Room Command Consoles (COMPLETED ✅)
* Decoupled offworld DHD and transport rings from SGC Sublevel 28 (reserved for offworld maps).
* Installed SGC Dialing Computer terminal in Control Room Mezzanine.
* Iris manual override safety throw lever and trinium status diagnostics.

#### ⏱️ Sprint 12: 38-Second Incursion Engine & Tug-of-War Waves (COMPLETED ✅)
* 38-Second wormhole physics limit translated into high-intensity arcade-tactical defense windows.
* Inbound wormhole collapse, 20s capacitor recharge, and resupply phases.
* 3-Tier difficulty: Easy (1 surge), Medium (2-3 surges), Hard (4-5 surges).

#### 🧪 Sprint 13: Hard Mode Goa'uld Buffer Virus & Lab Patch Drive (COMPLETED ✅)
* Goa'uld dialing buffer virus corruption on SGC mainframe.
* Lab data patch drive retrieval objective from Offworld Research Lab.
* Uploading patch drive under fire to restore outbound dialing capabilities.

#### 🤖 Sprint 14: SGC Airmen Fireteam AI & Tactical Downed Revives (COMPLETED ✅)
* Autonomous SGC Airmen NPC defenders scrambling to Gate Room and mounting .50 cal turrets.
* Two-way revive mechanics: Airmen revive downed players and players revive downed Airmen.
* Tactical ping command wheel (`[Q]` / middle click) to issue Move, Regroup, Defend, and Mount Turret orders.

#### 🛡️ Sprint 15: Squad Tactical Gear & 3-Stage Iris Repair (COMPLETED ✅)
* Deployable tactical ballistic shield (`[4]`) with directional damage absorption.
* M18 Smoke Grenades (`[5]`) creating visual obscuration zones against enemy targeting.
* Segmented 3-stage Iris servo repair minigame under fire in the Gate Room.
* Armory restocking stations for tactical consumables.

#### 🚪 Sprint 16: Level 28 Connectivity, 360 Orbit & Fog of War (COMPLETED ✅)
* Unified Level 28 floor geometry ($Y = 0.0\text{ m}$ continuous across all sectors).
* Removed all step obstacles, cliffs, and ramp collision boxes (`ControlSouthRamp`, `ControlRoomEntryRamp`, `ConnectorRamp`, `ControlDoorFrame`).
* Unconstrained 360-degree tactical isometric camera yaw orbit via mouse motion.
* Interactive blast door consoles across Central, West, and East bulkheads.
* 3-Tier Fog of War sector shrouding with dynamic hostile entity and objective pickup culling.
* AI hallway waypoint navigation avoiding solid walls and forbidding wall-aiming/shooting.
* Exhaustive 20-waypoint automated regression test suite passing 100%.

---

### Upcoming Sprints & Active Development

#### 🎯 Sprint 17: Auto Y-Axis Plane Auto-Locking & Advanced Elevation Aiming (CURRENT UAT TARGET)
* **Goal**: Solve aiming across vertical steps, stairs, platforms, and balconies by automatically locking the aiming plane to the true target elevation.
* **Core Deliverables**:
  - [ ] **Auto Y-Axis Plane Auto-Locking (`PlayerController3D.gd`)**:
    - **Dynamic Ground / Platform Elevation Auto-Detection**: Mouse crosshair raycast queries vertical terrain to auto-lock the horizontal aim plane to the true floor/platform height under cursor ($Y = 0.0$ arena floor, $Y = 1.0$ gate ramp/platform, $Y = 5.5$ Level 27 mezzanine).
    - **Enemy Target Elevation Snapping**: When the crosshair hovers near or over an enemy entity, the aim plane automatically snaps to the target's center of mass ($Y = \text{target.y} + 1.0$), ensuring bullets travel at chest height without manual pitch adjustments.
    - **Anti-Wall Ray Climbing Filter**: Raycast ignores sheer vertical walls ($|\text{normal.y}| < 0.2$), preventing reticle snapping to ceilings when aiming near corridor corners.
    - **Smooth Elevation Transition (Slerp/Lerp)**: Smoothly interpolates the locked $Y$-plane between elevations to prevent reticle jitter across stairs and ramps.
  - [ ] **Multi-Elevation Weapon Pitch Synchronization**:
    - Synchronize weapon 3D mesh pitch angle with the locked Y-axis target plane for realistic upward/downward ballistic trajectories.
    - Auto-aim assist cone for controller/keyboard operatives targeting across different vertical planes.
  - [ ] **Automated Multi-Elevation Aiming Verification Test**:
    - `test_sprint17_auto_y_plane_locking.gd`: validates crosshair elevation snapping across Gate Room arena ($Y=0$), Gate Ramp ($Y=1.0$), Briefing Overlook ($Y=5.5$), and enemy bounding boxes.

#### 🌍 Sprint 18: Offworld Expedition Theater: Abydos Temple & Desert Dunes
* **Goal**: Deploy SG-1 / SG-3 on the first outbound mission through the Stargate to an offworld combat theater.
* **Core Deliverables**:
  - [ ] Reintroduce canonical **DHD Pedestal (`DHDDialer.gd`)** on offworld sandy terrain for outbound return dialing.
  - [ ] Reintroduce **Goa'uld Transport Rings** inside pyramid temple outposts.
  - [ ] Sandstorm weather particle effects, outdoor combat spacing, and sniper dune perimeters.
  - [ ] Outbound wormhole transit sequence: entering the event horizon triggers map change to Offworld Theater.

#### 🛸 Sprint 19: Ha'tak Mothership Infiltration & Stealth Tactics
* **Goal**: Deep infiltration mission behind enemy lines on a Goa'uld mothership.
* **Core Deliverables**:
  - [ ] Silent takedowns with Zat'nik'tel 1-shot stun.
  - [ ] Glider bay sabotage with remote C4 satchels.
  - [ ] Dynamic stealth alert state machine (Unaware -> Suspicious -> Full Alert).
  - [ ] Jaffa patrol routes, alarm klaxons, and bulkhead containment fields.
