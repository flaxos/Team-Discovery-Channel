# SGC delivery roadmap

Godot target: **4.4.1**, strict typed GDScript and native ENet multiplayer. Updated 9 November 2026 against gameplay commit `a720594`. This is implementation/acceptance status, not a new delivery-date commitment.

## Current delivered behavior

- **Three-level map:** Levels 28/27/26, raised sealed operations, briefing overlook, revised gate/chamber proportions, side/rear access and physical stairs/lift.
- **Mission selection:** host-selectable Defense or quiet UAT, shared with clients and retained on retry.
- **Defense progression:** three cleared incursions on every tier; Medium adds the lab computer upgrade; Hard adds in-incursion iris repair. Gate direction and reservations prevent incoming/outbound overlap.
- **Controls:** shoulder ADS, squad selection while aiming, persistent remapping, aimed cabin buttons and lift picker.
- **Authority:** server combat/shared interactions, native NPC replication, joining-client snapshots and coordinated world replacement.
- **Enclosure/UI fixes:** clipped corridor portals, enclosed connecting shafts, bake/CI enclosure gate and non-modal buffer-lockout/upload notifications.

The map/core delivery is covered by [PR #22](https://github.com/flaxos/Team-Discovery-Channel/pull/22), [mission/UAT selection #23](https://github.com/flaxos/Team-Discovery-Channel/pull/23), [architecture/lift UAT fixes #24](https://github.com/flaxos/Team-Discovery-Channel/pull/24) and [enclosure/lockout fixes #25](https://github.com/flaxos/Team-Discovery-Channel/pull/25). Check GitHub for merge and hosted CI state. Local code may be on a feature branch ahead of main.

At `a720594`, **51/51 local Godot checks passed**, including continuous three-capsule routes, live lift grounding, negative enclosure cases and native multiplayer regressions. Forward+ captures were inspected. Human multiplayer/combat acceptance remains separate; [TESTING.md](docs/TESTING.md) contains the current route and commands.

## Milestone history

The earlier sprint numbers describe the sequence of development, not current geometry or immutable gameplay rules.

| Milestone | Delivered work and later corrections |
| --- | --- |
| Sprints 0–3 | Gate/rendering, basic multiplayer/combat, Jaffa, turrets/C4/claymores, hallway and wave escalation. Offworld transport rings were later removed from the SGC core. |
| Sprints 4–5 | Downing/revive, HUD/settings, dedicated launch, callsigns and reconnect handling. |
| Sprints 6–9 | Expanded bunker rooms, cover/Zat mechanics, briefing/office, vertical combat, resupply/CCTV and defense interactions. |
| Sprints 10–13 | ADS and layout polish, SGC dialing console, incoming/recharge engine and lab-ROM objective. The old 1/2–3/4–5 surge difficulty design is superseded by the current three-incursion minimum and objective gates. |
| Sprints 14–16 | Friendly squad AI, tactical gear, iris repair, hallway connectivity and fog of war. The temporary flat Level 28/control-floor design is superseded by raised operations and side/rear stairs. |
| Sprints 17–20 | Elevation/gunplay and integration work, TPS camera, accessible stair/lift controls, ADS squad selection and persistent remapping. The old numbered offworld proposals were not delivered under those sprint numbers. |
| Stabilisation / Sprint 21 cleanup | Combat authority, mission lifecycle/settings, late joins/retry, NPC/shared-state replication, strict CI and authenticated Alignment exports. See the historical [engineering report](docs/hardening/engineering-report.md). |
| SGC refactor and UAT follow-up | Authored region/connection/art schema, all three floors, shared faction navigation, mission selector, closer SG-1 proportions, ceilings, independent shutters, grounded lift travel and enclosure/lockout fixes. |

## Acceptance work

- Run the documented quiet UAT route on the checkout being evaluated; log new map/rendering/control defects with locations and steps.
- Complete two-human Defense runs across difficulties, including objectives, late join/retry, revives, shutters, lift contention and fallback pressure.
- Assess combat spacing, readability, sound and latency tolerance. Existing automated tests and fixed-camera captures do not establish these qualities.
- Preserve the passing enclosure, traversal, authority and controls contracts when addressing feedback. Rebuild navigation with collision/layout changes.

## Future milestones — not implemented mission selections

1. **Offworld outpost/sabotage:** outbound theater loading, offworld DHD and transport rings, objective extraction and shared mission data.
2. **Alpha Site evacuation:** civilian evacuation and defense progression using shared gate/combat components.
3. **Ha'tak infiltration:** mothership routes, stealth/alarms and sabotage objectives.
4. **Art replacement:** replace dimensioned placeholders with reviewed props/textures while retaining collision and route validation.

These require scoped designs and acceptance criteria. Do not present the original MALP/UAV, stealth or scene-transition proposals as shipped features. The [work tracker](plan/README.md) records implementation and follow-up status; the [GDD](GDD.md) preserves the wider design direction.
