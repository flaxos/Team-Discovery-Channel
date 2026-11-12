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

The last recorded full local run is **69/69 checks** on the PR #40 branch (project import, 67 suites and the persistence reader), recorded in the [authoring review](reviews/ai-level-authoring-2.md). It was not re-run for the documentation-only roadmap change.

**Hosted CI:** the `Godot full` job failed on every push to `main` from PR #35 to #41. `test_level_authoring` runs `tools/level_authoring.py`, which looks for `godot` on `PATH` (or the `GODOT` environment variable); the workflow installs the engine elsewhere and passed its path only to the test runner. Since roadmap milestone EX-1 the runner exports the engine it was given as `GODOT` to every suite, and `tools/tests/test_godot_runner.py` checks that. Check the pull request's hosted run for the current state.

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
