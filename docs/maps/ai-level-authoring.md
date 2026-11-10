# Shared AI-native level authoring guide

This is the authoritative workflow for Codex, Claude Code and Antigravity. All three use the same local CLI and native Godot resources. Routine level creation should not require reading implementation scripts.

Run commands from the repository root. Use Godot 4.4.1 and Python 3; no MCP server or additional Python packages are needed. `GODOT` or `--godot` can select the installed engine binary.

## Start with discovery

```sh
python3 tools/level_authoring.py prepare
python3 tools/level_authoring.py catalogue --search 'barracks'
python3 tools/level_authoring.py catalogue --kind preset --search 'command center'
python3 tools/level_authoring.py catalogue --kind module --search 'adapter' --detail
python3 tools/level_authoring.py catalogue --kind theme
python3 tools/level_authoring.py catalogue --kind composite --detail
```

Compact results contain stable IDs, human descriptions/synonyms, footprints, connectors, supported roles and theme identifiers. Detailed results include occupied bounds, actual marker/attachment branches, socket transforms and elevation offsets, equipment clearances, functional components, visual slots, placement constraints and required validation capabilities. Source definitions and scenes are read directly; discovery does not instantiate gameplay scenes. The CLI can discover newly added resources without editing a filename index.

```sh
python3 tools/level_authoring.py catalogue --detail --output build/level-catalogue.json
python3 tools/level_authoring.py catalogue --verify build/level-catalogue.json
```

The JSON is a generated snapshot, never a second geometry source. Verification rejects changed dimensions, metadata or source fingerprints. Regenerate it after source changes. Semantic metadata is stored as typed resource data; dimensions, sockets and eligible presets are derived from real module/preset/theme resources. Existing historical Markdown tables are explanatory; use the live catalogue for authoring decisions.

## Translate a brief into a graph

1. Separate physical requirements, room purposes and appearance. “Asgard bridge” means a suitable command-room shell/preset plus `asgard` theme; it does not imply an implemented Asgard transport or gameplay system.
2. Discover compatible presets first, then choose a structural module from each preset's `modules`. Check entrances, reserved volume, equipment clearance and deck requirements. A larger footprint alone does not guarantee that a preset clears its doorway arrangement.
3. Sketch named room instances and connection edges. Include an entry, destination, optional branches and each required room purpose. Use stable instance IDs, not guessed world coordinates.
4. Place the first module at a deliberate seed position. Grow the graph with `place.attach`, which aligns named sockets and computes the translation/quarter turn. Use a width adapter when connector families differ. Grid adjacency alone is not a connection contract.
5. For vertical routes, create the required deck elevations and bind the elevated sockets. A fixed-rise ramp cannot be stretched to satisfy arbitrary heights. Transport pairing is separate from continuous walking navigation.
6. Choose the map's default theme; add sparse room or zone exceptions only when needed. Faction artwork may be unavailable and must be reported as neutral fallback.
7. Validate/build, inspect structured failures, repair the data and walk/preview the result. Do not change engine code merely to make a routine brief pass.

Unsupported mechanics, assets or structural shapes must be reported explicitly. Examples: outdoor terrain, Asgard-specific beaming, enemy patrol decisions, mission directors, access cards and full alarm systems are not implied by a theme or marker. Reuse a declared neutral substitute only when it meets the brief's physical/purpose requirements, and state that substitution.

## Create or edit a native layout transactionally

Write a disposable request outside the saved map, for example `/tmp/level-request.json`:

```json
{
  "version": 1,
  "create": {"theme_id": "neutral", "decks": {"deck0": 0}},
  "operations": [
    {"op": "place", "id": "store", "module_id": "room04", "preset_id": "cargo", "at": [0, 0]},
    {"op": "place", "id": "barracks", "module_id": "room04", "preset_id": "jaffa_barracks",
     "attach": {"socket": "north", "target": "store", "target_socket": "south"}},
    {"op": "endpoint", "kind": "entry", "id": "store"},
    {"op": "endpoint", "kind": "destination", "id": "barracks"}
  ]
}
```

```sh
python3 tools/level_authoring.py apply --request /tmp/level-request.json --output res://resources/levels/my_installation.tres
python3 tools/level_authoring.py inspect --layout res://resources/levels/my_installation.tres
```

For an existing map omit `create` and provide `--layout`. Updating an existing destination requires explicit `--overwrite`:

```sh
python3 tools/level_authoring.py apply --layout res://resources/levels/my_installation.tres --request /tmp/edits.json --output res://resources/levels/my_installation.tres --overwrite
```

Every operation uses the existing typed resources, assembler and validators. A failed operation rejects the whole request; earlier operations are not saved. Existing layout bytes remain unchanged on failure, and successful replacement preserves an existing resource UID. Saves are staged and renamed. Explicit links and connection classifications are retained unless a request specifically changes/removes them. Do not manually maintain a JSON graph alongside the `.tres`; discard the request once saved. Layouts remain editable in the native Godot editor and previous tools.

Instance IDs must be unique and node-safe. `at` is horizontal `[x,z]`; attachment `at` is local `[x,y,z]`. `turn` is a quarter-turn integer, while attachment `yaw` is degrees. Placement does not round arbitrary coordinates: named socket alignment is authoritative. The catalogue exposes the editor's visual grid separately.

### Operation reference

| Operation | Required / optional fields | Behaviour |
|---|---|---|
| `place` | `id`, `module_id`; `at` or `attach`; optional `deck`, `turn`, `preset_id`, `socket_decks`, `auto_connect` | Create a scene instance. `attach` has `socket`, `target`, `target_socket`, optional `type`. Its socket pose determines placement. |
| `move` | `id`, `at`; optional `turn`, `auto_connect` | Preserve existing links; reject a move that invalidates one. |
| `connect` | `from`, `from_socket`, `to`, `to_socket`; optional `type`, `security_id`, `initially_locked` | Record a compatible coincident join without moving either room. Never overwrite an existing connection. |
| `snap` | `moving_instance`, `moving_socket`, `target_instance`, `target_socket`; optional `type` | Use the same deterministic socket solver as the editor. Invalid placement rolls back. |
| `connection` | Four endpoint fields above; optional `type`, `security_id`, `initially_locked` | Explicitly change an existing link. Types: `open`, `door`, `security_door`. |
| `connect_touching` | No other fields | Link matching unused touching doorways without changing existing choices. |
| `disconnect` | Four endpoint fields | Explicitly remove exactly that connection. |
| `remove` | `id`; optional `remove_links` | Connected-room removal requires `remove_links: true`. |
| `configure` | `id`, `preset_id` | Change the functional preset without changing structure. Empty preset ID clears it. Retain overrides by attachment ID. |
| `attachment` | `id`, `attachment_id`; optional `at`, `yaw`, `disabled`, `reset` | Override/reset a content attachment. Required attachments cannot be disabled; inactive overrides remain stored. |
| `theme` | `scope`, other fields described below | Assign map, room or zone appearance. |
| `deck` | `id`, `elevation`, or bulk `elevations` object | Create/update deck metadata. Use bulk updates when linked deck elevations must move together. |
| `bind_socket` | `id`, `socket`, `deck` | Explicit deck binding with world-height validation. |
| `endpoint` | `kind` (`entry`/`destination`), `id`; optional `marker` | Choose required path endpoints. New placement never overwrites an already chosen endpoint. |
| `composite` | `composite_id`, `prefix`, `at`; optional `turn`, `deck_map` | Expand a template into ordinary instances with prefixed stable IDs and retained internal links. Grow further rooms from its exposed named sockets. |
| `transport` | `id`, `endpoint_id`, `target_id`; optional `target_instance`, `kind`, `anchor`, `node_path` | Declare transport metadata. `target_instance` creates a reciprocal pair atomically. Ring preset defaults point at the discovered ring attachment; elevators remain metadata-only. |

`auto_connect` defaults true on placement/movement, consistent with the editor. Existing explicit choices remain unchanged. Defaults come from module connection preferences; security doors are explicit. Incomplete/disconnected layouts remain editable, but full build requires connectivity, enclosure, navigation and required approaches. Creating a room defaults empty endpoints to that first room; choose meaningful endpoints explicitly before publication.

Only a currently declared attachment can be edited; `reset` also removes a stored override. A component may reserve an operating volume without making that whole volume solid. Full validation checks actual movement collision and navigation, not just declared boxes.

## Themes and visual safety

Recognised initial IDs: `neutral`, `tauri_sgc`, `goauld`, `asgard`, `tokra`, `replicator`. Faction definitions contain semantic intent and valid neutral palette/fallback references; detailed faction art is absent. Inspect/build results report both the requested theme and the effective visual source.

```json
{"operations": [
  {"op":"theme", "scope":"map", "theme_id":"goauld"},
  {"op":"theme", "scope":"zone", "zone_id":"command_zone", "theme_id":"asgard", "instances":["bridge"]},
  {"op":"theme", "scope":"room", "id":"store", "theme_id":"neutral"}
]}
```

Precedence: legacy explicit `instance.theme` resource → explicit `theme_id` → non-neutral legacy `style` → assigned zone → map default → neutral/generic. An unregistered legacy style remains loadable with neutral fallback. Unknown explicit new theme IDs fail with discovery guidance. A room `theme` operation replaces its old explicit resource/style override; `inherit: true` clears those overrides and resumes zone/map inheritance. Supplying a room `zone_id` assigns it; an empty value clears its zone. Zone membership exists only on each instance, not in a parallel coordinate database.

`LevelVisualTheme` declares ID/display name, semantic description/synonyms, material and typed lighting palettes, compatible module families, fallback ID, typed visual variants and future detail slots. `LevelThemeVariant` targets a generic slot or exact visual-slot ID, optionally limited to specific module IDs. Missing soft scene references resolve to existing generic geometry. Oversized or undersized primary replacements fall back rather than exposing holes. Variant scenes may contain only cosmetic nodes and no scripts, signal connections, collision or navigation nodes. Slot replacement changes only visuals; original collision, footprint, decks, sockets and navigation stay intact. Material-only changes do not require rebaking.

Room/zone overrides are optional. Existing `style` and material-theme resources remain compatible. Native resource Inspector fields expose the same data; save and reopen the resource in the modular editor after external edits. The preview uses the map lighting palette. No complete faction structural scenes are duplicated.

## Validate, repair, build and preview

```sh
python3 tools/level_authoring.py validate --layout res://resources/levels/my_installation.tres
python3 tools/level_authoring.py build --layout res://resources/levels/my_installation.tres --output user://my_installation.tscn --nav-output user://my_installation_navigation.tres
python3 tools/level_authoring.py preview --scene user://my_installation.tscn
python3 tools/level_authoring.py preview --scene user://my_installation.tscn --capture /tmp/my_installation.png
```

`preview --layout ...` can build a temporary preview directly. Interactive preview returns its process ID and log path; close the game window when done. Captures require a graphical display, or `xvfb-run` where available. They use the existing player-preview pipeline, with a roof-visual cutaway for the overview and physical ceilings retained. No enemies or missions are started. CLI caches live in `user://`; exported scenes embed their input layout, so discarded request/snapshot files cannot break them.

Commands print one JSON response and use a nonzero exit code for failure. Errors contain `code`, `reason`, affected `instance_ids`, `socket_ids`, an operation index where relevant, and a suggested `remedy`. Engine diagnostics are included when a command cannot return normally. Common repairs:

- **Overlap / misaligned sockets:** use a compatible named attachment or snap; do not guess corrective coordinates or discard links.
- **Wrong corridor family:** select the declared width adapter.
- **Disconnected region:** explicitly connect matching available sockets and inspect endpoints.
- **Deck mismatch:** create matching elevations/bindings; choose geometry with the required rise.
- **Blocked preset approach:** reset/move the attachment through the same API or choose a compatible shell.
- **Locked security isolation:** unlock it or supply an accessible alternate route. Runtime lock changes need an explicit navigation rebuild when appropriate.
- **Unknown capability:** rediscover and report the unsupported requirement. Do not invent a prefab, role or game mode.

Layout writes are restricted to native `.tres` resources under `res://resources/levels/` or `user://`. Builds are restricted to modular scene/navigation directories or `user://`. Existing SGC map paths, structural scene assets and source layout resources are protected from build-output replacement. Builds stage both outputs before publication. Do not merge branches or overwrite user work as part of routine data authoring.

## Verification and benchmark scope

Run `python3 tools/run_godot_tests.py test_level_themes test_level_catalogue test_level_authoring test_level_demonstrations --timeout 180`. Run the existing full inventory at an integration milestone. Human UAT should open each demo in the native editor, inspect theme/fallback metadata, validate/build, and walk its entry/destination and branches with the existing player controller.

Natural-language demonstration briefs live in `docs/maps/briefs/`; their saved `.tres` maps are authoritative. Benchmark records count authoring CLI invocations (including discovery and preview), explicit validation/repair iterations, generated/modified files and whether implementation code changed during the measured data-authoring run. This is distinct from the tool calls used to implement this milestone. Agent-token consumption is null when no reliable per-layout usage meter exists; do not estimate it from file sizes.

See [the demonstration and benchmark report](../reviews/ai-level-authoring.md) for the three saved maps, measured calls, shared preview repairs, launch commands and manual UAT checklist.

For the full structural/preset integration example, use [Batch D's two-deck construction laboratory](modular-integration-demo.md), saved as `modular_integration_demo.tres` and discoverable as the `integration_lab` composite.
