# Runtime architecture

The game is the Godot project in `client/`. Multiplayer uses native Godot high-level networking over ENet. The Node/React Alignment app is a separate planning service; it is not the game server.

## Ownership and entry points

| Component | Responsibility |
| --- | --- |
| [`MainGameCoordinator`](../client/scripts/world/MainGameCoordinator.gd) | Lobby/world transition, selected mission scene and old-world retirement on retry. |
| [`NetworkManager`](../client/scripts/net/NetworkManager.gd) | Autoload; host/join/dedicated setup, roster/classes, host-owned mission/difficulty and join/readiness/restart coordination. |
| [`GateRoom`](../client/scripts/world/GateRoom.gd) | Shared world assembly, players, doors, independent window shutters and room snapshots. `SGCUATBase.tscn` inherits this map. |
| [`WaveManager`](../client/scripts/world/WaveManager.gd) | Defense progression, incoming scheduling, cleared incursions, objective eligibility and mission snapshots. Guards hostile startup/update paths for UAT. |
| [`StargateRing`](../client/scripts/props/StargateRing.gd) | Gate reservation, direction, chevrons, kawoosh/horizon lifecycle and authorized extraction. |
| [`DHDDialer`](../client/scripts/props/DHDDialer.gd), [`SGCDialingConsole`](../client/scripts/props/SGCDialingConsole.gd) | Approved dialing input and session cancellation; SGC buffer corruption and ROM upload. |
| [`SGCMapDefinition`](../client/scripts/map/SGCMapDefinition.gd), [`SGCMap`](../client/scripts/map/SGCMap.gd) | Region/connection data, floor offsets, ceilings, geometry, art slots and baked navigation. |
| [`SGCNavigator`](../client/scripts/map/SGCNavigator.gd) | Shared friendly/hostile routing, local paths, physical stair following, passage reservation and lift actions. |
| [`SGCEnclosureValidator`](../client/scripts/map/SGCEnclosureValidator.gd) | Physical exterior-shell checks used by map baking and automated acceptance. |
| [`PlayerController3D`](../client/scripts/entities/PlayerController3D.gd), [`HUD`](../client/scripts/ui/HUD.gd) | Local input/camera, aimed interaction, lift picker, squad wheel, controls UI and observable mission status. |

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
