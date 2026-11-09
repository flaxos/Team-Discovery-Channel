# Modular room pipeline — Phase 1 delivery

Base: `6ef5e97`; branch: `feat/modular-room-scaffolding`. Engine: Godot 4.4.1. This is the neutral reusable room scaffolding milestone, not a Goa'uld level or a new mission.

## Implementation

Four PackedScene archetypes (straight, corner, T and chamber) share typed module/socket/instance/connection/layout resources. The eight-instance fixture repeats all four scenes. Shared socket snapping derives horizontal translation and quarter-turn yaw, validates compatibility/overlap and rolls rejected placements back. Unused portals are capped; connected caps derive from serialized connections on load.

The assembly exposes minimal Inspector capture, snap, rebuild and validate/bake actions and a matching headless builder. It owns its navigation map and uses existing capsule clearance settings. Structure, visual meshes, markers and attachments remain separate. The preview uses the existing player controller without starting SGC or enemy activation.

## Preservation and confirmed corrections

The interrupted implementation was already partly preserved at `d946588`; remaining resources and docs were preserved at `d220152` before corrections. Three unrelated untracked files were excluded throughout.

Resume verification reproduced two defects and added regression coverage: uncaptured live scene poses could be validated against stale resource data, and PackedScene reload restored closed archetype caps despite saved connections. Validation now rejects pose/closure disagreement and load derives cap state from the saved layout. Readiness is cleared before a new validation attempt. No SGC map, generator, mission, NPC controller or network files changed.

## Validation

- Existing interrupted full report: 52/52 passed; inspected rather than inferred from a banner.
- Expanded `test_modular_level`: passed with strict project import. Covers rotation, rollback, negative layouts, removed caps/floors/ceilings, layout/scene persistence, all four Inspector action callables, reopened scene execution and continuous traversal in both directions with production player/airman/Jaffa capsules.
- Five CLI cases passed: validate, build/save, missing value, unknown option, protected SGC output rejection.
- Godot headless editor loaded `ModularSmoke.tscn` without errors. Inspector action callables were exercised programmatically; this is not a claim of manual mouse-driven editor UX acceptance.
- Forward+ preview regenerated and inspected after the reload correction; no engine/script errors in its log.
- Final integration: **52/52 checks passed**, with strict import, no exclusions and unchanged SGC/mission/multiplayer regressions.
- Local documentation links and Git whitespace checks pass.

Evidence: `build/test-results/modular-resume-reload/`, `build/test-results/modular-phase1-final/`, `/tmp/modular-resume-cli.json`, `/tmp/modular-resume-editor.log`, `/tmp/modular-resume-visual2.log` and `/tmp/modular-overview.png`. Build/test artifacts are local, ignored output; regenerate them rather than treating these paths as portable repository content.

## Launch and authoring

From the repository root:

```sh
godot --path client --script res://tests/support/modular_level_preview.gd
```

To inspect native scene instances, open `client/scenes/level/ModularSmoke.tscn` in the Godot editor. The preview is a roof cutaway; ceiling collision remains active. See [the authoring guide](../maps/modular-levels.md) for creating a module, manual instancing/capture/snapping, typed AI authoring, CLI builds and navigation validation.

## Remaining limitations / next increment

**PHASE 1 COMPLETE** for the approved scaffolding and minimum validation pipeline. No confirmed failing Phase 1 defect remains after targeted fixes and full integration. Enclosure is sampled physical validation, not a material-opacity proof. Minimal Inspector actions do not provide Undo/Redo or a custom dock. Runtime validation rebakes navigation; a content-hash cache is not implemented. NPC behavioral adapters, locks/alarms, multiplayer mission integration, vertical modules and Goa'uld dressing are deferred. Native editor pointer-click UX and human game-feel review remain review tasks.

Stop after this milestone. Recommended next increment, only after approval: Phase 2 authoring ergonomics and Undo/Redo.

## Complete file manifest

All changes relative to the base, including Godot UID companions:

- `client/resources/level_modules/Room01Straight.tres`
- `client/resources/level_modules/Room02Corner.tres`
- `client/resources/level_modules/Room03TJunction.tres`
- `client/resources/level_modules/Room04Chamber.tres`
- `client/resources/levels/modular_smoke.tres`
- `client/resources/levels/modular_smoke_navigation.res`
- `client/scenes/level/ModularSmoke.tscn`
- `client/scenes/level/modules/Room01Straight.tscn`
- `client/scenes/level/modules/Room02Corner.tscn`
- `client/scenes/level/modules/Room03TJunction.tscn`
- `client/scenes/level/modules/Room04Chamber.tscn`
- `client/scripts/level/LevelAssembler.gd`
- `client/scripts/level/LevelAssembler.gd.uid`
- `client/scripts/level/LevelAssembly.gd`
- `client/scripts/level/LevelAssembly.gd.uid`
- `client/scripts/level/LevelEnclosureValidator.gd`
- `client/scripts/level/LevelEnclosureValidator.gd.uid`
- `client/scripts/level/LevelLayout.gd`
- `client/scripts/level/LevelLayout.gd.uid`
- `client/scripts/level/LevelLayoutValidator.gd`
- `client/scripts/level/LevelLayoutValidator.gd.uid`
- `client/scripts/level/LevelModule.gd`
- `client/scripts/level/LevelModule.gd.uid`
- `client/scripts/level/LevelModuleConnection.gd`
- `client/scripts/level/LevelModuleConnection.gd.uid`
- `client/scripts/level/LevelModuleDefinition.gd`
- `client/scripts/level/LevelModuleDefinition.gd.uid`
- `client/scripts/level/LevelModuleInstance.gd`
- `client/scripts/level/LevelModuleInstance.gd.uid`
- `client/scripts/level/LevelNavigation.gd`
- `client/scripts/level/LevelNavigation.gd.uid`
- `client/scripts/level/LevelSocketDefinition.gd`
- `client/scripts/level/LevelSocketDefinition.gd.uid`
- `client/scripts/level/build_level.gd`
- `client/scripts/level/build_level.gd.uid`
- `client/tests/support/modular_level_preview.gd`
- `client/tests/support/modular_level_preview.gd.uid`
- `client/tests/test_modular_level.gd`
- `client/tests/test_modular_level.gd.uid`
- `docs/README.md`
- `docs/TESTING.md`
- `docs/maps/modular-levels.md`
- `docs/reviews/modular-phase1.md`
