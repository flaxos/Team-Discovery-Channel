# Sprint 2 — timed extraction

17 November 2026. Baseline main `9b292c7` after PR #72; branch `feat/sprint2-timed-extraction`, supplied checkout. [Mission brief](../maps/briefs/timed-extraction.md), [event contract](../maps/mission-events.md).

## Behavior

The sixth visible mission is **Goa'uld Infiltration — Timed Extraction** (`--mission goauld_timed_extraction`). Generator sabotage releases command security. Downloading records starts a provisional 180-second window to bring all standing operatives to the existing Stargate extraction marker. The host alone decides success or expiry. Menus cannot extend the deadline. Failure reports **EXTRACTION WINDOW EXPIRED**, preserving the actual count of standing operatives. Victory stops the clock; later expiry cannot overwrite it. Retry replaces all event state.

The variant inherits the infiltration scene and references the existing native layout without editing its geometry or anchors. The ordinary infiltration and travel missions keep their existing rules. This consumes EV-2's timer action only; sprint 3's alarm-driven stage remains planned.

## Implementation and limits

`MissionTrigger` adds `start_timer`, duration and label; existing resources default to `release_door`. Validation permits one finite, positive timer per mission and rejects ambiguous door/timer targets, unknown actions and impossible references. `MissionEvents` owns a monotonic real-time deadline and always processes during pause. An objective-admission guard checks the deadline before accepting extraction, independent of frame callback order. Expiry uses the existing result path. A final result stops event execution and freezes operative health, including late-spawned operatives.

The authority sends revisioned timer state and remaining seconds at four updates per second. Clients interpolate receipt-anchored estimates, reject stale/invalid snapshots and cannot extend an existing displayed window. Packet delay can make estimates lag the host; this is deliberately not a general clock-sync service. Only the host expires the mission. A terminal snapshot updates the debrief even if the ordinary room-result snapshot arrived first. Timer snapshots do not replay the start notice.

The countdown sits at the top right and turns red at 30 seconds. Live notices now sit below the objective banner; the rendered check found and fixed their former overlap. The Timed Extraction lobby hides Defense-only difficulty controls and explains that menus leave the clock running.

## Evidence

- `test_mission_countdown`: authored-data rejection cases; actual generator and records interactions; one-shot timing; HUD placement at 1280×720; expiry while paused; admission after the deadline before the timer callback; final failure/success; retry after both; return during a running clock.
- `test_mission_countdown_multiplayer` and `test_mission_countdown_dedicated`: listen host plus three clients, or pawnless dedicated host plus four clients. Real remote console interactions start the timer. Remaining-time snapshots for late joins agree with the host within 1.5 seconds on loopback. Invalid/stale snapshots and attempted client execution leave authority unchanged. Every peer receives shared success and expiry, retries twice, and returns cleanly after host disconnect during a clock. One client leaves and rejoins in the same process after expiry to check the terminal debrief, hidden clock and frozen health.
- Short deadlines are private resource copies in fixtures. The cached/shipped definition remains 180 seconds.
- Strict local full and hosted results are recorded on the pull request. Generated detailed logs stay under ignored `build/test-results/`.

The reproducible graphical fixture is `client/tests/support/mission_countdown_review.gd`, rendered using Godot 4.4.1 Forward+ at 1440×900. It parks AI, places the operative between scenes and points its camera into the command room. These captures review HUD layout, not combat or art acceptance. The urgent/expiry captures use a private two-second clock.

| View | Capture |
| --- | --- |
| Selected mission and launch description | [Lobby](sprint2-timed-extraction/1-selected.png) |
| Authored three-minute window, objective and live notice | [Countdown](sprint2-timed-extraction/2-countdown.png) |
| Red urgency state, shortened fixture | [Urgent](sprint2-timed-extraction/3-urgent-fixture.png) |
| Final expiry debrief, clock hidden | [Expired](sprint2-timed-extraction/4-expired-fixture.png) |

Human checks remain: play the three-minute route with a real squad, tune duration, and assess countdown accuracy/responsiveness over WAN latency. No human co-op, balance or latency acceptance is claimed. [Sprint 3](../plans/next-six-sprints.md) is the next planned package after this lands.
