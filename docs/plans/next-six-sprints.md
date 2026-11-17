# Next six sprints

Execution sequence requested by the owner on 17 November 2026, after PR #71. This refines the [roadmap](../../ROADMAP.md); it does not assign delivery dates or replace human acceptance.

| Sprint | Goal | Scope / completion evidence | State |
|---|---|---|---|
| 1 | Network session cleanup | Burst losses with a survivor; no stale roster or replicas; paused HUD return; same-process rejoining; retries; native/intentional server shutdown; same-port rehosting; canceled reconnect and handoff callbacks. Four-operative listen/dedicated fixtures and clean strict logs | Merged in [#72](https://github.com/flaxos/Team-Discovery-Channel/pull/72); [review](../reviews/2026-11-17-sprint1-session-lifecycle.md) |
| 2 | EV-2-2 timed objectives | Write a short mission brief, then a consumed timer action, shared countdown and existing failure/result path. Configurable provisional duration, late join, successful completion, expiry and retry reset. Ordinary missions retain their rules | Merged in [#73](https://github.com/flaxos/Team-Discovery-Channel/pull/73); [evidence](../reviews/2026-11-17-sprint2-timed-extraction.md) |
| 3 | EV-2-3 alarm-driven stage | One authored alarm consequence through MissionEvents. Add only conditions/actions its mission consumes; reuse countdown/notice behavior. Validate progression, one-shot execution, peer snapshots and retry | Implemented for review on `feat/sprint3-alarm-escape`; [evidence](../reviews/2026-11-17-sprint3-alarm-escape.md) |
| 4 | TA-2 chunk 1 flanking | Server-owned alternate-route flanking using the existing room graph/navigation, locks, perception and cover. Safe no-route fallback. Suppression and friendly squad tactics remain separate chunks | Planned |
| 5 | CO-2 chunk 1 ammunition sharing | Specify compatible ammunition, amount and capacity rules; validate sender/reach/inventory on the server; conserve ammunition and explain the interaction in the HUD. Four-player/retry coverage | Planned |
| 6 | GA-2 part 1 visual expansion | Inspect and recover existing unfinished work before replacing it. Extend the next room types from the visual brief; preserve geometry, collision, sockets and navigation; provide captures. Owner art acceptance remains explicit | Planned |

Trigger a package with “Start sprint N from `docs/plans/next-six-sprints.md`.” Complete one package before starting another.

Use the supplied checkout, preserve unfinished work and follow AGENTS.md. Start from updated main after the preceding PR lands. Run targeted checks while developing, a full strict run at the end, and hosted checks before reporting green. Update the roadmap and evidence, commit/push a reviewable PR, and record remaining human checks. A request to commit and merge authorizes finishing on main under AGENTS.md.
