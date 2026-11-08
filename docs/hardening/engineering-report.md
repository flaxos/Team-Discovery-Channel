# Multiplayer stabilisation engineering report

Status: work in progress; no release-readiness claim yet. Godot target: 4.4.1.

## Scope and preservation

The previous unfinished SGC cleanup was preserved without resetting or discarding files at `b70ed19` on `recovery/unfinished-sgc-cleanup`. The release branch starts from fetched main `a81304e`. Six specialist workstreams use separate Git worktrees; changes are integrated sequentially. No shared history is rewritten and no merge to main is authorized.

## Confirmed audit findings

| Severity | Confirmed defect | Evidence / root cause | Correction owner |
| --- | --- | --- | --- |
| P0 | Sprint 20 missing from main | PR20 merged to Sprint19 branch; exact tree/commit comparisons in Agent1 report | Git: exact recovery on current-main branch |
| P0 | Remote shots mutate only a client replica | Separate ENet audit: client Jaffa 90→66, server remains90; WeaponBase local hit calls unguarded HealthComponent | Combat: server shot validation and health/status results |
| P0 | Health/status mutations and countdowns run without server authority | Direct damage, heal, revive, Zat and timers accept every peer; property replication does not emit transitions | Combat: authoritative state contract |
| P1 | Repeated vaporisation is not idempotent | Repeated dead-target Zat emits vaporized twice in runtime probe | Combat + state lifecycle |
| P1 | Equipment switches replenish ammunition | Weapon replacement constructs fresh magazine/reserve state | Combat: preserve per-slot state |
| P0 | Mid-mission join never enters mission | register_player sends roster/settings but no start/world-ready handshake; fixed spawn delay | State: coherent late-join handshake/snapshot |
| P1 | Airmen do not follow server movement | No Airman synchronizer; real ENet contexts retain different positions | State: native NPC state replication |
| P1 | Blast doors mutate locally and elevator lacks late-join snapshot | Local console toggles; movement-only RPCs cannot initialize late joiners | State: validated server interactions + snapshots |
| P1 | Ended mission keeps broadcasting and replica NPC handlers count/remove independently | Snapshot occurs before ended guard; non-authoritative lifecycle paths | State: retirement and once-only server events |
| P1 | API mutators lack authentication/validation | Non-export POST routes are public; export trusts loopback; unrestricted CORS | Backend: explicit authorization and validated transactions |
| P1 | Ordinary votes overwrite human documents | saveState calls root-document regeneration | Backend: docs/generated isolation |
| P1 | Clean checkout cannot reliably bootstrap tests | Missing class cache; first editor import exits0 with Busy resource error | Combat lazy resource loads + QA strict bootstrap |
| P2 | Operational docs do not describe implemented project | README foregrounds obsolete planning and omits authority/run/release contracts | Architecture: source-backed operational docs |

Rejected hypothesis: current main already contains EnemySpawner and Jaffa replication. These systems must be repaired where necessary, not duplicated.

## Specialist workstreams

1. Git integration: completed baseline recovery and targeted controls validation; see `agent1-integration.md`.
2. Combat: implementation in isolated worktree.
3. Mission/NPC state: audited; implementation follows baseline/interface agreement.
4. API security and document safety: implementation in isolated worktree.
5. QA/CI: clean-bootstrap and suite coverage work in isolated worktree.
6. Architecture/docs: read-only audit complete; final documentation follows stable contracts.

## Integration and validation

Baseline integration commits: `0d9dcce` (exact PR20 squash), `0bb2d1b` (preserved prior cleanup), `62d15bf` (evidence and UID sidecars). No conflicts occurred in baseline recovery. Final implementation commits, exact commands, results and limitations will be recorded after sequential integration.

Human graphical multiplayer UAT is mandatory before a RELEASE CANDIDATE classification. Headless assertions alone cannot establish rendering, combat feel or two humans successfully playing the mission.
