# Runtime architecture

The game is the Godot project in `client/`. Multiplayer uses native Godot high-level networking over ENet. The Node/React Alignment app is a separate planning service; it is not the game server.

## Ownership and entry points

| Component | Responsibility |
| --- | --- |
| [`MainGameCoordinator`](../client/scripts/world/MainGameCoordinator.gd) | Lobby/world transition, the selected mission's world or two worlds, and old-world retirement on retry. |
| [`NetworkManager`](../client/scripts/net/NetworkManager.gd) | Autoload; host/join/dedicated setup, roster/classes, host-owned mission/difficulty and join/readiness/restart coordination. |
| [`GateRoom`](../client/scripts/world/GateRoom.gd) | Shared world assembly, players, doors, independent window shutters and room snapshots. `SGCUATBase.tscn` inherits this map. |
| [`WaveManager`](../client/scripts/world/WaveManager.gd) | Defense progression, incoming scheduling, cleared incursions, objective eligibility and mission snapshots. Guards hostile startup/update paths for UAT. |
| [`StargateRing`](../client/scripts/props/StargateRing.gd) | Gate reservation, direction, chevrons, kawoosh/horizon lifecycle and authorized extraction. |
| [`DHDDialer`](../client/scripts/props/DHDDialer.gd), [`SGCDialingConsole`](../client/scripts/props/SGCDialingConsole.gd) | Approved dialing input and session cancellation; SGC buffer corruption and ROM upload. |
| [`SGCMapDefinition`](../client/scripts/map/SGCMapDefinition.gd), [`SGCMap`](../client/scripts/map/SGCMap.gd) | Region/connection data, floor offsets, ceilings, geometry, art slots and baked navigation. |
| [`SGCNavigator`](../client/scripts/map/SGCNavigator.gd) | Shared friendly/hostile routing, local paths, physical stair following, passage reservation and lift actions. |
| [`SGCEnclosureValidator`](../client/scripts/map/SGCEnclosureValidator.gd) | Physical exterior-shell checks used by map baking and automated acceptance. |
| [`PlayerController3D`](../client/scripts/entities/PlayerController3D.gd), [`HUD`](../client/scripts/ui/HUD.gd) | Local input/camera, aimed interaction, lift picker, squad wheel, controls UI and observable mission status. |

## Modular missions and levels

A second mission path runs on modular levels. It shares the player, weapon, health, enemy and networking code above.

| Component | Responsibility |
| --- | --- |
| [`ModularMission`](../client/scripts/mission/ModularMission.gd) | Mission host for a modular level. Extends `GateRoom` for spawning, late join, squad-down failure, result and retry; SGC-only behaviour is stubbed ([decision D-008](DECISIONS.md)). |
| [`MissionDefinition`](../client/scripts/mission/MissionDefinition.gd), [`MissionObjectives`](../client/scripts/mission/MissionObjectives.gd) | Mission data (layout, ordered `reach` / `interact` / `extract` objectives, patrols) and server-decided sequential progression with a join snapshot. |
| [`LevelAssembly`](../client/scripts/level/LevelAssembly.gd) | Builds a `LevelLayout` into rooms, doors and attachments, validates it and bakes one navigation map. |
| [`LevelNavigator`](../client/scripts/level/LevelNavigator.gd) | Navigation-mesh route following for both factions on modular levels; `SGCNavigator` delegates to it when no `SGCMap` is present. |
| [`ModularDoor`](../client/scripts/level/ModularDoor.gd) | Server-validated doors and security locks with snapshots; AI opens them through `open_for`. |
| [`LevelPlanner`](../client/scripts/level/LevelPlanner.gd), [`LevelTopology`](../client/scripts/level/LevelTopology.gd), [`LevelAuthoring`](../client/scripts/level/LevelAuthoring.gd) | Authoring-time only: graph planning, connectivity checks and transactional layout edits behind `tools/level_authoring.py`. Not used at run time. |

## Worlds and the session

A **world** is one self-contained place: its level, players, enemies, spawners, objectives and HUD under one root (`GateRoom` or a `ModularMission`). A mission is one world, or two side by side. There is no travel between them yet; the design and the reasons are in [gate travel with a split team](plans/gate-travel-split-worlds.md) (decisions D-016 and D-017).

| Component | Responsibility |
| --- | --- |
| [`MissionWorld`](../client/scripts/world/MissionWorld.gd) | How an actor finds its own world. `of(node)` is the nearest ancestor world; `find(node, name)` looks a node up inside it; `in_group(node, group)` returns the group members the actor can meet. **Never search the whole game** (`get_tree().root.find_child`, `get_tree().get_nodes_in_group`): with two worlds loaded that returns the wrong one. `tools/tests/test_world_scoping.py` fails on such a lookup |
| [`MissionSession`](../client/scripts/world/MissionSession.gd) | Exists only for a two-world mission, above both worlds. Records which world each peer's operative belongs in (default: home), loses the mission only when every operative in every world is down, gives both worlds one result, and decides which world this peer presents |
| `MainGameCoordinator` | Loads one world at `WorldContainer/GateRoom`, or two: home at that same path and the site at `WorldContainer/Site/GateRoom`, 2,000 m away (`SITE_OFFSET`). A mission entry with a `"site"` scene is a two-world mission. Every peer loads both worlds, so one readiness report covers them |
| `GateRoom.set_presented` | A peer presents the world its own operative is in. A world that is not presented is hidden, has no HUD and no active environment, and plays no positionless sound; it keeps simulating |

`client/scripts/world/world_cost.gd` measures a mission's frame cost on a display; the figures for one world and two are in [the design](plans/gate-travel-split-worlds.md#8a-measured-cost). The session rebuilds the shadow atlas once after presenting a world, because loading two worlds can leave every shadowed light redrawing each frame.

A single-world mission has no session and behaves as it did. `two_worlds_dev` is a development mission (the quiet SGC and the infiltration compound) that is not listed in the lobby: start it with `--mission two_worlds_dev`. Sentry perception is a component of the enemy controller ([`JaffaPerception`](../client/scripts/entities/JaffaPerception.gd), decision D-004).

## Gate and mission lifecycle

`StargateRing` owns `INACTIVE`, `DIALING`, `KAWOOSH` and `ACTIVE` states, plus `NONE`, `INBOUND` or `OUTBOUND` direction. The wave system requests incoming connections; the dialing computer requests outbound permission through the mission system. These states are not a second monolithic phase-enum coordinator.

Only an active incoming gate can stream gate reinforcements. Closed, outbound, ended or retired missions reject stale spawn/transition work. Outbound permission uses the same completed-incursion and objective rules displayed to players. Eligible dialing reserves the gate so incoming and outbound activation cannot both win the same race. Extraction requires an authorized outbound connection.

## Multiplayer authority

The server resolves combat, mission progression and shared interactions. Client requests are validated against sender/actor identity, weapon/rate/ammunition state, aim/origin constraints or interaction distance as appropriate. Existing enemy/friendly spawners and synchronizers carry authoritative NPC transforms, posture and lifecycle. Repeated death/vaporization cannot award or count twice.

Joining clients receive mission/settings and object snapshots rather than assuming default gate, door, shutter or lift state. Readiness coordination precedes mission replication; retries retire the old world and its spawners before replacement. The lift snapshot carries its floor, destination, cabin height, doors and remaining travel time. Control and briefing shutter states are independent.

## Map, navigation and rendering

The authored map is `client/resources/maps/sgc.tres`; the checked-in navigation mesh is `sgc_navigation.res`. Runtime uses a private resource copy and a navigation map per scene, including multiplayer fixtures. Walking connections must share a physical boundary; portal width is clipped to the receiving room. Enclosed stair/lift volumes close the gaps between floor shells without blocking their room approaches.

NPC navigation drives ordinary character movement. It does not teleport actors or invent upward velocity. Rejected truncated local paths are cleared; invalid goals hold position with a reported status. Stair and lift reservations serialize constrained passages. Rebuild navigation after collision/layout changes and pass the [map contract](maps/sgc.md).

Physics layer 1 is world geometry; layer 2 is players/friendlies, layer 3 Jaffa, and layer 8 (`128`) ceiling/shaft caps. Cap collision is included in character/weapon masks and excluded from navigation baking to avoid roof islands. Zat corpse queries use bit `64`; do not reuse it for ceilings.

## UI boundaries

[`KeybindingManager`](../client/scripts/input/KeybindingManager.gd) owns validated persistent action bindings. Gameplay routes interaction once through the player controller; aimed controls take priority over proximity fallback. UI modals suppress the relevant gameplay input and release mouse capture as needed.

Buffer lockout and patch progress are objective notifications. They do not engage the dialing panel; that panel belongs to an approved dialing session. Global status/snapshot events must not leave an orphan session UI. Verify this with `test_buffer_lockout_hud`.

For current commands and evidence, use [testing](TESTING.md); for future work rather than current implementation, use the [roadmap](../ROADMAP.md).
