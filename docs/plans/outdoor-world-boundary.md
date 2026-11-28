# Outdoor Authoring Boundary (`OW-0`, Decision `D-006`)

## Goal

Define and prove the boundary between an outdoor terrain area and a modular interior `LevelLayout` so exterior gate sites, courtyards, and approaches can join interior buildings cleanly without weakening modular enclosure or socket guarantees.

## Decision (`D-006`)

- **Modular interiors stay strictly enclosed.** `LevelLayout`, `LevelLayoutValidator`, `LevelEnclosureValidator`, and `tools/level_authoring.py` remain interior-only. No terrain heightfields, outdoor foliage, or open-sky relaxations are added to `LevelLayout` schemas.
- **Exterior worlds are authored separately.** Terrain, cliffs, cover rocks, foliage, sky lighting, and offworld Stargate/DHD pads live in a sibling `OutdoorBoundary` subtree outside `LevelAssembly`.
- **The join happens strictly at declared exterior doorways.**

## Executable Doorway & Navigation Contract

1. **Interior validation first (no weakened enclosure):**
   - `LevelAssembly.validate_and_bake()` validates `LevelLayout`, builds all interior modules with unconnected portals closed, populates room presets, and runs `LevelEnclosureValidator.validate(self)` on the fully sealed interior.
   - Any unintended wall/roof/floor gap or mismatched socket fails identically to an interior-only map.

2. **Explicit exterior portal opening:**
   - Before `LevelAssembly` bakes, its sibling `OutdoorBoundary` registers one or more unconnected interior sockets (`"<instance_id>/<socket_id>"`) via `LevelAssembly.register_exterior_portal()`.
   - Only after `LevelEnclosureValidator.validate(self)` passes does `LevelAssembly` open those declared portal closures and optionally mount a standard `ModularDoor` (`ExteriorDoor_<instance>_<socket>`) at the exact socket transform.
   - Connected interior sockets, unknown instances, unknown sockets, or duplicate declarations are rejected as setup errors.

3. **Shared `NavigationServer3D` map across separate `NavigationRegion3D` bakes:**
   - `LevelAssembly` bakes its interior `NavigationMesh` using `LevelNavigation.profile()` (`agent_radius = 0.6`, `agent_height = 1.9`, `agent_max_climb = 0.2`, `agent_max_slope = 42`, `cell_size = 0.15`, `cell_height = 0.1`) and validates interior region reachability with `LevelNavigation.validate_regions(self)`.
   - `OutdoorBoundary` waits for `LevelAssembly.navigation_ready`, bakes its own `ExteriorNavigation` `NavigationRegion3D` strictly from its own static colliders (layer `1`) using the **identical** `LevelNavigation.profile()`, and attaches that region to `level.navigation_map`.
   - Because each independent bake respects `agent_radius = 0.6` along its side of the threshold plane, `OutdoorBoundary` bridges the interior socket approach point and the exterior threshold landing point with a bidirectional `NavigationLink3D` (`OutdoorDoorwayLink`) on `level.navigation_map`.
   - Any `LevelNavigator` path crossing that link naturally intersects the exterior `ModularDoor`, opens it within `DOOR_REACH`, and steers operatives, Airmen, and Jaffa across the threshold in both directions.

4. **Boundary verification (`OutdoorBoundary.validate_boundary()`):**
   - Every exterior marker under `Exterior/Markers` must snap onto `level.navigation_map` within `0.5 m` and lie outside all interior module `occupied` boxes.
   - Round-trip pathfinding on `level.navigation_map` must succeed from the outdoor arrival marker (`gate_arrival`) to the interior entry and destination markers, and back to `gate_arrival` within `0.6 m`.

5. **Mission & world integration:**
   - `MissionDefinition.exterior_markers` explicitly lists named exterior markers addressable via `room = &"exterior"` (objectives) or `"exterior:<marker>"` (patrol routes). Interior-only missions leave `exterior_markers` empty, so referencing `&"exterior"` on an interior-only mission fails validation.
   - Offworld `Stargate` and `DHD` instances under `Exterior` are discovered automatically by `GateRoom` and `MissionSession`, so exterior gate sites support both standalone missions and SGC-to-offworld gate travel.
   - All lookups remain scoped via `MissionWorld` so an outdoor gate site can coexist beside the SGC world at a 2 km offset (`D-002`, `GT-1`).

## Proof & Regression Coverage

- Unit contract suite: `client/tests/test_ow0_outdoor_boundary.gd`
- Playable `OW-1` exterior gate site suites:
  - `client/tests/test_ow1_exterior_gate_site.gd`
  - `client/tests/test_ow1_exterior_gate_site_multiplayer.gd`
  - `client/tests/test_ow1_exterior_gate_site_dedicated.gd`
