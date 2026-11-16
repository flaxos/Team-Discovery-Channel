# Modular NPC navigation and patrols

The production Jaffa (`JaffaAI`) and friendly airman (`SGCAirmanAI`) controllers now navigate any `LevelAssembly` level. Nothing SGC-specific was rewritten and no second navigation bake was added: NPCs follow the navigation map the assembly already bakes, using their existing `CharacterBody3D` physics.

![Jaffa on patrol, runner arrived on the upper deck, sentry held by the locked security door](../reviews/modular-npc-navigation.png)

Recording of the same run (55 s, overview camera): [`docs/reviews/modular-npc-navigation.mp4`](../reviews/modular-npc-navigation.mp4).

## What was coupled to the SGC map

Both controllers only ever call `navigator.next_position(goal, delta)`, `navigator.reset()` and read `navigator.status`. The coupling was inside `SGCNavigator`:

| SGC assumption | Where | Modular equivalent |
|---|---|---|
| An `SGCMap` sibling must exist, otherwise the actor waits forever | `SGCNavigator._find_map` | Falls back to the nearest `LevelAssembly` |
| Routes are planned over named regions and `SGCConnection`s | `SGCNavigator._plan` | Navmesh path between any two points |
| Stairs, spiral and lift use passage reservations and scripted points | `_plan`, `_lift`, `claim_passage` | Not needed: the ramp is ordinary walkable navmesh |
| Doors mean the gate-room blast doors | `next_position` | `ModularDoor` instances found along the path |
| With no targets, Jaffa march to named SGC regions | `JaffaAI._overrun_destination` | Explicit waypoint patrol |

Sector naming, turret and tactical-anchor logic in the airman remain SGC-flavoured but do not affect commanded movement.

## What changed

- `client/scripts/level/LevelNavigator.gd` (new): plans a navmesh path, follows it corner by corner, and returns only a steering point. It never moves the actor.
- `SGCNavigator`: when no `SGCMap` is present it delegates to `LevelNavigator`. With an `SGCMap` the original code path is untouched.
- `ModularDoor.open_for(actor)`: server-only request for server-owned actors, with the same 3.2 m reach and lock rules as a player. It never unlocks. TA-3 schedules safe closing for doors it opens; manual openings stay open.
- `JaffaAI.start_patrol(points, loop)` with `patrol_waypoint_reached` and `patrol_lap_completed` signals. Patrol resumes after combat because it replaces the idle advance destination.
- Friendly movement needs no controller change: `order_move_to(level.marker(room, marker))`.

### Navigator statuses

`navigator.status` on either controller (and `navigator.level_route.status_changed` as a signal):

| Status | Meaning | Actor behaviour |
|---|---|---|
| `moving` / `arrived` | Normal travel | Walks / stops |
| `waiting_for_door` | Closed door in reach could not be opened this tick | Holds, retries |
| `blocked_door` | No navmesh route avoiding locked connections can be built (`level_route.blocked_door`) | Holds where it is, re-checks every second |
| `unreachable` | Goal is not on the navigation mesh | Holds, re-checks every second |
| `stuck` | No progress after three replans (about 12 s) | Holds, re-checks every second, resumes if cleared |

No status teleports the actor.

## Demonstration scene

`res://scenes/level/ModularNpcDemo.tscn` instances the canonical `modular_integration_demo.tres` unmodified and adds actors on the host:

- **Jaffa patrol** loops `wide_junction → wide_elbow → wide_straight → width_adapter → hub`: a wide junction, a wide corner, both width transitions, two standard doors and the four-way junction.
- **Runner** (airman) is ordered from `entry` to the saved destination marker in `command`: four-way junction, 4 m ramp, upper T-junction and a standard door.
- **Sentry** (airman) is ordered to `barracks` while the host locks the `crew_quarters` security door. It reports `blocked_door` and holds; after 30 s the host unlocks and it completes the route.

Run it with Godot 4.4.1:

```sh
godot --path client res://scenes/level/ModularNpcDemo.tscn
```

The view is a fixed overview with roofs hidden and a status readout. `L` locks or unlocks the security door on the host. Set `unlock_after` to `0` on the root node to keep the door locked. The overview demo sets `npc_door_auto_close_delay = 0` so traversed doors remain open and the route is visible; normal mission doors use 2.5 seconds.

### UAT checklist (pending human sign-off)

1. The Jaffa opens each adapter door as it approaches, walks through and keeps looping.
2. The runner climbs the ramp on foot, opens the command door and stops inside.
3. The sentry stays put with `blocked_door` while the door is locked, and no door on its route opens.
4. Press `L` (or wait 30 s): the sentry walks through cargo and the security door into barracks.
5. Press `L` again while the Jaffa or sentry is elsewhere: the lock holds and nothing walks through it.
6. Start the normal SGC Defense and SGC UAT missions and confirm Jaffa and airmen behave as before.

## Automated coverage

```sh
python3 tools/run_godot_tests.py test_modular_npc_navigation test_modular_npc_multiplayer
```

`test_modular_npc_navigation` runs the real controllers (the test only observes) and checks:

- Runner reaches the upper-deck marker, peak height above 3.9 m, grounded on 99% of ticks, command door opened.
- Jaffa completes a five-waypoint lap in order (56 m), grounded throughout, both doors opened, then loops.
- No actor moves more than 0.35 m in a tick or drops below the floor.
- Locked door: sentry reports `blocked_door`, holds within 0.3 m, door stays locked and closed, no door upstream is opened; after a server unlock it arrives.
- `open_for` refuses out-of-reach actors, locked doors and actors not owned by the server.
- Off-mesh objective reports `unreachable` and the actor holds.
- A wall added after the bake produces `stuck` with the actor on its own side; removing it lets the patrol finish.
- Freeing and re-instancing the scene rebuilds navigation and the patrol runs again.

`test_modular_npc_multiplayer` runs a host and a connected client, each with its own copy of the level:

- Only the host spawns and commands NPCs; the client receives them through `MultiplayerSpawner`.
- Client Jaffa position stays within 1 m of the host's and its state matches.
- The client copy has no patrol, no route and zero velocity.
- Door opening and the security lock replicate; the client cannot call `open_for` or `set_locked`.

Existing SGC AI suites are unchanged and run in the full regression.

## TA-3 navigation follow-ups

Implemented 16 November 2026 on this branch. Native `LevelLayout` resources remain authoritative; no saved layout, navigation mesh or structural geometry changes.

- A locked door removes its connection from the walking graph passed to `LevelTopology.path`. The navigator stitches navmesh legs through the alternate rooms and checks every leg for locked crossings. It replans when a remaining route door locks; when all routes are blocked it holds and retries once per second, including after an unlock.
- Nearby NPCs on the same deck steer to their right on the assembly navigation map when meeting head-on. Local passing applies to oncoming actors ahead of the navigating NPC; actors trailing behind, marching ahead in the same travel direction, or sharing the same patrol route do not trigger avoidance, avoiding mutual wall stalling and post-combat patrol resumption regressions. The test uses production Jaffa with mutual body collision and observes both arriving without moving them during traversal.
- An AI-opened door closes on the server after nearby NPCs clear 2.5 m and `auto_close_delay` elapses (default 2.5 s). The existing occupied-doorway query protects players and NPCs. Set the delay to zero to leave doors open. An AI passing through a manually opened door does not start its close timer. Open/closed state uses the existing RPC and late-join snapshot; clients never run the timer.

```sh
python3 tools/run_godot_tests.py test_modular_navigation_ta3 test_modular_navigation_ta3_multiplayer test_modular_npc_navigation test_modular_npc_multiplayer --timeout 240
```

The existing alarm suite now checks the runner’s selected working console and its destination, since passing changes patrol positions and either console may be closest. Its alarm, reinforcement, retry, disabled-console and calm-down checks remain.

The new suites cover a production patrol walking the alternative arm of a loop, both arms locked, runtime lock/unlock recovery, planning on the canonical infiltration loop, head-on passing, co-patrol non-interference and trailing actor avoidance regression, automatic closure, occupied doorways, explicit opt-out and manual openings. The multiplayer suite connects after a door opens, checks its snapshot and replicated closure, rejects client AI requests, and tears down without timer errors.

Human verification remains pending: walk a loop with one locked security door, observe patrols meeting head-on, watch doors close behind patrols without closing on an operative, and check that the changed sight lines remain readable with sentry perception active. Run with two players to confirm both see the same door state.

## Known limitations

- Runtime geometry changes do not rebake the navmesh. An obstruction still uses bounded stall detection and retries.
- Room-graph rerouting requires an alternate walking connection and valid navmesh legs. It does not invent links or use transport rings.
- Local passing is not a guarantee against arbitrary crowds or formations in a doorway. Human co-op and combat tuning remain outstanding.
- The demonstration deliberately names factions `Hostiles` and `Friendlies` so they do not acquire each other. Actual missions use world-scoped `Players`, `Allies` and `Enemies` and have combat/late-join coverage. Modular cover uses props when available and markers as a fallback; coordinated flanking is TA-2.
- Transport rings are not NPC navigation links.

## Recorded delivery evidence

Godot 4.4.1.stable.official.49a5bc7b6. The complete regression inventory ran once after integration, in a clean worktree of this branch: **66/66 records passed** (project import plus 64 suites, one of which runs in two phases), including the two new suites and all existing SGC AI and multiplayer suites. No existing test was changed. The recording and still above were rendered from the demo scene and inspected. Human UAT of the checklist is still pending.
