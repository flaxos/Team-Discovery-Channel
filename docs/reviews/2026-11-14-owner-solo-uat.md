# Owner solo UAT — 14 November 2026

The first human session on `main` after phase 3. One owner played alone, then declared UAT passed and set the two-player sessions aside. This record separates three things: what the console log shows, what the owner stated, and what was not run.

## Session

| | |
|---|---|
| Date | 14 November 2026 |
| Commit | `ce9ad71` (`main`), from a separate checkout at `/home/flax/games/tdc-play` |
| Engine | Godot 4.4.1.stable, Vulkan Forward+, NVIDIA GeForce RTX 3060 |
| Host type | Listen host, one player |
| Player | flaxos, peer 1, `sg3_heavy` |
| Missions | Modular Extraction UAT once; Goa'uld Infiltration twice (one failure, one retry) |
| Script errors in the log | None |

Two SGC runs earlier the same day were launched from the old checkout (`feat/modular-npc-navigation`, `19b8317`) and are not evidence for `main`.

## What the log shows

Modular missions print room entries, Jaffa combat lines, kills and downs. They do **not** print objectives, alert changes, the alarm or the result, so those rows rest on the owner's statement.

### Modular Extraction UAT

| | |
|---|---|
| Route | entry → hub → stores, cargo, barracks, control → ramp → upper junction → rings → command → back to entry |
| Room entries | 37 |
| Hostiles killed | 5 of 5 |
| Ending | Returned to the lobby and hosted again, which is what follows a result screen |

### Goa'uld Infiltration, attempt 1 (quiet route)

| | |
|---|---|
| Route | gate → service → service 2 → adapter → stores → lower rings → stores → maintenance |
| First seen | Stores, by the stores sentry (`Jaffa_P2_0`), who was killed |
| Then | A checkpoint guard (`Jaffa_P0_1`) and another sentry (`Jaffa_P3_0`) engaged in maintenance |
| Result | Operative downed in maintenance; the mission relaunched without a new server start, which is the retry path |

### Goa'uld Infiltration, attempt 2 (loud route)

| | |
|---|---|
| Route | gate → approach → checkpoint, then every room on both decks, several times; 109 of the session's 119 room entries |
| First seen | Checkpoint, by both checkpoint guards; the generator watch (`Jaffa_P1_0`) and `Jaffa_P4_0` joined |
| Alarm | Raised: reinforcement group 1 (`Jaffa_R0_0`, `Jaffa_R0_1`) and group 2 (`Jaffa_R1_0`, `Jaffa_R1_1`) both arrived, which only happens after the alarm |
| Hostiles killed | 10 of 10 (six sentries and four reinforcements) |
| Other | One body dragged in the barracks |
| Ending | Generator, command and observation visited; last line is the operative back at the gate beside the DHD |

Room entries across both infiltration attempts, used by the [Goa'uld visual brief](../maps/goauld-visual-brief.md#4-which-rooms-matter): checkpoint 14, barracks 13, inner 9, stores 8, gate 7, maintenance 7, generator 7, service 2 6, adapter 6, approach 6, approach 2 6, armoury 6, upper hall 6, service 5, antechamber 4, lower rings 2, ramp 2, command 2, upper rings 2, observation 1.

## Owner's verdict

> UAT Passed

Stated by the owner on 14 November 2026 after this session, with the instruction to resume development and set the two-player playtest aside.

## Checklist coverage

*Log*: the console log is consistent with the item. *Owner*: covered by the owner's verdict; the log cannot show it. *Not run*: needs a second player or was not attempted.

### [Extraction checklist](../maps/modular-extraction-mission.md#human-uat-checklist-pending-sign-off)

| Item | Status |
|---|---|
| 1. Solo launch, spawn, objective 1, five hostiles | Log (spawn in entry, five kills); HUD by owner |
| 2. Nothing completes while waiting in the entry corridor | Owner |
| 3. Patrols notice, fire, one of a pair moves to cover; doors open | Log (both pairs engaged, front and trailing behaviour) |
| 4. Command room, console, objective 3, extraction ring | Owner (command room entered in the log) |
| 5. Success screen, then **Retry mission** | Owner for the success screen. Retry was not used here; the owner returned to the lobby |
| 6. Failure screen when downed alone | Not run in this mission (seen in the infiltration mission) |
| 7–10. Second player, late join, shared extraction, revive | Not run |
| 11. SGC Defense and SGC UAT on this build | Not run on `main` (the SGC runs were on the old checkout) |

### [Infiltration checklist](../maps/goauld-infiltration-mission.md#human-uat-checklist-pending)

| Item | Status |
|---|---|
| 1. Launch, objective 1, six hostiles | Log (six sentries met); HUD by owner |
| 2. Quiet route to the generator unseen | **Not achieved.** Seen in the stores on the first attempt |
| 3. Checkpoint route: guards notice, generator watch joins | Log |
| 4. Ramp, antechamber and command sentries, main console | Log (rooms and kills); console by owner |
| 5. Return to the gate, extraction, debrief | Owner (last log line is at the gate) |
| 6. Two players, one quiet and one loud | Not run |
| 7. **?** and **!** readable in time | Owner |
| 8. Spotted on purpose; see and stop the alarm runner | Not shown. The alarm was raised, so the runner was not stopped |
| 9. Alarm sounds once; play through to extraction | Log (both reinforcement groups) and owner |
| 10. Consoles disabled, nobody runs | Not run |
| 11. Unsuppressed weapon against the MP5 | Not run (one class played) |

## Gates

| Gate | As defined in the roadmap | After this session |
|---|---|---|
| EX-2 | A dated two-person record for extraction and one SGC Defense run | **Accepted by the owner on solo play.** The two-person and SGC parts were not run |
| Stealth | Two people cross unseen on purpose and read the tells | **Accepted by the owner on solo play.** No unseen crossing was achieved |
| Infiltration greybox | Two people finish by each route | **Accepted by the owner on solo play.** Finished by the loud route; the quiet attempt failed |
| Infiltration complete | Both routes worth replaying with alarm and reinforcements | **Accepted by the owner on solo play** |

The owner accepted the gates and deferred the two-player sessions. Nothing here shows two-player behaviour (late join, shared extraction, revive, alert spread between players) on a human run; that remains covered by automated suites only.

## Observations for tuning

Not conclusions; one session, one class.

1. **The quiet route was not quiet on a first attempt.** The stores sentry saw the operative, and two more sentries arrived in maintenance.
2. **The alarm did not stop a heavy gunner.** All four reinforcements and all six sentries were killed by one player. Whether the alarm is enough of a consequence is still an open question for a session with other classes.
3. **Much of attempt 2 was spent circling a cleared lower deck.** 58 room entries fall between the last reinforcement fight and the first trip up the ramp, with only the two upper-deck sentries left alive: several laps of checkpoint → barracks → armoury → generator → stores → service → gate. That may mean the next objective was not obvious. Worth asking the owner.

## Defects and follow-ups

| Severity | What | Evidence |
|---|---|---|
| Low | Modular missions log nothing for objectives, alert level, the alarm runner, reinforcements or the result, so a session cannot be checked from the console | This record |
| Low | Sentries print the SGC assault lines ("Front rank halting & crouching…", "Trailing rank breaking…") when they enter combat | Every infiltration fight in the log |
| Low | Modular missions are labelled `GateRoom:` and "Launching GateRoom mission" in the log | Every line |
| Note | The play machine's main checkout is behind `main` and lists only the two SGC missions in the lobby | The first two runs of the day |
