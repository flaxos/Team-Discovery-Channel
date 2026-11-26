# Sprint 29 — Goa’uld command room

Sprint 29 builds on `bf2371b`, the Sprint 28 merge to `main`. The native catalogue identifies the live command room as `cmd_command` with module `room11` (`Room11LargeChamber`) and the `command` preset. The stock shell receives the Goa’uld engineering kit with a recessed bronze seal on its eastern wall. It occupies 16 × 16 m with a 3.4 m clear height at `(-16, 4, 48)` and a 90° turn. [Sprint 28 PR](https://github.com/flaxos/Team-Discovery-Channel/pull/105) · [Command catalogue](../../build/sprint29/command-catalogue.json) · [Baseline capture](../../build/sprint29/command-baseline.png).

## Existing layout and console fit

The upper-deck entrance connects `cmd_antechamber/north` to `cmd_command/north_00` through the named security door. The second doorway connects `cmd_command/north_01` to `cmd_observation/north`. Generator sabotage releases the command security door. The console locations below use room-local coordinates. All three existing approach points project to the navmesh floor within 0.20 m. [Native layout](../../client/resources/levels/goauld_infiltration_01.tres) · [Command preset](../../client/resources/room_presets/command.tres) · [Native validation](../../build/sprint29/infiltration-validation.json).

| Slot | Room-local origin in metres | Existing solid envelope in metres (W × H × D) | Visible meshes and triangles |
|---|---|---|---|
| `console` | `(2.6, 0, -2.6)` | `1.0 × 1.0 × 0.8` | 9 meshes, 128 triangles |
| `secondary_console` | `(-2.6, 0, -2.6)` | `1.0 × 1.0 × 0.8` | 9 meshes, 128 triangles |
| `main_console` | `(8, 0, 4)` | `2.0 × 1.0 × 1.0` | 24 meshes, 368 triangles and one readout |

The live `download_records` interaction belongs to `main_console`. The kickoff probes verified that it cannot advance before sabotage and can advance after the real generator interaction. Infiltration leaves the timer idle. Timed Extraction starts the 180-second window on records download. In Alarm Escape the timer starts with the alarm and continues through records download. The Alarm Escape baseline raised the alarm through the existing controller before interacting with the records console. [Infiltration probe](../../build/sprint29/goauld_infiltration.log) · [Timed Extraction probe](../../build/sprint29/goauld_timed_extraction.log) · [Alarm Escape probe](../../build/sprint29/goauld_alarm_escape.log).

## Art integration

The three art families are the command-room surfaces, the two reusable console scenes and recessed insignia. The original static bodies remain the collision for the desks and the side consoles. The main terminal includes two records banks and a readout that follows its existing interaction objective and the authoritative clock. Timed Extraction starts the display clock after download. Alarm Escape can show the clock with access still locked. Each new mission starts with the locked state. [Records terminal](../../client/scenes/props/OffworldRecordsTerminal.tscn) · [Command station](../../client/scenes/props/OffworldCommandStation.tscn) · [Readout](../../client/scripts/level/CommandRecordsDisplay.gd).

**Sourcing.** Both consoles are original Godot scenes that use the project's basalt, bronze and gold materials. No new texture or third-party asset ships in this slice. The screened CC Attribution listings include DOM's 2.1k-triangle terminal with fixed spacecraft instrument text, Inditrion Dradnon's 2.6k-triangle computer desk with monitor stands, and x4vier28's 7.6k-triangle console with a damaged monitor. A recessed records screen and two matching low stations fit the measured heights and support live text. [Spacecraft Control Terminal](https://sketchfab.com/3d-models/spacecraft-control-terminal-console-follow-me-3e45923d316e48efb7b0650ebe6c9411) · [Sci-Fi Computer Desk Console](https://sketchfab.com/3d-models/sci-fi-computer-desk-console-28c67457f2ef4973a0bbc8b667bb183f) · [Abandoned Sci-Fi Control Console](https://sketchfab.com/3d-models/abandoned-sci-fi-control-console-689b4d970c1c4a099c7c3c2238310255).

## Technical verification

- Native validation passed with zero warnings. Authored theme pieces reach 17 of the 20 live rooms. All 60 Python checks passed. The theme suite confirmed that the room's physical structure, sockets, markers and baked navigation matched the assembly with the neutral theme. The console test checked the original shape and the bounds of each visible mesh. [Native validation](../../build/sprint29/final-native-validation.json) · [Python results](../../build/sprint29/python.log).
- Eight focused Godot suites passed. The local fixtures downloaded the records after the actual sabotage and checked Timed Extraction expiry, successful extraction, retry and the alarm runner. Four-operative listen and dedicated fixtures covered both timed variants, with live records interactions, running and terminal late-join snapshots, clock agreement and resets across retry. The unchanged Infiltration suite traversed the maintenance route and extracted after downloading the records. [Focused runner summary](../../build/sprint29/focused/summary.json).
- The standard Linux package booted and passed the packaged records, countdown and retry fixture. Both standard and procedural-gate packages passed the dais route and extraction. [Linux export log](../../build/sprint29/linux-export.log).
- The full Godot run had two failures. The preset suite assumed that a sized attachment always used the stock placeholder. Its assertion now follows the composer’s scene precedence, and the fixture passed on retry. The SGC dedicated result fixture passed on an isolated retry. [Full runner log](../../build/sprint29/full.log) · [Isolated retry results](../../build/sprint29/full-retries/summary.json).

## Owner art review

Compare the console scale and readout from the approach, and check the bronze wall seal from the room entrance. The records views show the locked, ready and downloaded states after live interactions. The alarm view uses the stock shoulder camera. Owner art approval is open. [Room](../../build/sprint29/command-room.png) · [Locked](../../build/sprint29/command-locked.png) · [Ready](../../build/sprint29/command-ready.png) · [Timed download](../../build/sprint29/command-timed.png) · [Alarm shoulder](../../build/sprint29/command-alarm-shoulder.png).
