# Game design: Stargate SG Extraction

Team Discovery Channel's co-op tactical shooter uses **Godot 4.4.1**, native ENet multiplayer and a shared three-level SGC map. This document separates the playable slice from the broader extraction-game vision. Implementation baseline: `a720594`, 9 November 2026; see the [roadmap](ROADMAP.md) and pull requests for delivery status.

## Playable slice

**SGC Defense — Levels 28/27/26** is the active combat mission. Players defend against incoming Jaffa, use the base's equipment and corridors, satisfy difficulty-specific objectives, dial an authorized outbound gate and extract. **SGC UAT Base — No Hostile Activation** uses the same geometry and props for quiet traversal and interaction testing; automatic hostile activation and waves are disabled.

| Difficulty | Outbound requirements |
| --- | --- |
| Easy | At least three cleared incursions. |
| Medium | Three cleared incursions plus the lab-ROM dialing-computer upgrade. |
| Hard | Medium requirements plus iris repair during an active incoming breach. |

Incoming windows default to 38 seconds, followed by 20-second recharge periods. Pressure continues until requirements are satisfied. A valid outbound dial reserves the gate against new incoming activation. Dialing uses seven chevrons and four GDO beats; extraction requires an authorized outbound gate. These are game timings rather than the television show's maximum wormhole duration.

## Space and visual direction

The SGC includes Level 28 embarkation, operations and combat corridors; Level 27 briefing, command and security; and Level 26 support, staging, storage and service rooms. Operations is 1.5 m above embarkation behind sealed glazing, with side/rear stairs. Briefing overlooks the chamber from 5.5 m. Main floor elevations are 0, 5.5 and 11 m; Level 25 is excluded.

The 6.7 m gate sits in a 24 m wide, 12 m high chamber. The layout follows referenced SG-1 relationships, with gameplay proportions and authored peripheral/support spaces rather than a claim of measured blueprint accuracy. Muted concrete, charcoal steel, subdued lighting, ceiling panels/beams and clear thresholds support the former-silo setting. Independent control/briefing shutters remain inside their frames.

Generated modules carry dimensions, material briefs and replacement-art slots. Visual replacement preserves gameplay collision and rejects oversized assets. Bespoke art must preserve readability and traversal. See the [SGC map contract](docs/maps/sgc.md) for provenance, palette and schema.

## Classes and combat

The selectable profiles currently equip these primary/secondary weapons:

| Class | Primary | Secondary |
| --- | --- | --- |
| SG-3 Heavy Support Marine | M249 | M9 |
| Tech Specialist & Archaeologist | MP5 | Zat |
| Pointman / Recon Leader | P90 | M9 |
| Allied Jaffa / Tok'ra Infiltrator | Staff weapon | Zat |

The slice also includes resupply and weapon racks, C4/claymores, deployable turrets, shields, smoke, downing/revive and friendly squad orders. Zat progression is stun, kill, then corpse vaporization; stun defaults to 20 seconds. Broader class descriptions may contain aspirational equipment and do not establish that every listed perk is implemented.

Players use a tactical third-person/isometric camera with shoulder ADS and camera-relative movement. The squad radial works while holding ADS. Persistent remapping supports keyboard/mouse alternatives, conflict resolution and live prompts. [Playing](docs/PLAYING.md) is the current control reference.

## World and AI contracts

Both factions share the region graph, local navigation paths, physical stair traversal and explicit lift actions. Gate-lane hostiles enter the perimeter corridors; overrun pressure can order friendly fallback to briefing and then Level 26. Passage reservations serialize narrow routes. Movement must not teleport actors or supply artificial vertical velocity to pass tests.

The lift serves three floors, with aimed buttons or an in-cabin picker. Riders remain grounded during travel. Walking portals share a room boundary and sufficient clearance; exterior walls, floors, ceilings and shafts must close the indoor shell. Enclosure failure blocks the map bake and CI acceptance, at the documented sampling resolution. Manual inspection remains necessary for visual seams and replacement materials.

Mission, combat and shared interactions are server controlled. Joining/retrying clients receive selected mission/difficulty and current gate, objective, NPC, door, shutter and lift state. UI observes those states; buffer-lockout and ROM-upload messages remain objective HUD notices rather than opening an orphan dialing panel. See [architecture](docs/ARCHITECTURE.md).

## Future vision and scope boundary

The wider concept remains recon → sabotage → alarm → retreat → dial home under fire, inspired by Stargate SG-1, Helldivers, Door Kickers, Alien Swarm and GTFO. Candidate missions include a Goa'uld outpost, Alpha Site evacuation and Ha'tak infiltration, with offworld DHDs, transport rings, MALP/UAV reconnaissance and stealth objectives. These are future concepts; there is no claim that selectable offworld theaters or scene-to-scene insertion are shipped.

Share gate, weapon, AI and interaction components across future modes. Prioritize a playable two-person mission over bespoke art, new networking systems or expanding the galaxy. The [team contract](TEAM_CONTRACT.md) and [acceptance guide](docs/TESTING.md) define the grounding and verification requirements.
