# Testing and UAT

Run from the repository root with Godot **4.4.1**. The runner checks the engine version and imports the project before executing suites. A success banner or process exit zero does not override an assertion, script/engine error, leak warning or timeout.

## Automated validation

```sh
python3 tools/run_godot_tests.py --profile full --timeout 240
python3 tools/run_godot_tests.py --profile fast
python3 tools/run_godot_tests.py --profile multiplayer
python3 tools/run_godot_tests.py --profile full --list
```

The full profile discovers every `client/tests/test_*.gd`; helpers belong under `client/tests/support/` without that naming pattern. Fast and multiplayer profiles report their unselected suites and do not substitute for full acceptance. The default timeout is 180 seconds per process; 240 seconds is the documented full-run allowance. Avoid the old 12/20/30-second diagnostic limits: continuous route coverage takes about 100 seconds on the development machine.

To target map and UI fixes:

```sh
python3 tools/run_godot_tests.py test_sgc_enclosure test_sgc_map_routes test_sgc_lift_routes test_sgc_uat_architecture test_sgc_ai_wayfinding test_buffer_lockout_hud --timeout 240
```

Reports default to `build/test-results/godot/`: `summary.json`, `junit.xml`, process output and engine logs. Use `--output` to keep a separate run. Test user data is isolated from normal keybindings/settings; the persistence suite uses separate writer and reader processes. `--skip-import` is diagnostic only and is not clean-checkout acceptance.

### Current baseline

The last recorded full local run is **80/80 checks** on the GT-1 branch: project import, 78 suites and the persistence reader. Each milestone's pull request records its own run. Local green is not hosted green: three suites passed locally and failed on the slower hosted runner in phase 3 (see below).

**Hosted CI:** the `Godot full` job failed on every push to `main` from PR #35 to #41. `test_level_authoring` runs `tools/level_authoring.py`, which looks for `godot` on `PATH` (or the `GODOT` environment variable); the workflow installs the engine elsewhere and passed its path only to the test runner. Since roadmap milestone EX-1 the runner exports the engine it was given as `GODOT` to every suite, and `tools/tests/test_godot_runner.py` checks that. The hosted `Godot full` job passed on PRs #42 and #43 with this change; check each pull request's hosted run for the current state.

**Hosted runs are slower than local ones.** Phase 3 hit three failures that passed locally: the runner imported with `--editor --quit`, which can exit before every asset is imported (now `--import`); a late-join test required three Jaffa to hold one awareness level for 1.5 s; and a retry could cross a health-snapshot reply, logging a missing-node error on the client. When writing multi-process tests, assert eventual or at-least states, not exact counts at one moment, and check `gh pr checks <n>` before calling a branch green.

Historical baseline: at gameplay commit **`a720594`**, the full profile passed **51/51 local checks**: 49 discovered scripts, an extra persistence reader process and project import. The evidence is a baseline result, not a promise that a later branch or hosted workflow passed. CI status belongs to the corresponding pull request.

## Coverage contracts

| Suite | Required behavior |
| --- | --- |
| `test_sgc_enclosure` | Closed room/shaft boundaries; deliberate placement gap, portal crack, removed floor/ceiling/casing fail; closure with lift on another floor; invalid floor rejected. |
| `test_sgc_map_routes` | Production player, friendly and Jaffa capsules move continuously through every walk/stair edge in both directions. Only route setup places an actor. |
| `test_sgc_lift_routes`, `test_elevator_replication` | Three-floor entry/arrival/exit, queued calls, physical carrying and replicated lift state. |
| `test_sgc_uat_architecture` | Roof coverage, sealed raised operations, shutter alignment, picker and aimed buttons, live-controller grounding throughout long ascent/descent. |
| `test_sgc_ai_wayfinding` | Actual friendly orders and hostile overrun traversal into upper/support floors. |
| `test_sgc_map_contract` | Provenance, alternate routing, art bounds/collision preservation and invalid destination handling. |
| `test_mission_selection_uat` | Real lobby/coordinator dispatch, quiet UAT startup, retry and retained Defense activation. |
| `test_modular_extraction_mission`, `test_modular_extraction_multiplayer`, `test_modular_extraction_dedicated` | Modular mission from the lobby and from a dedicated server: objectives, extraction rule, Jaffa patrol combat and cover, failure, stand-down after the result, retry, error-free late join during a firefight and shared result. See the [mission guide](maps/modular-extraction-mission.md). |
| `test_goauld_infiltration_loud` | The infiltration mission's loud route with hearing, alarm, reinforcements and cover live, through extraction and stand-down. |
| `test_goauld_theme` | The Goa'uld theme on the infiltration compound: palette on 20 rooms, pieces on 8, and collision, navigation, sockets, markers and cover identical to the same compound built neutral. |
| `test_world_coexistence`, `test_world_coexistence_multiplayer` | Two worlds side by side (GT-1): the quiet SGC and the infiltration compound loaded together through the lobby and coordinator. Each world finds only its own operatives, enemies, props and map; a sentry notices an operative in its own world; operatives start at home and a late joiner arrives there; a hidden world has no HUD or environment and keeps simulating; the mission is lost only when every operative in both worlds is down; retry replaces both. The two-process suite checks a late-joining client loads both worlds and follows the far one. There is no travel yet: the suites move an operative by hand. |
| `test_goauld_infiltration_mission` | Infiltration mission from the lobby: unseen insertion, guarded checkpoint, quiet route to the generator without an alert, objectives in order, extraction, retry and failure. See the [mission guide](maps/goauld-infiltration-mission.md). |
| `test_mission_alert`, `test_mission_alert_multiplayer` | Compound alert on the infiltration mission: escalation, alarm runner and console, reinforcement budget and timing, disabled consoles, stopped runner, calm-down, debrief, retry; two-process late join during an alarm, client console disable through the server and runner tell. See the [alert guide](maps/mission-alert.md). |
| `test_jaffa_hearing` | Sentry hearing with real weapons and a C4 charge: per-weapon radii, suppressed shot silent, unsuppressed shot heard and investigated, no escalation from noise, range limit, walls do not muffle, fighting sentry unaffected, blast heard beyond rifle range, search points visited and route resumed. |
| `test_jaffa_prop_cover` | Cover props on the integrated fixture: which attachments count, a spot behind the prop away from the threat and blocked at crouched height, held spots not reused, a sentry taking the crate, crouching most of the time and standing to fire hits over it, still alerted, relocation when flanked, and the unchanged fallback far from any prop. |
| `test_jaffa_perception` | Sentry perception on the integrated fixture with fresh sentries: nothing seen through walls or floors (where the assault rule would acquire), nothing outside the cone, suspicious before alerted no sooner than the notice time, forgetting, smoke, closed and open doors, damage alert, one-hop spread, search of the last seen position and resumption of the route at the same waypoint. |
| `test_buffer_lockout_hud` | Denied dialing and upload/cancel/snapshot updates leave no orphan panel; approved dialing can open and dismiss its panel. |

The full inventory also covers gate lifecycle/difficulty, combat authority, native multiplayer joins/state/retry, inventory, controls/remapping, camera and objectives. Use `--list` for exact names rather than maintaining a second hand-written inventory.

## Map bake and enclosure gate

```sh
godot --headless --path client --script res://scripts/map/bake_sgc_map.gd -- --bake-sgc
```

The bake preserves authored data, rebuilds navigation and refuses to save on enclosure failure. `--reset-layout` explicitly restores the factory layout; it is not a routine repair switch. Commit the resulting map/navigation resources with layout changes. The [enclosure rule](maps/sgc.md#indoor-enclosure-rule) documents sampling resolution and structural limits; visual inspection is still required.

## Graphical and human UAT

For reproducible Forward+ captures on an available display:

```sh
godot --path client --script res://tests/support/sgc_visual_review.gd
```

Frame cost of a mission, on a display (prints one `WORLD_COST` line; compare `sgc_uat` with `two_worlds_dev`):

```sh
godot --path client --script res://scripts/world/world_cost.gd -- --mission two_worlds_dev
```

On the development machine's X11 desktop, prefix `DISPLAY=:0` when needed. The helper writes `build/sgc-review/` views of the corridor joins, service/spiral stairs, support rooms, gate/control/briefing sightlines, both closed shutters, alert lighting and an active gate. It hides HUD/shrouds for inspection and is not the normal gameplay entry point.

Human acceptance route:

1. Launch **SGC UAT Base** from the normal lobby. Confirm all three floors, no automatic enemies/gate activation and usable controls.
2. From embarkation, use both perimeter corridors, the connector/west return joins and side/rear control stairs. Look around corners and up/down for exterior voids and rendering seams.
3. Confirm raised operations, sealed front glass, the briefing overlook and independent shutter consoles. Check frames with shutters open/closed and during lighting changes.
4. Ascend and descend the spiral and both service flights from their actual approaches. Test handrails and headroom without clipping or position resets.
5. Select each lift destination through aimed buttons and the picker; ride Level 26→28 while standing, then leave diagonally at each landing.
6. Issue friendly movement orders between floors. In Defense, check hostile corridor pressure and fallback paths under combat.
7. With two humans, complete Defense on each difficulty, checking required objectives, gate direction, revive/combat, late joining and retry. Verify the lockout is a HUD notice, not an undismissable overlay.

Record commit, mission, difficulty, peer roles, route/action, expected/actual result and screenshots or logs. Automated closure/traversal is not acceptance of combat balance, latency tolerance, sound or visual quality.

## Other repository checks

`tools/tests` holds the runner's failure contract, a static check that no script searches the whole game for its surroundings (`test_world_scoping.py`: use `MissionWorld`), and the Goa'uld kit's geometry and palette rules (`test_theme_kit.py`: the committed kit matches its generator, each piece fills its slab, nothing can be seen through, gold stays above door height). They need no engine.

```sh
python3 -m unittest discover -s tools/tests -v
npm ci --prefix alignment-app
node --test alignment-app/server/*.test.js
npm run build
```

The existing CI workflow runs runner contracts, Godot fast/multiplayer/full profiles, Alignment API tests and a frontend build. It pins Godot 4.4.1, Python 3.11 and Node 22.14.0, and retains diagnostic artifacts for 14 days. See [Alignment operations](ALIGNMENT.md) for that app's runtime requirements.


## Modular room scaffolding

The separate [modular kit guide](maps/modular-levels.md) documents the Phase 1 builder, neutral preview and `test_modular_level` contract. Later modular suites cover the catalogue, vertical kit, presets, security doors, themes, authoring CLI, planner and topology (`test_modular_*`, `test_level_*`), NPC navigation and the extraction mission. Full test discovery includes them without changing the existing SGC tests.

## Human acceptance still outstanding

No mission has a signed human run. The written checklists are: the route above for the SGC, the eleven steps in the [extraction mission guide](maps/modular-extraction-mission.md#human-uat-checklist-pending-sign-off), the six steps in the [NPC navigation guide](maps/modular-npc-navigation.md), and the editor checklists in the modular guides. Record completed runs under `docs/reviews/` with commit, roles and results. The [roadmap](../ROADMAP.md#near-term-acceptance-gates) lists the gates that depend on them.
