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

**Sprint 7 infrastructure baseline, `a778fb4`, 18 November 2026.** Full local and hosted runs both passed **117/117 checks**; the pinned Python tooling suite passed **60 tests**. All five hosted jobs passed in [run 44223594937](https://github.com/flaxos/Team-Discovery-Channel/actions/runs/44223594937). Clean Linux release export passed the actual MP5SD and offline-credit tests, including eight packaged model files and both full licence texts. See the [review](reviews/2026-11-18-sprint7-mp5-intake.md) and [verification record](assets/intake/mp5sd/verification.json). Sprint 7 reached main through #79/#78; these results do not certify later documentation commits or human acceptance. The earlier GT-1 **80/80** result is historical. Each milestone must record its own local and hosted results.

**Hosted CI:** the `Godot full` job failed on every push to `main` from PR #35 to #41. `test_level_authoring` runs `tools/level_authoring.py`, which looks for `godot` on `PATH` (or the `GODOT` environment variable); the workflow installs the engine elsewhere and passed its path only to the test runner. Since roadmap milestone EX-1 the runner exports the engine it was given as `GODOT` to every suite, and `tools/tests/test_godot_runner.py` checks that. The hosted `Godot full` job passed on PRs #42 and #43 with this change; check each pull request's hosted run for the current state.

**Hosted runs are slower than local ones.** Phase 3 hit three failures that passed locally: the runner imported with `--editor --quit`, which can exit before every asset is imported (now `--import`); a late-join test required three Jaffa to hold one awareness level for 1.5 s; and a retry could cross a health-snapshot reply, logging a missing-node error on the client. When writing multi-process tests, assert eventual or at-least states, not exact counts at one moment, and check `gh pr checks <n>` before calling a branch green.

Historical baseline: at gameplay commit **`a720594`**, the full profile passed **51/51 local checks**: 49 discovered scripts, an extra persistence reader process and project import. The evidence is a baseline result, not a promise that a later branch or hosted workflow passed. CI status belongs to the corresponding pull request.

## Coverage contracts

Sprint 14 extends `test_gate_lifecycle_and_modes` with SGC rim measurements, the physical aperture contract and the secured inbound iris. `test_sgc_iris_join_multiplayer` and `test_sgc_iris_join_dedicated` exercise the replacement peer’s repair snapshot and a clean retry with four operatives. [Sprint 14 review](reviews/2026-11-24-sprint14-sgc-control-gate-iris.md).

Sprint 13’s `test_sgc_embarkation_materials` checks the three shared PBR sets, texture channels and mipmaps, legacy fallback, player camera fade and collision along the route to the gate. It also runs from the Linux release pack. [Sprint 13 review and GPU captures](reviews/2026-11-24-sprint13-sgc-embarkation.md).

Sprint 12’s `test_field_kit_visuals` verifies the four exterior fits, C4 and smoke effect origins, arming cues and shield removal. Use `-- --expect-fallback` in an export with both community prop GLBs excluded. The four-operative `test_field_kit_join_multiplayer` and `test_field_kit_join_dedicated` verify remote deployment, readiness-gated delivery during gate travel, spent stock at destination and a clean retry. [Sprint 12 review](reviews/2026-11-23-sprint12-field-kit.md).

Sprint 11 adds `test_imported_m2_visual` for the fitted gun and fixed tripod, original muzzle and interaction volume, shared mipmapped resources and fallback. The four-operative `test_m2_join_multiplayer` and `test_m2_join_dedicated` cases cover remote SG‑3 deployment and mounting, a server shot, a replacement joining during gate travel and a clean retry. Sprint 25 checks the same rear position on all peers and adds a full local yaw sweep. `test_sgc_airman_visual` also tests both slots per role, moving palm contact, muzzle alignment, magazine and heat behavior, crawl, drag, revive, stun and death. [Sprint 25 review](reviews/2026-11-26-sprint25-sg3-heavy.md) · [Sprint 15 positioning fix](reviews/2026-11-24-sprint15-sgc-armoury.md#m2-operator-positioning-follow-up).

Sprint 26 adds `test_sgc_civilians` for the three SGC stations, shared head cache, independent skeletons, visible role props, hand placement and floor contact during a full work cycle. The four-player roster fixtures compare civilian station transforms at late join, outbound gate travel, return to SGC and retry. Pass `-- --expect-civilian-fallback` when the Linux pack excludes both character GLBs or `-- --expect-head-fallback` when it excludes only the civilian head. [Sprint 26 review](reviews/2026-11-26-sprint26-sgc-civilians.md).

Sprint 10’s `held_weapon_audit.gd` records live mesh, LOD, material, mipmap and cache data for the six modeled weapons. It runs from the checkout and the Linux release pack. The visual helper's `--audit` mode equips the owning classes and `--downed` captures their existing sidearm selection. [Commands and evidence](reviews/2026-11-23-sprint10-held-weapon-audit.md).

Sprint 9 adds `test_imported_zat_visual` for fitted geometry, unchanged handling and shot origin, shared textures and fallback. The quiet combat fixture checks stun, dragging, kill and vaporization with the new visual. Four-player snapshots check Carter and Teal’c’s Zats plus active slot delivery through travel and late join. [Sprint 9 review](reviews/2026-11-23-sprint9-zat-visual.md).

Sprint 8 adds `test_imported_staff_visual` for player and both Jaffa meshes, independent emitter alignment, decoded texture cost and sharing, old procedural fallback, and player/NPC plasma origins. It runs from the Linux release pack alongside `test_asset_credits`. The four-player listen and dedicated fixtures travel Teal’c and check the staff on replicas through join and retry. [Sprint 8 review](reviews/2026-11-23-sprint8-staff-intake.md).

Sprint 7 infrastructure adds `test_asset_credits` (real lobby open/select/close, every packaged model, exact full official CC0/CC BY texts; also runnable from a clean release PCK) and `test_asset_packer_maps` (real opaque PNG packing, normal flip and ORM reference channels). Python tests exercise work-order rejection/readiness/path/LOD/intake budgets and credit coverage/staleness. Install the pinned `tools/requirements.txt` dependency in a build-area environment before running the tooling suite. `python3 tools/sync_asset_credits.py --check` is a CI gate. See the [Sprint 7 review](reviews/2026-11-18-sprint7-mp5-intake.md); `test_imported_mp5_visual` checks its independently measured crown, immutable handling, cache, lossless-map delivery and fallback. Four-operative listen/dedicated snapshots also check each Carter replica; the gate-return fixture checks Carter’s returned model. Owner art acceptance remains separate.

Sprint 6 extends `test_goauld_theme` and `tools/tests/test_theme_kit.py` for all nine
corridor/compact-chamber definitions, four rotations, connected narrow/wide gallery
interfaces, neutral/themed physical and navigation equality, continuous floor
runners, finished corner ends and both lintel faces. The [review](reviews/2026-11-18-sprint6-goauld-corridors.md)
contains the recovery record and reproducible render evidence.

Sprint 5's `test_ammunition_sharing`, `test_ammunition_sharing_multiplayer`,
`test_ammunition_sharing_dedicated` and `test_ammunition_sharing_travel` cover finite
calibres, atomic conservation/caps, health/reload/reach/wall/result guards, default
and remapped aiming/input, authenticated remote intent, forged/replayed requests,
competing donors, four-operative listen/dedicated late snapshots, retry,
disconnect and real gate handoff with carried reserves and retired incarnations.
See the [contract](plans/ammunition-sharing.md) and [review](reviews/2026-11-18-sprint5-ammunition-sharing.md).

| Suite | Required behavior |
| --- | --- |
| `test_sgc_enclosure` | Closed room/shaft boundaries; deliberate placement gap, portal crack, removed floor/ceiling/casing fail; closure with lift on another floor; invalid floor rejected. |
| `test_sgc_map_routes` | Production player, friendly and Jaffa capsules move continuously through every walk/stair edge in both directions. Only route setup places an actor. |
| `test_sgc_lift_routes`, `test_elevator_replication` | Three-floor entry/arrival/exit, queued calls, physical carrying and replicated lift state. |
| `test_sgc_uat_architecture` | Roof coverage, sealed raised operations, shutter alignment and readout, two-sided observation glass collision, fitted briefing and command furniture, two-sided table fade, aimed buttons and live-controller grounding throughout long ascent/descent. |
| `test_sgc_ai_wayfinding` | Actual friendly orders and hostile overrun traversal into upper/support floors. |
| `test_sgc_map_contract` | Provenance, alternate routing, art bounds and collision, and invalid destinations. Sprint 16 adds medical cabinet and case fit, original cover rays and crouch camera fade. `test_multiplayer_mission_join` checks the slots after load and retry. [Lab and support review](reviews/2026-11-24-sprint16-sgc-lab-support.md). |
| `test_sprint9_interactives_climax` | Armoury resupply and loadouts, defense override, all four CCTV feeds and wraparound, clean CCTV exit, and the existing three-sector incursion. Sprint 18 adds CRT fit, shared mipmapped material and label selection. Run with `-- --expect-cctv-fallback` in the release pack that excludes the CRT GLB. [SGC coverage review](reviews/2026-11-24-sprint18-sgc-coverage.md). |
| `test_sgc_airman_visual` | NPC movement and turn steps, shared skin across all four playable classes, six held weapon fits, camera fade, shots, health poses, M2 grips, dismount and gameplay anchors. Pass `-- --expect-airman-fallback` or `-- --expect-m2-fallback` when the corresponding GLB is excluded from the release pack. The four-player join fixtures check the shared squad appearance through travel and retry. [Airman and squad review](reviews/2026-11-25-sprint19-airman-rig.md). |
| `test_mission_selection_uat` | Real lobby/coordinator dispatch, quiet UAT startup, retry and retained Defense activation. |
| `test_modular_extraction_mission`, `test_modular_extraction_multiplayer`, `test_modular_extraction_dedicated` | Modular mission from the lobby and from a dedicated server: objectives, extraction rule, Jaffa patrol combat and cover, failure, stand-down after the result, retry, error-free late join during a firefight and shared result. See the [mission guide](maps/modular-extraction-mission.md). |
| `test_modular_navigation_ta3`, `test_modular_navigation_ta3_multiplayer` | Locked-door alternate-route traversal, live lock/unlock recovery, all routes blocked, head-on colliding NPCs both arriving, co-patrol non-interference regression, safe auto-close after passing, occupied doorway, explicit opt-out and manual openings; late-join door snapshot, server-only closing and replicated collision/visuals without teardown errors. |
| `test_modular_flanking`, `test_modular_flanking_multiplayer`, `test_modular_flanking_dedicated` | Sprint 4 / TA-2 chunk 1: genuine perception, committed alternate-entrance traversal, one nearby flanker, live locks/open passages/cost fallback, bounded last-sighting behavior, invalidation and stand-down. Four-operative listen/dedicated native-compound late joins, physical pose/flag replication, client authority rejection, result cancellation, two retries and shutdown. [Contract](maps/modular-flanking.md), [review](reviews/2026-11-18-sprint4-modular-flanking.md). |
| `test_goauld_infiltration_loud` | The infiltration mission's loud route with hearing, alarm, reinforcements and cover live, through extraction and stand-down. |
| `test_goauld_theme` | The Goa'uld theme on the infiltration compound: palette on 20 rooms, pieces on 8, and collision, navigation, sockets, markers and cover identical to the same compound built neutral. |
| `test_world_coexistence`, `test_world_coexistence_multiplayer` | Two worlds side by side (GT-1): the quiet SGC and the infiltration compound loaded together through the lobby and coordinator. Each world finds only its own operatives, enemies, props and map; a sentry notices an operative in its own world; operatives start at home and a late joiner arrives there; a hidden world has no HUD or environment and keeps simulating; the mission is lost only when every operative in both worlds is down; retry replaces both. The two-process suite checks a late-joining client loads both worlds and follows the far one, and that it returns to its lobby without an engine error when the host leaves. |
| `test_gate_travel`, `test_gate_travel_multiplayer` | Outbound gate travel (GT-2): `travel_infiltration` lobby launch, SGC dialing and event-horizon hand-off to the offworld compound, complete carried-state preservation (health, slots, ammo, heat, explosives, ROM), presentation switching, late joiner arrival at home, D-017 split-squad loss rule, SGC dialing-console abort, and two-process host/client travel, SGC departure despawn verification, and active-host ENet remote peer removal assertion. |
| `test_gate_return`, `test_gate_return_multiplayer` | Return gate travel and SGC debrief (GT-3): real SGC dialing, offworld DHD denial before objectives complete, automatic site gate opening on objective completion, SGC ramp arrival (`z = -9.5`), D-017 victory evaluation, SGC debrief with real metrics and returned/lost callsigns, gate closure at mission end, and two-world retry across single-process and two-process runs. |
| `test_goauld_infiltration_mission` | Infiltration mission from the lobby: unseen insertion, guarded checkpoint, quiet route to the generator without an alert, objectives in order, extraction, retry and failure. See the [mission guide](maps/goauld-infiltration-mission.md). |
| `test_mission_alert`, `test_mission_alert_multiplayer` | Compound alert on the infiltration mission: escalation, alarm runner and console, reinforcement budget and timing, disabled consoles, stopped runner, calm-down, debrief, retry; two-process late join during an alarm, client console disable through the server and runner tell. See the [alert guide](maps/mission-alert.md). |
| `test_mission_events`, `test_mission_events_multiplayer`, `test_mission_events_dedicated` | EV-2-1: validated objective/security bindings and stage reachability, real console release, reach/health/identity/host-authority rejection, TA-3 blocked/released routes, one-shot/result freeze, real late-join snapshots without stale notices, live client release, and two connected retries on listen and pawnless dedicated hosts. [Contract](maps/mission-events.md). |
| `test_four_player_join_multiplayer`, `test_four_player_join_dedicated` | R24: four operative identities across two worlds, deliberately stalled late loading, real gate dialing/travel, class/health/pose/posture and presentation agreement, stale retry readiness rejection, replacement late join after retry, two full-team retries and sequential clean departures. Listen host + three clients; pawnless host + four clients. [Review](reviews/2026-11-17-r24-four-player-joining.md). |
| `test_session_lifecycle_multiplayer`, `test_session_lifecycle_dedicated` | Sprint 1: native loss bursts with a surviving observer, authoritative roster cleanup, paused HUD return, same-process rejoining, full-team retries, native/intentional host shutdown, same-port rehosting, reconnect cancellation, handoff timeout/late ack and shutdown while a handoff is pending. Checks lobby/world/session state, signal counts and strict logs. [Review](reviews/2026-11-17-sprint1-session-lifecycle.md). |
| `test_sgc_result_multiplayer`, `test_sgc_result_dedicated` | R9: squad wipe during SGC staging with active guards and turrets, retired bolts and charges, one final result, post-result joiners, expired staging callback, and a fresh retry on four-player listen and dedicated servers. |
| `test_mission_countdown`, `test_mission_countdown_multiplayer`, `test_mission_countdown_dedicated` | Sprint 2: timed-action validation, actual console progression, deadline admission, pause expiry, readable HUD/result, victory and retry; four-operative listen/pawnless dedicated running and terminal late joins, loopback estimates, server authority, stale snapshots, two retries and active-clock disconnect cleanup. Short clocks use private resource copies; the shipped duration stays 180 seconds. [Review](reviews/2026-11-17-sprint2-timed-extraction.md). |
| `test_alarm_escape`, `test_alarm_escape_multiplayer`, `test_alarm_escape_dedicated` | Sprint 3: validated alarm condition, real sentry/runner start before or after records, searching/disabled-console prevention, quiet success, one-shot/init/result guards, expiry and retries. Four-operative listen/pawnless dedicated fixtures reuse the countdown contract with real remote sightings: late joins during/after the window, estimates, server authority, shared outcomes, two retries and active-clock disconnect. [Review](reviews/2026-11-17-sprint3-alarm-escape.md). |
| `test_jaffa_hearing` | Sentry hearing with real weapons and a C4 charge: per-weapon radii, suppressed shot silent, unsuppressed shot heard and investigated, no escalation from noise, range limit, walls do not muffle, fighting sentry unaffected, blast heard beyond rifle range, search points visited and route resumed. |
| `test_jaffa_prop_cover` | Cover props on the integrated fixture: which attachments count, a spot behind the prop away from the threat and blocked at crouched height, held spots not reused, a sentry taking the crate, crouching most of the time and standing to fire hits over it, still alerted, relocation when flanked, and the unchanged fallback far from any prop. |
| `test_jaffa_perception` | Sentry perception on the integrated fixture with fresh sentries: nothing seen through walls or floors (where the assault rule would acquire), nothing outside the cone, suspicious before alerted no sooner than the notice time, forgetting, smoke, closed and open doors, damage alert, one-hop spread, search of the last seen position and resumption of the route at the same waypoint. |
| `test_stealth_takedowns_and_weapons` | Stealth takedowns from behind on unalerted sentries, rejection of frontal or alerted takedowns, quiet Zat stun/kill/vaporize without alerting target or nearby sentries or raising `MissionAlert`, dragging Zat-stunned and taken-down Jaffa bodies, and AP-1a `.glb` weapon ingestion (`p90_smg.glb`, `mp5_silenced.glb`) with D-015 `metallic = 0.0` material sanitization and provenance checks. |
| `test_imported_crate_visual` | The two ammo stacks share one fitted crate mesh and the crouched-player camera fades only the intervening stack. Both loadout racks share a cabinet and use the original collision faces. The imported re-armour shelf fits the original envelope, with a stock fallback. `test_multiplayer_mission_join` checks that clients construct all three families on late join and retry. `test_multiplayer_state_replication` exercises two concurrent station visitors. [Sprint 15 review](reviews/2026-11-24-sprint15-sgc-armoury.md). |
| `test_imported_m9_visual` | AP-1d: the M9 keeps its id, stats and `MuzzlePoint`; its bore lies within 3 mm of the `MuzzlePoint`; real size, nothing in front of the muzzle, 10,185 triangles, no collision, metallic 0 and mipmapped textures; a second copy shares the parsed model; credits and CC BY 4.0 text present. See the [review record](reviews/2026-11-16-ap1d-beretta-m9.md). |
| `test_imported_p90_visual` | AP-1e: the P90 keeps its id, stats and `MuzzlePoint`; its bore lies within 3 mm of the `MuzzlePoint`; real length 500.5 mm, width 68.5 mm, height 212 mm; 38,083 triangles, no collision, metallic 0 and mipmapped textures; a second copy shares the parsed model; credits and CC BY 4.0 text present. See the [review record](reviews/2026-11-16-ap1e-p90.md). |
| `test_imported_m249_visual` | AP-1f: unchanged SAW values and muzzle, measured crown within 3 mm, 13,328 triangles, bounds including extended bipod, no collision/navigation, mipmaps, part-ID colours ignored, cached meshes/materials, credits. Isolated negative-transform and missing-file fallback checks: [review](reviews/2026-11-16-ap1f-m249.md). |
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

AP-1c crate captures and render cost, on a display (writes `build/asset-review/plastic-crate/`, prints `CRATE_COST` lines for the dressed and original armoury):

```sh
godot --path client --script res://tests/support/crate_visual_review.gd
```

Weapon captures held by a real operative, on a display (AP-1d; writes `build/asset-review/<weapon>/`; run once per mission and weapon, e.g. `sgc_uat` and `goauld_infiltration`):

```sh
godot --path client --script res://tests/support/weapon_visual_review.gd -- --mission sgc_uat --weapon m9
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

`tools/tests` holds the runner's failure contract, a static check that no script searches the whole game for its surroundings (`test_world_scoping.py`: use `MissionWorld`), and the Goa'uld kit's geometry and palette rules (`test_theme_kit.py`: the committed kit matches its generator, each piece fills its slab, nothing can be seen through, gold stays above door height). They need no engine. `test_asset_intake.py` also checks source preservation, GLB declarations, external dependency reporting, malformed input and the existing embedded weapon files; a passing inspection is not engine or licence acceptance.

```sh
python3 -m unittest discover -s tools/tests -v
python3 tools/asset_intake.py client/assets/weapons/p90_smg.glb --output build/asset-intake/p90.json
npm ci --prefix alignment-app
node --test alignment-app/server/*.test.js
npm run build
```

The existing CI workflow runs runner contracts, Godot fast/multiplayer/full profiles, Alignment API tests and a frontend build. It pins Godot 4.4.1, Python 3.11 and Node 22.14.0, and retains diagnostic artifacts for 14 days. See [Alignment operations](ALIGNMENT.md) for that app's runtime requirements.


## Modular room scaffolding

The separate [modular kit guide](maps/modular-levels.md) documents the Phase 1 builder, neutral preview and `test_modular_level` contract. Later modular suites cover the catalogue, vertical kit, presets, security doors, themes, authoring CLI, planner and topology (`test_modular_*`, `test_level_*`), NPC navigation and the extraction mission. Full test discovery includes them without changing the existing SGC tests.

## Human acceptance still outstanding

No mission has a signed human run. The written checklists are: the route above for the SGC, the eleven steps in the [extraction mission guide](maps/modular-extraction-mission.md#human-uat-checklist-pending-sign-off), the six steps in the [NPC navigation guide](maps/modular-npc-navigation.md), and the editor checklists in the modular guides. Record completed runs under `docs/reviews/` with commit, roles and results. The [roadmap](../ROADMAP.md#near-term-acceptance-gates) lists the gates that depend on them.

## Community gate preview (AP-1g)

`test_imported_stargate_visual` verifies unchanged gate shapes, transforms, masks and seven anchors; aperture/envelope; source mesh sharing; visual-only geometry and mipmaps; snapshot, seven-chevron dialing, kawoosh, active horizon, reset and closure. Isolated negative-scale and missing-file fallback checks, Linux release export and mission captures are described in [the review](reviews/2026-11-16-ap1g-stargate.md). On a display: `flock /tmp/tdc-godot-network-tests.lock godot --path client --script res://tests/support/stargate_visual_review.gd -- sgc_uat` (also `goauld_infiltration`).
