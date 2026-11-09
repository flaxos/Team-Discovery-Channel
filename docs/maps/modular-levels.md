# Modular room scaffolding — Phase 1

This independent kit does not replace SGC or add a lobby mission. It contains four reusable scene archetypes, typed layout resources, shared deterministic snapping, structural validation and a navigation-backed smoke fixture. NPC behavior/mission adaptation and a Goa'uld content level remain future phases.

## Kit and contract

`client/scenes/level/modules/` contains `Room01Straight`, `Room02Corner`, `Room03TJunction` and `Room04Chamber` PackedScenes. Each has a matching definition in `client/resources/level_modules/`. Multiple placements instance those scenes rather than copying their internals.

Every module reserves an 8 × 8 m cell, with floor at Y=0, 3.4 m ceiling clearance, 3 m clear corridors and 3 × 2.8 m portals. Straight/corner/T interiors occupy enclosed paths inside that cell; chamber clearance is 7.6 m. Reserved cells may touch but must not overlap. Conservative reservations intentionally leave unusable exterior corners between narrow modules.

Socket IDs are `north`, `east`, `south`, `west`; available sets depend on the archetype. Socket origins are doorway-floor centers, local -Z faces outward, and +Y is up. Socket origins must sit on the occupied reservation boundary, with local -Z pointing out of it; validation checks both sides of that boundary. Scene markers and resource transforms must agree. Connected socket origins coincide and their directions oppose. Portal cap state is derived from saved connections when a scene reopens; it does not depend on editable-child overrides. Only quarter-turn yaw, horizontal translation and declared deck elevations are supported; no scaling or tilted instances. Placement/dimension tolerance is 1 mm. An empty availability list means all archetype sockets are enabled; remove connections and use an explicit subset to disable selected chamber openings.

Typed resources under `client/scripts/level/` separate module geometry, socket data, instance identity/deck/role/style/tags, connection endpoints and layout schema/decks/required markers. Instance IDs are unique within a layout; socket IDs are unique within an archetype. Different placements reuse the same module definition. Connections support `open` passages and `door` links with one server-controlled operable door. The visual editor automatically creates door links for compatible touching sockets; existing open passages remain supported.

Stable scene branches: `Structure/Collision`, `Structure/NavigationSource`, `Structure/PortalClosures`, `Visuals`, `Sockets`, `Markers`, and `Attachments/{Props,Cover,Interactions,Spawns}`. Collision supplies navigation; `NavigationSource` is reserved for later explicit source extensions. Placeholder meshes carry `visual_slot` and dimension metadata. Change materials or replace visual meshes within those bounds without changing structural collision. Do not add collision beneath Visuals. Gameplay props that change clearance require validation and rebaking.

## Creating another module archetype

Create a new `LevelModuleDefinition` resource with a unique module ID and scene reference. Start a new scene with `LevelModule.gd` on its Node3D root, preserving the stable branch names above. Author its structural floor/wall collision, ceiling collision on layer 8 (128), and separate placeholder visual meshes. Set its occupied reservation and interior AABBs in local coordinates; the latter describe walkable enclosed space, not solid walls.

Add a `LevelSocketDefinition` for each doorway, its matching `Sockets/<id>` Marker3D, and matching collision/visual caps under `Structure/PortalClosures/<id>` and `Visuals/Closures/<id>`. Leave caps closed in the archetype. Set exact opening dimensions, outward socket transform and internal approach point. Add the named entry/destination/patrol markers and attachment branches. Set `definition_path` on the scene root to its definition resource. Test the new scene in an isolated layout before adding it to an authored level; inspect every supported orientation and both traversal directions. Room purpose belongs in instance role/tags and attachments rather than geometric socket names.

## Human authoring in Godot

1. Open a new Node3D scene, attach `LevelAssembly.gd`, and create a `LevelLayout` resource in its Inspector. Set entry/destination instance IDs and marker IDs (`entry`/`destination` by default).
2. Drag archetype scenes into the root. Each loads its matching definition through `definition_path`. Assign a unique `instance_id` and deck; place new instances apart initially so reservations do not overlap. Use Godot's transform tools for translation and 90-degree rotation.
3. Set `capture_destination` to an explicit `.tres` path. Click **Capture placed modules**. Incomplete disconnected layouts may be captured while authoring; final validation requires connectivity. Capture rejects arbitrary rotations, scaling, floor mismatches and overlaps. It renames placed nodes to their instance IDs.
4. On the assembly root, fill `moving_instance`, `moving_socket`, `target_instance` and `target_socket`. Click **Snap sockets (capture to save)**. It calculates placement and records the connection; failures roll back. Capture again to persist the result.
5. Click **Validate and bake** to validate the completed shell and bake navigation. Uncaptured scene poses or portal states inconsistent with the resource fail validation; capture moves first. Rebuild from the resource with **Rebuild from layout**; an existing scene requires explicitly enabling `discard_uncaptured_edits` first. Save the scene normally.

Inspector actions are minimal scaffolding, not an Undo/Redo-backed editor plugin. Save/capture before destructive rebuilding. A dock, socket selectors and editor undo integration are Phase 2 work.

## AI/programmatic authoring

Use native text `.tres` resources or typed GDScript, not guessed final coordinates or natural-language assembly. Example for a new layout:

```gdscript
var layout := LevelLayout.new()
var corridor := LevelModuleInstance.new()
corridor.id = &"corridor_01"
corridor.module = load("res://resources/level_modules/Room01Straight.tres")
var chamber := LevelModuleInstance.new()
chamber.id = &"chamber_01"
chamber.module = load("res://resources/level_modules/Room04Chamber.tres")
chamber.position = Vector2(100, 0) # Temporary non-overlapping reservation.
layout.instances.assign([corridor, chamber])
layout.entry_instance = corridor.id
layout.destination_instance = chamber.id
var errors := LevelAssembler.snap(layout, chamber.id, &"south", corridor.id, &"north")
assert(errors.is_empty(), str(errors))
assert(ResourceSaver.save(layout, "res://resources/levels/example.tres") == OK)
```

The snap API derives translation/yaw, adds the connection and rejects incompatible/reused/disabled sockets or overlap transactionally. Editing scene internals is unnecessary. These are trusted repository authoring resources, not an untrusted upload format.

Validate and build:

```sh
godot --headless --path client --script res://scripts/level/build_level.gd -- --layout res://resources/levels/modular_smoke.tres --validate
godot --headless --path client --script res://scripts/level/build_level.gd -- --layout res://resources/levels/modular_smoke.tres --build --output res://scenes/level/ModularSmoke.tscn --nav-output res://resources/levels/modular_smoke_navigation.res
```

Errors return nonzero before publishing invalid geometry. Build outputs are restricted to the modular scene/resource directories or `user://`, protecting SGC paths. Missing/unknown command arguments fail. Build/save I/O errors are reported; inspect output files after an interrupted write.

## Navigation, enclosure and preview

The assembly owns an independent active navigation map, `navigation_ready`, and `local_path(start, goal)`. It bakes structural collision with the current production clearance profile: radius 0.6 m, height 1.9 m, climb 0.2 m, slope 42°, cell size 0.15 m and cell height 0.1 m. Ceilings use bit 128 and do not create navigation roof islands. Phase 1 rebakes at runtime/validation; the saved mesh is also a development artifact, not a content-hash cache.

The generic enclosure checker samples exterior interior-volume faces every 0.25 m against actual world/cap collision. Internal shared volumes and connected portals remain open; unused portal caps stay closed. Errors identify the owning instance and boundary face/location. This is a sampled physical check, not proof of material opacity. Schema checks identify exact socket endpoints for bad joins.

The eight-instance fixture repeats all four archetypes. Explore it independently of missions:

```sh
godot --path client --script res://tests/support/modular_level_preview.gd
```

This uses the existing player controller and hides roof visuals as a preview-only cutaway, retaining ceiling collision. Add `-- --capture` to save `/tmp/modular-overview.png` and exit. The fixture contains no automatic enemies or mission logic.

Run focused acceptance:

```sh
python3 tools/run_godot_tests.py test_modular_level --timeout 180
```

Coverage includes socket orientations, transactional rejection, invalid references/overlap/disconnection/state, layout and scene round trips, cap closure, missing floor/roof rejection, Inspector capture, visual-material independence and continuous traversal of every fixture connection in both directions with real player/friendly/Jaffa capsules. AI physics controllers are disabled for these traversal tests: full NPC behavior still depends on `SGCNavigator` and is not integrated here.

## Next increment and boundaries

After Phase 1 review, Phase 2 can improve editor selection and Undo/Redo. Later work can adapt NPC navigation providers, locks and mission/alarm synchronization; basic player-operated doors are now implemented. Phase 4 can assemble a small Goa'uld interior with entry, objective and optional patrol branch. Ring/gate rooms should instance existing shared assets; no base/ship-specific generator conditions belong in the module layer. No additional game modes, artwork or SGC rewrite are part of this delivery.

Delivery evidence, the final scope boundary and the complete file manifest are recorded in the [Phase 1 delivery report](../reviews/modular-phase1.md).

`LevelAssembler.connect_touching(layout)` validates the layout, connects coincident compatible unused sockets without moving rooms or changing existing connection types. New corridor joins default open; room entrances default to doors. The visual editor calls it on placement/movement and exposes it as an undoable action for existing layouts. Bake excludes door panels from static navigation while their runtime collision remains closed until interacted with.

Batch B extends the same schema with per-socket deck bindings, optional sloped boundary patches and equipment/transport interfaces. Existing planar definitions remain valid. See [vertical kit authoring](modular-vertical-kit.md).

Batch C composes optional functional presets beneath the existing attachment branches and adds a security-door classification. Structural module authoring remains independent of role and material themes; see [room-preset authoring](modular-room-presets.md).
