# Sprint 4 — modular Jaffa flanking

18 November 2026. Baseline main `d2d74c3` after merged #74; branch `feat/sprint4-modular-flanking`, supplied checkout. [Brief](../maps/briefs/modular-flanking.md), [contract](../maps/modular-flanking.md).

## Result

A nearby trailing sentry can take another room entrance when it sees a threat already engaged by an earlier rank. One nearby guard takes that role; other guards retain ordinary cover/combat. A usable second approach must change the entrance angle and pass live-lock, navmesh and walking-budget checks. The host follows a committed route, never silently replacing it with the direct doorway. With no valid route it falls back safely.

The maneuver consumes a last sighting. Hidden movement cannot retarget it; a newly seen move, visible melee threat, new lock, obstruction, timeout, unavailable target, alarm errand, incapacitation or mission end retires it. Fresh sight then resumes combat/cover; otherwise the guard investigates. Retry replaces route state. The existing SGC tactics and future suppression/friendly squad chunks remain separate.

## Implementation and scope

`LevelNavigator` reuses its walking graph, native connection/socket approaches, navmesh stitching, door handling and yielding. A fixed-route branch prevents ordinary stall/lock replans from undoing the flank's alternate entrance. It verifies crossed socket planes for open passages too. `JaffaAI` owns assignment, remembered position, bounded execution and cancellation. Both Jaffa scene synchronizers add the flank flag; clients receive movement/state rather than a path planner. No new gameplay RPC, authored geometry, layout, mission variant or navigation bake was added.

The initial 48 m budget rejected the native compound's long loop. Inspection also found that routing through the hangar's insertion marker added an unnecessary detour. The final route uses socket-to-socket legs, with an 80 m maximum, a 20-second maneuver limit and an eight-second cooldown. At the controlled native encounter it completes in about 13.7 simulated seconds. The 45-degree entrance change, 2.7 m target clearance and all timing values remain provisional for human play.

## Verification

- `test_modular_flanking`: TA-3's existing four-room loop, with real sight-based engagement and physical alternate-route traversal. Covers one nearby flanker, lead retention, locked/missing routes, live lock cancellation, open passages, walk cost, concealed target movement without tracking, newly visible movement/close threat, stuck/timeout behavior, departure, alarm preemption, stun/downing and mission stand-down. Manual controls are negative cases; positive engagement and movement use the production controller.
- `test_modular_flanking_multiplayer` and `test_modular_flanking_dedicated`: four operatives on listen and pawnless dedicated hosts. Late joins inspect a deliberately held real plan, then every peer observes native-room traversal and agreement on the final pose/flag. Clients cannot execute the AI or plan paths. Two full-team retries remove old actors/plans, and mission failure cancels a second flank before clean server shutdown.
- Targeted cover, TA-3 navigation and SGC column-march checks passed during development. Python tooling, local full and hosted final counts are recorded on the pull request. Detailed logs remain under ignored `build/test-results/`.
- CLI capability discovery and topology inspection were used; the saved native compound remains unchanged. Other unfinished checkouts were not touched.

The reproducible `client/tests/support/modular_flanking_review.gd` uses Godot 4.4.1 Forward+ at 1440×1000. It parks authored patrols/alarms, opens an ordinary door via its real AI interface and places an invulnerable operative plus fresh controlled sentries. Actual perception starts the plan. Roof visuals are hidden only for the cutaway; collision remains. Cyan is the planned route, orange the observed host trajectory. The JSON contains raw world positions, native room sequence and simulated duration. These are controlled behavior captures, not human combat/art acceptance.

| Evidence | Artifact |
| --- | --- |
| Committed alternate entrance | [Plan](sprint4-modular-flanking/1-plan.png) |
| Physical progress around the compound | [Mid-route](sprint4-modular-flanking/2-mid-route.png) |
| Arrival at the opposite entrance | [Arrival](sprint4-modular-flanking/3-arrived.png) |
| Planned versus actual positions and duration | [Trajectory JSON](sprint4-modular-flanking/trajectory.json) |

Human checks remain: recognize and counter the flank in a squad firefight, assess the long-loop cost and cooldown, test interplay with alarms, and review WAN presentation. [Sprint 5](../plans/next-six-sprints.md), ammunition sharing, is next after this lands.
