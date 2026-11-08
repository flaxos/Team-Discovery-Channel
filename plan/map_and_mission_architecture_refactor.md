# Follow-up: map and mission architecture refactor

Do this after Sprint 21 cleanup is playable and verified. Preserve the working Q/ADS and remapping behavior.

## Map topology

Replace overlapping room-sized CSG walls/floors with reusable floor, wall, portal, landing and staircase modules. Define a floor-height table, minimum capsule clearance, wall thickness and door aperture dimensions once. Every portal must connect two named navigable regions, with explicit clearance volumes that neighboring floors/walls cannot occupy.

Keep a named region/connection graph alongside the authored map. Use that graph for spawn placement, test route generation, AI destinations and accessibility reporting. Validate connected regions with the production player capsule and both directions of every vertical connection. Test access from real spawn/corridor positions, not only positions within the target room.

## Mission ownership

Keep one server-authoritative mission coordinator with explicit phases: preparation, incoming sequence, incoming active, cleanup/recharge, outbound eligible, outbound dialing, outbound active, mission ended. The gate owns its direction and rendering lifecycle; the wave system requests transitions and reacts to accepted state changes. UI observes state and objectives rather than setting gate visuals directly.

Represent the mode objectives as data: minimum cleared incursions, computer upgrade required, iris repair required. Share the same predicate between UI prompts and server-side interaction acceptance. Publish a replicated mission snapshot for late joiners containing selected mode, phase, wave counts, gate direction, objective progress and timers.

## Verification and rollout

Migrate one subsystem at a time behind the existing public interfaces. Keep the strict test runner, true corridor-to-corridor routes, stale-callback/race tests and two-peer settings/state checks. Add a short graphical UAT route covering spawn → control room → both Level 27 access routes → every main room → return, then one full extraction run per mode. Do not claim headless visibility or collision checks establish graphical quality or game feel.
