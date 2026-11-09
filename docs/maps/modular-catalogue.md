# Modular catalogue — Phase 2.5

## Batch A: structural expansion

Definitions live in `client/resources/level_modules/<asset>.tres`; reusable scenes live in `client/scenes/level/modules/<asset>.tscn`. The editor palette is populated from `LevelCatalogue.MODULES`. No structural generation runs during placement or play. `tools/level_authoring/build_catalogue.py` is an explicit author-time baker for the new static assets; rerunning it replaces those generated assets, so preserve manual scene edits first.

| ID | Asset | Reserved X × Z | Portals | Status |
|---|---|---|---|---|
| room01 | Room01Straight | 8 × 8 m | north/south, 3 m | Existing |
| room02 | Room02Corner | 8 × 8 m | north/east, 3 m | Existing |
| room03 | Room03TJunction | 8 × 8 m | north/east/west, 3 m | Existing |
| room04 | Room04Chamber | 8 × 8 m | all four edges, 3 m | Existing |
| room05 | Room05XJunction | 8 × 8 m | all four edges, 3 m | Batch A |
| room06 | Room06WideStraight | 8 × 8 m | north/south, 6 m | Batch A |
| room07 | Room07WideCorner | 8 × 8 m | north/east, 6 m | Batch A |
| room08 | Room08WideJunction | 8 × 8 m | all four edges, 6 m | Batch A |
| room09 | Room09WidthAdapter | 8 × 8 m | north 3 m, south 6 m | Batch A |
| room10 | Room10LongChamber | 8 × 16 m | north/south; east_00/01, west_00/01, 3 m | Batch A |
| room11 | Room11LargeChamber | 16 × 16 m | north/south/east/west _00/01, 3 m | Batch A |
| gallery_24 | Gallery24 layout | 8 × 24 m | Three straight instances; open internal connections | Batch A |
| room13 | Room13SpecialHall | 16 × 24 m | north/south _00/01; east/west _00/01/02; east_01 6 m, others 3 m | Batch A |

`Gallery24` is `res://resources/levels/Gallery24.tres`, an ordinary reusable layout template, not duplicated corridor geometry. Open it in the editor and Save under a different name to extend it. The width adapter uses a narrow neck opening onto a wider landing; it has no raised threshold. Wide T configurations use Room08WideJunction with one socket capped, without duplicate collision.

New modules reserve bounds beginning at local (-4, -0.2, -4); their origin is the first cell centre. Width/depth extend in positive local X/Z. This preserves the existing 8 m placement grid. All clear heights are 3.4 m; portal height is 2.8 m. The 6 m family is `wide_passage`; the existing 3 m family remains `passage`. Use an adapter between these families. Exact transforms and dimensions, rather than grid proximity, determine compatibility.

Select a prefab, R to rotate, click to place. Larger footprint previews and room hit-testing use rotated resource bounds. For example, Room10's east_00 and east_01 can each connect to an independent 8 m corridor cell.

### Connections

New ordinary corridor-to-corridor links default to `open`; chamber entrances default to `door`. Definitions may declare `connection_default` as auto/open/door. A door preference takes priority over an open preference; auto uses corridor tags. Existing serialized choices remain unchanged by automatic linking, including explicitly authored open passages.

Click a connected socket marker, then **Open passage** or **Standard door**. This is undoable and does not move rooms. Full validation still checks enclosure and navigation. Existing automatic-door example resources retain their authored doors. In 3D use E near a door.

### Verification

Run `python3 tools/run_godot_tests.py test_modular_catalogue test_modular_level test_modular_editor test_modular_doors --timeout 180`.

The catalogue suite validates every archetype at four rotations, each socket's navigation route, independently attached corridor entrances, and player/friendly/Jaffa capsule traversal in both directions. It also covers multi-cell mouse selection, adjacent independent entrances, overlap rejection, preserved explicit connection choices and layout persistence.

### Remaining batches

Batch B adds the 4 m ramp, per-socket deck bindings, vertical enclosure checks, transport chamber and equipment shell. Batch C adds functional presets and security-door interfaces. Batch D supplies the integrated demonstration and final full regression run. These are not delivered by Batch A; SGC and multiplayer implementations remain unchanged.
