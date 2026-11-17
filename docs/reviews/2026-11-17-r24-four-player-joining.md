# R24 — ordered four-operative joining and travel

17 November 2026. Baseline `7c8786a` (main after #70); branch `fix/four-player-join-order`, in the existing checkout.

## What changes for players

An additional late join waits for its gameplay worlds before receiving operatives. A split squad can keep travelling while that peer loads. All four operatives are represented once across the SGC and the compound; a dedicated server has four remote operatives and no host pawn. Retry rebuilds the worlds before respawning each ready operative, including replacement peers joining after a retry.

Movement remains controlled by the operative's owner. Remote observers now receive the pose through the host, adding a replication step in exchange for sharing the host's spawn/despawn ordering. This has no new movement prediction or anti-cheat model. Human checks under WAN latency remain pending.

## Cause and implementation

Godot 4.4.1 computes spawn visibility using synchronizers owned by the spawner's authority. The previous filter was on a client-owned movement synchronizer, so the host skipped it when spawning that remote operative to a new peer. See the [pinned engine implementation](https://github.com/godotengine/godot/blob/4.4.1-stable/modules/multiplayer/scene_replication_interface.cpp#L358) and [synchronizer contract](https://docs.godotengine.org/en/4.4/classes/class_multiplayersynchronizer.html).

| Player synchronizer | Authority | Purpose |
|---|---|---|
| `MultiplayerSynchronizer` | Operative owner | Publish movement to the host, which already has its authoritative spawn |
| `SpawnVisibility` | Host | Gate spawns on world readiness; send initial position, rotation and class |
| `MovementRelay` | Host | Send pose/posture to ready observers; exclude the owner to avoid echoing delayed poses |

The relay prevents another client's movement/cache messages from overtaking the host's spawn stream. Independent MultiplayerAPI fixtures keep their existing direct synchronization path; the relay is disabled there.

Before a remote operative transfers worlds, the host asks its owner to pause movement publication and acknowledge on the same reliable stream. Only that owner can acknowledge the unique host-instance token. Duplicate travel requests are ignored while the handoff is pending. A five-second timeout cancels travel and restores the old controller; disconnect or retry cancels the handoff. The host captures carried state after acknowledgment, removes the old operative and spawns its destination copy. Host-owned travel remains immediate.

Stargate reserve, chevron, authorization, kawoosh, stabilization and closure updates use the existing readiness-gated mission RPC helper. A loading peer requests a current gate snapshot when its gate exists. Scene-ready replies received during restart preparation are ignored; registration during preparation waits for the replacement world.

## Verification

The original main code failed the new delayed-load fixture with missing spawners, missing synchronizers and invalid deltas (`build/test-results/r24-before/`). A spawn gate alone exposed cross-client movement ordering errors; adding the host relay exposed the departing owner's final packet after its old node was removed. The handoff acknowledgment addresses that final race. Failed diagnostic runs are not counted as acceptance.

`test_four_player_join_multiplayer` uses a listen host plus three real ENet clients. `test_four_player_join_dedicated` uses a pawnless server plus four real clients. Both exercise:

- Deliberately stalled world loading while network polling continues, including a second and subsequent late join.
- Real seven-chevron gate opening and operative travel while another peer still has no gameplay nodes.
- Exact roster, world placement, owner presentation, class, damaged health, movement and crouch agreement on every peer.
- A full-team retry with stale old scene-ready replies deliberately sent during preparation.
- One remote leaving, a replacement late joining after retry while an existing operative travels, then a second full-team retry.
- Graceful departures, one peer at a time, with logs checked for engine/script errors and leaks.

Focused listen/dedicated, gate travel/return, combat, replication, event and retry suites were run while developing. Final full local and hosted results belong to the PR. No human co-op, simultaneous connection-loss burst or WAN-latency acceptance is claimed. An exploratory simultaneous teardown produced ENet closed-channel diagnostics; the regression fixtures deliberately verify completed departures sequentially rather than treating that burst as passing.

## Human follow-up

Join a split squad with four humans, move and crouch while a peer travels, retry twice, and rejoin the vacated slot. Check local movement responsiveness and remote pose smoothness over real network latency. Native level layouts, mission objectives, combat authority and unrelated unfinished checkouts were preserved.
