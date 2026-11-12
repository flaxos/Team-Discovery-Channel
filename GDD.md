# Game design: Stargate SG Extraction

A Stargate-inspired, four-player tactical co-op shooter about reconnaissance, infiltration, combat, objectives and extraction. Built in **Godot 4.4.1** with native ENet multiplayer.

This document keeps two things apart: **Part 1** is what the game does today, **Part 2** is what it is meant to become. Reconciled 12 November 2026 against `main` at `bf56743`. Delivery order is in the [roadmap](ROADMAP.md); evidence for every status claim is in the [capability matrix](docs/plans/master-development-roadmap.md#2-capability-matrix).

---

# Part 1 — The game as implemented

## Selectable missions

| Mission | Play | Standing |
|---|---|---|
| **SGC Defense — Levels 28/27/26** | Defend the base against incoming Jaffa, meet the difficulty's objectives, dial an authorised outbound gate and extract | The most complete mission |
| **SGC UAT Base — No Hostile Activation** | The same geometry and props with hostile activation and waves disabled | Exploration and interaction testing |
| **Goa'uld Infiltration — Greybox** | Sabotage the generator, download command records on the upper deck and return to the Stargate, through a compound guarded by sentries that see and hear, with alarm consoles, reinforcements and barricades; a guarded checkpoint route and a quiet service route | Greybox testbed for stealth. No alarm, reinforcements or Goa'uld art yet. See [its guide](docs/maps/goauld-infiltration-mission.md) |
| **Modular Extraction UAT — Development** | Deploy into a modular test facility, reach the command room, download from a console, return to the insertion point; five Jaffa patrol | A development slice on neutral placeholder rooms. No gate, stealth, alarm or reinforcements. See [its guide](docs/maps/modular-extraction-mission.md) |

No mission has a signed human acceptance run yet. The **Stargate in the infiltration compound is inert**: insertion is a spawn beside it and extraction is walking back to it.

### SGC Defense rules

| Difficulty | Outbound requirements |
| --- | --- |
| Easy | At least three cleared incursions. |
| Medium | Three cleared incursions plus the lab-ROM dialing-computer upgrade. |
| Hard | Medium requirements plus iris repair during an active incoming breach. |

Incoming windows default to 38 seconds, followed by 20-second recharge periods. Pressure continues until requirements are satisfied. A valid outbound dial reserves the gate against new incoming activation. Dialing uses seven chevrons and four GDO beats; extraction requires an authorized outbound gate. These are game timings rather than the television show's maximum wormhole duration.

### Modular Extraction rules

Objectives are sequential and decided by the server. Extraction succeeds when every standing operative is in the zone and at least one is; downed operatives neither block it nor are required. If nobody is standing the mission fails. The first result is final.

## Space and visual direction (SGC)

The SGC includes Level 28 embarkation, operations and combat corridors; Level 27 briefing, command and security; and Level 26 support, staging, storage and service rooms. Operations is 1.5 m above embarkation behind sealed glazing, with side/rear stairs. Briefing overlooks the chamber from 5.5 m. Main floor elevations are 0, 5.5 and 11 m; Level 25 is excluded.

The 6.7 m gate sits in a 24 m wide, 12 m high chamber. The layout follows referenced SG-1 relationships, with gameplay proportions and authored peripheral/support spaces rather than a claim of measured blueprint accuracy. Muted concrete, charcoal steel, subdued lighting, ceiling panels/beams and clear thresholds support the former-silo setting. Independent control/briefing shutters remain inside their frames.

Generated modules carry dimensions, material briefs and replacement-art slots. Visual replacement preserves gameplay collision and rejects oversized assets. See the [SGC map contract](docs/maps/sgc.md) for provenance, palette and schema.

## Modular facilities

Offworld interiors are assembled from a separate modular kit: structural rooms with sockets, functional room presets (barracks, checkpoint, generator, command, ring room and others), multi-deck ramps and reusable composites, saved as native layout resources. Layouts are authored in a visual editor or through the shared [AI authoring CLI](docs/maps/ai-level-authoring.md), which can plan a map from a room graph and check route requirements.

Every modular room currently renders in a neutral placeholder style. Faction themes exist as identifiers only. Room presets place props and named markers; they do not add behaviour. The ring-transport and gate presets place the real props, inert.

## Classes and combat

| Class | Primary | Secondary | Health | Class gadget in code |
| --- | --- | --- | --- | --- |
| SG-3 Heavy Support Marine | M249 | M9 | 150 | Deployable .50 cal tripod |
| Tech Specialist & Archaeologist | MP5 | Zat | 100 | None |
| Pointman / Recon Leader | P90 | M9 | 120 | C4 satchels (timed or remote) |
| Allied Jaffa / Tok'ra Infiltrator | Staff weapon | Zat | 160 | None |

All classes can use claymores, the ballistic shield, smoke, body dragging, revive and squad orders. The SGC adds resupply and armour stations, weapon racks and fixed turrets. Zat progression is stun, kill, then corpse vaporization; stun defaults to 20 seconds. A downed operative bleeds out in 20 seconds and is revived to 40% health.

The lobby's class descriptions also mention a rocket launcher, flashbangs, a sprint dodge, a MALP scout, faster dialling, a melee parry and symbiote regeneration. **None of these is implemented.** Treat that text as aspiration until the roles are designed (roadmap workstream H).

Players use a tactical third-person camera with shoulder ADS and camera-relative movement. The squad radial works while holding ADS. Persistent remapping supports keyboard/mouse alternatives, conflict resolution and live prompts. [Playing](docs/PLAYING.md) is the control reference.

## AI as implemented

**Jaffa** march in columns, advance through the SGC, patrol named room markers on modular levels, open unlocked doors, and fight with staff weapons and melee. In the SGC they take sandbag cover and flank by fixed corridor points. On modular levels they crouch behind low cover props (barricades, crates), stand to fire over them and move when flanked; where a room has no such prop they fall back to a room-centre marker.

**Detection depends on the Jaffa's role.** *Patrols* (modular missions) are sentries: they see inside a view cone with line of sight, become suspicious before they are alerted, show a **?** or **!** overhead, alert patrols nearby, and search the last seen position before resuming their route. Damage alerts them at once. *Gate waves and column marches* (SGC Defense) keep the original assault rule: the nearest operative in sight within about 33 m, or failing that any operative within 22 m regardless of walls. All Jaffa fire only with line of sight, and target a downed operative only when no standing one is in reach. Smoke blocks sight. Patrols also **hear** gunfire and explosions within a straight-line radius per weapon (Carter's suppressed MP5 about 6 m, rifles 25–40 m, C4 45 m) and go to search the source; walls do not muffle. A search looks around the position, then checks a few points nearby before the patrol resumes.

**Compound alert (modular missions).** Once a sentry is alerted the compound is *alerted*, and the alerted sentry nearest a working alarm console runs for it, marked **!!**. If it works the console for a couple of seconds the alarm sounds: a klaxon, every sentry searches where the squad was last seen, and reinforcement groups arrive once each, up to the mission's budget. Operatives can disable consoles before that, and killing or stunning the runner stops the run. Without an alarm the compound calms down after a few quiet seconds. The infiltration mission has two consoles and four reinforcements; the extraction UAT has none.

**Airmen** follow squad orders, hold corners, leapfrog, crew turrets and revive in the SGC. On modular levels they can be ordered to a position; their tactical behaviour still depends on SGC sector names.

Both factions share one navigator. In the SGC it plans over regions, stairs and the lift with passage reservations; on modular levels it follows the baked navigation mesh. Movement never teleports an actor. Known gaps: no avoidance between NPCs, no route around a locked door, doors are left open.

## World and network contracts

Mission, combat, AI and shared interactions are server controlled. Joining and retrying clients receive the selected mission and difficulty and the current gate, objective, NPC, door, shutter and lift state. UI observes those states. One world is loaded per mission; there is no travel between worlds, and walking into the authorised gate ends the SGC mission. See [architecture](docs/ARCHITECTURE.md).

In the SGC, walking portals share a room boundary; exterior walls, floors, ceilings and shafts must close the shell, and enclosure failure blocks the map bake. The lift serves three floors and riders remain grounded.

---

# Part 2 — The intended game

Nothing in this part is implemented unless Part 1 says so.

## The loop

SGC preparation → Stargate deployment → offworld reconnaissance → stealth or combat approach → objective completion → dynamic enemy response → squad extraction → return to SGC → debrief and persistent outcomes.

Inspirations: Stargate SG-1, Helldivers, Door Kickers, Alien Swarm, GTFO.

## Pillars

1. **The approach is a choice.** A mission can be done quietly or loudly, and the level offers more than one route.
2. **Being seen escalates; it does not end the mission.** Detection leads to alarm, reinforcements and a harder extraction.
3. **Getting out is the climax.** Objectives are the middle; the run home under pressure is the end.
4. **Four roles, one squad.** Classes differ in what they enable for the team, not only in damage.
5. **Shared parts.** Every mission type uses the same gate, weapons, enemies and mission framework ([team contract](TEAM_CONTRACT.md)).

## Stealth and enemy response (design intent)

- Enemies notice by sight within a view cone and, later, by sound. Awareness is graded (unaware, suspicious, alerted) and visible to players as a tell, with time to react.
- A patrol that loses its target investigates the last place it saw one, then searches, then returns to its route.
- An alerted enemy tries to raise a level-wide alarm. The alarm brings reinforcements up to a budget and can change the level (locked doors, more patrols).
- Quiet tools (Zat stun, later takedowns and thrown weapons) trade speed and ammunition for staying unnoticed. Loud tools are faster and draw attention.
- Cover is real geometry, for both sides.

## Mission styles and the systems they share

Mission styles are configurations of shared systems, not separate engines.

| Style | Built from | Additionally needs |
|---|---|---|
| SGC defence | Exists | — |
| Goa'uld compound infiltration | Modular mission host, objectives, patrols | Perception, alert and reinforcements |
| Sabotage | Interact objective | A timed escape (mission timer event) |
| Intelligence retrieval | Interact objective (the current console download) | Optionally a carried item |
| Rescue and prisoner extraction | Detention preset, friendly follow orders | An escort objective |
| Alpha Site defence or evacuation | Reinforcement events, modular level | Defence waves off the SGC gate; escort for evacuees |
| Civilian protection | Escort objective | A protected-NPC failure rule |
| Ha'tak infiltration | Goa'uld kit, multi-deck layouts | Working ring transport |
| Multi-stage missions | All of the above | Mission stages; gate travel |
| Linked campaign | — | Persistent outcomes |

The shared systems are therefore: the mission host and objective list, perception and alert, a small event layer (reinforce, door, timer), gate travel, and co-op state. That is the order the roadmap builds them in.

## Stargate travel

The squad prepares in the SGC, dials, and steps through together into the offworld mission carrying its health and ammunition; it dials home from an offworld DHD and returns to a debrief. The intended approach is one world loaded at a time with mission state held above the world ([decision D-002](docs/DECISIONS.md)). Transport rings become short-range travel inside ships and bases. MALP or UAV reconnaissance remains an idea without a design.

## Factions and places

| Place | Character | Distinctive needs |
|---|---|---|
| Goa'uld compounds and motherships | Angular, monumental, gold and stone, ring rooms | First art kit; ring transport; shielded and officer enemies |
| Tau'ri Alpha Sites | Prefabricated military, close to the SGC palette | Defence and evacuation play |
| Asgard ships and bases | Clean, bright, sparse | Its own kit; beaming |
| Tok'ra tunnels | Crystalline, organic tunnels | Probably new tunnel modules |
| Replicator structures | Block-built, shifting | A new enemy type |
| Outdoor gate sites, villages, outposts | Terrain, cliffs, forest | A separate terrain authoring path ([decision D-006](docs/DECISIONS.md)) |

Art for all of these is original work inspired by the setting, fitted to the existing theme contract so that it never changes collision or navigation.

## Special weapons and faction mechanics (to be designed)

Stealth takedowns, knife and thrown weapons, and Goa'uld personal shields that stop fast projectiles and are beaten by slow attacks or flanking. Each is to be specified as an interaction with perception and alert before it is built, not added as a weapon type.

## Scope boundary

Prioritise a playable two-person mission over bespoke art, new networking systems or widening the galaxy. A feature belongs in Part 1 only when it is in the code and covered by a test; it is called human-accepted only when a dated human run is recorded. The [team contract](TEAM_CONTRACT.md) and [testing guide](docs/TESTING.md) define the grounding and verification rules.
