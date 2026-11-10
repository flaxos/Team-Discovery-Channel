# Functional room presets — Batch C

Room composition is independent of architecture. `LevelModuleDefinition` and its PackedScene still own walls, collision, portals and decks. A `LevelRoomPreset` supplies content; an optional `LevelVisualTheme` supplies materials. No geometry-prefab copies, mission modes, alarm logic or AI spawners are added.

## Catalogue

Every preset below is implemented as `res://resources/room_presets/<id>.tres`. `LevelPresetCatalogue.PRESETS` is the machine-readable inventory. Structural scene/resource paths and socket dimensions remain in the [structural catalogue](modular-catalogue.md) and [vertical kit guide](modular-vertical-kit.md).

Module groups used below:

- **Chambers:** room04 (8×8), room10 (8×16), room11 (16×16), room13 (16×24), and room15 (8×8 m, tall).
- **Long chambers:** room10, room11 and room13. Presets use explicit local coordinates and do not automatically fill larger shells. Compatibility also depends on doorway placement: the generic corner-console arrangement intersects the hangar’s wide north opening, so that shell uses dedicated or custom layouts. Overrides or a custom preset can redistribute their content.

| Preset identifier | Compatible geometry | Required attachments / components | Status |
|---|---|---|---|
| `jaffa_barracks` | Chambers | Two beds, weapon rack, console, three squad markers, patrol entry/exit | Implemented |
| `security_checkpoint` | Chambers | Two cover props, guard marker, console, door-control/alarm references, patrol markers | Implemented |
| `armoury` | Chambers | Existing armour station, weapon rack, inventory marker, console/patrol markers | Implemented |
| `detention` | Chambers | Cot, prisoner and guard markers, access-control reference, extraction marker | Implemented |
| `generator` | Long chambers | Machinery volume, console, power/repair/sabotage objective approach | Implemented |
| `cargo` | Chambers | Three crates, console, cover and cargo-interaction markers, patrol markers | Implemented |
| `engineering` | Long chambers | Equipment bay, service console and repair/system reference | Implemented |
| `security_control` | Chambers | Two consoles, door-network/alarm references and patrol markers | Implemented |
| `ring_transport` | room15 | Existing Transport Rings scene in `transport` anchor, console, arrival/patrol markers | Implemented |
| `stargate_dhd` | room16 | Existing Stargate in `gate` anchor, existing DHD, dialling and entry/extraction approaches | Implemented |
| `sarcophagus` | Long chambers | Placeholder sarcophagus, interaction approach, future healing/revival references | Implemented |
| `laboratory_medical` | Long chambers | Examination table, console, equipment and intelligence marker | Implemented |
| `command` | room11, room13 | Main/secondary consoles, commander and display markers, security interface | Implemented |
| `cargo_hangar` | room16 | Reserved vehicle volume, cargo props and access/objective markers | Implemented |
| `ceremonial` | room13, room16 | Low dais/throne placeholders, guard markers, side approaches, character objective | Implemented |
| `observation_communications` | Chambers | Communications/display prop, console, staff/intelligence markers | Implemented |

Existing shared assets are referenced at their original paths: `res://scenes/props/{TransportRings,Stargate,DHDConsole,ArmoryArmorStation}.tscn`. Missing assets use the single reusable `res://scenes/level/RoomPlaceholder.tscn` or named Marker3D nodes. Markers do not spawn actors or start objectives. System references such as `doors.access`, `systems.power` and `objective.extraction` are stable integration labels, not new gameplay systems.

## Typed authoring contract

- `LevelRoomPreset`: stable ID/label, explicit compatible module IDs, attachment definitions and system-reference labels.
- `LevelRoomAttachment`: stable node-safe ID, component label, optional shared PackedScene, module/equipment-anchor-relative transform, reserved bounds, optional placeholder size, movement-blocking proxy flag, required/reachable flags, relative approach point and reference labels.
- `LevelRoomOverride`: attachment ID, replacement local transform and disabled flag. Instance overrides never mutate the shared preset.
- `LevelModuleInstance.room_preset`, `attachment_overrides` and `theme` preserve this data in the existing LevelLayout resource. The existing `role` field remains compatible descriptive data; assigning a preset updates it to the preset ID.
- `LevelVisualTheme` has separate surface/placeholder materials. `res://resources/level_themes/neutral.tres` is the baseline. Themes do not change collision, positions or navigation. Existing shared equipment keeps its own appearance.

An attachment without an equipment anchor is relative to the module origin and is built at `Attachments/RoomContent/<id>`. Anchored content is built at `Attachments/Interactions/<anchor>/<id>`. For example, the ring component is `Attachments/Interactions/transport/Rings`. Bounds are local to the attachment; its approach is a floor standing point relative to that transform. Yaw edits rotate the bounds and approach together.

Reserved bounds are not automatically solid: a transport operating volume or vehicle clearance can remain walkable. Placeholders have real box collision. Shared scene props that request `blocks_movement` receive a separate collision envelope; the DHD and armour station use this to preserve solid movement clearance without modifying their original scenes. Changing appearance alone does not change that envelope.

Derived nodes retain external PackedScene identity and are regenerated from the layout. Validation catches stale/uncaptured content instead of accumulating props from a previous role. In the Inspector authoring workflow, use **Rebuild from layout** after a role/configuration change; the existing capture/discard safeguards still apply. Save and reopen generated scenes without duplicating attachments or losing component wiring.

### Human editor workflow

1. Enable **Modular Map Editor** in Project Settings → Plugins. Open its bottom panel and place/select a structural chamber.
2. Choose a compatible **Room preset**, then **Apply preset**. Incompatible presets are disabled. Selection shows the role label and attachment/clearance outlines.
3. Select an attachment ID. Edit local X/Y/Z and yaw, then **Apply attachment**. Anchored attachments indicate their coordinate space in the selector tooltip. **Use default** removes only that attachment's override.
4. Required attachments cannot be disabled. Unsupported transforms, overlaps, out-of-bounds placements, obvious standing-clearance problems and blocked portal envelopes reject the edit without changing the prior layout. Full Validate additionally checks actual collision and navigation.
5. Changing cargo to barracks leaves the same structural definition, placement and connections. Matching attachment IDs retain their overrides. Unmatched overrides remain stored but inactive; the results panel names them. Switching back reactivates them. Reset or edit them explicitly when needed.
6. Save under a new layout filename, reopen, Validate, Rebuild and Preview 3D. The two-room `res://resources/levels/room_presets_demo.tres` is a focused cargo/barracks/security-door test fixture, not Batch D's integrated environment.

Transport presets instantiate the existing ring asset without enemy spawning or activation. Existing reciprocal `LevelTransportEndpoint` IDs/path bindings are applied automatically once both rigs exist. Keep their `node_path` at the generated path above. Unpaired presets may remain idle; configured endpoints must form valid pairs. Changing a room role does not discard explicit transport data: clear or update those endpoint contracts when repurposing a configured transport room. The gate/DHD preset wires the existing DHD to the existing gate and leaves both inactive. Mission-specific entry/extraction configuration is still future work.

### AI / headless authoring

Use the same typed resources; no alternate JSON or graph format exists:

```gdscript
var layout := LevelLayout.new()
var room := LevelModuleInstance.new()
room.id = &"storage_01"
room.module = load("res://resources/level_modules/Room04Chamber.tres")
room.room_preset = load("res://resources/room_presets/cargo.tres")
room.theme = load("res://resources/level_themes/neutral.tres")
var override := LevelRoomOverride.new()
override.id = &"console"
override.local_transform.origin = Vector3(2.5, 0, -2.5)
room.attachment_overrides.append(override)
layout.instances.assign([room])
layout.entry_instance = room.id
layout.destination_instance = room.id
assert(LevelLayoutValidator.validate(layout).is_empty())
assert(ResourceSaver.save(layout, "res://resources/levels/storage_example.tres") == OK)
```

Build and preview the provided fixture:

```sh
godot --headless --path client --script res://scripts/level/build_level.gd -- --layout res://resources/levels/room_presets_demo.tres --build --output user://room_presets_demo.tscn --nav-output user://room_presets_navigation.tres
godot --path client res://addons/modular_editor/preview.tscn -- --scene user://room_presets_demo.tscn
```

To create a new preset, create a LevelRoomPreset resource and its typed attachments, choose existing compatible shells, and declare the content's bounds/approaches. Use shared scenes or the generic placeholder; do not copy a room scene to change its purpose. Validate each declared compatible geometry, required component and standing point. To create a genuinely new structural module, follow the separate [module-authoring guide](modular-levels.md).

`tools/level_authoring/build_room_presets.py` explicitly writes the sixteen starter resources; it never runs during placement/gameplay. Preserve manual changes before rerunning it. `create_presets_demo.gd` recreates only the dedicated test layout. Custom presets remain ordinary resources and do not require a generator.

## Security-door interface

Connections retain `open` and `door` and add `security_door`, `security_id` and `initially_locked` (default false). Existing authored choices are preserved. Click a linked socket, choose **Security door**, and edit the access ID/initial lock using **Apply door access**. Connection selection survives these edits and Undo/Redo. Leaving the ID empty derives a stable ID from its endpoint IDs. Explicit access IDs must be unique within a layout.

The reused ModularDoor renders security panels amber. E operates an unlocked security door. Trusted server code can call `set_locked(bool)` and subscribe to `access_changed(access_id, is_locked)`. Clients cannot invoke this lock interface; ordinary open/close requests retain actor identity/range checks. Lock/open state snapshots reach joining/reloaded clients. Locking an open door refuses to close through an occupied character volume.

Locked security doors remain obstacles during navigation baking. Full validation reports inaccessible regions and required attachment approaches with room/access IDs. An initially locked connection therefore needs an alternate accessible route if it would otherwise isolate part of a publishable layout. Ordinary closed but operable doors remain excluded from static baking as before.

Runtime locking does not automatically rebake the map. A future server access/AI system must consume the access-change signal and rebuild navigation when required; physical door collision and replicated state change immediately. No access cards, alarm escalation, stealth AI or console network is added here.

## Tests and UAT

```sh
python3 tools/run_godot_tests.py test_modular_presets test_modular_security test_modular_vertical test_modular_editor test_modular_doors --timeout 180
```

Preset tests cover every declared geometry compatibility, all sixteen built roles, reachable required approaches, actual asset identity, repeat build and scene/resource reload, role switches and independent overrides, rejected edits, missing components, blocked approaches, real placeholder collision, material-only changes and production player/friendly/Jaffa passage through the two configured rooms. Reciprocal preset ring components bind through the Batch B contract. Security tests use native server/client multiplayer contexts to exercise authority, actor spoof rejection, current-state snapshots and occupied-door protection. The multiplayer runner profile includes the new security suite.

Manual checklist:

1. Open the preset fixture, select cargo and inspect role/attachment outlines. Change to barracks; Undo/Redo and confirm walls/connections stay unchanged.
2. Move the console slightly, apply, reset, and Undo/Redo. Try moving it through a doorway or outside the room; confirm readable errors and unchanged prior data.
3. Override a crate, switch to barracks, inspect the inactive-override notice, and switch back. Save/reopen and verify the override survives.
4. Select the security connection, change its access ID and initial lock, and Undo/Redo. Validate the isolated locked case, then unlock it and rebuild.
5. Preview 3D, walk both rooms, test E, check props/clearances and confirm no actors, ring sequence or gate activation starts automatically.
6. Apply ring/gate presets to their compatible shells, rebuild and inspect shared scene instances/anchors. Compare material-only changes without changing collision.

Batch C adds reusable contracts and neutral content. It does not complete the full Phase 2.5 environment: Batch D's integrated fixture and broader manual UAT remain separate. Detailed visual themes and gameplay systems remain outside this milestone.


## Delivery evidence

Godot 4.4.1 full inventory: **58/58 checks passed** (`build/test-results/presets-full/`), including unchanged SGC/multiplayer coverage. Final preset/security acceptance passes (`presets-final-acceptance/`) after catalogue compatibility adjustments and optional-marker validation. Native Godot editor preset changes, attachment edits/invalid-edit rollback, security access editing, Undo/Redo, Rebuild and Preview 3D exit cleanly; the editor capture was inspected. The two-room fixture also builds through the actual headless CLI. Existing user maps, edited structural resources, project settings and Main scene remain byte-for-byte unchanged.

The [Batch D integrated fixture](modular-integration-demo.md) now demonstrates these presets together with the complete structural kit, mixed door types, paired idle rings and a walkable deck connection. Earlier Batch C evidence above remains historical.
