# Sprint 34 — Mothership exterior silhouette and vista dressing

Sprint 34 delivers **one hero exterior silhouette** for the Goa'uld Ha'tak mothership (`MothershipExteriorSilhouette.tscn`) and the vista dressing that exposes it from playable interiors: the forward observation viewport on the command bridge (`MothershipViewportFrame.tscn`) and the space threshold of the hangar bay (`MothershipHangarVista.tscn`). The exterior hull is strictly non-interactive background scenery: no landing, flight, space combat, destructible shell, or fully explorable ship is implied. [Sprint 33 review](2026-11-27-sprint33-mothership-objective.md) · [Sprint 34 scope](../plans/asset-vertical-slices.md#offworld-locations-and-mothership) · [Exterior silhouette scene](../../client/scenes/props/MothershipExteriorSilhouette.tscn).

## Physical and view scale specification

As established in the Sprint 32 scale analysis:
- **Canon / Lore Scale**: A standard Goa'uld Ha'tak vessel measures ~700 m in length, ~650 m in width, and ~250 m in height, composed of a central pyramid core encased in a sprawling trilateral superstructure with glider bays.
- **Scenery View Scale**: Modeling a 700 m walkable exterior in gameplay creates unnecessary collision overhead, immense draw distance requirements, and navigational confusion. Instead, the hero exterior model is authored at normalized hero proportions (~70 m wide × 75 m long × 28 m high) designed for multi-tier vista scaling:
  - **Bridge Observation Vista**: Scaled to 1.2% (`scale = Vector3(0.012, 0.012, 0.012)`) and integrated directly into `MothershipViewportFrame.tscn` behind the reinforced tinted quartz glass, framing an escort Ha'tak cruising in formation against the cosmic nebula.
  - **Hangar Space Threshold**: Scaled at 35% (`scale = Vector3(0.35, 0.35, 0.35)`) and 15% (`scale = Vector3(0.15, 0.15, 0.15)`) in `MothershipHangarVista.tscn` beyond the force field containment barrier, representing a multi-ship fleet patrol.
- **Material Sharing**: Reuses 100% of existing Goa'uld theme materials (`resources/level_themes/goauld/basalt.tres`, `bronze.tres`, `gold.tres`) alongside lightweight unshaded emissive shaders for engine thrusters and the apex capstone, requiring **zero additional texture memory**.

## Hero exterior silhouette construction (`MothershipExteriorSilhouette.tscn`)

The hero exterior model comprises four primary structural assemblies:
1. **Pyramid Core**:
   - `Plinth`: Heavy bronze foundation slab (32 × 3.5 × 32 m).
   - `BasaltTerrace`: Stepped basalt pyramid base (`bottom_radius = 21 m`, `top_radius = 6 m`, `height = 13 m`, 4 radial segments rotated 45°).
   - `GoldApex`: Gleaming metallic gold pyramid superstructure (`bottom_radius = 18 m`, `top_radius = 0 m`, `height = 18 m`).
   - `Capstone`: Emissive amber-gold glowing apex capstone (`Color(1.0, 0.9, 0.45)`).
   - `ApexSpire`: Gold tactical sensor spire (4.8 m height).
2. **Outer Superstructure (Trilateral Outriggers)**:
   - Three monumental outriggers (`ArmForward`, `ArmPort`, `ArmStarboard`) set at 120° trilateral symmetry.
   - Each arm incorporates a central bronze girder (`size = 5.5 × 4.5 × 27 m`), wide wing flanges (`11 × 1.6 × 18 m`), gold dorsal crest trim, and basalt ventral armor plating.
   - Heavy staff cannon turret blisters (`radius = 3.2 m`) with dual gold plasma cannon barrels (`length = 5.2 m`) mounted on the outer vertices.
   - Connecting bronze collars and gold trim wrapping around the pyramid waist to form the iconic triangular outer silhouette.
3. **Glider Launch Bays**:
   - Three recessed launch slit apertures along the collar flanks with deep void backing and cyan glowing runway strips (`Color(0.2, 0.6, 0.85)`).
4. **Sub-light Engine Thrusters**:
   - Rear stern propulsion bank with three heavy basalt engine housings and glowing amber propulsion thrusters (`Color(1.0, 0.65, 0.18)`).

## Pure scenery boundary verification

The exterior silhouette is strictly scenery:
- **Zero Collision**: Verified by automated test `test_mothership_exterior.gd` to contain exactly 0 `CollisionObject3D` or `CollisionShape3D` nodes.
- **Zero Simulation**: No flight mechanics, autopilot scripts, health, damage, or AI pilot components exist on the model.
- **Boundary Preservation**: The playable bridge interior retains its solid layer 1 occlusion body on `MothershipViewportFrame.tscn`, preserving camera occlusion fade and preventing player raycasts from escaping into the space void.

## Vista dressing

### 1. Command Bridge Observation Viewport (`MothershipViewportFrame.tscn`)
- The bridge observation frame's `SpaceVista` node now incorporates `EscortMothership` (`MothershipExteriorSilhouette.tscn`).
- Standing at the central bridge helm console (`MothershipBridgeConsole`), operatives look through the golden mullions and tinted quartz glass to see the sister Ha'tak mothership cruising in formation against the glowing violet nebula and starry backdrop.

### 2. Hangar Bay Space Threshold (`MothershipHangarVista.tscn`)
- Self-contained space vista attachment for the hangar bay aperture (`room16`).
- Features a shimmering blue force field containment barrier (`Color(0.15, 0.55, 0.85, 0.22)` with emission), heavy bronze emitter framing posts, deep space backdrop, cosmic nebula, and a fleet formation of three Ha'tak motherships (lead ship and two flanking escorts).

## Technical verification

- **Mothership Exterior Suite (`test_mothership_exterior.gd`)**: Passed 100% in headless Godot:
  - Validates `MothershipExteriorSilhouette.tscn` instantiation, node hierarchy, and dimensions.
  - Confirms 0 `CollisionObject3D` and 0 `CollisionShape3D` nodes (pure scenery).
  - Verifies shared Goa'uld theme materials (`basalt.tres`, `bronze.tres`, `gold.tres`).
  - Measures total triangle count: **1,084 triangles** (well under the 10,000 budget for background scenery).
  - Validates viewport vista integration and camera occlusion layer 1 boundary.
  - Validates hangar vista integration and fleet formation nodes.
- **Mothership Objective Suite (`test_mothership_objective.gd`)**: Passed 100% (zero regressions on Sprint 33 objective route).
- **Modular Presets Suite (`test_modular_presets.gd`)**: Passed 100% across all 16 presets.
- **Python Unit Tests (`tools/tests`)**: 60 unit tests passed 100% in 25.8s.

## Captures (Forward+ on NVIDIA RTX 3060)

Captures rendered at 1280 × 720 in Forward+ on NVIDIA GeForce RTX 3060:
1. [Mothership Hero Silhouette Full](../../build/sprint34/captures/01_mothership_hero_silhouette_full.png) — Full exterior view of the Ha'tak mothership in deep space, showing the central gold pyramid, glowing capstone, bronze outriggers, turret hardpoints, and amber sublight engine thrusters.
2. [Mothership Silhouette Near](../../build/sprint34/captures/02_mothership_silhouette_near.png) — Close-up view of the metallic gold pyramid core, apex capstone glow, basalt terrace, and staff cannon turret blister.
3. [Bridge Viewport Fleet Vista](../../build/sprint34/captures/03_bridge_viewport_fleet_vista.png) — Forward observation viewport on the bridge framing an escort Ha'tak silhouette cruising in formation against the purple nebula and stars.
4. [Hangar Bay Space Threshold](../../build/sprint34/captures/04_hangar_bay_space_threshold.png) — View from the hangar bay looking past the force field containment barrier at the Ha'tak fleet formation in deep space.
