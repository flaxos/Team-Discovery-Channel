# Map and mission architecture: implementation record and follow-up

Updated 9 November 2026 against gameplay commit `a720594`. The original follow-up proposal has been partly delivered; this record distinguishes implemented contracts from future restructuring. Preserve working Q/ADS, remapping, combat authority and mission behavior.

## Implemented map topology

- `SGCMapDefinition` supplies named regions/connections, main floor heights, local offsets, ceilings, clearance, lighting, references/confidence and art-replacement data. The playable map contains Levels 28/27/26.
- `SGCMap` builds reusable walls/floors, clipped portals, guarded stairs, shaft enclosures, cover, fixtures and dressing. Retained props own the gate, consoles, glazing and shutters.
- Both factions use `SGCNavigator` for graph/local paths, physical stair movement and lift actions. Production capsule traversal covers all walk/stair edges in both directions without intermediate position resets.
- The SG-1-informed core has raised sealed operations, briefing above, side/rear access and revised gate/chamber proportions. Quiet UAT is selected through the normal host lobby.
- `SGCEnclosureValidator` checks physical exterior closure; detached walking joins fail schema validation and the bake refuses shell errors. Negative tests introduce gaps and removed surfaces. Art slots retain briefs and dimension bounds.

These changes are delivered through [PR #22](https://github.com/flaxos/Team-Discovery-Channel/pull/22), [#23](https://github.com/flaxos/Team-Discovery-Channel/pull/23), [#24](https://github.com/flaxos/Team-Discovery-Channel/pull/24) and [#25](https://github.com/flaxos/Team-Discovery-Channel/pull/25). Current contracts and exact commands live in [the map guide](../docs/maps/sgc.md).

## Implemented mission ownership

Native server authority, gate direction/reservation, objective eligibility, late-join snapshots and coordinated retry/world retirement are in place. The host selects Defense/UAT and difficulty. Gate rendering/lifecycle stays with `StargateRing`; the wave system requests transitions and observes accepted changes. UI observes mission state. Buffer lockout/upload progress does not create an orphan dialing panel.

## Remaining design proposals

A single explicit mission-phase enum/coordinator and fully data-driven objective definitions remain possible follow-up refactors; they are not claims about the current implementation. Current public interfaces split responsibility across `NetworkManager`, `MainGameCoordinator`, `WaveManager`, `StargateRing` and the dialing console. See [architecture](../docs/ARCHITECTURE.md) before replacing them.

If this restructuring is pursued, keep one authoritative predicate for progression/UI acceptance, preserve reservation and stale-callback behavior, and migrate behind existing interfaces. Avoid a second gate state machine or parallel networking stack. Scope offworld scene transitions separately.

## Verification and acceptance

At `a720594`, all 51 local checks passed, including route/lift/enclosure/lockout contracts and native multiplayer regressions. Forward+ captures were inspected. Continue [graphical and two-human UAT](../docs/TESTING.md#graphical-and-human-uat), especially combat balance, latency and live mission completion. Automated collision/visibility checks do not establish game feel.
