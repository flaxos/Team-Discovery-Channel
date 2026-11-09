# Visual modular map editor — Phase 2

Requires Godot 4.4.1 and the Phase 1 room kit. This plugin edits the existing `LevelLayout` resource; it does not create another graph format or modify SGC missions.

## Enable and open

Open the `client/` project in Godot. In **Project → Project Settings → Plugins**, enable **Modular Map Editor**. Click the **Modular Map** bottom-panel tab and drag its upper edge upward if needed. The initial path is `res://resources/levels/editor_demo.tres`; click **Open** to inspect the eight-instance example built through the canvas mouse-event workflow using all four archetypes.

## Author a map

- Select a prefab in the palette, hover over the canvas for an overlap-colored footprint/socket preview, and left-click to place. The grid is 8 m; **R** rotates the placement preview before placement.
- Choose **Select / Move**, click a room to select, and drag/release to move it on the grid. **Rotate (R)** rotates the selected room. Selected sockets show their stable IDs; hover a socket for `instance/socket` text.
- Choose **Connect sockets**, click the fixed room's socket, then the moving room's socket. This calls Phase 1 `LevelAssembler.snap`, which may reposition/rotate the second room. When sockets coincide, the second click selects the other endpoint. Compatibility and existing connection constraints take precedence over the grid.
- Invalid edits display errors and leave the prior layout intact. Connected-room moves/rotations are rejected if they invalidate any connection. Use **Disconnect selected** explicitly before moving an attached room; this is undoable. **Remove room + links** explicitly removes the room and incident links together.
- Select a room and use **Entry** or **Destination** to assign required endpoint markers. New rooms receive stable generated IDs; all four archetypes use Phase 1 named markers.
- Middle-mouse drag pans; mouse wheel zooms around the cursor. Green lines show connections, amber dots show sockets, selection has a white outline, and errors containing room IDs highlight those rooms red. Errors also appear in the scrollable results panel. ESC cancels placement/connection gestures.
- Use the editor's standard **Undo/Redo** commands (Edit menu / Ctrl+Z and the configured redo shortcut). Each accepted layout edit uses `EditorUndoRedoManager`; rejected edits do not enter history. View pan/zoom is not a layout edit.

Incomplete/disconnected maps are permitted during editing. **Validate**, **Rebuild** and **Preview 3D** require the full Phase 1 graph, enclosure and entry/destination navigation checks.

## Save, build and walk

Enter a `.tres` filename under `res://resources/levels/` and click **Save**. Save before New/Open; unsaved changes block those operations rather than being discarded. Save before closing/disabling the plugin. Reopen the saved resource to retain placements, turns, decks and socket connections. The same resource works with the [Phase 1 CLI and AI interface](modular-levels.md).

**Validate** runs Phase 1's headless builder asynchronously using an immutable snapshot. **Rebuild** additionally exports `res://scenes/level/EditorPreview.tscn` and its navigation resource. Those are generated, ignored preview artifacts; the authored `.tres` remains the source of truth. The export embeds its layout so temporary build snapshot cleanup cannot break the scene. Builds time out after 60 seconds; details are returned in the results panel.

**Preview 3D** rebuilds and launches the preview scene using the existing player controller. WASD/arrows move; mouse/right-click aim follows the existing controls. Roof visuals are hidden for a cutaway; ceiling collision remains active. There are no automatic enemies or mission progression. Rebuild creates scene instances of the existing four archetypes.

## Verification and manual UAT

`test_modular_editor` drives canvas mouse-event handlers to place eight instances, connect all archetypes, move/rotate, reject overlap/broken connections, undo/redo, remove/restore, save/reload and build a navigation path. `test_modular_level` supplies continuous production player/friendly/Jaffa capsule coverage. Native editor verification separately exercises plugin activation, `EditorUndoRedoManager` history and headless rebuild. Automated events are not certification of mouse-driven usability.

Manual checklist:

1. Enable the plugin, open the example, pan/zoom and inspect selection, socket IDs and connection lines.
2. Start a new saved layout. Mouse-place at least eight rooms using all archetypes; rotate a preview and move/rotate an unconnected room.
3. Try an overlap and an incompatible/reused connection. Confirm readable errors, red highlighting and unchanged data. Correct the placement and connect compatible sockets.
4. Try moving a connected room. Confirm rejection preserves links; explicitly disconnect it, move it, then undo/redo both actions.
5. Remove a room with links and undo. Assign entry/destination, save, close/reopen the resource and verify all poses and connections.
6. Validate an incomplete map and correct the reported problem. Rebuild a complete map, inspect PackedScene instances and launch Preview 3D.
7. Walk entry to destination and the optional branch. Check corners, floor joins, caps and ceilings. Confirm the SGC lobby/missions remain unaffected.

## Limits

Initial palette is the existing four archetypes on `deck0`; no deck-management UI, custom ID/property inspector, procedural generation, new architecture/art, doors/alarms, mission creation or generic enemy behavior is added. Multiple simultaneous build jobs are blocked. The bottom panel may need resizing or horizontal palette scrolling on narrow screens. Saved-state indication is conservative after Undo/Redo: save again when prompted. Structural enclosure remains a sampled physical check, not a rendering proof.


## Delivery evidence

Phase 2 was implemented on `feat/visual-modular-editor`, based on merged Phase 1 at `62a781a`. The full Godot 4.4.1 inventory passed **53/53 checks** (`build/test-results/phase2-full/`). Targeted canvas/layout checks passed (`phase2-target-final/`), followed by the extended snapshot-deletion/export-reload test (`phase2-export-final/`). Native editor activation, editor Undo/Redo history, headless rebuild and the Preview 3D play/stop action were exercised, and a Forward+ editor-panel capture was inspected. The player preview boots without script/engine errors. These automated checks do not replace the manual checklist above.

The only Phase 1 implementation change embeds the input layout when packing an exported scene, avoiding a dependency on temporary editor build snapshots. SGC maps, missions, networking and NPC controllers are unchanged. Preview artifacts are ignored; `editor_demo.tres` is the persisted GUI-built eight-room example.
