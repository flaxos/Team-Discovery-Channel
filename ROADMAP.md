# Roadmap — Stargate SG Extraction

**This is the authoritative roadmap.** Audited 12 November 2026 against `main` at `bf56743` (PR #40). Godot **4.4.1**, typed GDScript, native ENet multiplayer.

The game: a Stargate-inspired, four-player tactical co-op shooter about reconnaissance, infiltration, combat, objectives and extraction. Design intent is in the [GDD](GDD.md). Evidence, milestone detail and agent work packages are in the [master development plan](docs/plans/master-development-roadmap.md). Architectural choices are in the [decision log](docs/DECISIONS.md).

Sizes below are relative effort, not dates. Nothing in this file is a delivery commitment.

## Start here

A new session should:

1. Read this page.
2. Open the next milestone's work package in [section 8 of the master plan](docs/plans/master-development-roadmap.md#8-the-first-three-work-packages).
3. Work on a new branch from `main` in a separate worktree, and leave uncommitted files in other checkouts alone.

**Phase 1 and 2:**
- EX-1 merged as [PR #42](https://github.com/flaxos/Team-Discovery-Channel/pull/42).
- ST-1 ([#43](https://github.com/flaxos/Team-Discovery-Channel/pull/43)) and GI-0/GI-1 ([#44](https://github.com/flaxos/Team-Discovery-Channel/pull/44)) were merged into their stacked base branches rather than `main`. [PR #45](https://github.com/flaxos/Team-Discovery-Channel/pull/45) puts them on `main` unchanged.
- Human gates EX-2, Stealth and Infiltration greybox are open.

**Phase 3 (give stealth consequences), in progress:**
- **EV-1 — Alert state, alarm and reinforcements** is implemented in [PR #46](https://github.com/flaxos/Team-Discovery-Channel/pull/46) ([guide](docs/maps/mission-alert.md)). It contains #45, so it lands correctly whichever merges first.
- **ST-2 — Sound and search** is implemented in [PR #47](https://github.com/flaxos/Team-Discovery-Channel/pull/47), which contains #45 and #46.

**Next milestone: TA-1 — Real cover from authored props.** Phase 3's tuning still needs the phase 2 human sessions: every value is provisional.

## What exists today

| | State |
|---|---|
| **Playable** | **SGC Defense** (three-floor wave defence, difficulty objectives, dial out and extract). **SGC UAT Base** (the same base, no hostiles). **Modular Extraction UAT** (development slice: reach a room, use a console, return, with five patrolling Jaffa). **Goa'uld Infiltration — Greybox** (stealth testbed: sight-based sentries, a guarded and a quiet route, three objectives, alarm consoles and reinforcements) |
| **Working systems** | Host/join and dedicated launch, four classes, server-authoritative combat, downing and revive, late join and retry, squad orders, Jaffa and airman AI, sentry perception, compound alert with alarm consoles and reinforcements, gate dialling and iris in the SGC, modular doors |
| **Content pipeline** | 15 structural modules, 16 room presets, 8 composites, a visual editor, and an AI authoring CLI with a graph planner and topology checks |
| **Placeholder only** | Faction themes (`goauld`, `asgard`, `tokra`, `replicator`, `tauri_sgc` all render the neutral fallback). Transport rings and the gate preset on modular levels (placed, inert). Several class perks named in the lobby text |
| **Not built** | Sound propagation through walls. Gate travel between worlds. Mission stages, triggers and door actions on modular levels. Real cover on modular levels. Takedowns, Goa'uld shields. Any faction art. Outdoor terrain. Campaign progression |
| **Not yet accepted by people** | Everything. Human playtests have produced fixes, but no mission has a signed acceptance run |

The full classification, with source paths and tests, is the [capability matrix](docs/plans/master-development-roadmap.md#2-capability-matrix).

### Known problems that affect planning

- **Hosted CI was red on `main` from PR #35 to #41** because one suite could not find the engine on the CI runner. EX-1 repairs the runner; the hosted `Godot full` job passed on PRs #42 and #43.
- **Jaffa in gate waves still detect through walls** (the assault rule kept for SGC Defense). Patrols on modular missions use sight-based perception (ST-1), a compound alarm (EV-1) and straight-line hearing (ST-2).
- **"Cover" on modular levels is a room-centre marker**, not cover.
- **The play machine's checkout is behind `main`** and does not contain the extraction mission or the planner.

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
| 5 | **ST-2** Sound and search — *implemented, PR #47* | Gunfire and blasts draw sentries; searches visit points around the last known position | M | Fable-class |
| 6 | **TA-1** Real cover from authored props | Jaffa fight from behind the props rooms already place | M | Fable-class |
| 7 | **GI-2** Infiltration mission complete | The compound with consequences and cover, ready for the replay gate | M | Codex-class plus authoring |

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

| Gate | Passed when |
|---|---|
| CI | Hosted `Godot full` is green on `main` (repair in EX-1) |
| EX-2 | A dated two-person record exists for Modular Extraction UAT and one SGC Defense run |
| Stealth | Two people cross the test facility unseen on purpose, and report the awareness tell as readable (ST-1 is implemented; this gate is open) |
| Infiltration greybox | Two people finish GI-1 by each route (mission implemented; gate open) |
| Infiltration complete | Both routes are reported as worth replaying with alarm and reinforcements active |

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
| ST-2 (PR #47) | Per-weapon noise radii (suppressed MP5 6 m) and explosive and turret noise; sentries hear and search the source; searches visit points around the last known position before resuming. One new suite; 75/75 local checks. |
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
