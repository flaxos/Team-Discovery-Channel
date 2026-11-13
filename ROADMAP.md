# Roadmap — Stargate SG Extraction

**This is the authoritative roadmap.** Audited 12 November 2026 against `main` at `bf56743` (PR #40); status updated 13 November 2026 at `6af561b` (PR #49). Godot **4.4.1**, typed GDScript, native ENet multiplayer.

The game: a Stargate-inspired, four-player tactical co-op shooter about reconnaissance, infiltration, combat, objectives and extraction. Design intent is in the [GDD](GDD.md). Evidence, milestone detail and agent work packages are in the [master development plan](docs/plans/master-development-roadmap.md). Architectural choices are in the [decision log](docs/DECISIONS.md).

Sizes below are relative effort, not dates. Nothing in this file is a delivery commitment.

## Start here

**State on 13 November 2026.** Phases 1 to 3 of the sequence below are implemented and merged. Phase 3 landed on `main` as PRs #45 (ST-1, GI-0/GI-1), #46 (EV-1) and #49 (ST-2, TA-1, GI-2; it was developed as #47 and #48, which #49 contains and which can be closed). The last full local run was **77/77** and hosted CI was green on #49. Every number in the game is provisional, because **no human has played any of it** (risk R13).

### Pick up here

| Option | What | Who | Detail |
|---|---|---|---|
| **A. Human play sessions** *(recommended first)* | Run extraction UAT, SGC Defense and the infiltration mission with two people, fill in the playtest template, tune from what you find | Two humans | [Next work, part A](docs/plans/next-work-packages.md#a-human-play-sessions) |
| **B. GA-0 Goa'uld visual brief** | A written design language and a theme-slot audit; documentation only | Any agent | [Package 4](docs/plans/next-work-packages.md#b-package-4--ga-0-goauld-visual-brief-and-theme-slot-audit) |
| **C. GT-1 session state and host split** | Make gate travel possible; no visible change; highest regression risk | Fable-class agent | [Package 5](docs/plans/next-work-packages.md#c-package-5--gt-1-mission-session-state-and-host-split) |

A, B and C do not depend on each other. C needs the owners to confirm decision D-002 (the squad always travels together). Phase 6 work (EV-2, TA-3, TA-2, CO-1, SW-1) should wait for A. Each package has a handoff prompt you can paste into a fresh session.

### Rules for any session

1. Read this page, then the package you are picking up. Do not start from the history.
2. Work on a new branch from `origin/main` in a **separate worktree** (`git worktree add`). The play machine's main checkout has uncommitted work and sits on an old branch; leave it alone.
3. Run targeted suites while working and `python3 tools/run_godot_tests.py --profile full --timeout 600` once at the end. Then **check `gh pr checks <n>`**: the hosted runner is slower than the development machine, and local green has not meant hosted green.
4. One milestone per pull request, drafted, never merged by the agent. Update ROADMAP.md, the touched guides and the capability matrix in the same PR.
5. Merging: the owner squash-merges. If follow-on PRs stack on an unmerged one, a squash puts the rest into conflict. Either merge only the last PR (it contains the rest), or use merge commits. Details: [merging stacked work](docs/plans/next-work-packages.md#merging-dependent-pull-requests).

### What was delivered, in order

| Milestone | PR | Guide |
|---|---|---|
| EX-1 trustworthy baseline | [#42](https://github.com/flaxos/Team-Discovery-Channel/pull/42) | [extraction guide](docs/maps/modular-extraction-mission.md) |
| ST-1 sentry perception; GI-0/GI-1 infiltration mission | [#43](https://github.com/flaxos/Team-Discovery-Channel/pull/43), [#44](https://github.com/flaxos/Team-Discovery-Channel/pull/44), landed by [#45](https://github.com/flaxos/Team-Discovery-Channel/pull/45) | [infiltration guide](docs/maps/goauld-infiltration-mission.md) |
| EV-1 alarm, runners, reinforcements | [#46](https://github.com/flaxos/Team-Discovery-Channel/pull/46) | [alert guide](docs/maps/mission-alert.md) |
| ST-2 hearing and area searches; TA-1 prop cover; GI-2 loud-route suite and playtest template | [#49](https://github.com/flaxos/Team-Discovery-Channel/pull/49) (from #47, #48) | extraction and infiltration guides |

## What exists today

| | State |
|---|---|
| **Playable** | **SGC Defense** (three-floor wave defence, difficulty objectives, dial out and extract). **SGC UAT Base** (the same base, no hostiles). **Modular Extraction UAT** (development slice: reach a room, use a console, return, with five patrolling Jaffa). **Goa'uld Infiltration — Greybox** (stealth testbed: sight-based sentries, a guarded and a quiet route, three objectives, alarm consoles and reinforcements) |
| **Working systems** | Host/join and dedicated launch, four classes, server-authoritative combat, downing and revive, late join and retry, squad orders, Jaffa and airman AI, sentry perception, compound alert with alarm consoles and reinforcements, gate dialling and iris in the SGC, modular doors |
| **Content pipeline** | 15 structural modules, 16 room presets, 8 composites, a visual editor, and an AI authoring CLI with a graph planner and topology checks |
| **Placeholder only** | Faction themes (`goauld`, `asgard`, `tokra`, `replicator`, `tauri_sgc` all render the neutral fallback). Transport rings and the gate preset on modular levels (placed, inert). Several class perks named in the lobby text |
| **Not built** | Sound propagation through walls. Gate travel between worlds. Mission stages, triggers and door actions on modular levels. Cover in rooms without low props (bare modules fall back to a marker). Takedowns, Goa'uld shields. Any faction art. Outdoor terrain. Campaign progression |
| **Not yet accepted by people** | Everything. Human playtests have produced fixes, but no mission has a signed acceptance run |

The full classification, with source paths and tests, is the [capability matrix](docs/plans/master-development-roadmap.md#2-capability-matrix).

### Known problems that affect planning

- **Hosted CI was red on `main` from PR #35 to #41** because one suite could not find the engine on the CI runner. EX-1 repairs the runner; the hosted `Godot full` job passed on PRs #42 and #43.
- **Jaffa in gate waves still detect through walls** (the assault rule kept for SGC Defense). Patrols on modular missions use sight-based perception (ST-1), a compound alarm (EV-1) and straight-line hearing (ST-2).
- **Cover on modular levels needs props.** Since TA-1 Jaffa use barricades and crates; rooms without low props still fall back to a room-centre marker.
- **The play machine's checkout is behind `main`** and contains none of milestones EX-1 to GI-2. Play from a separate worktree of `main`: [commands here](docs/plans/next-work-packages.md#get-a-build-to-play).

All 20 items, each checked against current code, are in the [risk register](docs/plans/master-development-roadmap.md#7-risk-and-defect-register).

## Direction

**Gameplay systems first, the mission map on top of them, art third.**

1. Give patrols real perception (line of sight, view cone, graded awareness). This is the smallest change that turns the existing mission framework into something that can host a stealth mission, and every later mission style reuses it.
2. Build the first designed Goa'uld compound in greybox with the existing planner, and use it as the single testbed for stealth, events, cover, extraction and art.
3. Produce Goa'uld art as one small vertical slice (a corridor, a door frame, a chamber) once that mission has been played, then expand the kit along the rooms the mission actually uses.

The greybox layout and the art brief cost little and can proceed in parallel now. The reasoning, including agent cost and regression risk for each option, is in [section 3 of the master plan](docs/plans/master-development-roadmap.md#3-decision-gameplay-map-or-art-first).

## Immediate priorities

| Order | Milestone | Delivers | Size | Worker |
|---|---|---|---|---|
| 1 | **EX-1** Trustworthy baseline and extraction hardening — *implemented, PR #42* | Green hosted CI; the extraction mission cleaned up for a two-person run, including a dedicated-server check | M | Codex-class |
| 2 | **ST-1** Perception and awareness core — *implemented, PR #43* | Patrols that see by line of sight inside a cone, become suspicious before alerted, investigate and give up | M | Fable-class |
| 3 | **GI-1** Goa'uld infiltration greybox mission — *implemented, PR #44* | A fourth selectable mission on a planned two-deck compound with a quiet route and a loud one | M | Scripted authoring plus Codex-class |
| 4 | **EV-1** Alert state, alarm and reinforcements — *implemented, PR #46* | One alert level per mission, alarm runners and consoles, a reinforcement budget; wired into the infiltration mission | M | Fable-class |
| 5 | **ST-2** Sound and search — *implemented, in PR #49* | Gunfire and blasts draw sentries; searches visit points around the last known position | M | Fable-class |
| 6 | **TA-1** Real cover from authored props — *implemented, in PR #49* | Jaffa fight from behind the props rooms already place | M | Fable-class |
| 7 | **GI-2** Infiltration mission complete — *agent part in PR #49; tuning and gate are human* | The compound with consequences and cover, ready for the replay gate | M | Codex-class plus authoring |

Each has objective, files, boundaries, acceptance tests, human checks, risks and a handoff prompt in the master plan. The layout half of GI-1 (GI-0) can be authored at any time.

**Human gate (EX-2):** after EX-1, two people run the existing extraction checklist and one SGC Defense session and record the result under `docs/reviews/`. This cannot be done by an agent.

## Milestone sequence

Workstream letters match the master plan.

| Phase | Milestones | Outcome for the player |
|---|---|---|
| **1. Stabilise** | EX-1, EX-2 | The current missions are dependable in co-op |
| **2. Make stealth possible** | ST-1, GI-0, GI-1 | A compound you can sneak through or fight through |
| **3. Give stealth consequences** | EV-1, ST-2, TA-1, GI-2 | Alarms, reinforcements, searching patrols, firefights with real cover |
| **4. Give it a look** | GA-0, GA-1, then GA-2 in parts | The compound looks like a Goa'uld installation |
| **5. Travel** | GT-1, GT-2, GT-3 | Brief in the SGC, step through the gate, come home and debrief |
| **6. Deepen** | TA-2, TA-3, EV-2, CO-1, CO-2, SW-1 to SW-3 | Flanking, locked-door play, multi-stage missions, co-op roles, takedowns, shielded and specialist enemies |
| **7. Widen** | OW-0 to OW-2, other locations, CA-1, CA-2 | Outdoor gate sites, Alpha Site, mothership, other factions, linked missions |

Phases 4 and 5 do not depend on each other. Phase 4's brief and phase 2's layout can start today.

## Dependencies

- **Fun two-player infiltration, shortest route:** EX-1 → ST-1 → GI-1 → EV-1 → GI-2. No gate travel, art or special weapons required.
- **SGC → gate → offworld → SGC, shortest route:** GT-1 → GT-2 → GT-3, arriving in the GI-1 mission.
- **Unblockers:** ST-1 (all stealth and infiltration), EV-1 (reinforcements, defence and multi-stage missions), GT-1 (travel and campaign).
- **Hard versus preferred:** ST-1 strictly needs only the CI repair from EX-1. GI-1's layout needs nothing; its mission needs ST-1. Art needs only its own brief. Everything else in the ordering is preference.

The diagram and the table of which streams can run at the same time without touching the same files are in [section 4 of the master plan](docs/plans/master-development-roadmap.md#4-dependencies-and-critical-path).

## Near-term acceptance gates

| Gate | Passed when | Status |
|---|---|---|
| CI | Hosted `Godot full` is green on `main` (repair in EX-1) | **Passed**: hosted CI is green on `main` at `6af561b` |
| EX-2 | A dated two-person record exists for Modular Extraction UAT and one SGC Defense run | **Open.** Sessions 1–3 of [the plan](docs/plans/next-work-packages.md#session-plan-about-two-hours-for-two-people) |
| Stealth | Two people cross the test facility unseen on purpose, and report the awareness tell as readable | **Open.** Sessions 4–5 |
| Infiltration greybox | Two people finish GI-1 by each route | **Open.** Sessions 4–5 |
| Infiltration complete | Both routes are reported as worth replaying with alarm and reinforcements active | **Open.** Session 6 and the tuning table |

Automated suites never satisfy a human gate.

## Longer-term workstreams

| | Workstream | First milestone | Starts after |
|---|---|---|---|
| A | Extraction mission hardening | EX-1 | Now |
| B | Stealth and perception | ST-1 | CI repair |
| C | Mission scripting and events | EV-1 | ST-1, preferably GI-1 |
| D | Tactical AI and combat | TA-1 | ST-1 |
| E | Goa'uld infiltration mission | GI-0 | Now (layout), ST-1 (mission) |
| F | Goa'uld architecture and visuals | GA-0 | Now (brief), art-method decision (slice) |
| G | Stargate world transitions | GT-1 | EX-1 and the transition decision |
| H | Expanded co-op mechanics | CO-1 | GI-1 |
| I | Special weapons and faction mechanics | SW-1 | ST-2 |
| J | Outdoor world construction | OW-0 | Any time; design spike only |
| K | Other factions and locations | Alpha Site mission | EV-1 |
| L | Campaign and replayability | CA-1 | GT-3 and two offworld missions |

## Open product decisions

Nine questions need an owner's answer; each has a working default so that work is not blocked. The most consequential are whether the squad always travels through the gate together, whether Jaffa attack downed operatives, and how art will be produced. See [section 10 of the master plan](docs/plans/master-development-roadmap.md#10-open-questions-for-the-product-owners).

## Milestone history

Earlier sprint numbers describe the order of development, not current geometry or rules. Historical records are kept as written; see the linked documents for their own baselines.

| Milestone | Delivered work and later corrections |
| --- | --- |
| Sprints 0–3 | Gate/rendering, basic multiplayer/combat, Jaffa, turrets/C4/claymores, hallway and wave escalation. Offworld transport rings were later removed from the SGC core. |
| Sprints 4–5 | Downing/revive, HUD/settings, dedicated launch, callsigns and reconnect handling. |
| Sprints 6–9 | Expanded bunker rooms, cover/Zat mechanics, briefing/office, vertical combat, resupply/CCTV and defense interactions. |
| Sprints 10–13 | ADS and layout polish, SGC dialing console, incoming/recharge engine and lab-ROM objective. The old 1/2–3/4–5 surge difficulty design is superseded by the current three-incursion minimum and objective gates. |
| Sprints 14–16 | Friendly squad AI, tactical gear, iris repair, hallway connectivity and fog of war. The temporary flat Level 28/control-floor design is superseded by raised operations and side/rear stairs. |
| Sprints 17–20 | Elevation/gunplay and integration work, TPS camera, accessible stair/lift controls, ADS squad selection and persistent remapping. The old numbered offworld proposals were not delivered under those sprint numbers. |
| Stabilisation / Sprint 21 cleanup | Combat authority, mission lifecycle/settings, late joins/retry, NPC/shared-state replication, strict CI and authenticated Alignment exports. See the historical [engineering report](docs/hardening/engineering-report.md). |
| SGC refactor and UAT follow-up (PRs #22–#25) | Authored region/connection/art schema, all three floors, shared faction navigation, mission selector, closer SG-1 proportions, ceilings, independent shutters, grounded lift travel and enclosure/lockout fixes. 51/51 local checks at `a720594`. |
| Modular construction, Phase 1–2 (PRs #27–#31) | Reusable room modules, typed layouts, validation and bake; native visual map editor; automatic doors between touching rooms. |
| Modular construction, Phase 2.5 (PRs #32–#37) | Expanded structural catalogue, vertical connectors and equipment shells, functional room presets and security doors, shared themes and the transactional AI authoring CLI, the integrated two-deck fixture, editor control fixes. |
| Modular NPC navigation (PR #38) | Production Jaffa and airmen navigate modular levels; patrols; AI door use. |
| First modular mission (PR #39) | Modular Extraction UAT: data-driven objectives, extraction rule, patrol combat, two shared netcode fixes. 68/68 local checks. |
| AI level authoring 2.0 (PR #40) | Graph planner, topology checks, six more composites, tactical catalogue metadata, four demonstration maps. 69/69 local checks. |
| Master roadmap (PR #41) | Documentation only: audit, capability matrix, milestone plan, decision log. |
| GI-0 and GI-1 (PR #44) | Twenty-room two-deck compound planned with the authoring CLI (gate insertion, guarded checkpoint route and quiet service route to the generator, upper command deck, paired rings); fourth selectable mission with six sentries and an automated quiet-route check. |
| ST-1 (PR #43) | Sentry perception for patrols: view cone and line of sight, suspicious then alerted with a replicated ? / ! tell, one-hop alert spread, search the last seen position and resume the route. Gate waves keep the assault rule. |
| GI-2 (PR #49) | Loud-route playthrough of the infiltration mission with hearing, alarm, reinforcements and cover live; cover verified in the guarded rooms; playtest record template for the human gates. 77/77 local checks. |
| TA-1 (PR #49) | Jaffa fight from behind solid low cover props: spot selection behind the prop, crouch and stand to fire over it, relocation when flanked, marker fallback; perception from eye height. One new suite; 76/76 local checks. |
| ST-2 (PR #49) | Per-weapon noise radii (suppressed MP5 6 m) and explosive and turret noise; sentries hear and search the source; searches visit points around the last known position before resuming. One new suite; 75/75 local checks. |
| EV-1 (PR #46) | Compound alert levels, alarm runners and consoles that operatives can disable, a one-time reinforcement budget, klaxon, banner, toasts and debrief line; wired into the infiltration mission. Two new suites; 74/74 local checks. |
| EX-1 (PR #42) | CI runner repair; readiness-gated mission messages so mid-firefight joins log no errors; hostiles stand down and squad state is final at the result; standing operatives targeted before downed ones; dedicated-server suite, client-requested retry and return to lobby on server loss; mission-owned HUD and debrief text. |

## References

- [Master development plan](docs/plans/master-development-roadmap.md) — capability matrix, dependencies, milestones, art track, risks, work packages
- [Decision log](docs/DECISIONS.md)
- [Game design](GDD.md)
- [Documentation index](docs/README.md)
- [Testing and UAT](docs/TESTING.md)
- [Work tracker](plan/README.md) — historical implementation records
- [Offworld extraction plan](docs/plans/offworld-extraction-mission.md) — the earlier dependency study this roadmap supersedes
