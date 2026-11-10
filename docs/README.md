# Documentation index

Maintained documentation describes the code available at gameplay baseline `a720594` (9 November 2026), including the enclosure and lockout fixes proposed in [PR #25](https://github.com/flaxos/Team-Discovery-Channel/pull/25). Consult GitHub for merge/CI status and your local checkout for the code actually running.

| Document | Purpose |
| --- | --- |
| [Project README](../README.md) | Quick launch, current scope and developer entry points. |
| [Player guide](PLAYING.md) | Hosting/joining, Defense/UAT, controls, lift and objective troubleshooting. |
| [Game design](../GDD.md) | Implemented mechanics and explicitly deferred mission concepts. |
| [Architecture](ARCHITECTURE.md) | Runtime ownership, multiplayer authority and code entry points. |
| [Visual modular editor](maps/modular-editor.md) | Native top-down GUI, Undo/Redo, save/build/preview and manual UAT. |
| [Modular room kit](maps/modular-levels.md) | Phase 1 scenes, typed layouts, editor/headless authoring and acceptance. |
| [Modular NPC navigation](maps/modular-npc-navigation.md) | Production Jaffa/airman navigation, patrols, AI door use, demo scene and limitations. |
| [Modular extraction mission](maps/modular-extraction-mission.md) | First playable modular mission: objectives, extraction rule, Jaffa combat, tests, UAT and travel blockers. |
| [Offworld extraction plan](plans/offworld-extraction-mission.md) | Dependency map for the offworld mission; its first milestone is now implemented. |
| [SGC map contract](maps/sgc.md) | Proportions, provenance, schema, art slots, navigation and enclosure rules. |
| [Testing and UAT](TESTING.md) | Automated checks, report interpretation, screenshots and manual route. |
| [Alignment app](ALIGNMENT.md) | Web app setup, tokens, deployment settings and generated exports. |
| [Roadmap](../ROADMAP.md) | Delivered milestones, current acceptance work and future scope. |
| [Contributor handoff](../BOOTSTRAP_PROMPT.md) | Instructions for continuing the existing game. |
| [Team contract](../TEAM_CONTRACT.md) | Team commitments and quality gates. |
| [Work tracker](../plan/README.md) | Implementation and acceptance records. |

## Historical and generated material

[Reviews](reviews/), [hardening audits](hardening/) and the [Sprint 20 plan](plans/sprint20_ads_squad_submenu_and_keybinding_remapping_plan.md) record findings and commands at their stated baseline. Their old branch states, suite counts and short diagnostic timeouts are not current release instructions. Their findings remain intact for traceability.

[Generated planning snapshots](generated/README.md) reflect Alignment Engine votes. They are not authoritative implementation status. Current operating instructions live in the maintained documents above; change those explicitly when behavior changes.
