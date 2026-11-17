# Modular Jaffa flanking — TA-2 chunk 1

Existing modular missions now give trailing sentries an alternate-entrance maneuver. It is part of their combat controller, not a new mission mode. [Brief](briefs/modular-flanking.md), [review and recorded trajectory](../reviews/2026-11-18-sprint4-modular-flanking.md).

## Starting a flank

The host can start one when a standing sentry of formation rank 1 or later actually sees a live standing threat, an earlier rank nearby is already engaging that same target, and no nearby guard already has a flank. Leads retain existing cover/combat behavior. A target within melee range plus one metre is too close to start. Support is checked at assignment; this chunk adds no suppression or squad-role coordinator.

`LevelNavigator.plan_flank` uses the native walking graph with current runtime locks. It finds a usable route with the fewest room connections, removes that approach's final connection and looks for another entrance. Same-room encounters, unreachable/out-of-level positions and a missing alternate retain ordinary combat/cover. The second entrance must offer at least 45 degrees of angle change from the direct approach and lie at least 2.7 m from the last sighting.

The route stitches real navmesh legs through each selected connection's socket approaches. It avoids visiting a large room's insertion marker unnecessarily. Every crossed native socket plane, including open passages without a runtime door, is checked: shortcuts through connections outside the selected route are rejected. Planning rejects locked doors and walks over 80 m. It never changes the native layout, navigation mesh, door collision or locks.

## Execution and cancellation

The host commits that path and runs to a floor point inside the alternate entrance. The navigator can open ordinary unlocked doors through the existing AI interface; automatic closing, occupancy and local NPC yielding still apply. A fixed flank never falls back to a direct-route replan when blocked. It cancels on a new lock or an unreachable/stalled path.

Movement uses the last-seen position, not an unseen target's live transform. Losing sight permits only this bounded maneuver. Newly seen movement over four metres or a visible threat entering melee range cancels the old approach. Target departure/death/downing, an alarm errand, the guard's incapacitation, or a final mission result also retires it. The maneuver lasts at most 20 seconds, with an eight-second cooldown after completion/cancellation. A blocked body reports stuck after the navigator's existing three-second limit. Limits are provisional.

On arrival or cancellation, a fresh sighting leads back to existing prop-cover/combat selection; otherwise the guard investigates the remembered position. A guard does not fire while executing the flank. Normal SGC behavior and friendly tactics remain outside this chunk.

## Multiplayer and evidence

Only the server plans and executes AI movement. Both Jaffa scenes replicate the existing pose/state plus `is_tactical_flanking`, including spawn/late-join snapshots. Clients have no committed path and cannot assign one through local AI calls. The planner has no RPC. Mission stand-down cancels it and retry creates fresh guards/state.

- `test_modular_flanking` reuses TA-3's existing loop fixture. Real perception starts combat, the lead holds and a trailing guard physically traverses the other rooms. It checks a second guard's fallback, open passages, locks before/during travel, cost and missing-route rejection, last-sighting behavior after concealed motion, newly visible movement/close threats, obstruction/timeout, target departure, alarm preemption, incapacitation and stand-down.
- `test_modular_flanking_multiplayer` / `test_modular_flanking_dedicated` use the unchanged infiltration compound with four operatives. Actual detection starts a flank; it is held briefly so late peers load deterministically, then the production controller traverses it. Every peer observes the alternate rooms and final pose/flag. They reject client planning, retry twice, cancel a second flank at mission failure and return cleanly on server shutdown.
- Existing cover, perception, alarms, TA-3, travel and lifecycle suites remain regression coverage. The graphical cutaway and JSON capture distinguish planned points from observed host motion. Human squad readability, timing and WAN behavior remain review work.
