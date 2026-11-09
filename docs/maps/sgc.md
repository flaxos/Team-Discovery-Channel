# Three-level SGC map

See [playing/local UAT](../PLAYING.md) for lobby and multiplayer instructions, [architecture](../ARCHITECTURE.md) for ownership, and [testing](../TESTING.md) for acceptance commands.

The playable mode contains Sublevels 28 (gate/operations/combat loop), 27 (briefing/command/security), and 26 (support, staging, storage and service rooms). Existing mission objectives and wave counts remain unchanged. Level 25 is excluded.

## Reference basis and deliberate extensions

- [RDA's SGC floor-plan and level references](https://rdanderson.com/stargate/cheyenne/index.htm), including the [floor-plan image](https://rdanderson.com/stargate/cheyenne/images/cheyenne.jpg), establish the reference core.
- [The July 2002 set tour](https://rdanderson.com/stargate/features/articles/2002-07-setday1.htm) describes the control room below the briefing room and stair access, including a corner spiral extending beyond the briefing level on the set.
- The revised core uses a 24 m wide, 12 m high embarkation chamber and a 6.7 m gate. Operations is raised 1.5 m above embarkation; briefing is at 5.5 m. These are playable proportions, not measured production dimensions. A solid sill and sealed glazing separate embarkation from operations; corridor stairs provide access from the side/rear.
- Preserve the gate → operations → briefing sightline, adjoining commander's office, and control/briefing corner stair. The playable spiral has been aligned with its actual landings and opening. Coordinates and circulation widths are gameplay adaptations, not claims of measured production-blueprint accuracy.
- The west return loop, peripheral combat corridors, security room, service stairs and Level 26 support layout are authored extensions. Level 26's exact room placement is not established by these references. Resource `confidence` and `reference` fields distinguish the core relationships from these extensions.

## Launch and mission selection

Use the lobby's **LEVEL / MISSION** selector before dispatch: **SGC Defense — Levels 28/27/26** enables incursions; **SGC UAT Base — No Hostile Activation** loads `SGCUATBase.tscn`, which inherits the same GateRoom map. UAT retains traversal, props and friendly personnel, but guards the staging scramble and wave start/update paths, so an incoming hostile connection cannot begin automatically. Difficulty is disabled for UAT. Mission IDs are carried in start/retry RPCs and sent to joining clients; clients cannot change the host selection. CLI: `--mission sgc_defense` or `--mission sgc_uat`.

`test_mission_selection_uat` launches through the actual lobby/coordinator, checks the inherited scene and Level 26, runs 30 simulated seconds without enemies or gate activation, verifies retry and checks Defense still activates. The settings synchronization suite covers client selection authority and stale start/retry caches.

## Interaction and objective UI

Buffer lockout and ROM-upload status use the objective HUD without opening the dialing panel. The panel is reserved for an approved dialing session and closes when that session is cancelled; global lockout/progress updates cannot leave an orphan overlay on screen. `test_buffer_lockout_hud` covers denied dialing, upload/cancel/snapshot notifications and normal dialing dismissal.

The control and briefing windows have independent shutter consoles. Inside the lift, use aimed buttons or the floor picker; keep UI state separate from authoritative movement. The [player guide](../PLAYING.md#floors-stairs-and-shutters) covers the interaction route.

## Authoring contract

`client/resources/maps/sgc.tres` is the editable map resource. `SGCMapDefinition.create_default()` supplies the factory layout; runtime loads a private copy of the authored resource. Regions define footprint, floor, local floor offset, ceiling height, anchor, style and lighting. Connections define stable endpoints, walk/stair/spiral/lift action, clearance, optional door and availability. Main floors are 0, 5.5 and 11 m; operations has a 1.5 m offset; player clearance derives from the existing 0.4 m radius / 1.8 m capsule.

`SGCMap` builds reusable wall segments around portals, split floors around stair holes, continuous stair collision, exposed-edge guards, recessed cover, fixtures and service dressing. Retained scene props still own objectives, consoles, weapons, observation glass and blast shutters. Lift floors are flush with landings; the cabin floor uses its moving physics body. Landing gates close over absent cabins. Aim at an individual cabin button and press **E** to select it. Press **E** elsewhere inside the cabin to open the three-floor picker. Calls during transit queue. Travel takes three seconds per floor at constant speed; rider detection includes character layers and platform exit adds no launch velocity. The live player controller is tested throughout the Level 26→28 descent.

After changing layout, collision or navigation dimensions, rebuild the checked-in navigation resource:

```sh
godot --headless --path client --script res://scripts/map/bake_sgc_map.gd -- --bake-sgc
```

This preserves authored layout/art data and refreshes generated slots and navigation. Add `--reset-layout` only to regenerate the factory layout. The fallback runtime bake supports missing artifacts, but normal play uses the prebuilt mesh. Each scene owns a separate navigation map, including host/client test fixtures.

## Indoor enclosure rule

An indoor map must not expose unmodelled space through corridor joins, floors, ceilings or connecting shafts. Walking portals must sit on a shared room boundary at the same elevation, with sufficient shared clearance; their built openings are clipped to the receiving room. Moving a corridor away from its neighbour fails schema validation even when the route graph remains connected.

`SGCEnclosureValidator` probes the built shell around the union of rooms, enclosed stair transitions and the lift shaft. It samples exterior wall faces at 0.25 m spacing and horizontal faces at 0.5 m spacing, including the space between floors. Every sampled exterior boundary must have physical closure; internal portals and stair holes remain open into other enclosed volumes. Errors name the region/connection, face, world position and direction. This is a deterministic structural check at the documented sampling resolution; it is not a test of transparent materials or replacement artwork.

The navigation bake refuses to save a map with enclosure errors, and `test_sgc_enclosure` runs in the full CI suite. Negative cases create a corridor-placement gap, a portal-edge crack, a missing floor, a missing ceiling and missing stair casing, and require validation to fail. Closure is also checked with the lift at a different floor. Generated shaft panels have the same art-replacement metadata as other map modules.

## Art briefs and replacement

Every generated module has a stable `SGCAssetSlot` in the map resource and `asset_slot` metadata on its body: dimensions, description, style, visual scene, texture and replacement status. Styles supply palette, roughness, metallic response, material channels, texture scale, wear and references.

| Family | Appearance brief |
| --- | --- |
| Ceilings | Grey reinforced concrete panels, dark seams, steel beams and silo service fittings; continuous overhead coverage with deliberate stair openings. |
| Bunker walls | Muted cast concrete, visible panel seams, dark painted steel surrounds, restrained grime at joints, exposed service conduits. |
| Corridor floors | Worn non-slip grey surface, readable seams, restrained hazard markings near equipment and thresholds. |
| Briefing | Dark charcoal carpet, subdued fluorescent fixtures, concrete walls, wood table, brushed metal fittings. |
| Command office | Dark office carpet, warm wood furniture, restrained grey surrounds and practical communications equipment. |
| Stairs and guards | Charcoal painted steel, visible treads and handrails, scuffed edges. Continuous protective collision stays independent of visual balusters. |
| Support props | Supply racks, utility cabinets and staging benches; utilitarian painted metal, clear silhouettes, no obstruction of portals or anchors. |

Textures can be assigned per slot. `replace_asset_visual(slot_id, packed_scene)` validates visual bounds against the slot envelope, disables replacement collision, and keeps the original gameplay shape. Oversized replacements fail without replacing the placeholder. Generated art should use the supplied dimensions and material channels. AI artwork generation is deferred; these are functional placeholders and briefs.

Ceilings have independent collision on physics layer 8 (128), included in character and weapon masks and excluded from navigation baking to prevent walkable roof islands. Both observation windows have separate blast shutters and consoles; the control shutter retracts into its sill and the briefing shutter retracts above its frame. Their closed positions are inset from the glass to avoid coplanar surfaces.

Lighting uses region fixture profiles and restrained ambient fill. The global directional light has been removed. Level 26 includes alarm fixtures in the existing alert system. Normal/emergency captures are generated by the visual review helper below.

## Navigation and combat progression

Both factions use `SGCNavigator`: weighted region routes, local navigation-mesh paths, physical stair following, passage reservations and explicit lift approach/call/board/ride/exit actions. Navigation never teleports actors or supplies artificial upward velocity. Doors open through the server-owned controller before crossing. Unavailable edges replan; invalid destinations hold position with a reported status. Blocked routes retry after a delay.

Jaffa retain gate formation behavior, then advance into the eastern or western corridor according to their formation lane. Without a nearby target they continue through the round hallway, briefing and support floor. Combat keeps existing line-of-sight and target rules. Three hostiles beyond the gate-room threshold trigger a briefing fallback; six trigger Level 26 staging. Airmen receive normal movement orders and can return fire while holding. Wave budgets and mission objectives are unchanged. Passage reservations and lift access serialize constrained movements; bounded stalls can choose alternative routes.

AI movement/combat remains server-authoritative and existing NPC state/transform synchronization carries its results. Dedicated servers wait for the client's mission-ready handshake before starting a replacement mission.

## Verification

```sh
python3 tools/run_godot_tests.py --profile full --timeout 240
DISPLAY=:0 godot --path client --script res://tests/support/sgc_visual_review.gd
```

The runner allows 180 seconds per suite by default because the full three-capsule route matrix takes about 100 seconds on the development machine. Explicit timeout overrides remain supported.

- `test_sgc_enclosure`: room/shaft closure, deliberate portal/placement gaps and missing surfaces, plus lift-independent closure.
- `test_buffer_lockout_hud`: denied dialing and upload/cancel/snapshot messages leave no orphan panel; approved dialing still opens and dismisses its session UI.
- `test_sgc_map_routes`: every walking and stair connection, both directions, with continuously moving production player, airman and Jaffa capsules. Initial placements are test setup, not movement shortcuts.
- `test_sgc_uat_architecture`: roof collision coverage, sealed raised operations, shutter alignment, aimed floor-button selection and continuous live-controller lift grounding in both directions.
- `test_sgc_lift_routes`: startup entry, physical rider carrying, three-floor arrivals, diagonal exits, queued calls and rejected Level 25 requests.
- `test_sgc_ai_wayfinding`: production friendly orders through both lift journeys and a seeded hostile overrun through both exits to Level 26.
- `test_sgc_map_contract`: source provenance, alternate routes, art metadata and replacement bounds, stable collision and unreachable destinations.
- Boundary, multiplayer lift/state, late join/retry, observation glass, objectives, gunplay and input regressions remain covered. The four old stair/lift tests based on CSG names or exact tread counts have been consolidated into the behavioral route/lift suites.

The visual helper writes actual Forward+ GPU captures to `build/sgc-review/`. It covers embarkation looking up at the stacked observation rooms, control looking at the gate, both shutters closed, briefing, spiral, east corridor, west/connector joins, service stairs, support, briefing alert lighting and an active incoming gate. Screenshots and headless tests do not establish subjective combat balance or replace a human multiplayer playtest.
