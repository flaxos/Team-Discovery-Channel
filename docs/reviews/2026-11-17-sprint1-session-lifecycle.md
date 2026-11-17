# Sprint 1 — session lifecycle and disconnect bursts

17 November 2026. Baseline `2cb9719` (main after #71), branch `fix/session-disconnect-lifecycle`, existing checkout.

## Behavior

Losing several connections together removes their roster entries and operatives while a survivor keeps playing. Intentional HUD return, unexpected connection loss and server shutdown all retire both gameplay worlds and return to the existing coordinator's lobby. The same processes can join again; a server can reopen the same port and complete another full-team retry.

Handoffs waiting for an owner are canceled before their old session is freed. Timeout leaves the original operative in place, restores publication when its owner responds, and ignores a late acknowledgment. Explicit leave cancels a scheduled reconnect. A stopped server never attempts to reconnect as a client.

## Implementation

Managed connections now use a host-only transport topology (`SceneMultiplayer.server_relay = false` on host and clients). The application already routes movement, combat and gameplay through the host after #71. The host now also announces profiles and departures authoritatively. `NetworkManager.peers` remains the complete roster; a client's transport peer list contains only the host.

Godot's automatic relay departure notification runs inside its ENet poll, before all dead links in a burst have been removed. It can send to another already inactive packet peer. See [the pinned relay departure implementation](https://github.com/godotengine/godot/blob/4.4.1-stable/modules/multiplayer/scene_multiplayer.cpp#L375), [ENet disconnect processing](https://github.com/godotengine/godot/blob/4.4.1-stable/modules/enet/enet_multiplayer_peer.cpp#L134), and [the public server-relay contract](https://docs.godotengine.org/en/4.4/classes/class_scenemultiplayer.html#class-scenemultiplayer-property-server-relay).

Player destruction and application roster departure broadcasts are deferred until polling has drained the burst. Deferred broadcasts carry a session generation and cannot alter a replacement session. Readiness, restart acknowledgments and transfer state are cleared on session end.

Disconnect first detaches ENet to a valid offline API, then closes the old socket and emits one `session_ended` notification. The coordinator removes gameplay and loads its lobby. HUD return uses that coordinator rather than replacing the entire main scene. Standalone scene previews retain their fallback return path. Reconnect callbacks capture the old session generation and endpoint; a later leave or join invalidates them.

Transfer waits use a change signal rather than suspended frame polling. Acknowledgment, owner departure, restart, disconnect or the five-second wall-clock deadline wakes the wait. Networking deadlines continue while the tree is paused. Cancellation resolves session callers before their world is freed, avoiding the function-state leak found by the pending-handoff shutdown test.

## Evidence

The initial fixture failed baseline roster consistency: clients that joined earlier could lack later profiles. A negative control under ignored `build/test-results/lifecycle_relay_control.gd` reenables the old relay after initial setup. A native loss burst then produces an ENet send to a null packet peer, recorded in `build/test-results/lifecycle-relay-control.engine.log`. Its forced failure and teardown diagnostics are excluded from acceptance.

The strict fixtures use a listen host plus three clients, or a pawnless dedicated host plus four clients. They cover:

- Full roster/replica agreement and a split squad before loss.
- A deterministic burst of native link losses with one surviving client; no stale profiles, readiness, placement or operatives.
- Same-process rejoining and full-team retry.
- Actual HUD return while paused, including a burst of intentional departures.
- Native host loss, intentional server shutdown, and reopening the same port.
- Canceled reconnect callbacks and prevention of server-to-client role changes.
- A timed-out handoff, late acknowledgment, restored owner publication, and shutdown during another pending handoff.
- Empty transfer waits, one lobby, no old worlds/session, and unchanged signal-handler counts after cleanup.

Test marker publication is atomic so readers cannot consume partially written JSON. The existing four-operative joining/travel suites remain part of acceptance. Final local and hosted full results are recorded on the PR. No human/WAN or long-duration soak acceptance is claimed.

## Next

Continue with sprint 2's timed mission definition after this change lands. The [six-sprint sequence](../plans/next-six-sprints.md) tracks the remaining scope. No geometry, mission objective, weapon balance or unrelated unfinished checkout changed.
