# Sprint 3 — alarm escape

17 November 2026. Baseline main `a9eaf83` after merged #73; branch `feat/sprint3-alarm-escape`, supplied checkout. [Brief](../maps/briefs/alarm-escape.md), [event contract](../maps/mission-events.md), [D-023](../DECISIONS.md#d-023--consume-raised-alarms-with-the-existing-mission-timer).

## Behavior

The seventh visible mission is **Goa'uld Infiltration — Alarm Escape** (`--mission goauld_alarm_escape`). A guard raising ALARM starts one provisional 180-second window to finish generator sabotage, recover command records and bring every standing operative to the existing Stargate extraction marker. The clock can start before either objective or after the download. Searching starts no clock; preventing the alarm through the existing consoles/runners keeps the run untimed. Records download alone starts no deadline in this variant.

The scene inherits the existing infiltration scene and references its unchanged native layout. Existing missions retain their rules. Sprint 3 consumes one new event condition with the existing timer action; other EV-2 conditions/actions remain future work.

## Implementation

`MissionTrigger.condition` defaults to `objective_completed` for existing data. Validation permits `alarm_raised` only with `start_timer`, an empty objective binding and a valid alarm console. It retains the single finite timer limit. Unknown/mixed conditions and alarm-driven door releases are rejected. Objective-driven security releases still earn their native door through the original topology proof.

`ModularMission` passes its existing alert node to `MissionEvents`. On the host, an actual ALARM consumes the event once; initialization also consumes a previously raised alarm. Both conditions use the same action implementation and fired-ID state. Repeated signals, records download and late joins never reset the deadline. Clients receive current fired/timer/alert state without executing actions from alert snapshots. The existing authority, remaining-time estimates, pause behavior, final debrief, retry and disconnect rules apply unchanged. No new director or RPC was introduced.

## Evidence

- `test_alarm_escape` validates authored data and unsupported combinations, dispatches through the real lobby, gets a sentry sighting and real runner to raise the alarm, checks searching without a clock and alarm timing before objectives, repeated signals/startup, a timer-only initialization probe against a genuinely raised alarm, successful extraction and fresh retry. It disables both real consoles and checks that a spotted squad stays untimed, completes a quiet mission, rejects a post-result negative-control alarm, starts another real alarm after records, expires while paused before any objective and retries fresh. Positive mission starts never use manufactured alert/event snapshots. Short deadlines use private resource copies.
- `test_alarm_escape_multiplayer` and `test_alarm_escape_dedicated` reuse the four-operative countdown acceptance contract. Listen host + three clients, or pawnless host + four clients. A remote operative is seen at the checkpoint; the host's real sentries run to an alarm console before any objective is complete. Actual generator/records console RPCs then advance without retiming. Other operatives join the running clock. All peers agree on estimates/results, reject client timer execution and stale/invalid snapshots, retry twice, leave/rejoin in the same process after expiry, and return cleanly after host disconnect during a running clock. The original countdown suites retain their objective-driven start.
- Python tooling and strict local/hosted full results are recorded on the pull request. Logs stay under ignored `build/test-results/`; the shipped mission remains at 180 seconds.

Graphical fixture: `client/tests/support/alarm_escape_review.gd`, Godot 4.4.1 Forward+, 1440×900. The operative is placed at the checkpoint with increased health while the actual alarm runner acts. AI is parked after the alarm and operative health is normalized for the stills. This is HUD/mission-state inspection, not combat or balance acceptance. Expiry uses a private two-second clock; total mission duration also includes time before the alarm.

| View | Capture |
| --- | --- |
| New mission and launch description | [Lobby](sprint3-alarm-escape/1-selected.png) |
| Alarm starts the clock while objective 1 remains unfinished | [Alarm deadline](sprint3-alarm-escape/2-alarm-before-objectives.png) |
| Expired clock hides and existing failure debrief explains the cause | [Expiry fixture](sprint3-alarm-escape/3-expired-fixture.png) |

Human checks remain: quiet/loud squad runs, duration tuning and WAN responsiveness. No human co-op, art or latency acceptance is claimed. [Sprint 4](../plans/next-six-sprints.md), alternate-route flanking, is next after this lands.
