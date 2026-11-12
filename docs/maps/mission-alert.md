# Compound alert, alarm consoles and reinforcements

Roadmap milestone **EV-1**. One host-owned alert level per modular mission, alarm consoles that an alerted Jaffa must reach, and a reinforcement budget. Used by the [Goa'uld infiltration mission](goauld-infiltration-mission.md). The [extraction UAT mission](modular-extraction-mission.md) defines no consoles, so its alarm can never be raised.

## How it plays

| Level | Starts when | HUD |
|---|---|---|
| **Calm** | Mission start, or the end of an escalation | Banner: `HOSTILE PATROLS ACTIVE: n JAFFA` |
| **Compound alerted** | Any sentry is alerted (red **!**). A sentry that is only suspicious or checking something does not start it | Banner `COMPOUND ALERTED`; toast *You have been spotted* |
| **Alarm raised** | A Jaffa worked an alarm console for its full raise time | Banner `ALARM RAISED`; toast; klaxon every 4 s |

- **The runner.** While the compound is alerted, the alerted sentry with the shortest walk to a working console runs for it. It ignores combat while it runs, shows a magenta **!!** overhead, and must stand at the console, uninterrupted, for the console's raise time (2.5 s in the infiltration mission). The squad gets a toast: *A Jaffa is running for the alarm*.
- **Stopping it.** If the runner dies, is stunned or downed, another alerted sentry is chosen, and its time at the console starts again. Disabling the console the runner is heading for stops that run at once.
- **Disabling consoles.** An operative can disable a console with interact (prompt *Disable alarm*, visible within 12 m) at any time before the alarm. A disabled console can never raise the alarm. With every console disabled, nobody runs and the alarm cannot be raised.
- **The alarm is final.** Once raised it stays raised for the mission, and consoles can no longer be disabled. Every sentry not already fighting goes to search where the squad was last seen. Each reinforcement group arrives once, after its delay, at its spawn point and sweeps between there and the last sighting. Nothing arrives beyond the budget.
- **Calming down.** Without an alarm, the escalation ends once no sentry has been alerted or searching for 8 s. Patrols resume and the banner returns to calm.
- **Debrief.** The status line ends with *Undetected*, *Spotted, no alarm* or *Alarm raised*.

## Mission data

Two typed lists on `MissionDefinition`, both by room and attachment id; no coordinates.

```text
alarms:          MissionAlarm          room, attachment (default "console"), raise_time, prompt
reinforcements:  MissionReinforcement  room, attachment (a spawn point), count 1–4, delay, shock_guard
```

`MissionDefinition.validate()` rejects an unknown room or attachment, a console listed twice, a console that is also an `interact` objective, and reinforcements without any console.

In the infiltration mission: consoles at `checkpoint/console` (lower deck, on the guarded route) and `cmd_observation/console` (upper deck, beside the command room). Reinforcements come from the barracks: two Jaffa at `squad_01` after 6 s, two shock guards at `squad_03` after 20 s. Every number is provisional until people play it.

## How it is built

| Piece | File | Notes |
|---|---|---|
| Director | `client/scripts/mission/MissionAlert.gd`, node `Alert` in both modular mission scenes | Server evaluates every 0.2 s: alert level, runner choice and raise time, reinforcement timers. All state changes go through one replicated `sync_state` (level, disabled consoles, runner name, spotted), which also runs on the server |
| Console use | `client/scripts/mission/MissionAlarmConsole.gd` | Added under each console attachment. Clients send identity; the server checks sender, reach and health |
| Data | `MissionAlarm.gd`, `MissionReinforcement.gd`, `MissionDefinition.gd` | |
| Jaffa | `JaffaAI.run_to`, `end_run`, `investigate_at`, `raising_alarm` | A run overrides the state machine but perception keeps running. `investigate_at` sends a calm or suspicious sentry to search a position |
| Host | `ModularMission.gd` | Banner, toasts, debrief line; the director stops at the result |

**Multiplayer.** Updates use the readiness-gated mission messages from EX-1. A joining client asks for a snapshot, so a late joiner sees the current level, disabled consoles and the runner's tell. Reinforcements are spawned by the existing enemy spawner. The alarm and disabled consoles never revert on a client, so a stale message cannot undo them. A retry builds a new director: calm, every console working, no reinforcements.

`WaveManager` remains the SGC Defense director and is not shared.

## Automated coverage

```sh
python3 tools/run_godot_tests.py test_mission_alert test_mission_alert_multiplayer --timeout 400
```

| Suite | Covers |
|---|---|
| `test_mission_alert` | Validation rules. Calm start with two working consoles. Spotted at the checkpoint → alerted → the checkpoint guard runs to the checkpoint console with the **!!** tell → alarm. Every sentry hunts; consoles read *Alarm active* and cannot be disabled. Reinforcements: two after about 6 s, none early for the second group, two shock guards after 20 s, then none beyond the budget. Retry resets everything. A killed runner is replaced; disabling the console a runner heads for stops it; with both consoles disabled, being seen raises nothing and no reinforcements come. The escalation calms down by itself. Debrief line. Director stops at the result |
| `test_mission_alert_multiplayer` | Two processes. A client joins after the alarm and the first reinforcements: it sees the alarm, the dead consoles, both reinforcements and the banner. After a retry it disables a console in reach through the server; its out-of-reach request for the other console is refused. It then sees the next runner's tell on the right replica and the alerted banner, and its log has no engine errors |

The tests place operatives and read state. Sentries, runners and reinforcements are the production code.

## Human checks (pending)

Part of the [infiltration mission checklist](goauld-infiltration-mission.md#human-uat-checklist-pending). In particular: can you tell which Jaffa is running for the alarm, is the raise time long enough to react, and do the reinforcements feel like a consequence rather than a wall?

## Known limitations

- **No hearing.** The alarm comes only from being seen or shot (ST-2 adds gunfire noise).
- **Consoles are the existing placeholder props.** Nothing on the console itself shows that it is an alarm, apart from the prompt within 12 m.
- **No door lockdown or ring-delivered reinforcements** (EV-2 and later).
- **A runner on another deck** may take a long route; nothing stops it except operatives.
- **Reinforcement Jaffa have no patrol route of their own** beyond their sweep.
