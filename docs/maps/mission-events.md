# Mission events — EV-2 chunk 1

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

`id` is unique within the mission, `objective_id` names an existing non-extraction objective, and `security_id` resolves to exactly one native layout connection whose state is `security_door`. Generated node names such as `Door_002`, room names and paths are not accepted. There is one release per target door in this chunk. An empty trigger array preserves the old mission behavior.

Validation checks references, duplicates and the sequence's walking connectivity with all mission gates initially locked. It rejects an objective behind the very door it must unlock. The native `LevelLayout` remains authoritative and unchanged; the mission defines temporary runtime gates rather than new geometry or permanently inaccessible regions. Use the [authoring CLI](ai-level-authoring.md) for structural changes.

`MissionEvents` is a child alongside `Objectives` and `Alert` in the two modular mission scenes. It initializes host-owned locks after navigation validation and before patrol startup. This keeps structural reachability checks meaningful while allowing staged access. It listens to the existing objective index and calls `ModularDoor.set_locked(false)` once; the door retains collision, reach checks, occupied-door protection, AI behavior and state replication.

## Multiplayer and lifecycle

Only the host executes actions. Clients can use an objective console through its existing identity/reach/health/order validation; there is no client event-completion RPC. Live releases use readiness-gated mission RPCs. The fired-ID snapshot is monotonic, ignores unknown IDs and does not replay old notices. Doors send their own authoritative state.

A client can finish its navigation bake before the host. Snapshot requests received before host initialization wait until locks have been applied; that response refreshes the target door state as well as event progress. Snapshot responses never re-run door actions or overwrite authoritative state from a reconstructed trigger list. This also covers retries while peers remain connected.

A final mission result stops actions. Restart creates a fresh world, objective index, event list and initial locks. SGC Defense keeps `WaveManager` and has no event director.

## Scope and verification

This is the first EV-2 chunk, not the full milestone. Alert/room/timer conditions, countdown failure, objective enabling, optional/parallel objectives and power visuals are not added. Add each only alongside a mission definition that needs it (D-003).

- `test_mission_events`: definition validation, unearnable-stage rejection, real generator interaction, reach/downed rejection, TA-3 blocked/released navigation, one-shot behavior, result freeze and retry.
- `test_mission_events_multiplayer`: real ENet late join after release, stale snapshot monotonicity, no stale notice, connected retry, rejected client event/door calls and forged/out-of-reach console identities, a real client console release and a second reset.
- `test_mission_events_dedicated`: the same network contract with a pawnless host. The first completed objective is a server-controller fixture for late join; after retry the remote operative earns the release through the real console.

[Review and captures](../reviews/2026-11-17-ev2-1-objective-doors.md).
