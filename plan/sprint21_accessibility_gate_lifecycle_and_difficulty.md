# Sprint 21: map access, gate lifecycle and selectable mission modes

Status: engineering implementation integrated; human multiplayer acceptance remains open. Requested 8 November 2026 after Sprint 20 playtest. Updated 9 November 2026. The execution plan below records the original work; use [current architecture](../docs/ARCHITECTURE.md), [map contract](../docs/maps/sgc.md) and [testing/UAT](../docs/TESTING.md) for implemented behavior and commands.

## Accepted playtest findings

- Q squad selection works well: preserve its input flow.
- PRs have merge conflicts: reconcile main's squash-merged Sprint 18 ancestry without losing Sprint 19/20 behavior.
- Level 27 east ramp can be climbed but cannot reliably be entered for descent; spiral entrance and much of the map are inaccessible.
- Gate visuals and Jaffa spawns disagree: the event horizon can disappear while incoming reinforcements continue.
- Fast outbound dialing must not skip the initial defense waves or coexist with an inbound connection.

## Execution plan

1. Reconcile and push PR #19 and #20 ancestry; confirm clean merges and unchanged baseline behavior.
2. Repair room/floor/portal collision topology. Validate real corridor entry points, access to major rooms, spiral and service route ascent AND descent. No mid-route position resets or starting above the entry obstruction. Preserve production player capsule dimensions.
3. Establish one authoritative gate lifecycle and direction reservation. Keep the horizon visible for the actual open duration. Reject stale delayed callbacks and spawns after closure, outbound reservation, mission end or teardown. Only an active inbound gate can emit gate reinforcements; extraction requires an outbound gate.
4. Add host-selectable Easy / Medium / Hard in the lobby, synchronized to clients before mission load. Defaults: Easy. All modes require at least three cleared incursions before outbound eligibility. Medium additionally requires a dialing-computer upgrade using the lab ROM/upload interaction. Hard adds iris repair during an active incursion, under combat pressure. Repair/upgrade progress persists across waves. If requirements remain incomplete, subsequent incoming waves keep applying pressure during scheduled recharge cycles. An eligible outbound dial attempt reserves the gate atomically and blocks a new incoming sequence.
5. Integrate and run strict headless regression checks, real two-peer network checks and physical route checks. Review the changes, update plans/PR descriptions, commit and push. Report any graphical UAT limitation honestly.

## Historical work ownership

- Root: integration, conflict reconciliation, plan, test runner and PR delivery.
- Navigation subagent: scene geometry, spiral walk surface, route-access tests.
- Gate/mode subagent: gate/wave/dialing/iris lifecycle, objective rules and targeted tests.
- Menu/network subagent: lobby selection, mission-setting synchronization and targeted tests.

## Acceptance checks

- Both feature PRs are mergeable against their intended base; no unresolved markers.
- Real walk routes into all major playable rooms pass; both stairs support complete corridor-to-corridor round trips.
- Incoming-active state, horizon visibility and permitted spawn queues agree. Closed/outbound gates emit no incoming Jaffa.
- Wave-one/two outbound attempts cannot bypass the defense requirement. A race between valid outbound reservation and incoming activation has exactly one winner.
- Easy unlocks after 3+ cleared incursions; Medium also requires the computer upgrade; Hard additionally requires an in-incursion iris repair.
- Host-selected difficulty reaches existing/new clients and is applied before game_started/mission scene initialization. Clients cannot override host settings.
- Q/ADS and remapping regression checks remain green. Test runner rejects errors/assertions even with exit code zero.

## Original larger-refactor proposal

This cleanup establishes explicit gate ownership and route tests first. A later map refactor should replace overlapping room CSG volumes with a shared floor/doorway module system and a documented navigation topology, then simplify state/UI ownership around the authoritative mission lifecycle. Avoid an unrelated full rewrite during these fixes.

## Final engineering progress

- Ancestry reconciliation and the recovered controls baseline were integrated; the stabilisation work landed through [PR #21](https://github.com/flaxos/Team-Discovery-Channel/pull/21).
- Host-selectable difficulty, gate lifecycle/reservation, objective progression, combat authority and native joining/retry/state replication are implemented and covered by the full suite.
- The subsequent map refactor replaced the old fixed-route baseline with continuous production player/friendly/Jaffa coverage across every walk/stair connection and three-floor lift coverage.
- [PR #22](https://github.com/flaxos/Team-Discovery-Channel/pull/22), [#23](https://github.com/flaxos/Team-Discovery-Channel/pull/23), [#24](https://github.com/flaxos/Team-Discovery-Channel/pull/24) and [#25](https://github.com/flaxos/Team-Discovery-Channel/pull/25) deliver the three-level map, mission/UAT selector, raised architecture/lift fixes and enclosure/lockout corrections.
- Gameplay baseline `a720594` passed 51 local checks. Fixed-camera Forward+ captures were inspected; live two-human mission completion, combat feel and network conditions still require acceptance. See the [current work record](map_and_mission_architecture_refactor.md).
