# Multiplayer stabilisation engineering report

Status (9 November 2026): engineering integration and local automated validation complete on `stabilisation/release-candidate`. Graphical multiplayer UAT is pending; this is not a release-readiness claim. Godot target: 4.4.1.

## Scope and preservation

The previous unfinished SGC cleanup was preserved without resetting or discarding files at `b70ed19` on `recovery/unfinished-sgc-cleanup`. The release branch starts from fetched main `a81304e`. The six existing specialist workstreams were preserved in their original Git worktrees. This continuation used no additional agents; changes were integrated sequentially. No shared history is rewritten and no merge to main is authorized.

## Confirmed audit findings

| Severity | Confirmed defect | Evidence / root cause | Correction owner |
| --- | --- | --- | --- |
| P0 | Sprint 20 missing from main | PR20 merged to Sprint19 branch; exact tree/commit comparisons in Agent1 report | Git: exact recovery on current-main branch |
| P0 | Remote shots mutate only a client replica | Separate ENet audit: client Jaffa 90→66, server remains90; WeaponBase local hit calls unguarded HealthComponent | Combat: server shot validation and health/status results |
| P0 | Health/status mutations and countdowns run without server authority | Direct damage, heal, revive, Zat and timers accept every peer; property replication does not emit transitions | Combat: authoritative state contract |
| P1 | Repeated vaporisation is not idempotent | Repeated dead-target Zat emits vaporized twice in runtime probe | Combat + state lifecycle |
| P1 | Equipment switches replenish ammunition | Weapon replacement constructs fresh magazine/reserve state | Combat: preserve per-slot state |
| P0 | Mid-mission join never enters mission | register_player sends roster/settings but no start/world-ready handshake; fixed spawn delay | State: coherent late-join handshake/snapshot |
| P1 | Airmen do not follow server movement | No Airman synchronizer; real ENet contexts retain different positions | State: native NPC state replication |
| P1 | Blast doors mutate locally and elevator lacks late-join snapshot | Local console toggles; movement-only RPCs cannot initialize late joiners | State: validated server interactions + snapshots |
| P1 | Ended mission keeps broadcasting and replica NPC handlers count/remove independently | Snapshot occurs before ended guard; non-authoritative lifecycle paths | State: retirement and once-only server events |
| P1 | API mutators lack authentication/validation | Non-export POST routes are public; export trusts loopback; unrestricted CORS | Backend: explicit authorization and validated transactions |
| P1 | Ordinary votes overwrite human documents | saveState calls root-document regeneration | Backend: docs/generated isolation |
| P1 | Clean checkout cannot reliably bootstrap tests | Missing class cache; first editor import exits0 with Busy resource error | Combat lazy resource loads + QA strict bootstrap |
| P2 | Operational docs do not describe implemented project | README foregrounds obsolete planning and omits authority/run/release contracts | Architecture: source-backed operational docs |

Rejected hypothesis: current main already contains EnemySpawner and Jaffa replication. These systems must be repaired where necessary, not duplicated.

## Completed integration

| Milestone | Commit | Result |
| --- | --- | --- |
| Recovered baseline and prior SGC work | `0d9dcce`, `0bb2d1b`, `62d15bf` | Exact Sprint 20 recovery and preservation; audit evidence retained |
| QA/CI and regression repair checkpoint | `4bffe66`, `6268c5c` | Strict complete test discovery, failure-sensitive import, CI and repaired current-game fixtures |
| Combat validation repair | `5e44413` | Preserve per-weapon inventory and prevent a holstered reload from overwriting active HUD ammo |
| Combat integration | `87217e7` | Preserves WIP `7530c27`; server resolves shots, ammo/rate limits, damage, Zat, downing and timed revive |
| State validation repair | `c6f7cf7` | Registration precedes mission start; readiness gates replication; correct class initialization, safe visual cleanup, lift snapshots and fixture shutdown |
| State integration | `763267f` | Preserves WIP `062be27`; NPC movement/posture/lifecycle, doors, lift and validated station requests |
| Backend integration | `c855811` | Preserves WIP `5182692`; explicit authentication, exact origins, bounded validation, separate Git-export capability and generated-document isolation |
| Combined combat/state repair | `e9ba96b` | Server-approved rack weapons remain usable; inventory arrives before ammo; initial weapon snapshots restore authoritative ammunition |
| Remaining full-suite repairs | `5b01a11` | Correct network fixture retirement, current TPS/stair assertions, headless audio retirement and missing climax gate-room enemies |

Only duplicate generated Godot UID files conflicted during the combat/state merges. The integration branch's existing canonical IDs were retained. Gameplay changes merged without discarding either workstream. All original WIP commits remain reachable, all branches/worktrees remain present, and main was neither merged into nor rewritten. The fetched `origin/main` remains `a81304e` and is an ancestor of this branch.

### Combat and mission-state verification

The native combat test uses separate physics worlds and ENet contexts. It verifies host/client/concurrent server hits, exactly-once death, spoofed sender/weapon/origin/direction rejection, server rate and ammunition limits, slot persistence, reload completion while holstered, weapon snapshot correction, authoritative Zat stun/kill/vaporization, downing, timed revive and disconnect handling.

The state test verifies existing NPC spawners, Airman movement/posture, Jaffa transform/posture/despawn, once-only kill counting, objective snapshots without false change events, door snapshots, lift floor/door/cabin snapshots, station distance validation, and a remote rack interaction followed by an accepted server shot. A new separate-process test uses the actual NetworkManager autoload and MainGameCoordinator to join an already-running dedicated mission, preserve the Carter class, receive objective progress and retry with canonical multiplayer paths. It exposed and drove fixes for early NPC replication and class initialization that the in-process fixtures did not catch.

The previously preserved regression repairs were reviewed against the current TPS camera, 29 visual stair treads and continuous helical collider. Physical stair traversal remains covered by its dedicated suite. UI/console fixtures explicitly establish earned extraction prerequisites; the separate three-wave test still earns extraction through actual wave progression.

## Executed validation

Environment: Godot `4.4.1.stable.official.49a5bc7b6`, Node `24.19.0`, npm `11.17.0`, Python `3.12`. CI pins Python 3.11 and Node 22.14.0. Native socket tests ran outside the filesystem/network sandbox so local ENet and HTTP fixtures could bind sockets.

| Check | Actual result | Evidence |
| --- | --- | --- |
| Initial complete Godot run after integration | 40/47 checks passed, 7 failed | `/tmp/tdc-resume-full/summary.json` |
| Targeted rerun of all seven failures after repairs | Import + 7/7 suites passed | `/tmp/tdc-resume-regression-repairs/summary.json` |
| Final full Godot profile | **47/47 checks passed, zero failures, zero exclusions** | `/tmp/tdc-resume-full-final/summary.json`, `junit.xml` and per-suite logs |
| Runner failure-reporting contracts | **9/9 passed** | `python3 -m unittest discover -s tools/tests -v` |
| Complete backend security suite | **14/14 passed** | `node --test alignment-app/server/*.test.js` |
| Server JavaScript syntax | Passed for every server `.js` file | `find alignment-app/server -name '*.js' -print0` piped to `xargs -0 -n 1 node --check` |
| Production frontend | Passed | `npm run build` |
| Official CI engine installer | Passed download and published SHA512 verification | `/tmp/tdc-hardening/verified-godot/godot --version` confirms 4.4.1 |
| Git whitespace and integration ancestry | Passed | `git diff --check`; `git merge-base --is-ancestor origin/main HEAD` |

The final Godot inventory contains **45 test scripts**. Persistence uses separate writer and reader processes, producing **46 test-process checks plus project import**. A fresh `.godot` cache was generated for the first complete integration run; the previous generated cache was moved to `/tmp/tdc-resume-integration-godot-cache` rather than deleted. Strict import passed on that clean bootstrap and on the final full run. The runner rejects assertions, engine errors and leak warnings even when the process exits zero or prints success.

Reproduce:

```sh
npm ci --prefix alignment-app --no-audit --no-fund
python3 tools/run_godot_tests.py --godot /home/flax/bin/godot \
  --profile full --output /tmp/tdc-resume-full-final --timeout 30
python3 -m unittest discover -s tools/tests -v
node --test alignment-app/server/*.test.js
npm run build
python3 tools/install_godot_ci.py --destination /tmp/tdc-hardening/verified-godot
git diff --check
```

### Failures found and resolved during continuation

- Sandbox-only import attempts could not open editor sockets. They were not counted as passing; validation was rerun with local sockets permitted.
- The first state test observed a cabin height before the physics body applied its fixture transform. The fixture now waits for physics; actual snapshot teleports and transit tweens are handled explicitly, with superseded door/transit tweens retired.
- The separate-process join test exposed premature Airman replication and class/visual initialization errors. Readiness visibility and roster initialization fixed these; its final join/retry run passes without client engine errors.
- The initial full run failed `test_gate_client_authority`, `test_jaffa_ai_smoke`, and `test_netcode_smoke` on closed ENet references during teardown; `test_sprint2_tactics_smoke` on an audio resource retained at shutdown; `test_sprint7_level27_smoke` and `test_sprint8_multifloor_combat` on superseded staircase/camera assertions; and `test_sprint9_interactives_climax` on eight counted enemies but only four spawned. Each was repaired, passed its targeted rerun, then passed the final full run. Headless turret/mine playback now avoids creating unneeded audio voices. The existing multi-sector climax creates its gate-room group independently of inbound-wormhole streaming.

## Remaining acceptance limits

There are no known failing local automated tests or unfinished engineering integration steps. Human graphical multiplayer UAT remains required before release-candidate acceptance: rendering, combat feel, two-human mission completion, WAN/latency behavior and the browser authentication/tunnel workflow were not established by these headless tests. No live external tunnel or real backend-triggered Git export push was performed. The engineering PR is prepared as a draft targeting main, with no merge authorization implied.

Hosted CI status and the PR URL should be checked on the pull request; local results above are not claims about an unexecuted hosted job.
