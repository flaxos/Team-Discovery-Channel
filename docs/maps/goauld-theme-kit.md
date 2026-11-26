# Goa'uld theme kit

The first faction art in the game: a palette that reaches every room of a `goauld` layout, and built pieces for all eight corridor/junction/adapter modules plus the compact chamber (`room01`–`room09`). Sprint 27 adds the `room16` arrival hangar. It follows the [Goa'uld visual brief](goauld-visual-brief.md), made in the engine by a generator ([D-012](../DECISIONS.md)). Sprint 6 recovers and finishes GA-2 part 1; [current evidence and provenance](../reviews/2026-11-18-sprint6-goauld-corridors.md).

Nothing here changes collision, sockets, positions or navigation ([D-010](../DECISIONS.md)). An automated suite proves that on the infiltration compound. **A person has not yet reviewed the look**: that is this milestone's open gate.

## What a player sees

| | Rooms in the infiltration compound | What changes |
|---|---|---|
| **Pieces** | 15 of 20: the original 14 plus the arrival hangar | Ribbed walls, a plinth, a frieze with a gold band, door lintels with a gold block, connected floor runners and margins, coffered ceilings |
| **Palette only** | Generator, command room, ramp and both ring rooms | The same slabs in dark stone, with bronze lintels and sandstone props |

The original GA-1 captures, taken under the mission's lighting, remain in [`docs/reviews/ga1-captures/`](../reviews/ga1-captures/). These two views show the first slice; the [Sprint 6 review](../reviews/2026-11-18-sprint6-goauld-corridors.md) compares every new shape against GA-1 coverage and includes Jaffa, connected joins and the production camera.

| Corridor | Chamber |
|---|---|
| ![Corridor](../reviews/ga1-captures/corridor.png) | ![Chamber](../reviews/ga1-captures/chamber.png) |
| Neutral, same shot: ![Neutral corridor](../reviews/ga1-captures/corridor_neutral.png) | Neutral, same shot: ![Neutral chamber](../reviews/ga1-captures/chamber_neutral.png) |

Others in the folder: `chamber_door` (a lintel and door leaf), `chamber_corner` (a corner pier and a sealed opening), `corridor_wall`, `corridor_lintel`, `cover` (props in the stores) and `palette_only` (a room without pieces).

## How it is built

```sh
python3 tools/theme_kit.py            # regenerate the kit
python3 tools/theme_kit.py --check    # fail if the committed kit is stale
```

`tools/theme_kit.py` reads ten module scenes, and for every structural slab writes a piece inside its box, with the lintel exception below:

| Output | Contents |
|---|---|
| `client/resources/level_themes/goauld.tres` | The theme: one material per resolver slot, and 130 variants, each with its slab and rotation |
| `client/resources/level_themes/goauld/*.tres` | Eight materials, one per palette role. Change a colour here by changing `PALETTE` in the generator |
| `client/scenes/level/themes/goauld/*.tscn` | 60 distinct shared piece scenes: box meshes only, no scripts, no collision. Together with eight materials and the theme, 69 generated files |

**Do not edit the generated files by hand.** A unit test fails when they differ from the generator's output.

The 12 m arrival hangar uses four-metre rib spacing and an upper band above the tall north opening. Thin portal floors and roofs remain flush, and the east-wall service recess stays within its original slab. [Sprint 27 room and DHD](../reviews/2026-11-26-sprint27-offworld-gate-arrival.md).

The rules the generator applies, each from the brief:

- **Walls.** The slab is split into a back half and a front half. The front carries a plinth to 0.6 m, ribs between 0.6 m and 2.8 m, and a frieze above 2.8 m with a gold band at 3.04 to 3.16 m. The gaps between ribs are the panels, recessed 0.10 m.
- **Where ribs go.** A wall end beside a door opening gets a 0.4 m jamb. A wall end in a corner gets a pier 0.6 m long, of which 0.2 m is inside the other wall. Elsewhere ribs sit on a 2 m grid from the module's centre (±1 m, ±3 m), wherever a rib fits with at least 0.3 m of panel either side. The corridor gets four grid ribs; a chamber segment gets a jamb and a pier.
- **Lintels.** A bronze header, recessed 0.04 m, with the gold band and a gold block 1.0 m wide.
- **Floors.** Colour only: a connected 1.6 m runner follows each corridor branch, and a 0.7 m margin surrounds the compact chamber. New corridor floors derive branch directions from the real headers, clip runner arms to the floor slabs and merge disjoint cells. A corner or T-junction's runner therefore continues across a short branch's mesh boundary. Every box is the full slab thickness, so the walking surface does not move.
- **Ceilings.** Beams flush with the slab's lower face and bays recessed 0.10 m upward, inside a flush border. Corridor beams follow the wall ribs; chamber beams spring from the door jambs.

### Four things found by looking at it

1. **Nothing is metallic.** A mission has no sky and no reflection probe. A metallic surface there loses its albedo, and gold rendered the same dull brown as bronze. All eight materials have `metallic = 0`; sheen is roughness only.
2. **A ceiling needs a flush border.** Walls and lintels stop at the ceiling slab's lower face. Bays that reached the slab's edge left a 0.10 m slit above them, open to the void outside the level.
3. **Lintels need both faces finished.** Existing north/south header offsets can expose a neighbour's back instead of the room's own front. The gold block/band stand 5 mm proud on both faces, above the opening and inside the resolver's 1 cm tolerance. This preserves the existing structural headers while keeping narrow and wide joins legible. Their offset geometry remains separate structural debt (R21).
4. **Corner ends need the same finish as the face they meet.** Exposed basalt end caps flickered against a perpendicular bronze/gold face. Bronze reveals and the gold band now wrap through each corner/jamb end. The pieces retain their original bounds; neither wall nor collision moves.

## Status reporting

`LevelThemeResolver.describe` now reports how much of a room a theme reaches:

| Field | Values |
|---|---|
| `visual_source` | The first theme in the fallback chain with art of its own. `goauld` for every room of a `goauld` layout |
| `coverage` | `pieces` when that theme has built scenes for the room's module, `palette` when it only recolours the slabs, `generic` when no theme applies |

`python3 tools/level_authoring.py validate --layout … --summary` counts rooms by both. The infiltration compound reports `goauld -> goauld (pieces)`: 15 and `goauld -> goauld (palette)`: 5. The nine-room `goauld_corridor_gallery.tres` reports nine pieced rooms and has a continuous entry-to-destination route.

A theme's `materials` must be keyed by the resolver's slot names: `floor`, `ceiling`, `door_frame`, `portal`, `wall`, `detail`, `prop`. `validate_theme` now rejects any other key, where it used to ignore it silently. The five other themes still declare the older descriptive names in `decoration_slots`; that list is catalogue text and nothing reads it.

## Readability, measured

These are the historical GA-1 measurements. Sprint 6 retains the palette and includes new controlled readability captures in its review; human acceptance is still pending.

Contrast ratios sampled from captures of the same chamber shot, under the mission's lighting. Higher is easier to see; 1.0 is invisible by brightness alone.

| What | Against | Neutral before | Goa'uld, armour as it was | Goa'uld, as merged |
|---|---|---|---|---|
| Alerted marker **!** | wall panel | 1.4 | 3.6 | **3.6** |
| Alerted marker **!** | bronze rib | 1.4 | 2.6 | **2.6** |
| Cover prop | floor | 1.0 | 2.6 | **2.6** |
| Cover prop | wall panel | 1.2 | 3.3 | **3.3** |
| Jaffa armour | wall panel | 1.9 | 1.3 | **5.0** |
| Jaffa armour | bronze rib | 1.9 | 1.1 | **3.6** |
| Door leaf | bronze jamb beside it | 1.7 | 1.0 | **1.0** |
| Door leaf | wall panel | 1.7 | 1.5 | **1.5** |

Sources: [`chamber_door_neutral_jaffa_before.png`](../reviews/ga1-captures/chamber_door_neutral_jaffa_before.png), [`chamber_door_jaffa_before.png`](../reviews/ga1-captures/chamber_door_jaffa_before.png), [`chamber_door_jaffa.png`](../reviews/ga1-captures/chamber_door_jaffa.png).

**Jaffa armour is now matte ([D-015](../DECISIONS.md)).** The brief predicted that Jaffa would stand out from dark walls, from the armour's stated gold. They did not: the armour was metallic (0.85 to 0.95), and for the reason in point 1 above it rendered as a dark olive in every mission. Against bronze that measured 1.1 : 1, worse than against the old grey walls. The owners chose to remove the metallic term from both Jaffa scenes. They are now the brightest warm shape in a room, here and in SGC Defense. The staff weapon keeps its metallic finish.

| Before | After |
|---|---|
| ![Metallic armour](../reviews/ga1-captures/chamber_door_jaffa_before.png) | ![Matte armour](../reviews/ga1-captures/chamber_door_jaffa.png) |

**Door leaves are told from their jambs by colour, not brightness.** A teal leaf between brown jambs under a gold block is easy to find in the captures, but it relies on hue. If it reads poorly in play, the remedy is a themed door leaf (gap G-2 in the brief), not a lighter wall.

## Tests

| Suite | Proves |
|---|---|
| `client/tests/test_goauld_theme.gd` | On the infiltration compound: all 20 rooms report `goauld`; 15 have built pieces and 5 use the palette; every slab of the pieced rooms is replaced; collision shapes, navigation vertices/polygons, module/socket/marker poses and cover are identical to neutral. All ten definitions apply under all four rotations without collision changes or fallback. The connected gallery also matches neutral structure/navigation. Gold stays above 2.8 m; floors are flat; relief faces inward; unknown material keys are rejected |
| `tools/tests/test_theme_kit.py` | On generated geometry: current output, positive dimensions, exact slab bounds with the 5 mm lintel allowance, disjoint boxes, solid pieces, flush ceiling edges, flat floors, connected runner bands, finished corner ends and both lintel faces, gold height/accent limits and the original palette/armour contrast rules |
| `client/tests/test_level_themes.gd`, `test_level_demonstrations.gd` | Updated: `goauld` now reports its own art; the other four factions still fall back to neutral |

## Review captures

```sh
godot --path client --script res://scripts/level/theme_capture.gd -- --output /tmp/captures
```

Needs a graphical display. Options: `--layout <res path>`, `--theme neutral`, `--baseline-ga1` (retain pieces only on `room01`/`room04` in a private resource copy), `--shots corridor,chamber`, `--jaffa` (stationary alerted guards for readability). New native shots: `narrow_corner,t_junction,wide_corner,adapter`; gallery shots: `wide_straight,cross_junction,wide_junction,narrow_join,wide_join`. File names carry the options used. The legacy `palette_only` shot now views the pieced inner junction. The original `_before` files were taken with metallic armour.

## Human review (pending)

Play `godot --path client -- --mission goauld_infiltration` from a checkout of this branch, and answer:

1. Do the corridor and the chambers read as one place, and as somewhere other than the neutral test facility?
2. Can you pick out each door at a glance from across a chamber?
3. Can you see an unaware Jaffa against the walls in time? Is the matte gold armour right, here and in SGC Defense?
4. Is cover obvious? Are the **?**, **!** and **!!** markers clear?
5. Does anything flicker, or can you see out of the level anywhere?
6. Do the new corners, junctions and width changes read as the same kit? Are the connected runners useful, and do any joins flicker while moving?
7. Do the six palette-only rooms look unfinished next to the fourteen with pieces? Larger chambers are the next planned art group.

## Not in this milestone

| | Where it goes |
|---|---|
| The remaining module types (long/large chambers, ramp and rings) | Later GA-2 chunks, in the brief's order. Inspect unfinished work before extending `MODULES`; tall rooms need a second frieze tier (G-8) |
| Lighting: warm ambient, fixtures, removing the fixed directional light | V3 (G-3) |
| Themed door leaves | G-2 |
| Free-standing decoration: columns, braziers | G-5 |
| Textures and modelled replacements | After the shapes are approved; the piece boxes in the brief are the contract |
