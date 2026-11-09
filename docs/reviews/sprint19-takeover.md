# Takeover review — 8 November 2026

> Historical record: findings, branch states, counts and environment limits below apply to the stated baseline. See the [current documentation index](../README.md) and [testing guide](../TESTING.md) for present behavior and commands.

Reviewed checkout: `087b4e3f2a4f46006f3ec00fb4a8bf945ab0287b` on `feat/sprint19-cursor-confinement-ads-zoom-fade`. Working tree clean. GitHub PR #19 is open, unmerged, and its head SHA matches this checkout. No gameplay code changed, no Sprint 20 implementation started, and no remote changes made.

## Codebase map

- `client/`: Godot 4.4.1 game. MainGameCoordinator transitions from lobby to GateRoom. NetworkManager autoload owns ENet connection/roster/session setup. GateRoom owns player spawning, mission layout and systems; WaveManager controls incursions. PlayerController3D combines movement, aiming, weapons, squad orders, camera and UI suppression. HUD owns the radial wheel and manual. JaffaAI and SGCAirmanAI implement tactical state machines.
- `alignment-app/`: separate React/Vite planning frontend and Express backend, backed by JSON. Its document export can overwrite the root project documents and optionally commit/push. Root README and roadmap describe earlier planning rather than current gameplay; treat scenes/scripts/tests as the current implementation evidence.
- Project uses strict GDScript untyped-declaration warnings. Installed Godot reports exactly 4.4.1.

## Findings, in priority order

1. **P1 — Existing alignment backend permits shell injection through commitMessage.** `alignment-app/server/index.js:438` interpolates request-controlled text into an execSync shell command. The export endpoint has no authentication middleware, CORS is unrestricted, and the server binds to `0.0.0.0` (line 483). If this service is reachable, a caller can execute commands as its user, in addition to triggering document rewrites. Use argument-based subprocess execution, explicit file staging, and an access boundary appropriate to its deployment. This predates Sprint 19; not exploit-tested.

2. **P1 — Elevator interactions do not consistently synchronize peers.** `client/scripts/props/SGCElevator.gd:199` calls `_open_doors()` locally for a same-floor closed-door call. `_dispatch_elevator()` at line 210 sends client requests to the server but calls `sync_move_elevator()` directly on the host; a direct call does not broadcast its RPC to clients. Host-operated transit therefore updates only the host, while same-floor door state can diverge on either peer. Route interaction decisions through the server and broadcast door/transit state. This includes a pre-existing host dispatch defect retained in the Sprint 19 path. Static control-flow finding; a two-peer run is still needed for validation.

3. **P1 — Captured mouse motion cannot select radial slices.** `client/scripts/entities/PlayerController3D.gd:226` forwards `motion.position` to HUD while `_update_mouse_mode()` keeps gameplay captured. The wheel needs accumulated relative motion. Existing `HUD.update_radial_command_wheel_rel()` and `RadialCommandWheel.update_mouse_direction()` already support this. A focused headless probe held ADS, opened the wheel, and delivered a motion event at screen center with `relative=(120,0)`: selection remained `-1` (CANCEL), offset `(0,0)`, rather than selecting the right slice. This affects ordinary TPS as well as ADS. Releasing RMB is not a code-level fix because mouse mode stays captured in both states.

4. **P1 — Claimed green radial verification contains a failing assertion.** `client/tests/test_squad_radial_wheel.gd:103` fails with “Quick tap must fire contextual ping without opening radial wheel.” Execution later prints the suite PASSED banner and exits 0. In this callback-based harness, an assertion aborts the callback but subsequent frames still reach success. All test runs need a failure-sensitive runner that rejects SCRIPT ERROR/assertion output, plus explicit failure propagation/timeouts. The first test's later hold assertions were skipped after the failure. The exact reason for the quick-ping assertion needs follow-up; do not infer a complete tap/hold pass from this run.

5. **P2 — Spiral staircase accessibility remains unverified.** `client/tests/test_sgc_dual_staircase_and_elevator.gd:161` and line 169 directly assign player.global_position to each stair. It checks positions/flags and then announces a smooth no-jump climb. It does not exercise continuous ascent with the production controller. The east staircase has a movement-based check, but runs movement in a render callback with live controller physics also enabled. Replace these with deterministic physics-tick traversal, no intermediate teleports, and clear arrival/timeout assertions. Likewise, visible-in-tree assertions do not prove that the observation window is unobstructed from a player's view. These are coverage findings, not a confirmed geometry failure.

## Verification rerun

Commands used Godot 4.4.1 headless with `--path client --script res://tests/<suite>.gd`. Full stdout and engine logs are in `/tmp/tdc-review/`.

| Suite | Result |
| --- | --- |
| test_sgc_dual_staircase_and_elevator | 4 pass sections; coverage limitations above |
| test_jaffa_column_march | 5 pass sections |
| test_sprint19_zoom_fade_cursor | 5 pass sections; out-of-tree Transform3D engine error |
| test_ads_pitch_alignment | 4 pass sections; out-of-tree Transform3D engine error |
| test_squad_radial_wheel | FAILED assertion despite success banner and exit 0 |
| test_keybindings_modal | 5 pass sections |
| test_sgc_4level_elevator_and_stairs | 5 pass sections; resource-in-use error at exit |

All seven processes exited 0. This is not an error-free green baseline. No graphical UAT, two-peer gameplay session, or exhaustive audit of every file was performed.

## Sprint 20 plan review

Original artifact: `/home/flax/.gemini/antigravity-cli/brain/601584bb-c83b-4967-8799-a2843a9a1d8e/sprint20_ads_squad_submenu_and_keybinding_remapping_plan.md`. It is local to Gemini and absent from tracked repository files.

The objectives are appropriate, but amend the technical plan before implementation:

- Use the actual current interfaces: `is_command_wheel_open`, HUD relative-motion method, and `update_mouse_direction()`. The proposed `radial_wheel.is_open`, `handle_mouse_motion()`, `airman_manager` and `squad_ordered` names are not the current integration path. Keep captured mouse mode and route deltas to the wheel. Preserve the already locked target on command-key press.
- Establish a canonical action registry and migrate every direct KEY_/MOUSE_BUTTON_/is_key_pressed branch to it, including squad command, context ping, stance toggles, weapon slots, deployables, C4 modes and zoom. InputMap edits alone cannot change those behaviors. Model individual movement/weapon actions instead of the manual's grouped rows. Remove the default Q overlap with gadget and define intentional G sharing.
- Define hold versus pulse semantics: wheel up/down are transient events and cannot directly sustain ADS, sprint or a 200ms radial hold. Specify toggle/pulse behavior or explicitly limit those assignments. Reserve ESC cancellation/recovery deliberately rather than promising literally any key without exceptions.
- Specify conflict resolution for multiple defaults and alternate bindings: swap/replace/cancel, contextual sharing, avoiding accidental unbinding of critical actions, and preservation of physical keyboard codes and modifiers.
- Prefer one KeybindingManager autoload with canonical defaults, validated load/save/reset, and change signals for modal/HUD prompt refresh. Validate malformed/unsupported config entries; handle missing files and write failures without losing usable controls. Keep tests isolated from real user settings.
- Input capture must consume the captured event, ignore the click that opened capture and keyboard repeats, and prevent rebinding from firing weapons, closing the menu, or issuing orders. Define cancellation on focus loss, modal close, death/downing and mission teardown; avoid stuck command holds when release events are swallowed by UI.
- Replace geometry-only radial tests with controller-to-HUD input tests while aim is held: all slices, deadzone, frozen pitch/yaw, retained ADS and target, release dispatch exactly once, resumed look, Q/M4 and remapped inputs. Test fresh-process persistence, reset, invalid config, conflict handling, and real gameplay activation for keyboard and every supported mouse event.

Recommended order: establish reliable failure reporting; fix and validate Sprint 19 blockers; track the amended plan in the repository; implement relative radial input; then implement the complete action registry and remapping UI/persistence. Preserve Sprint 19's commit as the takeover baseline.

## Resolution — accepted fixes

All nine suites in `tools/run_godot_tests.py` passed with error-sensitive log checking after the fixes. Added a real two-peer ENet elevator check and physics-tick traversal of both staircases. The spiral now has a wider continuous collider, visual-only treads, a floor opening and relocated rails. Corrected the weapon pitch calculation exposed by deferring test initialization. Headless runs skip audio playback, avoiding playback-resource leaks. Two Node tests cover export authorization and literal argument handling for malicious commit-message text. Graphical UAT remains a manual follow-up; scene visibility checks do not establish visual quality.
