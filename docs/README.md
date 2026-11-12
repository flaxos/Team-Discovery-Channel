# Documentation index

Maintained documentation describes `main` at `bf56743` (PR #40, 11 November 2026) unless a document states its own baseline. Consult GitHub for merge and CI status and your local checkout for the code actually running.

## Start here

| Document | Purpose |
| --- | --- |
| [Roadmap](../ROADMAP.md) | **Authoritative.** What exists, what is next, milestone sequence, dependencies and acceptance gates. |
| [Master development plan](plans/master-development-roadmap.md) | Capability matrix with evidence, dependency graph, every milestone, the art and content track, the risk register and three agent-ready work packages. |
| [Decision log](DECISIONS.md) | Architectural and direction decisions, with status and open questions. |
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

## Plans and records

| Document | Purpose |
| --- | --- |
| [Offworld extraction plan](plans/offworld-extraction-mission.md) | Earlier dependency study. Superseded by the master plan; kept for its analysis. |
| [AI level authoring 2.0 review](reviews/ai-level-authoring-2.md) | Friction study and before/after benchmark for the planner. |
| [Work tracker](../plan/README.md) | Implementation records for the SGC refactor and Sprint 21. |

## Historical and generated material

[Reviews](reviews/), [hardening audits](hardening/) and the [Sprint 20 plan](plans/sprint20_ads_squad_submenu_and_keybinding_remapping_plan.md) record findings and commands at their stated baseline. Their old branch states, suite counts and short diagnostic timeouts are not current release instructions. Their findings remain intact for traceability.

[Generated planning snapshots](generated/README.md) reflect Alignment Engine votes. They are not authoritative implementation status. Current operating instructions live in the maintained documents above; change those explicitly when behavior changes.
