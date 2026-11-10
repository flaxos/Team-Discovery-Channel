# First offworld extraction mission — engineering plan

Design only. Nothing here is implemented. Each "exists" item was read in the current code; nothing in this plan has been prototyped.

## Target experience

A squad gates to a modular offworld facility, reaches an objective room unseen if it can, fights if it cannot, and returns through the gate. Jaffa patrol, investigate, raise an alert and call reinforcements.

## Dependencies by system

| System | Exists today | Gap |
|---|---|---|
| Mission director and objectives | `WaveManager` runs the SGC defence as hard-coded phases and emits `objective_status_changed`; `GateRoom._finish_mission` / `sync_mission_result` end a mission | No data-driven objective list. Objectives are tied to waves, the iris and the lab patch |
| World transitions and gate travel | `NetworkManager.MISSIONS` maps a mission id to one scene; `MainGameCoordinator._load_gate_room` loads it; `StargateRing` has full dial/kawoosh/wormhole state and `player_extracted` | One scene per mission. Walking into the gate ends the mission rather than moving the squad |
| Modular level as a mission space | `LevelAssembly` builds, validates and bakes; room markers (`entry`, `destination`, `patrol`, `cover`, `interaction`); functional presets; `ModularDoor` security locks | `GateRoom.gd` owns player spawning and assumes SGC nodes. No mission scene hosts a `LevelAssembly` |
| NPC navigation and patrol | This milestone: `LevelNavigator`, `JaffaAI.start_patrol`, AI door use | No rerouting, no avoidance, combat positions are SGC coordinates (see navigation limitations) |
| Stealth suspicion and detection | `JaffaAI._find_nearest_target` (range plus line of sight, smoke blocks sight) | Detection is instant and binary. No view cone, no suspicion meter, no investigate state, no noise |
| Alerts and reinforcements | `_alert_nearby_formation_jaffa` alerts siblings; `TransportRings` can beam in Jaffa (`spawn_enemies_on_beam`, `reinforcement_spawned`); `WaveManager._spawn_sector_jaffa` | No level-wide alert state, no alarm console, no reinforcement budget |
| Tactical combat and cover | Jaffa cover/flank states; airman anchors, leapfrog and suppression; `cover` group and room `cover` markers | Jaffa cover and flank targets are literal gate-room coordinates; airman anchors come from SGC sectors |
| Downing, revives, resupply | `HealthComponent` downed/bleedout/revive with replication; airman auto-revive; `ArmoryResupplyStation`; `GateRoom._evaluate_squad_status` fails the mission when all are down | Resupply stations are SGC props, not yet a modular attachment |
| Extraction and completion | `StargateRing.authorize_extraction`, extraction area, `player_extracted`, DHD dialling minigame | Completion rule is "any player extracted". No "objective done and squad through" rule |
| Replication and late joining | Host-authoritative AI; `MultiplayerSpawner` for players and enemies; snapshot RPCs on gate, room, waves, health and doors; `mission_ready_peers` gating | Snapshots are per SGC object. A modular mission needs an objective and alert snapshot, and the client must build the same layout before spawns arrive |

## Smallest next playable milestone

**"Walk in, grab it, walk out"** on the existing integrated fixture, no stealth:

1. A new mission entry in `NetworkManager.MISSIONS` whose scene hosts a `LevelAssembly`, spawns players at the layout entry marker and reuses the existing player spawner and squad-down failure rule.
2. A minimal host-owned objective list with three steps: reach the destination room, interact with one existing console attachment, return to the entry room. One replicated snapshot for late joiners.
3. Two or three Jaffa patrols using `start_patrol` on room `patrol` markers, in containers named so existing perception and combat run.
4. Mission ends through the existing `sync_mission_result` path.

This proves the mission shell, modular combat and replication with the least new code, and exposes the combat-coordinate problem early. Gate travel, stealth and reinforcements are deliberately left out.

## Order after that

1. **Modular combat positions.** Replace hard-coded Jaffa cover/flank coordinates and airman SGC anchors with lookups on room `cover` markers. Blocks every later combat feature.
2. **Gate travel between worlds.** Decide between loading both spaces at once at separate origins or swapping scenes; then make walking through an active outbound gate move the squad. Highest technical risk, mostly replication and late join.
3. **Alert state and reinforcements.** One host-owned level alert value, an alarm interaction, and ring or gate reinforcements with a budget.
4. **Suspicion and detection.** View cone, suspicion build-up, investigate-last-seen, then hooks into the alert state.
5. **Extraction rule and debrief.** Objective complete plus squad through the gate; resupply as a modular attachment.
6. **Navigation follow-ups** as they start to hurt: rerouting around locked doors, NPC avoidance, door closing.

## Open decisions

- Whether the offworld space and the SGC are loaded together or swapped. This determines late-join and snapshot design.
- Whether `GateRoom.gd` is split into a reusable mission host or a new slim host is written beside it. Splitting touches the stable SGC mission.
- Whether friendly airmen accompany the squad offworld in the first mission.
