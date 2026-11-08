# Sprint 21: map access, gate lifecycle and selectable mission modes

Status: implementation in progress. Requested 8 November 2026 after Sprint 20 playtest.

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

## Work ownership

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

## Larger refactor follow-up

This cleanup establishes explicit gate ownership and route tests first. A later map refactor should replace overlapping room CSG volumes with a shared floor/doorway module system and a documented navigation topology, then simplify state/UI ownership around the authoritative mission lifecycle. Avoid an unrelated full rewrite during these fixes.

## Progress

- PR ancestry reconciliation is pushed. GitHub confirmed PR #19 and #20 mergeable against their intended bases.
- Host-selectable modes, synchronized mission settings and lobby layout checks pass.
- Navigation repair passes a continuous 427-waypoint route from the normal Gate Room floor through both stairs in both directions and the main rooms, with no intermediate teleports.
- Gate/mode lifecycle and real progression tests are being integrated. Retry handling includes mode preservation, old-world retirement and coordinated replication teardown.
