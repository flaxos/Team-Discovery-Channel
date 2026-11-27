# Roadmap — Stargate SG Extraction

**This is the authoritative roadmap.** Audited 12 November 2026 against `main` at `bf56743` (PR #40); resume status updated 21 November 2026 against `main` at `1f634d1` (PR #78, including Sprint 7 / PR #79). Godot **4.4.1**, typed GDScript, native ENet multiplayer.

The game: a Stargate-inspired, four-player tactical co-op shooter about reconnaissance, infiltration, combat, objectives and extraction. Design intent is in the [GDD](GDD.md). Evidence, milestone detail and agent work packages are in the [master development plan](docs/plans/master-development-roadmap.md). Architectural choices are in the [decision log](docs/DECISIONS.md).

Sizes below are relative effort, not dates. Nothing in this file is a delivery commitment.

## Start here

### Current and next sprints

| Status | Sprint | Work |
|---|---|---|
| In review | 31 · Alpha Site outpost | Playable interior route with pre-fab shelter surfaces, field equipment, observation aperture vista, and civilian presence. Entry, objective, and return loop verified. [Draft PR #108](https://github.com/flaxos/Team-Discovery-Channel/pull/108) · [Sprint 31 review](docs/reviews/2026-11-27-sprint31-alpha-site-outpost.md) |
| In review | 32 · Mothership boarding and ring breach | Two-deck 9-module boarding route, bulkhead/door/cargo props, and reciprocal R16 transport rings breach. Merged via PR #109. [Sprint 32 review](docs/reviews/2026-11-27-sprint32-mothership-boarding.md) |
| In review | 33 · Mothership bridge and engineering objective | 12-module route, command helm, reactor core with reactive sabotage status, deep-space viewport with camera boundary preservation, MissionEvents blast door release, and alarm extraction route. Merged via PR #110. [Sprint 33 review](docs/reviews/2026-11-27-sprint33-mothership-objective.md) |
| In review | 34 · Mothership exterior silhouette | Hero exterior Ha'tak silhouette (1,084 triangles, shared Goa'uld materials, pure scenery) with bridge viewport and hangar bay space threshold fleet vista dressing. [Sprint 34 review](docs/reviews/2026-11-27-sprint34-mothership-exterior.md) |
| Next | 35 · Programme acceptance slice | Four-player run from equipped SGC through one selected offworld site and back on listen and dedicated servers, multi-player views, normal/alarm lighting, export credits/licences, scene costs and final asset-coverage report. [Sprint 35 scope](docs/plans/asset-vertical-slices.md#offworld-locations-and-mothership) |

**Resume state on 21 November 2026.** Phases 1 to 3 are implemented, merged, and **accepted by an owner on a solo session** ([record](docs/reviews/2026-11-14-owner-solo-uat.md), [D-014](docs/DECISIONS.md)). The two-player sessions were deferred, so co-op behaviour on a human run is still covered by automated suites only, and every tuning value is provisional. Gate travel and SW-1 are now merged through PR #58. TA-3 and its post-combat hardening, CO-1 resupply, and the community weapon/gate imports are merged through #69. EV-2 chunk 1 is merged in #70. The R24 four-operative joining/travel fix is merged in #71. Sprint 1 session cleanup is merged in #72. Sprint 2 Timed Extraction is merged in #73. Sprint 3 Alarm Escape is merged in #74. Sprint 4 modular alternate-entrance flanking is merged in #75. Sprint 5 ammunition sharing is merged in #76. Sprint 6 GA-2 part 1 is merged in #77; owner art acceptance remains pending. The [completed six-sprint sequence](docs/plans/next-six-sprints.md) leads into the owner-requested [community-first asset programme, Sprints 7–35](docs/plans/asset-vertical-slices.md): weapons, SGC, rigged characters, offworld locations and bounded mothership art. The earlier GT-1 local baseline was **80/80**.

Two owner decisions on 14 November shape what follows: art is built in the engine by agents ([D-012](docs/DECISIONS.md)), and players may be in different worlds at once ([D-013](docs/DECISIONS.md)). The design that followed is written: [gate travel with a split team](docs/plans/gate-travel-split-worlds.md), with the owners' four rules for a split team in [D-017](docs/DECISIONS.md). A third, matte Jaffa armour ([D-015](docs/DECISIONS.md)), came out of building the art.

**Sprint 7 is merged to main, with owner art review pending:** WillyG99’s textured MP5SD replaces the Kenney stand-in with measured muzzle alignment, shared work-order intake and distributed credits. Owner art acceptance remains pending. [Review and evidence](docs/reviews/2026-11-18-sprint7-mp5-intake.md). The [asset workflow](docs/assets/ai-asset-workflow.md) governs measured integration, export and separate owner art acceptance. It landed through #79 into the planning branch and #78 into main. Implementation `a778fb4` passed 117 local and hosted full checks, 60 Python tests and clean release-export checks; [hosted run](https://github.com/flaxos/Team-Discovery-Channel/actions/runs/44223594937). The weapon and field-kit slices run through Sprint 12. Animated handling continues through Sprint 25.

### Pick up here

**24 November 2026.** Sprint 8’s shared staff and Sprint 9’s original Zat are merged via #81 and #82. Sprint 10 audited all six held weapons in SGC and offworld and verified the clean release pack. Owner mesh and material review remains open, including the M249’s extended bipod. **Sprint 11’s M2 integration is ready for review.** The community gun and tripod are fitted to the existing turret. Sprint 12 merged via #85, with all four field-kit visuals ready for owner review. Four-operative listen and dedicated simulations verify late delivery during gate travel, inventory at destination and clearing deployments on retry. [Sprint 12 review](docs/reviews/2026-11-23-sprint12-field-kit.md). [Sprint 11 review](docs/reviews/2026-11-23-sprint11-m2-intake.md) · [Sprint 10 review](docs/reviews/2026-11-23-sprint10-held-weapon-audit.md).

**Sprint 13 merged via #86.** The existing SGC embarkation chamber, side approaches and ramp use three shared PBR sets. Captures compare the original and dressed scenes under normal and alarm lighting and record the bounded lighting experiment. Owner art review is open. [Sprint 13 review](docs/reviews/2026-11-24-sprint13-sgc-embarkation.md).

**Sprint 14 merged via #87.** The control readout, observation frame, gate rim and secured iris are ready for owner art review. [PR #87](https://github.com/flaxos/Team-Discovery-Channel/pull/87) · [Sprint 14 evidence](docs/reviews/2026-11-24-sprint14-sgc-control-gate-iris.md).

**Sprint 15 merged via #88.** The armoury has fitted loadout cabinets and a community re-armour shelf. The ammo stacks use crate LODs and fade when they occlude the camera. The mounted M2 operator follows the live receiver on all peers. [PR #88](https://github.com/flaxos/Team-Discovery-Channel/pull/88) · [Sprint 15 review](docs/reviews/2026-11-24-sprint15-sgc-armoury.md).

**Sprint 16 merged via #89.** The lab has a fitted community microscope, and the hard-mode fixture uses the ROM pickup from the west aisle. Level 26 staging and storage have a fitted medical cabinet and transport cases. [PR #89](https://github.com/flaxos/Team-Discovery-Channel/pull/89) · [Sprint 16 review](docs/reviews/2026-11-24-sprint16-sgc-lab-support.md).

**Sprint 17 merged via #90.** Level 27 has fitted briefing and command furniture, a live briefing shutter readout and observation captures from both rooms. [PR #90](https://github.com/flaxos/Team-Discovery-Channel/pull/90) · [Sprint 17 review](docs/reviews/2026-11-24-sprint17-sgc-briefing-command.md).

**Sprint 18 route dressing merged via #91.** The three-floor route has a fitted CCTV bank, storage and staging props, and shared concrete finishes. The architecture follow-up integrates the deferred ceilings, fluorescent fixtures, conduits and service stair finishes. Owner art review is open. [PR #91](https://github.com/flaxos/Team-Discovery-Channel/pull/91) · [Sprint 18 review](docs/reviews/2026-11-24-sprint18-sgc-coverage.md).

**Sprint 19 is ready for art review.** The uniformed Airman is the model for existing SGC personnel and the basis for all four playable operatives. The shared rig steps through stationary turns and follows both M2 handles when mounted. [Sprint 19 review](docs/reviews/2026-11-25-sprint19-airman-rig.md).

**Sprint 20 preview merged via #99.** The downloaded Serpent helmet is fitted locally to the shared rig. Body art and the helmet authorship check are open. [PR #99](https://github.com/flaxos/Team-Discovery-Channel/pull/99) · [Serpent preview and intake](docs/reviews/2026-11-25-sprint20-serpent-jaffa.md).

**Sprint 21 has a saved Horus preview.** The existing shock guard wears a native falcon helmet and blue-black armour in the opt-in build. Final surface and motion review remain open.

**Sprint 22 merged via #100.** O’Neill wears slate fatigues, tan webbing and a shoulder radio on the shared Airman rig. The P90 and M9 have Recon-specific palm targets and a cosmetic reload posture. The review includes the SGC alarm lights, shoulder and ADS cameras, and motion footage. [PR #100](https://github.com/flaxos/Team-Discovery-Channel/pull/100) · [Sprint 22 review](docs/reviews/2026-11-25-sprint22-oneill-recon.md).

**Sprint 23 merged with Sprint 24 in PR #101.** Carter wears khaki fatigues and a compact scanner on the shared rig, with MP5SD and Zat grip fits. The SGC iris-repair state drives the close-range lever and panel pose. [Carter Tech review](docs/reviews/2026-11-25-sprint23-carter-tech.md).

**Sprint 24 merged via PR #101.** The bronze plates and two-handed staff fit were checked through standing, running and crouch walking. The Zat stays equipped through the drag, and the staff returns on recovery. Owner art review remains open for both previews. [Teal’c review](docs/reviews/2026-11-25-sprint24-tealc-jaffa.md) · [PR #101](https://github.com/flaxos/Team-Discovery-Channel/pull/101).

**Sprint 25 passed owner art review on 26 November 2026.** SG-3 Heavy wears a new carrier on the shared Airman rig with measured M249 and M9 grips. The four-class weapon matrix and M2 rear-position check are recorded with Linux export evidence and screenshots. The review records the accepted fit and remaining animation polish. [Sprint 25 review](docs/reviews/2026-11-26-sprint25-sg3-heavy.md).

**Sprint 26 adds three stationary civilian roles.** The lab technician, medic and administrator appear at authored workstations in SGC UAT and Defense. They share a fitted head and the Airman rig, with distinct workwear and props. The four-player fixtures check the stations after travel, late join and retry. Owner art review is open. [Sprint 26 review](docs/reviews/2026-11-26-sprint26-sgc-civilians.md) · [Sprint 25 merge](https://github.com/flaxos/Team-Discovery-Channel/pull/102).

**Sprint 27 fits a reusable stone platform to the offworld gate.** A full stone slab meets the inner rim and event horizon at foot level. The stock operative can walk either approach and cross the gate plane while grounded. The original DHD follows the existing gate state, and the hangar has tall-wall trim and recessed service cabinets. Sprints 26 and 27 reached main together in PR #103. Owner art review is open. [PR #104](https://github.com/flaxos/Team-Discovery-Channel/pull/104) · [Sprint 27 review](docs/reviews/2026-11-26-sprint27-offworld-gate-arrival.md).

**Sprint 28 merged via PR #105.** The long chamber gets engineering surfaces, a fitted generator and console, and recessed service detail. The cores and console display dim when the existing sabotage event releases command security. The review includes both routes, alarm extraction, late join, retry and the Linux export. Owner art review is open. [Sprint 28 review](docs/reviews/2026-11-26-sprint28-goauld-generator-room.md).

**Sprint 29 dresses the upper-deck command room.** Its fitted records terminal shows access, download and countdown state from the mission. Two reusable side consoles and a bronze wall seal complete the room. The review covers Infiltration, Timed Extraction, Alarm Escape and four-operative late joins. Owner art review is open. [Sprint 29 review](docs/reviews/2026-11-26-sprint29-goauld-command-room.md).

**Sprint 30 dresses the Goa’uld ramp and ring chambers.** Both pads share the tall-wall kit and flush frame around the operating space. The pitched floor runner and two-tone rails continue through both landings. [Sprint 30 review](docs/reviews/2026-11-26-sprint30-goauld-vertical-chambers.md).

**Sprint 31 dresses the Alpha Site outpost interior and observation vista.** Pre-fab shelter surfaces (`tauri_sgc`), field cargo crates, communications rack, and field console dress native room presets. The observation aperture frames an exterior alien mountain vista beyond the authored boundary while preserving 100% enclosure and collision containment. SGC civilian presence and the full entry/objective/return mission loop are verified. Owner art review is open. [Sprint 31 review](docs/reviews/2026-11-27-sprint31-alpha-site-outpost.md).

**Sprint 32 dresses the Ha’tak mothership boarding route and ring breach.** The two-deck route (`ai2_goauld_mothership_boarding.tres`) spans 9 modules dressed in authored Goa’uld trim, featuring three prop families (boarding bulkhead frame, sliding interior door, heavy naquadah cargo crates). Operatives enter via safe gate travel to the hangar, breach Deck 1 via reciprocal R16 transport rings (`rings_boarding` <-> `rings_upper`), access the shipboard manifest console, and extract. The mothership coexists with SGC as the two live worlds without flight or docking simulation. Owner art review is open. [Sprint 32 review](docs/reviews/2026-11-27-sprint32-mothership-boarding.md).

**Sprint 33 dresses the Ha’tak mothership bridge and engineering objective route.** Spanning 12 modules across two decks (`ai2_goauld_mothership_objective.tres`), the route introduces three prop families: the Command Bridge Navigation Helm, the Hyperdrive Naquadah Reactor Core with reactive status visuals (`MothershipReactorStatus.gd`), and the Forward Deep-Space Observation Viewport Frame. Solid layer 1 collision preserves camera occlusion and bounds at the viewport without void leaks. The canonical `MissionEvents` trigger unlocks the security blast door upon hyperdrive sabotage, triggering red alarm escape lighting across the ship for the tactical return route and Stargate debrief. Owner art review is open. [Sprint 33 review](docs/reviews/2026-11-27-sprint33-mothership-objective.md).

**Sprint 34 delivers the Ha’tak mothership hero exterior silhouette and vista dressing.** Built as pure background scenery (`MothershipExteriorSilhouette.tscn`, 1,084 triangles) with zero physics or flight simulation, the model features a stepped gold pyramid core, glowing apex capstone, trilateral bronze/basalt outriggers with staff cannon turrets, and amber propulsion thrusters, sharing 100% of existing Goa'uld palette materials. The silhouette is exposed through the command bridge observation window (`MothershipViewportFrame.tscn`) framing an escort Ha'tak against the cosmic nebula and stars, and through the hangar bay force field threshold (`MothershipHangarVista.tscn`) framing a multi-ship fleet formation. Owner art review is open. [Sprint 34 review](docs/reviews/2026-11-27-sprint34-mothership-exterior.md).

**R16 ring transport.** In Goa’uld Infiltration, step onto a ring pad and press Interact to carry the squad members aboard between decks. Both endpoints share a server-controlled cycle and an occupied receiving pad blocks transport. This gameplay slice uses the existing ring assets and clears a prerequisite for the mothership work. [Transport setup](docs/maps/modular-vertical-kit.md#equipment-and-transport-interfaces).

| Option | What | Who | Detail |
|---|---|---|---|
| **A. Review the corridor kit, then larger chambers** | GA-1 and GA-2 part 1 provide pieces for all nine corridor/compact-chamber modules: 14 of 20 native compound rooms. Sprint 6 recovers the unfinished corridor work, completes junction variants and fixes runner/corner/lintel joins while preserving gameplay geometry. **Owner art acceptance remains pending.** Then inspect unfinished larger-chamber work | Owner visual review; agent implementation | [Kit guide: human review](docs/maps/goauld-theme-kit.md#human-review-pending); order of rooms in the [brief](docs/maps/goauld-visual-brief.md#42-by-module-which-is-the-order-art-should-follow) |
| **B. Review co-op behavior** | R24 and sprint 1 are merged. Sprint 1 covers burst losses, authoritative rosters, paused HUD return, rejoining, retries, server shutdown, same-port rehosting and cancellation of stale reconnect/handoff callbacks. Sprint 2 Timed Extraction is merged. Sprint 3 Alarm Escape is merged. Sprint 4 flanking is merged. Sprint 5 ammunition sharing is merged in #76, with compatible active reserves, aimed/rebindable HUD interaction, server validation, conservation, four-operative snapshots/retry/disconnect and gate handoff | Agent implementation; owner co-op/latency review | [Sprint 1 review](docs/reviews/2026-11-17-sprint1-session-lifecycle.md); [next six sprints](docs/plans/next-six-sprints.md) |
| **C. Two-player sessions** *(deferred by the owner)* | The co-op checklist items no human has run: late join, shared extraction, revive, mixed quiet and loud play | Two humans | [Next work, part A](docs/plans/next-work-packages.md#a-human-play-sessions) |
| **D. Community asset insertion** | AP-1c (CC0 crates), AP-1d (CC BY Beretta M9) and AP-1e (Rotuma P90) are merged. AP-1f adds the CC BY M249 SAW by AK / skaf13 in [merged #68](https://github.com/flaxos/Team-Discovery-Channel/pull/68), with measured muzzle, fallback, mission captures and release export checked. AP-1g adds the Stargate glyph ring/seven-chevron visual; on 17 November 2026 the owner authorized inclusion with the uploader-authorship gap documented. Owner art review is pending. Sprint 7 adds the community MP5SD, ready work-order intake and distributed credits/full licences. Sprints 8 and 9 merged the original staff and Zat. Sprint 10 delivers the held-weapon audit. Sprint 11 covers the M2 defensive position and Sprint 19 covers the Airman rig. | Owner art review; asset integration agents (Claude, Codex, Gemini) | [Playbook](docs/assets/community-asset-playbook.md); [SAW review](docs/reviews/2026-11-16-ap1f-m249.md); [gate preview](docs/reviews/2026-11-16-ap1g-stargate.md) |

A and B do not depend on each other. Gate travel (GT-1 to GT-3) and SW-1 are merged in PRs #54–#58. TA-3 and CO-1 offworld resupply are merged. EV-2-1 implements objective-driven door releases and EV-2-2 adds Timed Extraction. EV-2-3 Alarm Escape is merged. TA-2 chunk 1 flanking is merged in #75; CO-2 chunk 1 ammunition sharing is merged in #76. Sprint 6 GA-2 corridor expansion is merged in #77 for owner visual review with recovered work, seven new module variants and unchanged production geometry. Human co-op sessions remain deferred. Weapon art expansion (AP-1b) and later chamber/tall-room theme work remain on the old SW-1 checkout. Sprint 6 recovers only the corridor-theme portion and preserves that checkout.

Community asset preparation now includes source-verified shortlists, a staged intake record and an offline GLB inspector. The [handoff](docs/assets/README.md) records acquisition, licence, fidelity and rig/animation gaps. AP-1c then imported the first community binary, a CC0 crate, with its intake record, validator report, captures and an exported-build check ([D-018](docs/DECISIONS.md)).

### Rules for any session

1. Read this page, then the package you are picking up. Do not start from the history.
2. Use the existing checkout and preserve its unfinished work. Do not create worktrees, clones, sibling project directories or alternate project copies unless explicitly requested; [AGENTS.md](AGENTS.md) is authoritative.
3. Run targeted suites while working and `python3 tools/run_godot_tests.py --profile full --timeout 600` once at the end. Then **check `gh pr checks <n>`**: the hosted runner is slower than the development machine, and local green has not meant hosted green.
4. Keep complete code, evidence and guide updates together. Use a draft PR when review is requested; when the user asks to commit and merge, run checks, merge and finish this checkout on `main` without another confirmation.
5. Merging: the owner squash-merges. If follow-on PRs stack on an unmerged one, a squash puts the rest into conflict. Either merge only the last PR (it contains the rest), or use merge commits. Details: [merging stacked work](docs/plans/next-work-packages.md#merging-dependent-pull-requests).

### What was delivered, in order

| Milestone | PR | Guide |
|---|---|---|
| EX-1 trustworthy baseline | [#42](https://github.com/flaxos/Team-Discovery-Channel/pull/42) | [extraction guide](docs/maps/modular-extraction-mission.md) |
| ST-1 sentry perception; GI-0/GI-1 infiltration mission | [#43](https://github.com/flaxos/Team-Discovery-Channel/pull/43), [#44](https://github.com/flaxos/Team-Discovery-Channel/pull/44), landed by [#45](https://github.com/flaxos/Team-Discovery-Channel/pull/45) | [infiltration guide](docs/maps/goauld-infiltration-mission.md) |
| EV-1 alarm, runners, reinforcements | [#46](https://github.com/flaxos/Team-Discovery-Channel/pull/46) | [alert guide](docs/maps/mission-alert.md) |
| ST-2 hearing and area searches; TA-1 prop cover; GI-2 loud-route suite and playtest template | [#49](https://github.com/flaxos/Team-Discovery-Channel/pull/49) (from #47, #48) | extraction and infiltration guides |
| GA-0 visual brief and GA-1 Goa'uld theme slice | [#51](https://github.com/flaxos/Team-Discovery-Channel/pull/51), [#53](https://github.com/flaxos/Team-Discovery-Channel/pull/53) | [kit guide](docs/maps/goauld-theme-kit.md) |
| GT-1 world coexistence; GT-2 outbound gate travel; GT-3 return gate travel and SGC debrief | [#54](https://github.com/flaxos/Team-Discovery-Channel/pull/54), [#55](https://github.com/flaxos/Team-Discovery-Channel/pull/55), [#56](https://github.com/flaxos/Team-Discovery-Channel/pull/56), [#57](https://github.com/flaxos/Team-Discovery-Channel/pull/57) | [split-world travel design](docs/plans/gate-travel-split-worlds.md) |
| CO-1 offworld co-op resupply & armoury | [#62](https://github.com/flaxos/Team-Discovery-Channel/pull/62) | [mission guide](docs/maps/goauld-infiltration-mission.md#offworld-armoury--resupply-co-1) |

## What exists today

| | State |
|---|---|
| **Playable** | **SGC Defense** (three-floor wave defence, difficulty objectives, dial out and extract). **SGC UAT Base** (the same base, no hostiles). **Modular Extraction UAT** (development slice: reach a room, use a console, return, with five patrolling Jaffa). **Goa'uld Infiltration — Greybox** (stealth testbed: sight-based sentries, a guarded and a quiet route, three objectives, alarm consoles and reinforcements). **Operation Infiltration — SGC to Offworld** (`travel_infiltration`: gear up in SGC, dial out, step through the gate into the Goa'uld compound, complete objectives, return through the offworld gate, and debrief in the SGC). **Timed Extraction** (`goauld_timed_extraction`: records download starts a three-minute window). **Alarm Escape** (`goauld_alarm_escape`, for review: a raised alarm starts that window; preventing the alarm leaves it untimed) |
| **Working systems** | Host/join and dedicated launch, four classes, server-authoritative combat, downing and revive, late join and retry, squad orders, Jaffa and airman AI, sentry perception, stealth takedowns from behind and quiet Zat incapacitation (`SW-1`), compound alert with alarm consoles and reinforcements, gate dialling and iris in the SGC, two-way Stargate travel between split worlds with carried state and SGC debrief (`MissionSession`), modular doors, locked-door rerouting and local NPC passing with safe AI door closing (TA-3 on this branch), licensed external `.glb` weapon asset ingestion (`AP-1a`), CC0 plastic crates dressing the SGC armoury ammo stations (`AP-1c`), the community Beretta M9 sidearm (`AP-1d`), the community FN P90 (`AP-1e`), M249 (`AP-1f`), Stargate glyph-ring/chevron visual (`AP-1g`) and Sprint 7 MP5SD, all pending art review; generated offline credits/full licences are available from the lobby; EV-2-1 adds objective-driven security releases; sprint 2 adds Timed Extraction; sprint 3 adds Alarm Escape; sprint 4 adds modular flanking; sprint 5 adds compatible ammunition sharing; sprint 6 adds the corridor theme kit for review |
| **Content pipeline** | 15 structural modules, 16 room presets, 8 composites, a visual editor, and an AI authoring CLI with a graph planner and topology checks |
| **First faction art** | The `goauld` theme: a dark stone, bronze and gold palette on every room, and built pieces (ribbed walls, lintels, floors, coffered ceilings) for the narrow corridor and the compact chamber. Generated in the engine; not yet reviewed by a person. [Kit guide](docs/maps/goauld-theme-kit.md) |
| **Placeholder only** | The other faction themes (`asgard`, `tokra`, `replicator`, `tauri_sgc` render the neutral fallback). Goa'uld larger-chamber/tall-room pieces beyond the Sprint 6 corridor subset. Several class perks named in the lobby text |
| **Not built** | Sound propagation through walls. General room-entry triggers and objective enabling beyond the implemented objective-completion/raised-alarm actions. Cover in rooms without low props (bare modules fall back to a marker). Goa'uld shields. Non-Goa'uld faction art. Outdoor terrain. Campaign progression |
| **Accepted by people** | Phases 1 to 3, by one owner playing alone on 14 November 2026 ([record](docs/reviews/2026-11-14-owner-solo-uat.md)). Not yet run by two people: late join, shared extraction, revive, mixed-route play, SGC Defense, and two-world gate travel on the current build |

**TA-2 suppression.** Closely spaced ballistic fire makes a modular sentry duck and seek nearby cover. An amber down arrow marks the opening for the squad. [Behavior and verification](docs/maps/modular-flanking.md#suppression).

The full classification, with source paths and tests, is the [capability matrix](docs/plans/master-development-roadmap.md#2-capability-matrix).

### Known problems that affect planning

- **Hosted CI was red on `main` from PR #35 to #41** because one suite could not find the engine on the CI runner. EX-1 repairs the runner; the hosted `Godot full` job passed on PRs #42 and #43.
- **Jaffa in gate waves still detect through walls** (the assault rule kept for SGC Defense). Patrols on modular missions use sight-based perception (ST-1), a compound alarm (EV-1) and straight-line hearing (ST-2).
- **Cover on modular levels needs props.** Since TA-1 Jaffa use barricades and crates; rooms without low props still fall back to a room-centre marker.
- **Ten modules place door headers 0.2 m outside their own cell**, overlapping the neighbouring room's header. Harmless until themed pieces met them; GA-1 works round it (risk R21).
- **Use this checkout to play.** Check its branch/commit and restart the running game after changes; do not create a separate play checkout. [Commands here](docs/plans/next-work-packages.md#get-a-build-to-play).
- **R24 joining/travel and sprint 1 session cleanup are merged.** New full-team lifecycle fixtures cover simultaneous losses and server shutdown, including a survivor, rejoining, retries and pending callbacks. WAN responsiveness remains a human check. [Review](docs/reviews/2026-11-17-sprint1-session-lifecycle.md).

All 25 items are in the [risk register](docs/plans/master-development-roadmap.md#7-risk-and-defect-register), including the session-lifecycle follow-up.

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
| **5. Travel** | GT-0, GT-1, GT-2, GT-3 | Brief in the SGC, step through the gate, come home and debrief; players may be in different worlds |
| **6. Deepen** | TA-2, TA-3, EV-2, CO-1, CO-2, SW-1 to SW-3 | Flanking, locked-door play, multi-stage missions, co-op roles, takedowns, shielded and specialist enemies |
| **7. Widen** | OW-0 to OW-2, other locations, CA-1, CA-2 | Outdoor gate sites, Alpha Site, mothership, other factions, linked missions |

Phases 4 and 5 do not depend on each other. Phase 4's brief (GA-0) is written and its first slice (GA-1) is built. Phase 5's design (GT-0) is written: two worlds side by side in one process, each player's game holding both and showing one.

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
| EX-2 | A dated two-person record exists for Modular Extraction UAT and one SGC Defense run | **Accepted by the owner on solo play**, 14 November 2026 ([D-014](docs/DECISIONS.md)). The two-person and SGC Defense parts were not run |
| Stealth | Two people cross the test facility unseen on purpose, and report the awareness tell as readable | **Accepted by the owner on solo play.** No unseen crossing was achieved in the recorded session |
| Infiltration greybox | Two people finish GI-1 by each route | **Accepted by the owner on solo play.** Finished by the loud route; the quiet attempt failed |
| Infiltration complete | Both routes are reported as worth replaying with alarm and reinforcements active | **Accepted by the owner on solo play** |

Automated suites never satisfy a human gate. The gates were defined for two people; the owner accepted them on one solo session and deferred the rest. The [record](docs/reviews/2026-11-14-owner-solo-uat.md) lists what was and was not run.

## Longer-term workstreams

| | Workstream | First milestone | Starts after |
|---|---|---|---|
| A | Extraction mission hardening | EX-1 | Now |
| B | Stealth and perception | ST-1 | CI repair |
| C | Mission scripting and events | EV-1 | ST-1, preferably GI-1 |
| D | Tactical AI and combat | TA-1 | ST-1 |
| E | Goa'uld infiltration mission | GI-0 | Now (layout), ST-1 (mission) |
| F | Goa'uld architecture and visuals | GA-0/GA-1 done; GA-2 part 1 corridor kit implemented for review ([brief](docs/maps/goauld-visual-brief.md), [kit](docs/maps/goauld-theme-kit.md)); human art review, then larger chambers | Now |
| G | Stargate world transitions | GT-1, GT-2, and GT-3 done | Complete (CA-1 / GA-2 / AP-1 next) |
| H | Expanded co-op mechanics | CO-1 | GI-1 |
| I | Special weapons and faction mechanics | SW-1 done (`test_stealth_takedowns_and_weapons`); SW-2 next | ST-2 |
| J | Outdoor world construction | OW-0 | Any time; design spike only |
| K | Other factions and locations | Alpha Site mission | EV-1 |
| L | Campaign and replayability | CA-1 | GT-3 and two offworld missions |

## Open product decisions

Two of the nine questions were answered on 14 November 2026: art is built in the engine by agents ([D-012](docs/DECISIONS.md)), and players may be in different worlds at once ([D-013](docs/DECISIONS.md)). The second went against the plan's default; its [design](docs/plans/gate-travel-split-worlds.md) is written, and four follow-up rules for a split team were decided the same day ([D-017](docs/DECISIONS.md)). Seven questions remain, each with a working default so that work is not blocked. The most consequential is whether Jaffa attack downed operatives. See [section 10 of the master plan](docs/plans/master-development-roadmap.md#10-open-questions-for-the-product-owners).

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
| SW-1 and AP-1a (15 November 2026) | Stealth takedowns from behind on unalerted sentries (`JaffaAI.can_be_taken_down_by`, `perform_stealth_takedown`, `PlayerController3D.try_stealth_takedown`), quiet Zat incapacitation (`noise_radius = 4.0`, silent stun/kill/vaporize without alerting target or nearby sentries or raising `MissionAlert`), dragging Zat-stunned Jaffa bodies into cover, and licensed CC0 Kenney `.glb` weapon asset ingestion (`p90_smg.glb`, `mp5_silenced.glb`) with D-015 `metallic = 0.0` sanitization and `credits/ATTRIBUTIONS.md` provenance (`test_stealth_takedowns_and_weapons`). |
| AP-1d (16 November 2026, `feat/ap1d-m9-onto-main`) | First realistic weapon. The owner's Sketchfab download of "Beretta M9" by emran.bayati (CC BY 4.0) was converted from FBX in the engine by the new recipe-driven `pack_model_glb.gd` (kept gun and seated magazine, bound five maps, 1024² JPEG with ORM packing; Khronos 0 errors, 0 warnings). `WeaponBase` turns it to −Z and puts its measured bore on the unchanged `MuzzlePoint`; weapon GLBs are now parsed once per session and shared (59 ms first, 0.1 ms after). D-015 matte kept; SGC/offworld captures and a Linux release export checked (`test_imported_m9_visual`). Owner art review pending ([record](docs/reviews/2026-11-16-ap1d-beretta-m9.md), D-019). |
| AP-1c (16 November 2026, `feat/ap1c-crate-cosmetic-proof`) | First community asset proof. The M9 download needed a Sketchfab account (HTTP 401), so the documented CC0 fallback was used: Poly Haven "Plastic Crate 02", packed byte-for-byte into a GLB by the new `tools/gltf_to_glb.py`, validated (Khronos, 0 errors) and loaded at runtime by `RuntimeGLB`. `CrateStackVisual` dresses the two SGC armoury ammo stations with 33 crates each inside their unchanged collision boxes; tint, opacity, occlusion and mipmaps are runtime-only. Forward+ captures, +385,440 triangles in the armoury view, late-join/retry and a Linux release export checked (`test_imported_crate_visual`). Owner art review pending ([record](docs/reviews/2026-11-16-ap1c-plastic-crate.md), D-018). |
| TA-3 (16 November 2026, this branch) | Locked-door rerouting uses the native layout graph with live locks and navmesh legs; NPCs pass to their right when oncoming while preserving co-patrol and trailing non-interference; AI-opened doors close only when clear, with an explicit opt-out and replicated state. Includes dynamic lock/unlock, occupied doorway, manual-door preservation, post-combat patrol resumption hardening and late-join multiplayer coverage. Human playtest pending. |
| GT-3 (15 November 2026) | Return gate travel and SGC debrief (`feat/gt3-return-debrief`). Wired `stargate_dhd` preset's `Stargate` and `DHD` inside `ModularMission`; offworld DHD dialing blocked until objectives complete (D-017); completing objectives in a travel mission opens the site Stargate for home instead of concluding immediately; SGC outbound dialing allowed during travel missions; returning operatives land on the SGC Stargate platform; D-017 success rule finishes the mission once objectives are complete, zero standing operatives remain offworld, and at least one returned home; SGC debrief synced to all peers with real kills, objectives, duration, alert status, and returned vs lost operative callsigns; gates close across both worlds and two-world retry resets cleanly (`test_gate_return`, `test_gate_return_multiplayer`). |
| GT-2 (14 November 2026) | Outbound gate travel from SGC to offworld compound. `MISSION_TRAVEL_INFILTRATION` selectable mission; SGC outbound dialing and extraction authorization; complete operative state capture and hand-off (health, inventory, weapons, ammo, heat, gadget cooldowns, patch ROM); peer presentation switching; late joiner spawning at home; split-squad failure rule; SGC Mezzanine abort control. Single-process and two-process multiplayer test suites pass cleanly. |
| GT-1 (14 November 2026) | Worlds that can coexist. `MissionWorld` scopes 63 lookups to the actor's own world; `MissionSession` places operatives, presents one world per peer and loses the mission only when everyone in both worlds is down; the coordinator loads one world or two. A hidden development mission runs the SGC and the compound together. No travel and no visible change. 80/80 local checks. |
| GT-0 (14 November 2026) | Documentation only: [gate travel with a split team](docs/plans/gate-travel-split-worlds.md). An experiment ran the SGC and the infiltration compound together in one process, 2 km apart, with no errors, and showed the fault to fix first: 48 whole-game lookups, which left a sentry unable to see an operative in front of it. Strategy [D-016](docs/DECISIONS.md); the owners' rules for a split team [D-017](docs/DECISIONS.md). GT-1 to GT-3 rewritten. |
| GA-1 (14 November 2026) | The Goa'uld theme kit: palette on all 20 rooms of the infiltration compound, generated pieces on the 8 that use the narrow corridor or compact chamber, per-module coverage reporting, slot-name validation, a capture tool, and readability measured from captures. Collision and navigation proved identical with and without the theme. Found and fixed: metallic surfaces lose their colour in missions, so Jaffa armour rendered dark; it is now matte (D-015). Found and worked round: ten modules place headers outside their own cell (R21). One new suite; 78/78 local checks. |
| GA-0 (14 November 2026) | Documentation only: the [Goa'uld visual brief](docs/maps/goauld-visual-brief.md) (design language with dimensions and a palette checked against the Jaffa and awareness markers, theme-slot audit with eight gaps, rooms ranked by use, art-method options), the [owner's solo UAT record](docs/reviews/2026-11-14-owner-solo-uat.md) and decisions D-012 to D-014. |
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
