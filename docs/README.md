# Documentation index

Resume status checked **23 November 2026**, with Sprint 8’s shared staff merged and Sprint 9’s original Zat integrated for review. **Sprint 10, the six-weapon audit, is next.** Historical documents retain their stated baselines. Consult GitHub for merge and CI status and your local checkout for the code actually running.

## Start here

| Document | Purpose |
| --- | --- |
| [Roadmap](../ROADMAP.md) | **Authoritative.** What exists, what is next, milestone sequence, dependencies and acceptance gates. |
| [Asset sprint programme](plans/asset-vertical-slices.md) | **Current agent sequence.** Sprint 10 weapon audit, then field kit, SGC, characters, offworld and mothership through Sprint 35; exact prompts and acceptance boundaries. |
| [Human sessions and earlier packages](plans/next-work-packages.md) | Deferred human play sessions, tuning and dependent-PR guidance; the GA-0/GT-1 package prompts are historical completed work. |
| [Master development plan](plans/master-development-roadmap.md) | Capability matrix with evidence, dependency graph, every milestone, the art and content track, the risk register and three agent-ready work packages. |
| [Decision log](DECISIONS.md) | Architectural and direction decisions, with status and open questions. |
| [Gate travel with a split team](plans/gate-travel-split-worlds.md) | The design for travelling between the SGC and an offworld site when players need not travel together: the owners' rules, what the code does today, the experiment, the strategy, edge cases and milestones GT-1 to GT-3. |
| [Game design](../GDD.md) | Part 1: the game as implemented. Part 2: the intended game. |
| [Project README](../README.md) | Quick launch and developer entry points. |

## Playing, architecture and testing

| Document | Purpose |
| --- | --- |
| [Player guide](PLAYING.md) | Hosting/joining, missions, controls, lift and objective troubleshooting. |
| [Architecture](ARCHITECTURE.md) | Runtime ownership, multiplayer authority and code entry points. |
| [Testing and UAT](TESTING.md) | Automated checks, report interpretation, screenshots and manual routes. |
| [Contributor handoff](../BOOTSTRAP_PROMPT.md) | Standing instructions for continuing the existing game. |
| [Team contract](../TEAM_CONTRACT.md) | Team commitments and quality gates. |
| [Alignment app](ALIGNMENT.md) | Web app setup, tokens, deployment settings and generated exports. |

## Missions and maps

| Document | Purpose |
| --- | --- |
| [SGC map contract](maps/sgc.md) | Proportions, provenance, schema, art slots, navigation and enclosure rules. |
| [Modular extraction mission](maps/modular-extraction-mission.md) | First playable modular mission: objectives, extraction rule, Jaffa combat, tests, human checklist and travel blockers. |
| [Goa'uld infiltration mission](maps/goauld-infiltration-mission.md) | Greybox stealth mission: compound layout and requirements, objectives, patrols, quiet and guarded routes, tests, human checklist. |
| [Compound alert, alarms and reinforcements](maps/mission-alert.md) | EV-1: alert levels, alarm runners and consoles, reinforcement budget, mission data, netcode, tests. |
| [Goa'uld visual brief](maps/goauld-visual-brief.md) | GA-0: design language with dimensions and palette, theme-slot audit and gaps, rooms ranked by use, art-method options. The target for GA-1, with what building it corrected. |
| [Goa'uld theme kit](maps/goauld-theme-kit.md) | GA-1: what is themed, the generator and how to extend it, coverage reporting, readability measured from captures, tests, the capture tool and the pending human review. |
| [Modular NPC navigation](maps/modular-npc-navigation.md) | Production Jaffa/airman navigation, patrols, AI door use, demo scene and limitations. |

## Level authoring

| Document | Purpose |
| --- | --- |
| [AI level authoring guide](maps/ai-level-authoring.md) | The shared CLI used by every coding agent: discover, plan, validate, build, preview, topology checks. |
| [Modular room kit](maps/modular-levels.md) | Phase 1 scenes, typed layouts, editor/headless authoring and acceptance. |
| [Structural catalogue](maps/modular-catalogue.md) | Structural modules, sockets and gallery. |
| [Vertical kit](maps/modular-vertical-kit.md) | Ramps, decks, tall rooms, equipment anchors and transport contracts. |
| [Functional room presets](maps/modular-room-presets.md) | Sixteen room roles, attachments, overrides and the security-door interface. |
| [Integrated fixture](maps/modular-integration-demo.md) | The two-deck demonstration level used by the extraction mission. |
| [Visual modular editor](maps/modular-editor.md) | Native top-down GUI, Undo/Redo, save/build/preview and manual UAT. |
| [Authoring briefs](maps/briefs/) | Brief text and route requirements for the demonstration maps. |

## Art and community assets

| Document | Purpose |
| --- | --- |
| [Shared AI asset workflow](assets/ai-asset-workflow.md) | Community-first acquisition, learning from prior imports, strict work orders, packaging and evidence for each playable slice. |
| [Texture import contract](assets/texture-import-contract.md) | PBR channels, normals, alpha, theme scale, provisional budgets and measured exceptions. |
| [Asset sourcing register](assets/asset-program-sourcing.md) | Integrated MP5SD and dated source leads for later sprints, with acquisition and licence gaps kept explicit. |
| [Community asset integration playbook](assets/community-asset-playbook.md) | Start here to put a community model in the game: routes by target, licence gate, staging, the packer, wrappers, proof and records, with pitfalls from AP-1c and AP-1d. |
| [Community asset handoff](assets/README.md) | Ranked first insertion queue, verified sourcing, outstanding acquisition/rig/licence gaps and a ready-to-run intake workflow. |
| [Static asset shortlist](assets/community-static-shortlist.md) | Specific tactical weapons, Stargate props, industrial dressing and PBR material candidates with primary evidence. |
| [Characters and animation shortlist](assets/community-characters-animation-shortlist.md) | Specific rig/motion candidates, raw redistribution constraints, current controller contracts and first Airman visual proof. |
| [Asset import pipeline](plans/asset-import-pipeline.md) | What is actually implemented, GLB inspection tool, source/credit records, wrapper/socket rules and insertion acceptance. |
| [AP-1c crate record](reviews/2026-11-16-ap1c-plastic-crate.md) | The first community asset in the game: acquisition, licence, measurements, placement, captures, render cost and the exported-build check. |
| [AP-1d M9 record](reviews/2026-11-16-ap1d-beretta-m9.md) | The first realistic weapon: owner-downloaded CC BY archive, FBX conversion by recipe, bore alignment, finish comparison, sharing and the exported-build check. |
| [Sprint 7 MP5SD record](reviews/2026-11-18-sprint7-mp5-intake.md) | Imported Carter MP5SD, shared intake validation, distributed credits/full licences, captures, costs, local/hosted checks and remaining owner acceptance. |
| [Sprint 8 shared staff](reviews/2026-11-23-sprint8-staff-intake.md) | Archive assessment, original textured visual shared by the player and Jaffa, fit, tests and captures. |
| [Sprint 9 Zat](reviews/2026-11-23-sprint9-zat-visual.md) | Source comparison, original sidearm, fit, quiet hit states, travel and release evidence. |

## Plans and records

| Document | Purpose |
| --- | --- |
| [Offworld extraction plan](plans/offworld-extraction-mission.md) | Earlier dependency study. Superseded by the master plan; kept for its analysis. |
| [AI level authoring 2.0 review](reviews/ai-level-authoring-2.md) | Friction study and before/after benchmark for the planner. |
| [Infiltration playtest template](reviews/infiltration-playtest-template.md) | Copy per human session; the evidence for the Stealth and Infiltration gates. |
| [Owner solo UAT, 14 November 2026](reviews/2026-11-14-owner-solo-uat.md) | First human session on `main` after phase 3: what the log shows, what the owner stated, what was not run; gates accepted on solo play. |
| [Work tracker](../plan/README.md) | Implementation records for the SGC refactor and Sprint 21. |

## Historical and generated material

[Reviews](reviews/), [hardening audits](hardening/) and the [Sprint 20 plan](plans/sprint20_ads_squad_submenu_and_keybinding_remapping_plan.md) record findings and commands at their stated baseline. Their old branch states, suite counts and short diagnostic timeouts are not current release instructions. Their findings remain intact for traceability.

[Generated planning snapshots](generated/README.md) reflect Alignment Engine votes. They are not authoritative implementation status. Current operating instructions live in the maintained documents above; change those explicitly when behavior changes.
