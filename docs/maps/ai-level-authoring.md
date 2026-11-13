# Shared AI-native level authoring guide

This is the authoritative workflow for Codex, Claude Code and Antigravity. All three use the same local CLI and native Godot resources. Routine level creation should not require reading implementation scripts.

Run commands from the repository root. Use Godot 4.4.1 and Python 3; no MCP server or additional Python packages are needed. `GODOT` or `--godot` can select the installed engine binary.

## Fast path: describe the room graph

For a new map, three calls are normally enough. Details are in the sections below.

```sh
python3 tools/level_authoring.py catalogue --summary          # what exists, in about half the bytes
python3 tools/level_authoring.py plan --request /tmp/plan.json --output res://resources/levels/my_map.tres
python3 tools/level_authoring.py build --summary --layout res://resources/levels/my_map.tres --output user://my_map.tscn --nav-output user://my_map_navigation.tres
```

`plan` takes named rooms and the links between them. It chooses modules, positions, rotations and sockets, closes loops, and reports whether your route requirements hold. You never write a coordinate or a socket name.

## Start with discovery

```sh
python3 tools/level_authoring.py prepare
python3 tools/level_authoring.py catalogue --summary
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

### Tactical metadata

Every module and preset record carries a `tactical` block with three clearly separated sources:

| Block | Source | Examples |
|---|---|---|
| `authored` | Designer intent stored in `semantics.tres` | `gameplay_roles` (patrol_route, junction, chokepoint, objective_room, defensible_room, deck_transition …), `sightlines` |
| `derived` | Read from the module or preset resource | openings, socket families, narrowest opening, reserved area, clear height, deck rise, marker names; for presets: objective locations, cover attachments, patrol and spawn markers |
| `inferred` | Heuristic from opening count and width only | `chokepoint_potential` |

None of it is play-tested. Structural modules have marker positions but no cover props (`cover_props: 0`); only presets that list `cover_attachments` add cover. Do not describe a room as offering cover, patrols or objectives unless the derived block lists them.

## Plan from a room graph

Write a disposable plan request:

```json
{
  "version": 1,
  "theme_id": "goauld",
  "decks": {"deck0": 0, "upper": 4},
  "rooms": [
    {"id": "entry", "kind": "corridor"},
    {"id": "forecourt", "kind": "junction"},
    {"id": "west", "kind": "corridor"},
    {"id": "checkpoint", "kind": "security_checkpoint"},
    {"id": "inner", "kind": "junction"},
    {"id": "ramp", "kind": "ramp"}
  ],
  "links": [
    {"a": "entry", "b": "forecourt"},
    {"a": "forecourt", "b": "west"}, {"a": "west", "b": "inner"},
    {"a": "forecourt", "b": "checkpoint", "type": "security_door", "security_id": "front_gate", "locked": true},
    {"a": "checkpoint", "b": "inner"},
    {"a": "west", "b": "ramp"}
  ],
  "clusters": [
    {"composite_id": "generator_section", "prefix": "power", "attach_to": "inner"},
    {"composite_id": "command_section", "prefix": "cmd", "attach_to": "ramp"}
  ],
  "entry": "entry",
  "destination": "power_generator",
  "requirements": [
    {"check": "alternate_route", "from": "entry", "to": "destination", "around": "checkpoint"},
    {"check": "reachable", "from": "entry", "to": "destination", "unlocked_only": true},
    {"check": "only_via", "room": "cmd_command", "via": "ramp"}
  ]
}
```

- **`kind`** is a preset ID (the room gets that preset and its smallest compatible shell) or a structural part: `corridor`, `junction`, `wide_corridor`, `wide_junction`, `adapter`, `ramp`, `chamber`. Corridor and junction pieces are chosen by how many links the room has; a two-link corridor may come out straight or as a corner, whichever lets the map fit.
- **`size`** (`small`, `medium`, `large`) or an explicit **`module_id`** overrides the shell. **`deck`** defaults to `deck0`.
- **Links** default to the modules' normal door/open choice. `type`, `security_id` and `locked` are optional; only a `security_door` can be locked.
- **Loops** are just links that close a cycle. A room linked to both arms closes the loop.
- **Decks:** rooms on different decks must be joined through a `ramp` room. Its sockets are bound to the matching deck elevations for you.
- **Narrow and wide** passages do not join directly; put an `adapter` room between them.
- **`clusters`** hang an existing composite on a planned room. The cluster's rooms are named `<prefix>_<member>` and may be used as the destination or in requirements. `opening` optionally names which member room faces the host.
- **`transports`** takes the same fields as the `transport` operation, for pairing ring rooms.
- Omit `--output` for a dry run.

The response lists each placed room, a `topology` summary and a result per requirement. Planning is deterministic: the same request gives the same layout.

### When a plan cannot be placed

The planner never adds rooms, stretches modules or invents geometry. If the graph does not fit, it returns `plan_unplaceable` with the blocked room, the rooms placed before it, rejection counts by cause and the nearest gap in metres. Typical causes and repairs:

| Diagnosis | Repair |
|---|---|
| `loop_not_closed` / `out_of_reach` | The rooms on that loop cannot form a closed shape on the 8 m grid. Add or remove one corridor room on the loop. Loops of plain 8 m rooms need an even count. |
| `incompatible_sockets` | Add an `adapter` between narrow and wide rooms. |
| `socket_decks` / `socket_height` | Join decks through a `ramp`. |
| `occupied_overlap` | Give the crowded room fewer links, or move a branch to another room. |
| `no_module` | No existing module offers that many doorways for that kind; split the room with a junction. |
| Budget used | Simplify the loop or fix `module_id` on some rooms; `budget` can be raised to 20000. |

## Check gameplay topology

Structural validity and mission topology are separate. A linear map validates and builds; it simply fails a requirement for two routes.

```sh
python3 tools/level_authoring.py topology --layout res://resources/levels/my_map.tres
python3 tools/level_authoring.py topology --layout res://resources/levels/my_map.tres --requirements /tmp/requirements.json
```

Without requirements the command describes the graph: rooms, links, loops, separate areas, dead ends, junctions, chokepoint rooms (rooms whose removal cuts part of the map off from the entry), security doors and rooms by role. With requirements it reports each one and exits nonzero if any fails. `from`, `to` and similar fields accept a room ID, `entry` or `destination`.

| Check | Fields | Passes when |
|---|---|---|
| `connected` | — | No room is cut off from the entry |
| `distinct_routes` | `from`, `to`, `min` (default 2) | That many routes share no intermediate room |
| `alternate_route` | `from`, `to`, `around` | A route exists that avoids the `around` room |
| `reachable` | `from`, `to` | A route exists |
| `route` | `through` (list) | Each consecutive pair is reachable |
| `only_via` | `room`, `via`, optional `from` | Every way in passes through `via` (a single guarded approach) |
| `single_access` | `room`, optional `max` | The room has at most that many neighbours |
| `min_branches` | `min` | At least that many rooms have three or more neighbours |
| `dead_ends` | `allowed` (list) | The dead ends are exactly the ones you declared |
| `room_count` | `min`, `max` | Room total is in range |
| `roles` | `required` (preset → count) | Enough rooms carry each preset |

Add `"unlocked_only": true` to route checks to treat initially locked security doors as closed, and `"label"` to carry your own wording into the report. These checks count walking links only; ring transport is not a route. They say nothing about cover quality, sightlines or stealth.

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
| `place` | `id`, `module_id`; `at` or `attach`; optional `deck`, `turn`, `preset_id`, `socket_decks`, `auto_connect` | Create a scene instance. `attach` has `target`, optional `socket`, `target_socket` and `type`. Omitted sockets are chosen for you: the first free pair that fits. |
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
| `composite` | `composite_id`, `prefix`; `at` or `attach`; optional `turn`, `deck_map` | Expand a template into ordinary instances with prefixed stable IDs and retained internal links. `attach` has `target`, optional `opening` (member room, or `member/socket`), `target_socket` and `type`; it positions the whole group and adds the joining link. |
| `transport` | `id`, `endpoint_id`, `target_id`; optional `target_instance`, `kind`, `anchor`, `node_path` | Declare transport metadata. `target_instance` creates a reciprocal pair atomically. Ring preset defaults point at the discovered ring attachment; elevators remain metadata-only. |

`auto_connect` defaults true on placement/movement, consistent with the editor. Existing explicit choices remain unchanged. Defaults come from module connection preferences; security doors are explicit. Incomplete/disconnected layouts remain editable, but full build requires connectivity, enclosure, navigation and required approaches. Creating a room defaults empty endpoints to that first room; choose meaningful endpoints explicitly before publication.

Only a currently declared attachment can be edited; `reset` also removes a stored override. A component may reserve an operating volume without making that whole volume solid. Full validation checks actual movement collision and navigation, not just declared boxes.

### Composite building blocks

`catalogue --kind composite --summary` lists them with room counts, presets, roles and openings. All expand into ordinary editable rooms, inherit the map theme and keep prefixed IDs and security IDs.

| ID | Rooms | Contents |
|---|---|---|
| `barracks_wing` | 4 | Through junction, two barracks, armoury |
| `checkpoint_cluster` | 4 | Corridor, checkpoint with a security door on its far side, security control |
| `cargo_wing` | 3 | Through junction, long store, small store |
| `command_section` | 3 | Checkpoint antechamber, command room behind a security door, observation room |
| `generator_section` | 3 | Access corridor, engineering bay, generator room |
| `ring_access_wing` | 3 | Corridor, guard post, ring chamber (unpaired until a `transport` pairs it) |

`gallery_24` and `integration_lab` remain available.

## Themes and visual safety

Recognised initial IDs: `neutral`, `tauri_sgc`, `goauld`, `asgard`, `tokra`, `replicator`. Faction definitions contain semantic intent and valid neutral palette/fallback references; detailed faction art is absent. Inspect/build results report both the requested theme and the effective visual source. What each theme slot renders today, and the target for the first Goa'uld pieces, is in the [Goa'uld visual brief](goauld-visual-brief.md).

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

Run `python3 tools/run_godot_tests.py test_level_themes test_level_catalogue test_level_authoring test_level_demonstrations test_level_planning --timeout 240`. Run the existing full inventory at an integration milestone. Human UAT should open each demo in the native editor, inspect theme/fallback metadata, validate/build, and walk its entry/destination and branches with the existing player controller.

Natural-language demonstration briefs live in `docs/maps/briefs/`; their saved `.tres` maps are authoritative. Benchmark records count authoring CLI invocations (including discovery and preview), explicit validation/repair iterations, generated/modified files and whether implementation code changed during the measured data-authoring run. This is distinct from the tool calls used to implement this milestone. Agent-token consumption is null when no reliable per-layout usage meter exists; do not estimate it from file sizes.

See [the planning benchmark](../reviews/ai-level-authoring-2.md) for the before/after comparison on three briefs, and [the earlier demonstration and benchmark report](../reviews/ai-level-authoring.md) for the three saved maps, measured calls, shared preview repairs, launch commands and manual UAT checklist.

For the full structural/preset integration example, use [Batch D's two-deck construction laboratory](modular-integration-demo.md), saved as `modular_integration_demo.tres` and discoverable as the `integration_lab` composite.
