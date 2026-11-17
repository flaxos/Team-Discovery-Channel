# Mission events — EV-2 chunks 1 to 3

An objective can now release a named security door. In Goa'uld Infiltration (including the travel mission's offworld site), command-room security starts locked. Sabotaging the generator releases it and shows `GENERATOR SABOTAGED — COMMAND SECURITY RELEASED`. The player then opens the door normally. Retry restores the lock and clears event progress.

## Authoring contract

Add a `MissionTrigger` resource to `MissionDefinition.triggers`:

```ini
[sub_resource type="Resource" id="release_command"]
script = ExtResource("trigger_script")
id = &"generator_releases_command"
objective_id = &"sabotage_generator"
security_id = &"cmd_command"
notice = "GENERATOR SABOTAGED — COMMAND SECURITY RELEASED"
```

`condition` defaults to `objective_completed`. For that condition, `id` is unique within the mission, `objective_id` names an existing non-extraction objective, and a door action's `security_id` resolves to exactly one native layout connection whose state is `security_door`. Generated node names such as `Door_002`, room names and paths are not accepted. There is one release per target door in this chunk. An empty trigger array preserves the old mission behavior.

Validation checks references, duplicates and the sequence's walking connectivity with all mission gates initially locked. It rejects an objective behind the very door it must unlock. The native `LevelLayout` remains authoritative and unchanged; the mission defines temporary runtime gates rather than new geometry or permanently inaccessible regions. Use the [authoring CLI](ai-level-authoring.md) for structural changes.

`MissionEvents` is a child alongside `Objectives` and `Alert` in the modular mission scenes. It initializes host-owned locks after navigation validation and before patrol startup. This keeps structural reachability checks meaningful while allowing staged access. It listens to the existing objective index and calls `ModularDoor.set_locked(false)` once; the door retains collision, reach checks, occupied-door protection, AI behavior and state replication.

## Timed Extraction consumer (sprint 2)

**Goa'uld Infiltration — Timed Extraction** (`goauld_timed_extraction`) is a separate standalone mission. Its [brief](briefs/timed-extraction.md) specifies a provisional three-minute extraction window after downloading command records. It inherits the existing infiltration scene and references the exact same native layout. Ordinary infiltration and travel keep their existing rules.

```ini
[sub_resource type="Resource" id="extraction_window"]
script = ExtResource("trigger_script")
id = &"records_start_extraction_window"
objective_id = &"download_records"
action = "start_timer"
duration_seconds = 180.0
timer_label = "EXTRACTION"
notice = "RECORDS ACQUIRED — EXTRACTION WINDOW STARTED"
```

`action` defaults to `release_door` for existing resources. A `start_timer` action needs a finite duration in `(0, 86400]` seconds, a nonempty label and no security-door target. Its objective must exist and precede extraction. A definition supports one timer; validation rejects unknown actions and multiple timers. There is no reset/extend action.

The host starts a monotonic wall-clock deadline once. `MissionEvents` processes even while paused. `MissionObjectives` also checks deadline admission before advancing, so extraction cannot win after expiry merely because the timer's process callback has not run yet. Expiry calls the existing mission failure path; it freezes the result, stands down enemies, freezes operative health, hides the clock, closes pause UI and shows **EXTRACTION WINDOW EXPIRED**. Early extraction stops the clock and preserves success.

Timer snapshots carry a revision, known trigger ID, state and remaining seconds. Only the authority RPC can update clients. Each client anchors remaining time on receipt and interpolates locally, refreshing from the host at most every 250 ms. Later running estimates can shorten but never extend the displayed window. This is an estimate affected by packet delay, not a synchronized server clock; only the host decides expiry. Stale revisions, nonfinite/negative/out-of-range values, unknown IDs and terminal-to-running transitions are ignored. Late joins receive current state without replaying a start notice. A result arriving before the timer snapshot is refreshed when the timer snapshot arrives, including the expiry-specific debrief. New operatives arriving after the result have frozen health too.

The top-right `MM:SS` panel rounds remaining seconds upward and turns red at 30 seconds. Mission notices sit below the objective banner. Retry replaces the world and all countdown state; disconnect frees it without a scheduled timeout callback.

## Alarm Escape consumer (sprint 3)

**Goa'uld Infiltration — Alarm Escape** (`goauld_alarm_escape`) consumes one new condition with the existing timer action. The [brief](briefs/alarm-escape.md) keeps the original compound and all objectives: if an alarm runner raises **ALARM**, a provisional three-minute extraction window starts immediately, including when generator sabotage or the records download remains unfinished. Searching alone starts no clock. Preventing the alarm allows an untimed escape; records download alone starts no timer in this variant.

```ini
[sub_resource type="Resource" id="extraction_window"]
script = ExtResource("trigger_script")
id = &"alarm_starts_extraction_window"
condition = "alarm_raised"
action = "start_timer"
duration_seconds = 180.0
timer_label = "EXTRACTION"
notice = "ALARM RAISED — FINISH OBJECTIVES AND EXTRACT"
```

An alarm trigger has no `objective_id`, requires at least one valid alarm console and supports only `start_timer`. Validation rejects unknown conditions, mixed alarm/objective bindings and alarm-driven door releases. Door topology proof still uses objective-driven releases only. The one-timer limit remains; there are no extra actions or generalized condition expressions.

`ModularMission` passes its existing `MissionAlert` to `MissionEvents`. The host consumes its actual raised state, not a client report or a SEARCHING transition. Initialization also checks a previously raised alarm. The same one-shot action path handles objective and alarm events. Later alert signals and objective completions cannot restart or extend the timer. Event execution stops at the final result.

On clients, an alert snapshot can refresh presentation but cannot run actions. Timer/fired-ID snapshots retain the existing revision, remaining-time, terminal-state and live-only notice rules. A late join during or after the deadline receives current state; it never reconstructs a new deadline from the alarm state. Retry creates a calm compound, working consoles and an idle timer. [Review and captures](../reviews/2026-11-17-sprint3-alarm-escape.md).

## Multiplayer and lifecycle

Only the host executes actions. Clients can use an objective console through its existing identity/reach/health/order validation; there is no client event-completion RPC. Live releases use readiness-gated mission RPCs. The fired-ID snapshot is monotonic, ignores unknown IDs and does not replay old notices. Doors send their own authoritative state.

A client can finish its navigation bake before the host. Snapshot requests received before host initialization wait until locks have been applied; that response refreshes the target door state as well as event progress. Conversely, a late client can receive an initialized lock during its own bake: doors retain the newest authoritative open/lock state until `navigation_ready`, so structural checks use the authored layout. Snapshot responses never re-run door actions or overwrite authoritative state from a reconstructed trigger list. This also covers retries while peers remain connected.

A final mission result stops actions. Restart creates a fresh world, objective index, event list and initial locks. SGC Defense keeps `WaveManager` and has no event director.

## Scope and verification

EV-2 remains incremental. Other alert levels, room conditions, objective enabling, optional/parallel objectives and power visuals remain future work. Add each only alongside a mission definition that needs it (D-003).

- `test_mission_events`: definition validation, unearnable-stage rejection, real generator interaction, reach/downed rejection, TA-3 blocked/released navigation, one-shot behavior, result freeze and retry.
- `test_mission_events_multiplayer`: real ENet late join while locked and after release, stale snapshot monotonicity, no stale notice, connected retry, rejected client event/door calls and forged/out-of-reach console identities, a real client console release and a second reset.
- `test_mission_events_dedicated`: the same network contract with a pawnless host. The first completed objective is a server-controller fixture for late join; after retry the remote operative earns the release through the real console.

[Review and captures](../reviews/2026-11-17-ev2-1-objective-doors.md).

- `test_mission_countdown`: timer-data validation, actual generator/records interactions, one-shot start, readable HUD placement, pause expiry, deadline admission before timer processing, frozen result, success, retry after either outcome and return during a running clock.
- `test_mission_countdown_multiplayer`, `test_mission_countdown_dedicated`: four operatives on listen/pawnless dedicated servers; real client console RPCs, late joins during the clock, loopback estimate agreement, rejected stale/invalid snapshots and client timer execution, shared success/expiry, terminal late join in the same process, two full-team retries and disconnect during an active clock.

[Sprint 2 review and captures](../reviews/2026-11-17-sprint2-timed-extraction.md).

- `test_alarm_escape`: definition rejection cases, real sentry detection and runner start before objectives, searching without a timer, repeat/init one-shot behavior, consuming a preexisting real alarm on initialization, disabled-console prevention, quiet success, alarm after records, pause expiry, result freeze and fresh retries.
- `test_alarm_escape_multiplayer`, `test_alarm_escape_dedicated`: reuse the four-operative countdown contract with real server alarm runners triggered by a remote operative's sighting. Cover running and terminal late joins, estimates, authority, records progression without retiming, shared results, two retries and active-clock host disconnect. The original countdown suites keep their original objective-driven start.
