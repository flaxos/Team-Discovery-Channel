# Sprint 32 — Mothership boarding and ring breach

Sprint 32 delivers a Ha’tak mothership boarding and ring-breach route from supported modular components, three hull/interior-door/cargo prop families reusing Goa’uld trims, an interior vs exterior scale analysis for mothership spaces, R16 reciprocal transport rings breach between decks, and a full entry/objective/return mission loop. The mothership serves as the chosen offworld destination coexisting with the SGC as the two live game worlds, utilizing safe gate travel for mission insertion without flight or docking simulation. [Sprint 31 review](2026-11-27-sprint31-alpha-site-outpost.md) · [Sprint 32 scope](../plans/asset-vertical-slices.md#offworld-locations-and-mothership) · [Mothership layout](../../client/resources/levels/ai2_goauld_mothership_boarding.tres).

## Route and modular structure

The playable boarding route reuses the authored modular layout `res://resources/levels/ai2_goauld_mothership_boarding.tres` spanning 9 modules across two decks with full Goa’uld themer pieces:

| Module instance | Room module | Deck & elevation | Grid position | Role & dressing |
|---|---|---|---|---|
| `gate` | `room16` (Hangar Shell) | `deck0` (`0.0 m`) | `(0, 0)` | Safe mission insertion Stargate and DHD platform. |
| `vestibule` | `room01` (Straight) | `deck0` (`0.0 m`) | `(0, 32)` | Airway vestibule connecting hangar to main lower deck. |
| `cargo_bay` | `room04` (Chamber) | `deck0` (`0.0 m`) | `(0, 40)` | Lower cargo bay dressed with heavy naquadah transport crates and ship log terminal. |
| `stores_hall` | `room01` (Straight) | `deck0` (`0.0 m`) | `(8, 40)` | East transit corridor leading to lower transport ring platform. |
| `ring_lower` | `room15` (Chamber) | `deck0` (`0.0 m`) | `(16, 40)` | Lower ring transport platform housing `rings_boarding` endpoint. |
| `ramp` | `room14` (Ramp 4m) | `deck0` (`0.0 m`) -> `upper` (`4.0 m`) | `(-8, 40)` | Physical structural ramp connecting Deck 0 to Deck 1 upper deck. |
| `upper_hall` | `room01` (Straight) | `upper` (`4.0 m`) | `(-24, 40)` | Upper deck corridor leading to the interior checkpoint. |
| `interior_checkpoint` | `room04` (Chamber) | `upper` (`4.0 m`) | `(-32, 40)` | Heavily fortified checkpoint with boarding bulkhead, barricades, and logistics terminal. |
| `ring_upper` | `room15` (Chamber) | `upper` (`4.0 m`) | `(-32, 32)` | Upper ring chamber housing `rings_upper` reciprocal transport endpoint. |

The route is 100% enclosed, contiguous in the navigation graph across both decks, and fully sealed against vacuum leaks.

## Three hull, interior-door, and cargo families

### Family 1: Boarding bulkhead frame (`MothershipBoardingBulkhead.tscn`)
- **Dimensions**: 1.6 × 2.0 × 0.6 m.
- **Visuals**: Dark basalt jambs with warm bronze casing, dual overhead mechanical clamping brackets, engraved gold Goa'uld cartouche header, and a cyan status/pressure indicator plate.
- **Physics**: StaticBody3D collision on layer 1, matching `placeholder_size = Vector3(1.6, 2.0, 0.6)`. Placed at `door_control` in `mothership_checkpoint.tres`.

### Family 2: Shipboard interior sliding pressure door (`MothershipInteriorDoor.tscn`)
- **Dimensions**: 2.6 × 2.8 × 0.3 m.
- **Visuals**: Heavy basalt portal posts with embedded bronze tracks, two motorized sliding door panels clad in dark burnished bronze, gold hieroglyph relief plates, and interlocking center seal teeth.
- **Physics**: StaticBody3D collision on layer 1. Reusable as modular doorway portal fixture for shipboard compartment isolation.

### Family 3: Heavy ordnance cargo transport crates (`MothershipCargoCrate.tscn`)
- **Dimensions**: 1.4 × 1.2 × 1.4 m.
- **Visuals**: Chamfered basalt base block, bronze reinforced corner brackets with heavy rivet banding, twin gold top-latching fasteners, and an inset amber glowing core representing stored naquadah power cells.
- **Physics**: StaticBody3D collision on layer 1, matching `placeholder_size = Vector3(1.4, 1.2, 1.4)`. Dressed into `mothership_cargo.tres` (`crate_01`, `crate_02`, `crate_03`) and `mothership_checkpoint.tres` (`cover_left`, `cover_right`).

## Interior scale vs exterior scale analysis

A key requirement of Sprint 32 is documenting how playable interior scale relates to exterior scale without forcing film dimensions into modules:

1. **Film / Lore Exterior Dimensions**:
   - In Stargate canon, a standard Goa'uld Ha'tak vessel measures approximately 700 meters in length, 650 meters in width, and 250 meters in height, comprising a central pyramid structure surrounded by a sprawling golden superstructure with glider bays.
   - The total internal volume exceeds several million cubic meters across dozens of decks.
2. **Modular Level Interior Scale**:
   - Team-Discovery-Channel's modular level architecture operates on an 8 × 8 meter room module grid with 4-meter vertical deck elevations and 2.8 to 3.4-meter ceiling clearances.
   - Sockets and doorways are standardized at 3.0 m width by 2.8 m height to support standard player character movement and camera clearances.
3. **Scale Reconciliations**:
   - **Tactical Slice vs Whole-Ship Modeling**: In an action shooter, modeling a full 700 m ship creates immense empty spaces, disorienting navigation, and excessive draw calls. Instead, the level represents a targeted tactical boarding breach into a specific operational sector of the ship (Hangar Bay 4, Lower Cargo Transit, and Security Sub-Deck 1).
   - **Ceiling & Corridor Proportions**: Interior corridors are 4 m wide and 3.4 m high. This provides sufficient room for tactical fireteams, Jaffa sentry lines-of-sight, and weapon handling without feeling cramped, while maintaining the imposing monumental aesthetic of Goa'uld palace-ship architecture.
   - **Vertical Deck Transitions**: The 4 m vertical deck step corresponds cleanly to single-story ship decks. Ramps provide continuous physical route access, while Goa'uld Transport Rings (`TransportRings`) provide canonical instant vertical transit between non-adjacent decks.
   - **Conclusion**: The modular architecture preserves the monumental feel and authentic textures of a Ha'tak interior without burdening the game engine or player navigation with empty exterior volume.

## R16 reciprocal transport rings breach

- **Layout Endpoints**:
  - `ring_lower` on Deck 0 binds `rings_boarding` (`target_id = &"rings_upper"`).
  - `ring_upper` on Deck 1 binds `rings_upper` (`target_id = &"rings_boarding"`).
- **Validation & Binding**:
  - `LevelLayoutValidator.validate_transports(layout, true)` verifies exact reciprocal pairing, kind consistency (`"rings"`), anchor resolution (`"transport"`), and clearance bounds.
  - `LevelTransportBindings.bind_rings(layout, assembly)` resolves nodes at runtime, linking `rings_boarding.paired_rings = rings_upper` and configuring reciprocal beam coordinates.
- **Tactical Functionality**: Operatives can breach the heavily defended upper deck by ring transport, bypassing the guarded physical ramp.

## Two live worlds coexistence

- In this mission, the Ha'tak mothership is the chosen offworld site (`GoauldMothershipBoardingMission.tscn`).
- It coexists directly with the SGC UAT base (`SGCUATBase.tscn`) as the two live game worlds.
- Mission insertion uses the proven Stargate wormhole travel pipeline: operatives gear up in SGC Sublevel 28, dial the gate, step through the event horizon, and materialize inside the mothership's hangar bay. No space flight or docking simulation is introduced.

## Playable mission loop

The mission is defined in `client/resources/missions/goauld_mothership_boarding.tres` and `client/scenes/mission/GoauldMothershipBoardingMission.tscn`:
1. **Boarding Insertion (`reach_cargo`)**: Away team deploys through the Stargate in `gate` and moves through `vestibule` into `cargo_bay`.
2. **Ring Platform Infiltration (`reach_rings`)**: Team pushes east into `stores_hall` to secure `ring_lower`.
3. **Upper Deck Breach (`reach_checkpoint`)**: Operatives ring-transport (or take the ramp) to breach Deck 1 and secure `interior_checkpoint`.
4. **Data Acquisition (`download_manifest`)**: Interfacing with the shipboard terminal downloads the mothership's ordnance manifest and navigational telemetry.
5. **Extraction (`extract`)**: All standing operatives fall back through the ship corridors to the Stargate in `gate` for wormhole extraction.

Registered under `NetworkManager.MISSION_TRAVEL_MOTHERSHIP = "travel_mothership"` with `"hidden": true` to protect public lobbies while supporting CLI-driven launch.

## Technical verification

- **Mothership Boarding Suite (`test_mothership_boarding.gd`)**: Passed 100% in headless Godot:
  - Layout validation with `goauld` theme and 9 modules.
  - Transport ring reciprocal validation and runtime pairing.
  - Enclosure validation with 0 open portal leaks.
  - Verification of all 3 prop families and collision layers.
  - Deck 0 to Deck 1 physical path reachability via ramp.
  - Full 5-stage mission objective loop execution.
  - NetworkManager registration and site binding.
- **Modular Presets Suite (`test_modular_presets.gd`)**: Passed 100% across all 16 presets including `mothership_cargo` and `mothership_checkpoint`.
- **Gate Travel Suite (`test_gate_travel.gd`)**: Passed 100% with zero regressions in two-world gate transitions.

## Captures (Forward+ on NVIDIA RTX 3060)

Captures rendered at 1280 × 720 in Forward+ on NVIDIA GeForce RTX 3060:
1. [Boarding Gate & Hangar](../../build/sprint32/captures/01_boarding_gate.png) — Insertion Stargate, DHD, and basalt/bronze hangar walls.
2. [Transition Vestibule](../../build/sprint32/captures/02_bulkhead_vestibule.png) — Vaulted corridor with gold decorative trim connecting the hangar to the cargo deck.
3. [Cargo Bay](../../build/sprint32/captures/03_cargo_bay.png) — Heavy naquadah ordnance crates, logistics terminal with glowing display, and corridor portals.
4. [Ramp & Ring Access](../../build/sprint32/captures/04_ramp_and_rings.png) — Corridor view towards the physical ramp ascent and lower ring transport chamber.
5. [Upper Interior Checkpoint](../../build/sprint32/captures/05_upper_checkpoint.png) — Deck 1 security checkpoint with boarding bulkhead frame, crate cover positions, and logistics console.
