# Decision log

Architectural and product-direction decisions for Stargate SG Extraction. Started 12 November 2026 with the [master roadmap](../ROADMAP.md) audit at `bf56743`.

**Status values.** *Accepted*: already true in the code or signed off by the team. *Recommended*: the roadmap assumes it; an owner has not confirmed it. *Open*: undecided, with the question stated.

Add new entries at the end. Change a decision by adding an entry that supersedes the old one; do not edit history.

| # | Decision | Status |
|---|---|---|
| D-001 | Gameplay systems before the mission map before art | Recommended |
| D-002 | Gate travel by sequential world swap, squad together | Recommended, with one open question |
| D-003 | Mission events extend the existing mission data; no second mission manager | Recommended |
| D-004 | Perception is a server-side component of the enemy controller, with two profiles | Recommended |
| D-005 | One navigation adapter; reroute on the room graph, not by rebaking | Accepted (adapter), Recommended (rerouting) |
| D-006 | Indoor modules and outdoor terrain are separate authoring systems | Recommended, pending a spike |
| D-007 | Host-authoritative ENet; no persistence yet | Accepted (authority), Open (persistence) |
| D-008 | Modular missions inherit `GateRoom` until gate-travel work begins | Accepted |
| D-009 | Native `LevelLayout` resources are the only saved map format | Accepted |
| D-010 | Themes never change collision or navigation | Accepted |
| D-011 | Automated tests never count as human acceptance | Accepted |

---

## D-001 — Priority: gameplay, then map, then art

**Decision.** Build a minimal perception core first (ST-1), then the first designed Goa'uld mission in greybox on top of it (GI-1), then a small Goa'uld art slice (GA-1). The greybox layout and the art brief may proceed in parallel because they are cheap and touch no shared code.

**Why.** Detection that ignores walls makes every modular mission the same running fight (`client/scripts/entities/JaffaAI.gd`, `_find_nearest_target`), so a larger map or better art would not improve play. Perception is reused by every mission style in the [GDD](../GDD.md). The [team contract](../TEAM_CONTRACT.md) already ranks gameplay above bespoke art.

**Alternatives rejected.** Map first: the existing extraction mission shows the gap is behaviour, not rooms. Art first: a kit made before the mission is played targets the wrong rooms.

**Detail.** [Master plan, section 3](plans/master-development-roadmap.md#3-decision-gameplay-map-or-art-first).

## D-002 — Gate-world transition strategy

**Decision.** One world is loaded at a time. Stepping through an authorised gate is a squad-level transition that swaps the world, as the lobby-to-mission and retry transitions already do. Roster state (class, health, ammunition), objective progress and the result move into a session object above the world so that they survive the swap.

**Why.** `NetworkManager.MISSIONS` maps a mission to one scene and `MainGameCoordinator` already replaces the whole world behind a readiness handshake. Player, enemy and gadget spawners and every snapshot RPC are children of one world root. Loading two spaces together would need a second set of spawners, per-space visibility and navigation, and a late-join rule for "which space is each operative in". The swap reuses machinery that is already tested (`test_mission_restart_cleanup`, `test_multiplayer_mission_join`).

**Consequences.** The whole squad travels together. A late joiner loads whichever world the squad is in. `StargateRing.player_extracted` must hand over to a transition instead of ending the mission (`GateRoom._on_player_extracted`).

**Open question.** Whether players may ever be in different worlds at once (for example one staying in the SGC control room). The recommendation assumes not. Changing that reopens this decision.

**Source.** Blockers listed in [the extraction mission guide](maps/modular-extraction-mission.md#remaining-blockers-for-sgc--stargate--offworld-travel); milestones GT-1 to GT-3.

## D-003 — Mission-event architecture

**Decision.** Mission behaviour beyond sequential objectives is added to the existing data contract (`MissionDefinition`, `MissionObjective`, `MissionPatrol`) as a short typed list of triggers and actions, executed by one host-side director node in the mission scene next to `MissionObjectives`. `WaveManager` remains the director of SGC Defense and is not generalised.

**Why.** There is already one data-driven mission path (PR #39). A general event framework written before a second mission exists would be designed without evidence. The first alert and reinforcement rules (EV-1) are therefore written after, or alongside, the first designed mission (GI-1), and a trigger or action is added only when a mission definition uses it.

**Not decided.** Whether SGC Defense is ever migrated onto the same contract. Nothing requires it.

## D-004 — Perception and stealth ownership

**Decision.** Perception is a server-only component used by `JaffaAI`. It has two profiles: *sentry* (line of sight, view cone, graded awareness; selected by `start_patrol`) and *assault* (today's rules; kept for wave and column Jaffa). The awareness state replicates to clients for display only. The level-wide alert state, when it exists, belongs to the mission director (D-003), not to individual enemies.

**Why.** Keeping the assault profile leaves SGC Defense and its test suites unchanged, the same containment PR #39 used for patrol combat. Clients never decide what an enemy knows, consistent with D-007.

**Deferred.** Sharing the component with friendly airmen; noise; light and concealment.

## D-005 — Navigation ownership

**Accepted.** Both AI controllers talk to one navigator. `SGCNavigator` plans over SGC regions when an `SGCMap` is present and otherwise delegates to `LevelNavigator`, which follows the navigation mesh a `LevelAssembly` bakes (PR #38). There is no second bake and no per-faction navigation.

**Recommended.** When a locked door blocks a route, choose an alternative on the layout's room graph (the search `LevelTopology.path` already performs) and walk it room by room. Do not rebake the navigation mesh at run time.

**Why.** The mesh is baked once. A door that is locked at bake time is an obstacle; a door locked later leaves walkable mesh behind it and is detected on the planned path instead. A room-graph detour handles both cases without a rebake and works for both factions.

## D-006 — Indoor versus outdoor authoring

**Decision.** `LevelLayout` and the modular kit are for interiors. Outdoor areas are separate terrain scenes with their own navigation region, joined to interiors through a defined doorway contract. Terrain is not expressed as modules, sockets or footprints.

**Why.** The module system's guarantees (snap, overlap, enclosure, deck height) assume boxes with sockets. Terrain, cliffs and villages break all of them, and bending the validator to fit would weaken it for interiors.

**Status.** Recommended. No outdoor code exists. Spike OW-0 must prove the doorway contract and shared navigation before this is accepted.

## D-007 — Network authority and persistent state

**Accepted.** Native Godot ENet with a host or dedicated server that resolves combat, objectives, AI and shared interactions. Clients send requests that are validated by sender, reach and state. No rollback netcode ([team contract](../TEAM_CONTRACT.md), Article III). Joining clients receive snapshots per object behind a readiness gate.

**Open.** Persistence. Nothing is saved between missions today. When it is needed (CA-1), the recommendation is host-owned state written by the host only. Whether progress belongs to the host, to each player, or to a shared campaign file is a product decision.

## D-008 — Mission hosting

**Accepted (PR #39).** `ModularMission` extends `GateRoom` and inherits spawning, late join, squad-down failure, result and retry. SGC-only behaviour is stubbed.

**Planned change.** Extract a slim shared host when gate-travel work starts (GT-1), because that work must restructure state ownership anyway. Not before: a second modular mission can reuse `ModularMission` as it stands, and an early split would touch the stable SGC mission for no player-visible gain.

## D-009 — Level representation

**Accepted (PRs #27, #35, #40).** A native `LevelLayout` `.tres` is the only saved form of a modular map. Planner requests are disposable inputs. Requirement lists in `docs/maps/briefs/` describe intent and are re-checked by tests; they are not a second map format.

## D-010 — Theme contract

**Accepted (PR #35).** A `LevelVisualTheme` supplies materials and decoration only. It cannot change collision, sockets, positions or navigation. A theme without art falls back to `neutral` and says so (`art_status = "fallback"`). Faction art must fit this contract; if a slot is missing, extend the resolver, not the geometry.

## D-011 — Acceptance

**Accepted.** A passing suite establishes that code behaves as tested. It does not establish feel, balance, readability or latency tolerance. Documents may say "human-accepted" only when a dated record of a human run exists under `docs/reviews/`.
