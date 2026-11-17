# Sprint 3 — alarm escape brief

**Goa'uld Infiltration — Alarm Escape** (`goauld_alarm_escape`) is a selectable standalone variant on the existing compound and its native layout. It keeps generator sabotage, command records, all-standing-operative extraction, alarm consoles, runners and reinforcements.

An actual **ALARM** starts one provisional **180-second extraction window**, even if the generator or records objectives remain unfinished. Finish those objectives and return every standing operative to the existing Stargate extraction marker before expiry. Searching/suspicion does not start it. Preventing the alarm through the existing console/runner mechanics lets the squad complete a quiet, untimed mission. Downloading records alone starts no countdown in this variant.

The consumed event is `alarm_raised → start_timer`, with “ALARM RAISED — FINISH OBJECTIVES AND EXTRACT”. Reuse Sprint 2's host-owned wall-clock deadline, countdown, expiry debrief, final-result handling and retry reset. A live start shows its notice once; snapshots convey current state without executing actions. Alarm state arriving before event initialization is evaluated once when the host starts events. Late join, repeated alert signals and subsequent objectives cannot restart or extend the timer. A final result prevents new alarm actions.

Only this new condition/action combination is supported. Alarm-driven door releases, room conditions, extra objectives, layout changes, timer bonuses, a second timer and travel-specific rules remain outside this sprint. Existing missions keep their rules. Durations used in tests are private copies; the shipped duration remains 180 seconds. Human route, balance and WAN checks remain open.
