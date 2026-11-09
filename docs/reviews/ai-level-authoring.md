# Phase D.5 verification and authoring benchmark

The shared CLI authored three native layouts from the briefs in `docs/maps/briefs/`, using the existing structural catalogue and room presets. All requested faction themes resolve safely to neutral visuals. No new geometry, faction artwork, missions or AI behaviour was introduced.

| Brief / saved layout | Instances | Functional presets | Authoring CLI calls | Layout repairs | Code changes during measured run |
|---|---:|---|---:|---:|---|
| `ai_neutral_installation.tres` | 5 | barracks, security control, cargo | 7 | 0 | Preview shutdown cleanup; theme registry caching |
| `ai_goauld_compound.tres` | 6 | ring transport, generator | 5 | 0 | None |
| `ai_asgard_ship.tres` | 5 | command, laboratory/medical, ring transport | 5 | 0 | None |

Each run included catalogue discovery, one transactional authoring request, strict validation, navigation build and graphical capture. The first neutral capture exposed a renderer/coroutine shutdown leak; two capture retries followed shared cleanup changes, plus one direct Godot diagnostic invocation. No layout request needed repair. Later visual inspection found overview clipping on the larger maps. The shared camera was corrected and all three were recaptured in three additional CLI calls. Those integration verification calls are separate from the table's measured authoring runs.

The machine-readable [benchmark](ai-level-authoring-benchmark.json) records calls, timings where retained, repair scope and generated paths. Initial neutral timings and per-layout agent tokens are unavailable and explicitly null. Counts do not include the tool calls used to develop the pipeline. This demonstrates data authoring after the shared fixes; it does not claim zero toolchain work was needed to implement the milestone.

The `.tres` layouts under `client/resources/levels/` are checked in. Request JSON was disposable and is not a runtime dependency. Derived scenes and navigation resources live in Godot's `user://` directory; captures live in ignored `build/authoring-benchmark/`. Recreate outputs through the CLI instead of committing baked duplicates.

## Launch and manual UAT

From the base checkout, use Godot 4.4.1:

```sh
python3 tools/level_authoring.py prepare
python3 tools/level_authoring.py preview --layout res://resources/levels/ai_neutral_installation.tres
python3 tools/level_authoring.py preview --layout res://resources/levels/ai_goauld_compound.tres
python3 tools/level_authoring.py preview --layout res://resources/levels/ai_asgard_ship.tres
```

Launch one at a time and close its window before continuing. Preview uses the existing player controller; WASD moves and E operates an unlocked door. No hostile mission starts. Captures use `preview --layout ... --capture /tmp/overview.png`. Each captured overview was inspected after correcting framing.

For native authoring, open `client/project.godot`, enable **Modular Map Editor** under Project Settings → Plugins, open its **Modular Map** bottom panel and load the same `.tres` resource. The CLI and editor share that file.

Manual UAT checklist (human traversal remains to be signed off):

- Open each map, verify placements and links, save/reopen without losing presets, themes or endpoints.
- Inspect the map default theme and confirm requested Goa'uld/Asgard themes report neutral fallback through CLI `inspect`.
- Change a room's appearance, then move/undo/redo in the editor; structure, role and theme metadata must survive.
- Validate, rebuild and preview. Walk from entry to destination, through both compound branches and each functional room. Exercise operable doors and inspect floor/ceiling joins.
- Confirm existing SGC Defense and SGC UAT still load from their normal game flow.

Automated tests cover native layout/resource persistence, deterministic transactions and rollback, theme precedence and structural isolation, live catalogue freshness, actual navigation through all three demos and packed-scene reload. The full strict runner includes existing SGC and multiplayer coverage. Headless checks and rendered overviews are not a claim that mouse-driven editor UAT has been completed.

## Limits

All five faction definitions currently use neutral fallback. Themes may supply cosmetic scenes/materials only; dimensions, collision, decks, sockets and navigation remain structural. Unsafe scripted/physics visuals fail validation, and unavailable or mismatched visual assets retain generic geometry. Theme overrides are available through typed resources/CLI and the native Inspector; no additional theme-picker dock was built. Transport areas reuse idle rings, including the explicitly accepted Asgard substitute; no Asgard beaming or mission logic is implied.

Batch C is present; its PR #34 is merged. Batch D's broader integrated construction fixture was not present and is not silently substituted by these three small D.5 authoring demonstrations. Existing authored maps, editor settings, modified structural resources and the Main scene were preserved byte-for-byte and excluded from these commits.
