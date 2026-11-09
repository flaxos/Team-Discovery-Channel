# Modular vertical and equipment kit — Batch B

Batch B extends the existing layout, scene assembly, editor, enclosure and navigation pipeline. It does not add a mission, enemy activation, functional room presets or an elevator implementation. Original maps and their connection types remain compatible.

## Structural catalogue

Definitions are `res://resources/level_modules/<asset>.tres`; scenes are `res://scenes/level/modules/<asset>.tscn`. All remain reusable external PackedScene instances. The existing planar catalogue is `LevelCatalogue.MODULES`; `VERTICAL_MODULES` lists these three additions and `all_modules()` supplies the complete editor palette.

| ID | Asset | Reserved footprint | Clear height / rise | Sockets |
|---|---|---|---|---|
| room14 | Room14Ramp4m | 8 × 16 m | 3.4 m vertical headroom; 4 m rise | `lower`: (0,0,-4), north-facing; `upper`: (0,4,12), south-facing; both passage, 3 × 2.8 m |
| room15 | Room15TransportChamber | 8 × 8 m | 10.4 m | north/south, passage, 3 × 2.8 m |
| room16 | Room16HangarShell | 24 × 32 m | 12 m | north: (8,0,-4), equipment_passage, 12 × 10 m; south_00: (0,0,28), passage, 3 × 2.8 m; south_01: (8,0,28), wide_passage, 6 × 2.8 m |

The ramp has 2 m lower/upper landings and a 12 m run (about 18.4°). Continuous floor collision supports player/friendly/Jaffa capsules; full side walls prevent falling off. Rails sit against the walls without extra protruding collision. Ceilings remain physical even when hidden in the preview cutaway. Its reservation spans both decks, so another room cannot occupy its shaft volume.

The transport chamber is taller than the initial 10 m estimate: the existing retracted ring stack reaches about 10.1 m. The 10.4 m shell and 10.2 m operating clearance fit the actual asset without sinking it into the floor.

## Decks and editor workflow

`LevelLayout.decks` remains the elevation dictionary. An instance's `deck` controls its placement origin. Its optional `socket_decks` dictionary binds elevated socket IDs to existing deck IDs; ordinary zero-offset sockets default to the instance deck.

For example, a ramp on `deck0` at elevation 0 has `socket_decks = {"upper": "upper"}` when the `upper` deck is at elevation 4. Socket world height must equal the bound deck elevation. Snapping compares endpoint deck bindings, world height, position and direction; it never moves a room vertically to conceal a mismatch.

1. Open the Godot `client/` project and enable **Modular Map Editor** under Project Settings → Plugins.
2. Open the **Modular Map** bottom panel. Enter a new deck ID and elevation, then click **Add deck**. Select a deck to place rooms on it. **Set elevation** edits the selected deck using Undo/Redo.
3. Place Ramp4m on the lower deck. If exactly one existing deck matches its upper elevation, that socket binds automatically. Otherwise it remains unbound while editing.
4. To bind explicitly, select the ramp, choose `upper` in the socket dropdown, switch the active deck to the desired upper deck, then click **Bind socket to active deck**. Selection is retained when changing the view deck.
5. Place a compatible corridor against the upper landing. Automatic linking and manual socket snapping both work across different instance base decks. Lower sockets are selectable on the lower deck; upper sockets on the upper deck. Other rooms remain as inactive outlines.
6. **Move room to deck** changes a selected room's base deck and rebinds matching socket elevations. Invalid edits leave previous placement and connections intact. Deck elevation edits that break a binding or connection are rejected.
7. **Frame layout** fits the declared footprints; Open also frames the map. Pan/zoom remain available. Save and reopen the same `.tres` to preserve decks, rotations and connections.

Incomplete layouts with an unbound elevated socket remain editable. Full validation/build requires explicit valid bindings. Ambiguous equal-height decks require manual binding. Deck IDs/elevations are map data; SGC floor numbers are not used. The first ramp asset supports a fixed 4 m rise. Other rises require separately authored geometry/socket definitions rather than stretching this scene.

## Equipment and transport interfaces

Definitions declare `equipment_anchors` (local Transform3D values) and matching `equipment_clearances` (local AABBs). Scene markers live at `Attachments/Interactions/<id>`. Validation checks their agreement and detects structural collision in the reserved operating space. Shared equipment itself may occupy that space; a future preset can instance it beneath the anchor without duplicating shell geometry.

| Asset / slot | Anchor | Reserved local operating volume |
|---|---|---|
| TransportChamber / transport | (0,0,0) | AABB(-2.5,0.02,-2.5, 5,10.2,5) |
| HangarShell / gate | (8,3.5,8) | AABB(4.5,0.02,6, 7,7.2,8), covering the existing gate and forward kawoosh envelope |
| HangarShell / cargo | (8,0,20) | AABB(-1,0.02,16, 18,11.5,10) |

`LevelTransportEndpoint` is an optional per-instance contract in `transport_endpoints`: stable `id`, reciprocal `target_id`, `kind` (`rings` or `elevator`), declared `anchor`, and a module-relative `node_path`. IDs are unique across the layout and each anchor can serve one endpoint. Elevators receive pairing metadata only; there is no moving platform or new elevator gameplay.

For rings, instance the existing `res://scenes/props/TransportRings.tscn` as `Rings` directly beneath each transport anchor, with its local transform unchanged. Define matching endpoints with `node_path = NodePath("Attachments/Interactions/transport/Rings")`. Once both scenes are present, call:

```gdscript
var errors := LevelTransportBindings.bind_rings(layout, assembly)
assert(errors.is_empty(), str(errors))
```

This resolves every endpoint before changing any rig, sets existing paired-ring references/paths and disables enemy spawning. It does not activate the rings, create new RPCs or replace transport behaviour. Reapply the binding after instancing/reloading manually attached rigs. Automatic equipment instantiation and preset integration remain Batch C work. The test suite confirms the existing shared gate scene fits its anchor and remains inactive.

Transport pairs are not continuous navigation edges. Existing ring gameplay handles transport when invoked; NPC transport decisions are not implemented. Final walkable layout connectivity still requires physical routes. Selected-room structural inspection omits transport pairing requirements for the isolated preview.

## Build and inspect the development fixture

Open `res://resources/levels/vertical_kit_demo.tres`, click **Open**, then **Validate** and **Preview 3D**. It contains a ramp, lower T-junction, upper corridor, transport shell and hangar shell. Decks are `deck0` (0 m) and `upper` (4 m). Walk from the lower junction up the ramp; the transport branch has a standard E-operated door. Equipment anchors are empty; there are no automatic enemies or gate/ring activation.

The same fixture works headlessly:

```sh
godot --headless --path client --script res://scripts/level/build_level.gd -- --layout res://resources/levels/vertical_kit_demo.tres --build --output user://vertical_demo.tscn --nav-output user://vertical_navigation.tres
godot --path client res://addons/modular_editor/preview.tscn -- --scene user://vertical_demo.tscn
```

`tools/level_authoring/build_vertical_kit.py` explicitly bakes the three static assets; it never runs per placement or during gameplay. `godot --headless --path client --script ../tools/level_authoring/create_vertical_demo.gd` recreates only the dedicated demo resource. Neither command edits an authored SGC map or the user's editor demo. Preserve manual edits to these generated kit assets before rerunning their authoring utilities.

## Validation and manual UAT

Run `python3 tools/run_godot_tests.py test_modular_vertical test_modular_level test_modular_catalogue test_modular_editor test_modular_doors --timeout 180`.

The vertical suite covers four ramp orientations, arbitrary elevation datum, real player/friendly/Jaffa traversal both ways, floor/ceiling/wall removal, invalid height/overlap rejection, every tall-shell entrance, equipment obstructions, ring pairing failures without mutation, actual shared equipment bounds, resource and built-scene round trips, and navigation throughout the fixture. Sloped enclosure uses typed sampled boundary patches; planar modules retain their original volume checks. Connected portals are excluded precisely by their authored opening plane/dimensions, allowing a planar corridor to meet a sloped module without inventing an interior volume.

Manual checklist:

1. Open the fixture; frame the layout and switch decks. Confirm inactive outlines and the ramp's upper/lower socket visibility.
2. On a new map, create decks at 0 and 4 m, place the ramp and corridors, and confirm automatic connections. Rotate a fresh ramp before placement.
3. Try a 5 m upper deck or a conflicting upper-room placement over the tall transport chamber. Confirm readable errors and unchanged data. Undo/Redo a valid deck addition and binding edit.
4. Save/reopen, Validate, Rebuild and Preview 3D. Walk the ramp both ways, check floor transitions/headroom/side protection and enter the transport/hangar branch.
5. Attach the shared equipment through its declared anchor and inspect the operating clearance. Keep it inactive during structural UAT.

Native editor verification exercises deck selection, failed elevation rollback, deck Undo/Redo and Rebuild/Preview 3D. Automated checks supplement this manual checklist; they do not certify all mouse-driven interactions.


## Delivery evidence

Godot 4.4.1 full regression: **56/56 checks passed** (`build/test-results/vertical-full/`), including unchanged SGC and multiplayer coverage. Final targeted vertical/editor tests pass (`vertical-final-target/`); the strengthened all-profile grounding and complete catalogue-ID check passes (`vertical-grounding/`). The five-room fixture builds through the actual headless builder. Native editor deck controls, failed elevation rollback, Undo/Redo, Rebuild and Preview 3D exit cleanly; a framed editor capture was inspected. The existing user's map, original edited prefabs, project settings and Main scene remain byte-for-byte unchanged.

Batch B is complete. Functional role presets, automatic equipment composition, security-door interfaces and the integrated Phase 2.5 environment remain Batches C/D.
