# Sprint 6 — Goa'uld corridor kit

18 November 2026. Baseline main `08aed27` after merged #76; supplied checkout,
branch `feat/sprint6-goauld-corridor-kit`. [Brief](../maps/briefs/goauld-corridor-expansion.md),
[kit guide](../maps/goauld-theme-kit.md).

## Result and recovery

The kit now covers `room01`–`room09`: the original straight corridor and compact
chamber, plus the narrow corner, T-junction, X-junction, wide straight, wide corner,
wide junction and width adapter. There are **106 variants using 41 shared piece
scenes**. Native compound coverage increases from **8 to 14 of 20 rooms**; the gate,
generator, command room, ramp and two ring rooms retain palette-only coverage.

Recovered the theme generator and its Python/Godot checks from mixed commit
`e72ff28`, without its navigation or weapon changes. Retained the unfinished
`room05`/`room08` junction entries from the existing historical checkout. Its later
chamber/tall-room and mission work remains there. All **46 dirty paths** retained
the same names and byte hashes after recovery; the source checkout was untouched.
[Recovery record](sprint6-goauld-corridors/recovery.json). Raw manifests/logs remain
under ignored `build/`.

Three finishing changes were needed:

1. Deriving a floor runner from each slab's long axis left breaks at corners and
   junction branches. Connected runner arms now follow the actual headers and are
   clipped/tiled into disjoint floor boxes. Heights and physical floors stay fixed.
2. Basalt end caps conflicted with perpendicular bronze/gold faces. The finish now
   wraps through corner and jamb reveals, removing the observed dotted seams.
3. R21's offset headers can expose the back of a neighbouring lintel. Both faces
   now carry the gold block/band, standing 5 mm proud above the opening within the
   existing slot tolerance. Structural header offsets remain separate debt.

The original module scenes, production layout, palette, lighting, collision,
sockets, markers, navigation and cover remain unchanged. No runtime gameplay or
external asset was added. The CLI-authored nine-room
[`goauld_corridor_gallery.tres`](../../client/resources/levels/goauld_corridor_gallery.tres)
joins every supported type for review, including narrow/wide interfaces.

## Verification

- `test_goauld_theme`: every native slab applies without fallback; gold stays above
  door height, floors are flat and relief faces inward. All nine definitions apply
  under all four rotations without collision changes. Both the production
  compound and connected gallery match neutral collision, navigation vertices and
  polygons, module/socket/marker poses and cover.
- `tools/tests/test_theme_kit.py`: generated output is current; boxes have positive
  dimensions, disjoint volume and closed coverage; ceiling edges stay flush;
  runner bands reach every corridor branch; reveals and both lintel faces carry
  the intended finish. The original palette/armour rules remain enforced.
- Targeted theme, catalogue, authoring, demonstrations and planning suites passed.
  Final lintel changes passed strict import plus theme/theme-system/demonstration
  checks separately. Python tooling passed **51 tests**. The pull request records
  the final full local run and hosted results.
- CLI compound validation reports **14 pieces / 6 palette**, no warnings. Gallery
  planning, build, navigation and marker/enclosure validation pass, with all nine
  rooms pieced and an entry-to-destination route. Native structural/layout bytes
  are unchanged from baseline.

## Captures

All 26 delivered images were inspected. Interior shots use Godot 4.4.1 Forward+
at 1280×720 under the mission's existing white ambient/directional lighting.
`_ga1` reconstructs GA-1 coverage in private resource copies: only the original
two module types have pieces. `_jaffa` adds stationary alerted guards to inspect
armour and marker readability. No structural geometry is hidden in these shots.

| Shape | GA-1 coverage | Finished | With Jaffa |
| --- | --- | --- | --- |
| Narrow corner | [Before](sprint6-goauld-corridors/narrow_corner_ga1.png) | [After](sprint6-goauld-corridors/narrow_corner.png) | [Guard](sprint6-goauld-corridors/narrow_corner_jaffa.png) |
| T-junction | [Before](sprint6-goauld-corridors/t_junction_ga1.png) | [After](sprint6-goauld-corridors/t_junction.png) | [Guard](sprint6-goauld-corridors/t_junction_jaffa.png) |
| Wide corner | [Before](sprint6-goauld-corridors/wide_corner_ga1.png) | [After](sprint6-goauld-corridors/wide_corner.png) | [Guard](sprint6-goauld-corridors/wide_corner_jaffa.png) |
| Width adapter | [Before](sprint6-goauld-corridors/adapter_ga1.png) | [After](sprint6-goauld-corridors/adapter.png) | [Guard](sprint6-goauld-corridors/adapter_jaffa.png) |
| Wide straight | [Before](sprint6-goauld-corridors/wide_straight_ga1.png) | [After](sprint6-goauld-corridors/wide_straight.png) | [Guard](sprint6-goauld-corridors/wide_straight_jaffa.png) |
| X-junction | [Before](sprint6-goauld-corridors/cross_junction_ga1.png) | [After](sprint6-goauld-corridors/cross_junction.png) | [Guard](sprint6-goauld-corridors/cross_junction_jaffa.png) |
| Wide junction | [Before](sprint6-goauld-corridors/wide_junction_ga1.png) | [After](sprint6-goauld-corridors/wide_junction.png) | [Guard](sprint6-goauld-corridors/wide_junction_jaffa.png) |

Connected [narrow](sprint6-goauld-corridors/narrow_join.png) and
[wide](sprint6-goauld-corridors/wide_join.png) lintels show the reverse-face fix.
The [gallery overview](sprint6-goauld-corridors/gallery_overview.png) is the CLI's
roof cutaway; physical ceilings remain in the built scene.

The controlled native mission uses the production player camera at a close TPS
zoom, existing HUD and ordinary held-ADS movement. Hostiles are stood down and
parked in the barracks; no environmental geometry is hidden. The operative walks
over 2 m on the original floor. [Before](sprint6-goauld-corridors/native_tps.png),
[after walking](sprint6-goauld-corridors/native_tps_after_walk.png),
[raw positions](sprint6-goauld-corridors/native_walk.json). This is controlled
functional evidence; a human firefight/visual acceptance session remains open.

Rendered armour contrast, using median RGB from the pixel rectangles in
[readability.json](sprint6-goauld-corridors/readability.json):

| Native shape | Armour / wall field | Armour / bronze |
| --- | ---: | ---: |
| Narrow corner | 4.09 | 3.00 |
| T-junction | 5.19 | 3.31 |
| Wide corner | 4.09 | 2.59 |
| Adapter | 4.09 | 3.00 |

These are selected controlled surface samples, not worst-case combat measurements.
Lit bronze is the weaker background; perspective can also place an outlined
awareness marker against a gold frieze. Owner review should judge those cases in
motion before palette or lighting changes.

## Reproduce and remaining work

```sh
python3 tools/theme_kit.py --check
python3 tools/level_authoring.py preview --layout res://resources/levels/goauld_corridor_gallery.tres
DISPLAY=:0 godot --path client --script res://scripts/level/theme_capture.gd -- --output "$PWD/build/sprint6-captures" --shots narrow_corner,t_junction,wide_corner,adapter
DISPLAY=:0 godot --path client --script res://tests/support/goauld_corridor_review.gd
```

For the three other shapes, add `--layout res://resources/levels/goauld_corridor_gallery.tres`
and `--shots wide_straight,cross_junction,wide_junction`. Add `--baseline-ga1` or
`--jaffa` for the corresponding comparisons. Open the normal infiltration mission
for human review of the native route.

Owner art acceptance remains explicit: corridor identity, branch/door legibility,
Jaffa/marker visibility during motion, and seams from both sides. The next art
group is larger chambers, starting with inspection of the preserved unfinished
work. Tall rooms, props, textures, lighting and weapon expansion remain separate.
