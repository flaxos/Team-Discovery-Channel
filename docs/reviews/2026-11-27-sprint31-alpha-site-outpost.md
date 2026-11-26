# Sprint 31 — Offworld outpost (Alpha Site)

Sprint 31 delivers an offworld Alpha Site pre-fab shelter interior route with three surface and equipment families, reused civilian presence, an observation aperture with a non-traversable alien mountain vista beyond the authored boundary, and an entry/objective/return mission loop. This work adheres to the constraint that full outdoor navigation and terrain is a future capability: all modules maintain 100% enclosure and collision containment with zero leaks. [Sprint 30 review](2026-11-26-sprint30-goauld-vertical-chambers.md) · [Sprint 31 scope](../plans/asset-vertical-slices.md#offworld-locations-and-mothership) · [Alpha Site layout](../../client/resources/levels/ai2_tauri_alpha_site.tres).

## Route and modular structure

The playable route reuses the authored modular layout `res://resources/levels/ai2_tauri_alpha_site.tres` spanning four 8 × 8 m prefabricated modules in an L-shaped compound:

| Module instance | Room type | Placement & rotation | Role & dressing |
|---|---|---|---|
| `hub` | `room01` (8 × 8 m) | Origin `(0, 0, 0)`, rot 0 | Staging entrance and extraction zone; connects south to command and east to storage. |
| `stores_store_small` | `room02` (8 × 8 m) | `(8, 0, 0)`, rot 0 | Field cargo storage depot dressed with rugged transport crates. |
| `cmd_command` | `room03` (8 × 8 m) | `(0, 0, 8)`, rot 0 | Operations centre and tactical records desk; connects south to observation suite. |
| `cmd_observation` | `room04` (8 × 8 m) | `(0, 0, 16)`, rot 0 | Communications & telemetry station with field comms rack, console, civilian analyst, and aperture vista. |

The route guarantees seamless operative traversal across all door seams with zero collision steps or snags.

## Three surface, shelter, and equipment families

### Family 1: Pre-fab shelter / outpost interior surfaces (`tauri_sgc` theme)
The `tauri_sgc` level theme transitions from fallback to authored status (`art_status = "authored"`) with a full set of 7 PBR material definitions in `client/resources/level_themes/tauri_sgc/`:
- `wall.tres`: Rugged insulated prefabricated wall panels (albedo `(0.48, 0.50, 0.49)`, roughness `0.85`).
- `floor.tres`: Heavy-duty industrial diamond-tread steel flooring (albedo `(0.24, 0.25, 0.26)`, metallic `0.70`, roughness `0.45`).
- `ceiling.tres`: Utility acoustic ceiling panels with recessed service fittings (albedo `(0.18, 0.19, 0.20)`, roughness `0.90`).
- `door_frame.tres`: Structural reinforced steel portal jambs and lintels (albedo `(0.15, 0.16, 0.17)`, metallic `0.80`, roughness `0.40`).
- `portal.tres`: Heavy airtight pressure-bulkhead door leaf (albedo `(0.32, 0.34, 0.35)`, metallic `0.60`, roughness `0.50`).
- `detail.tres`: High-visibility industrial caution and trim accents (albedo `(0.85, 0.65, 0.10)`, roughness `0.50`).
- `prop.tres`: Matte tactical field-equipment finish (albedo `(0.28, 0.32, 0.28)`, roughness `0.60`).
- `observation_glass.tres`: Tinted reinforced observation glass (transparency alpha `0.35`, metallic `0.20`, roughness `0.10`, refraction enabled). Assigned to `cmd_observation` south wall aperture via theme variant `v_obs_south`.

### Family 2: Field equipment & storage family
Authored three ruggedized field props inheriting `RoomPlaceholder.tscn` to preserve the native modular composer contract:
- **`AlphaSiteFieldCrate.tscn`** (1.4 × 1.2 × 1.4 m): Military field cargo container with olive-drab steel casing, reinforced corner bracings, stencil markings, and heavy latching hardware. Dressed into `client/resources/room_presets/cargo.tres` across `crate_01`, `crate_02`, and `crate_03`.
- **`AlphaSiteFieldCommsRack.tscn`** (2.0 × 1.5 × 0.3 m): Dual-bay offworld telecommunications relay rack with rackmounted transceivers, diagnostic displays, status LEDs, and cabling harnesses. Dressed into `client/resources/room_presets/observation_communications.tres` at `communications_display`.
- **`AlphaSiteFieldConsole.tscn`** (1.0 × 1.0 × 0.8 m): Ruggedized field operations desk with an angled CRT display, mechanical keyboard deck, auxiliary telemetry dials, and power modules. Dressed into `client/resources/room_presets/observation_communications.tres` at `console`.

### Family 3: Shelter observation aperture & exterior vista
- **`AlphaSiteObservationVista.tscn`**: Heavy reinforced industrial observation window frame with dual steel mullions framing an open viewport pane. Beyond the frame (outside the room's authored boundary), an alien mountain terrain vista unfolds featuring:
  - Rugged canyon valley terrain floor (`CanyonGroundMesh`).
  - Three jagged rocky mountain peaks (`MountainPeakLeft`, `MountainPeakCenter`, `MountainPeakRight`).
  - Five alien alpine conifer trees (`PineTree1` through `PineTree5`) placed along the ridgeline.
  - A distant twilight sky backdrop (`SkyBackdrop`).
- **Enclosure and boundary containment**: Full physical containment is maintained. The south wall closure retains its static collision barrier (`cap.collision_layer = 1`) and uses `observation_glass.tres` for visibility, passing `LevelEnclosureValidator` with zero leaks.

## Civilian presence

The observation and communications center features a stationed civilian technician (`client/scenes/characters/SGCCivilian.tscn`) at slot `staff_station` in `cmd_observation`. The civilian is stationed at the telemetry monitors, lending vital narrative context to the offworld research post.

## Playable entry / objective / return loop

The mission is fully playable through `client/resources/missions/tauri_alpha_site.tres` and `client/scenes/mission/TauriAlphaSiteMission.tscn`:
1. **Entry & Approach (`reach_command`)**: Squad deploys at the Alpha Site entrance staging area in `hub` and infiltrates inward past the storage wing to reach `cmd_command`.
2. **Data Extraction (`download_records`)**: Squad secures `cmd_observation`, interfaces with the field console, and downloads outpost telemetry and operational logs.
3. **Outpost Extraction (`extract`)**: Squad falls back through the secured corridors to the `hub` extraction zone.

Registered under `NetworkManager.MISSION_TAURI_ALPHA_SITE = "tauri_alpha_site"`.

## Technical verification

- **Python Unit Tests**: All 60 tests in `tools/tests/` passed cleanly in 25.6s.
- **Dedicated Outpost Suite**: `test_alpha_site_outpost.gd` passed in 4s, verifying:
  - Layout resolution with `tauri_sgc` theme.
  - Full room enclosure and 0 disconnected open portals via `LevelEnclosureValidator`.
  - Proper attachment and bounding of all 3 prop families.
  - Observation aperture and background vista geometry beyond room boundaries.
  - Stationed SGC civilian presence.
  - Complete live mission loop (entry -> advance -> download -> extract -> victory).
- **Theme Suite**: `test_level_themes.gd` passed, verifying authored visual sources and fallback precedence.
- **Full Godot Suite**: Executed via strict runner `tools/run_godot_tests.py --profile full`.

## Captures (Forward+ on NVIDIA RTX 3060)

Captures generated at 1280 × 720 in Forward+:
1. [Outpost Hub / Entrance](../../build/sprint31/captures/01_outpost_hub.png) — Corridors, diamond plate floor, bulkhead frames, and caution trim.
2. [Stores & Cargo Wing](../../build/sprint31/captures/02_stores_cargo.png) — Field cargo crates deployed in the supply depot.
3. [Command Operations](../../build/sprint31/captures/03_command_center.png) — Tactical command desk and outpost records terminal.
4. [Observation & Comms Suite](../../build/sprint31/captures/04_observation_room.png) — Field console, comms rack, and stationed civilian analyst.
5. [Observation Aperture & Exterior Vista](../../build/sprint31/captures/05_aperture_vista.png) — Window frame with transparent glass looking out over the mountain terrain and alien pine forest.
