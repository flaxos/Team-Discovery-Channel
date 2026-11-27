# Sprint 33 — Mothership bridge, engineering objective, and return route

Sprint 33 expands the Ha'tak mothership playable theater into high-value tactical ship compartments: a multi-deck objective-and-return route spanning 12 supported modular rooms, three new Goa'uld prop families (Command Bridge Navigation Helm, Hyperdrive Reactor Core with reactive status visuals, and Forward Deep-Space Observation Viewport Frame), integration with the canonical `MissionEvents` trigger pipeline to release security blast doors upon hyperdrive sabotage, shipboard alarm escape lighting, and evacuation return to the Stargate for debrief. Boundary preservation and camera occlusion fade are strictly maintained at the viewport without open geometry leaks or gameplay simulation sprawl. [Sprint 32 review](2026-11-27-sprint32-mothership-boarding.md) · [Sprint 33 scope](../plans/asset-vertical-slices.md#offworld-locations-and-mothership) · [Objective layout](../../client/resources/levels/ai2_goauld_mothership_objective.tres).

## Route and modular structure

The objective route is authored in `res://resources/levels/ai2_goauld_mothership_objective.tres`, expanding the Sprint 32 boarding route to 12 contiguous modules across two deck elevations (`deck0` at `0.0 m` and `upper` at `4.0 m`):

| Module instance | Room module | Deck & elevation | Grid position | Role & dressing |
|---|---|---|---|---|
| `gate` | `room16` (Hangar Shell) | `deck0` (`0.0 m`) | `(0, 0)` | Insertion & extraction Stargate platform with DHD. |
| `vestibule` | `room01` (Straight) | `deck0` (`0.0 m`) | `(0, 32)` | Vaulted corridor connecting hangar to lower cargo bay. |
| `cargo_bay` | `room04` (Chamber) | `deck0` (`0.0 m`) | `(0, 40)` | Lower transit bay with heavy naquadah cargo crates. |
| `stores_hall` | `room01` (Straight) | `deck0` (`0.0 m`) | `(8, 40)` | East transit corridor to lower ring platform. |
| `ring_lower` | `room15` (Chamber) | `deck0` (`0.0 m`) | `(16, 40)` | Lower ring platform housing `rings_boarding` endpoint. |
| `ramp` | `room14` (Ramp 4m) | `deck0` (`0.0 m`) -> `upper` (`4.0 m`) | `(-8, 40)` | Physical structural ramp connecting Deck 0 to Deck 1 upper deck. |
| `upper_hall` | `room01` (Straight) | `upper` (`4.0 m`) | `(-24, 40)` | Upper deck corridor leading to interior checkpoint. |
| `interior_checkpoint` | `room04` (Chamber) | `upper` (`4.0 m`) | `(-32, 40)` | Fortified security checkpoint with barricades and terminal. |
| `ring_upper` | `room15` (Chamber) | `upper` (`4.0 m`) | `(-32, 32)` | Upper ring chamber housing `rings_upper` reciprocal endpoint. |
| `corridor_engineering` | `room01` (Straight) | `upper` (`4.0 m`) | `(-40, 40)` | West transit passage connecting checkpoint to engineering compartment. |
| `engineering` | `room10` (Long Chamber) | `upper` (`4.0 m`) | `(-48, 40)` | Shipboard engineering room dressed with the naquadah reactor core and diagnostics console (`mothership_engineering.tres`). |
| `bridge` | `room11` (Large Chamber) | `upper` (`4.0 m`) | `(-48, 24)` | Command bridge dressed with navigation helm console, tactical stations, and deep-space viewport (`mothership_bridge.tres`). |

The route achieves 100% enclosure, zero portal leaks, and full continuous navigation graph connectivity across both decks.

## Three bridge-console, reactor-detail, and hero-trim families

### Family 1: Command Bridge Navigation Helm (`MothershipBridgeConsole.tscn`)
- **Dimensions**: 2.0 × 1.1 × 1.0 m (attachment bounds `AABB(-1.0, 0, -0.5, 2.0, 1.1, 1.0)`).
- **Visuals**: Tiered basalt footing, burnished bronze pedestal with sweeping curved gull wings, gold Goa'uld chevron trim, an illuminated tactical navigation display screen, central glowing golden navigation orb, gold function keys, and twin cyan status crystals.
- **Physics**: StaticBody3D collision on layer 1, with front approach vector `Vector3(0, 0, -1.2)` facing south towards the bridge entrance.
- **Preset**: Placed at `bridge_console` in `mothership_bridge.tres`.

### Family 2: Hyperdrive Naquadah Reactor Core (`MothershipReactorCore.tscn` & `MothershipReactorStatus.gd`)
- **Dimensions**: 2.4 × 2.8 × 3.2 m (attachment bounds `AABB(-1.2, 0, -1.6, 2.4, 2.8, 3.2)`).
- **Visuals**: Heavy basalt foundation bed, bronze support brackets, dual vertical magnetic containment towers, overhead containment clamp rings, glowing cyan naquadah energy column, and front diagnostics terminal.
- **Reactive State (`MothershipReactorStatus.gd`)**: Listens to `MissionEvents.trigger_fired` for the `&"sabotage_releases_bridge"` event. When sabotage occurs, the script replaces the cyan active energy column material with a darkened unshaded shutdown material (`Color(0.08, 0.12, 0.14)`), providing immediate visual feedback of hyperdrive power failure.
- **Physics**: StaticBody3D collision on layer 1, with approach vector `Vector3(0, 0, -2.0)`.
- **Preset**: Placed at `reactor_core` in `mothership_engineering.tres`.

### Family 3: Forward Deep-Space Observation Viewport Frame (`MothershipViewportFrame.tscn`)
- **Dimensions**: 3.6 × 2.6 × 0.35 m (attachment bounds `AABB(-1.8, 0, -0.15, 3.6, 2.6, 0.3)`).
- **Visuals**: Basalt bottom sill plinth, bronze upper lintel with gold accent trim, bronze side jambs, twin vertical gold mullions, reinforced tinted quartz glass pane, and a self-contained deep space backdrop featuring a dark void quad, glowing violet cosmic nebula, and bright distant stars.
- **Boundary & Camera Preservation**: Solid `StaticBody3D` on layer 1 sealed across the aperture (`size = Vector3(3.6, 2.6, 0.35)`). This prevents players and third-person camera raycasts from clipping outside the room volume, maintaining Godot's occlusion and camera fade boundaries without exposing void gaps.
- **Preset**: Placed at `viewport` in `mothership_bridge.tres` against the north wall.

## MissionEvents integration: Sabotage and blast door release

The mission script `client/resources/missions/goauld_mothership_objective.tres` wires the interaction pipeline:
1. **Initial Security Lockdown**: The security blast door connecting `engineering/north` to `bridge/south_00` (`bridge_blast_door`) starts in the locked state (`set_locked(true)` applied by `MissionEvents.start()`), preventing direct rush to the bridge.
2. **Sabotage Hyperdrive**: The operative reaches `engineering` and interacts with the naquadah reactor core.
3. **Trigger Execution (`sabotage_releases_bridge`)**:
   - `MissionEvents` fires the trigger:
     ```gdscript
     [sub_resource type="Resource" id="trigger_sabotage_unlock"]
     script = ExtResource("4_trigger")
     id = &"sabotage_releases_bridge"
     event_name = &"trigger_fired"
     objective_id = &"sabotage_hyperdrive"
     actions = Array[Dictionary]([{
         "action": "unlock_door",
         "connection_id": &"bridge_blast_door"
     }])
     ```
   - `bridge_blast_door` is unlocked and opened automatically.
   - `MothershipReactorStatus.gd` switches the reactor column to shutdown material.
4. **Bridge Command Override**: With the blast door open, operatives breach `bridge` and override flight navigation controls on the central helm console.
5. **Alarm State & Extraction**: Upon bridge override, the shipboard alert is triggered: red alarm emergency lighting activates across the ship, and the team executes a tactical return route through `engineering`, `interior_checkpoint`, down the ramp (or ring transport), through `cargo_bay` and `vestibule` to extract through the Stargate in `gate`.
6. **Debrief**: Stepping into the Stargate event horizon completes the mission with successful debrief.

## Technical verification

- **Mothership Objective Suite (`test_mothership_objective.gd`)**: Passed 100% in headless Godot:
  - Validates 12-module layout with `goauld` theme coverage and two decks.
  - Verifies presence and collision of all three prop families (`bridge_console`, `reactor_core`, `viewport`).
  - Verifies camera occlusion boundary on `MothershipViewportFrame` (solid layer 1 collision).
  - Tests reactive `MothershipReactorStatus` switching from active cyan naquadah glow to darkened shutdown material.
  - Executes full 4-stage mission loop (`reach_checkpoint` -> `sabotage_hyperdrive` -> `override_bridge_helm` -> `extract`).
  - Verifies `sabotage_releases_bridge` trigger unlocks `bridge_blast_door`.
  - Verifies shipboard alert activation and debrief completion.
- **Modular Presets Suite (`test_modular_presets.gd`)**: Passed 100% across all 16 presets including `mothership_bridge` and `mothership_engineering`.
- **Level Authoring Inspector (`tools/level_authoring.py inspect`)**: 0 warnings, 0 errors, 12 modules validated.
- **Mothership Boarding Suite (`test_mothership_boarding.gd`)**: Passed 100% (zero regressions on Sprint 32 boarding route).
- **Gate Travel Suite (`test_gate_travel.gd`)**: Passed 100% (zero regressions in wormhole transit).
- **Python Unit Tests (`tools/tests`)**: 60 unit tests passed 100% in 26.1s.

## Captures (Forward+ on NVIDIA RTX 3060)

Captures rendered at 1280 × 720 in Forward+ on NVIDIA GeForce RTX 3060:
1. [Engineering Reactor Core](../../build/sprint33/captures/01_engineering_reactor_core.png) — Heavy naquadah hyperdrive generator, magnetic containment rings, and cyan energy core.
2. [Engineering Diagnostics Console](../../build/sprint33/captures/02_engineering_diagnostics.png) — Engineering side station, power raceway conduit, and basalt masonry.
3. [Security Blast Door](../../build/sprint33/captures/03_security_blast_door.png) — Heavy bulkhead blast door transition isolating engineering from the command bridge.
4. [Bridge Command Helm](../../build/sprint33/captures/04_bridge_command_helm.png) — Central navigation helm console, tactical side stations, and observation viewport framed beyond.
5. [Bridge Viewport Vista](../../build/sprint33/captures/05_bridge_viewport_vista.png) — Forward observation viewport framing deep space, purple cosmic nebula, and stars.
6. [Alarm Escape Lighting](../../build/sprint33/captures/06_alarm_escape_lighting.png) — Command bridge bathed in red shipboard emergency alert lighting following sabotage and helm override.
