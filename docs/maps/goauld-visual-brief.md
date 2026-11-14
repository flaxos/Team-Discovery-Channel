# Goa'uld visual brief and theme-slot audit (GA-0)

Written 14 November 2026 against `main` at `ce9ad71` as the target for the first themed slice (GA-1) and for the kit expansion after it (GA-2).

**GA-1 has since been built to it.** What exists, how to regenerate it, and readability measured from captures are in the [Goa'uld theme kit guide](goauld-theme-kit.md). Building it corrected this brief in five places, each marked *As built* below. The audit in section 3 describes the code before GA-1; gaps G-1, G-6 and G-7 are closed.

**Art method (decided 14 November 2026, [D-012](../DECISIONS.md)):** pieces are built in the engine by agents, from primitive meshes and materials, behind the existing theme slots. Section 6 keeps the alternatives for the record.

All designs are original and only inspired by the setting. No production asset, screenshot or texture is copied. Line references are to `ce9ad71`.

## 1. What the theme system gives us to work with

A Goa'uld room is a neutral room with different surfaces. [D-010](../DECISIONS.md) forbids a theme from changing collision, sockets, positions or navigation, so the design below fits inside the boxes the modules already have.

| Fixed by the modules | Value | Source |
|---|---|---|
| Wall slab thickness | 0.2 m | every module scene, `metadata/dimensions` |
| Standard room height (floor to ceiling) | 3.4 m | wall slabs are 3.4 m high |
| Narrow corridor interior | 3.0 m wide × 8 m long | `Room01Straight.tscn` |
| Compact chamber interior | 7.6 × 7.6 m (8 m cell less two wall slabs) | `Room04Chamber.tscn`, walls centred at ±3.9 m |
| Door opening, narrow / wide / equipment | 3.0 × 2.8 m / 6.0 × 2.8 m / 12 × 10 m | socket `width` and `height` in the catalogue |
| Door header (lintel) | 0.6 m high, 0.2 m deep, as wide as the opening | `Header*` meshes |
| Door leaf | opening less 0.08 m by 0.05 m, 0.16 m thick | [`ModularDoor.gd:17`](../../client/scripts/level/ModularDoor.gd#L17) |
| Tall rooms | ramp walls 7.4 m, transport chamber 10.4 m, hangar 12 m | `Room14`, `Room15`, `Room16` |

A themed piece replaces one slab and must occupy exactly that slab's box (section 3). **Relief is therefore cut into the 0.2 m slab, never added in front of it.** Nothing leans, nothing narrows an opening, and nothing stands proud of a wall where a player or a Jaffa could clip it.

## 2. Design language

### 2.1 The idea in one sentence

Dark stone held up by heavy bronze ribs, with gold kept for a narrow band above head height: a fortress that looks expensive, in which the gold-armoured Jaffa stay the brightest warm thing in the room.

### 2.2 Why the walls are dark

The obvious Goa'uld palette is gold walls. It would hide the enemy. Jaffa armour is gold already ([`JaffaGuard.tscn:11`](../../client/scenes/entities/JaffaGuard.tscn#L11), `Color(0.68, 0.52, 0.22)`), and the suspicion marker is yellow ([`JaffaAI.gd:435`](../../client/scripts/entities/JaffaAI.gd#L435)). Against a gold surface both have a contrast ratio near 1 : 1. So gold is an accent, limited to the frieze above 2.8 m, and the field colour is a dark warm stone.

### 2.3 Palette

Colours are Godot `Color(r, g, b)` values as written in a `.tres`, with their hex equivalent. *L* is relative luminance (sRGB, 0 = black, 1 = white).

| Role | Theme slot | Colour | Hex | L | Metallic / roughness |
|---|---|---|---|---|---|
| Wall field (basalt) | `wall` | `Color(0.16, 0.13, 0.11)` | `#29211c` | 0.016 | 0.0 / 0.85 |
| Rib, plinth, lintel (aged bronze) | part of the wall and header pieces | `Color(0.30, 0.22, 0.13)` | `#4c3821` | 0.045 | 0.0 / 0.5 |
| Frieze accent (gold) | part of the wall and header pieces, above 2.8 m only | `Color(0.66, 0.49, 0.18)` | `#a87d2e` | 0.232 | 0.0 / 0.35 |
| Floor margin | `floor` | `Color(0.11, 0.10, 0.10)` | `#1c1a1a` | 0.010 | 0.0 / 0.45 |
| Floor runner | part of the floor piece | `Color(0.21, 0.18, 0.14)` | `#362e24` | 0.028 | 0.0 / 0.6 |
| Ceiling | `ceiling` | `Color(0.08, 0.07, 0.07)` | `#141212` | 0.006 | 0.0 / 0.9 |
| Sealed opening | `portal` | `Color(0.13, 0.11, 0.10)` | `#211c1a` | 0.012 | 0.0 / 0.7 |
| Cover and placeholder props (sandstone) | `prop` | `Color(0.50, 0.43, 0.32)` | `#806e52` | 0.162 | 0.0 / 0.8 |

Rules a reviewer can check:

1. No surface below 2.8 m has L above 0.05, except props.
2. Gold (L above 0.2) is never below 2.8 m, and covers no more than 15% of a wall piece's visible face. The one larger gold shape is the cartouche block on a door lintel.
3. Props are the lightest large shapes at floor level: at least 2.5 : 1 against both floor colours and the wall field (they measure 3.5, 2.7 and 3.2).
4. Surfaces are flat colour with roughness only. No textures in GA-1; a texture pass belongs to GA-2 once the shapes are approved.

*As built:* the first draft gave bronze and gold a metallic term (0.6 and 0.8). A mission has no sky or reflection probe, so those surfaces lost their albedo and the two rendered the same dull brown. Nothing in the kit is metallic.

### 2.4 Wall rhythm

One rule produces every wall: **ribs on a 2 m grid, measured from the module's centre, at ±1 m and ±3 m.**

| Element | Dimension |
|---|---|
| Rib width | 0.4 m |
| Rib spacing, centre to centre | 2.0 m |
| Panel between ribs | 1.6 m wide, recessed 0.10 m into the slab |
| Plinth | floor to 0.6 m, flush with the ribs (not recessed) |
| Panel zone | 0.6 m to 2.8 m |
| Frieze | 2.8 m to 3.4 m, flush with the ribs; a gold band 0.12 m high centred at 3.1 m |
| Visible relief | 0.10 m, leaving 0.10 m of slab behind every recess |

Because the grid is measured from the centre of an 8 m cell, a cell edge always falls in the middle of a panel. Two corridor modules placed end to end continue the rhythm with no doubled rib and no gap.

The frieze starts at 2.8 m because that is the height of every standard door opening. The lintel over a door is the same band as the frieze beside it, so one unbroken line runs round a room at door-head height. That line is the Goa'uld signature here, and it sits above every gameplay silhouette: a Jaffa's awareness marker is drawn at 2.45 m above his feet ([`JaffaAI.gd:408`](../../client/scripts/entities/JaffaAI.gd#L408)).

### 2.5 Pieces for GA-1

A reviewer should be able to choose and check each of these from this section alone.

**Piece A: narrow corridor wall** (`Room01Straight`, meshes `Wall2` and `Wall3`)

- Box: 0.2 × 3.4 × 8.0 m. Two per corridor, mirrored by a half-turn so the relief faces inward.
- Four ribs at z = −3, −1, +1, +3 m, each 0.4 m wide and the full 3.4 m high.
- Three full panels between them and a half panel (0.8 m) at each end, all recessed 0.10 m between 0.6 m and 2.8 m.
- Plinth and frieze run the full 8 m, flush with the ribs. Gold band 0.12 m high at 3.04 to 3.16 m.

**Piece B: door frame** (the `Header*` meshes of `Room01Straight` and `Room04Chamber`)

- Box: 3.0 × 0.6 × 0.2 m. A bronze lintel, flush, carrying the same gold band at the same height as the frieze.
- A centred cartouche block 1.0 m wide and the full 0.6 m high, gold, flush with the lintel face; the lintel either side of it is recessed 0.04 m so the block reads as a keystone.
- *As built:* the gold block and band stand 5 mm proud of the slab and the block stops 2 cm above the soffit, so that they are drawn in front of a neighbouring module's header where one overlaps the lintel (gap G-9).
- In a chamber the jambs are the ends of the wall segments (piece C). In a corridor the opening is the full corridor width and there are no jambs; the last half panels of piece A stand in for them.
- The opening stays 3.0 × 2.8 m. A tapered or trapezoid doorway is not possible: it would put visuals inside the opening the door leaf and the players use.

**Piece C: chamber wall segment** (`Room04Chamber`, meshes `Wall2` to `Wall9`)

- Box: 0.2 × 3.4 × 2.5 m. Eight per chamber: two on each side, flanking the 3 m door opening.
- A 0.4 m jamb at the door end, bronze through the full depth of the slab so the door reveal is one colour.
- A pier at the corner end. *As built:* 0.6 m long, because the last 0.2 m of each segment is inside the wall it meets; a 0.4 m rib there would have shown only 0.2 m. The piece is therefore not symmetric, and there are two scenes, one the mirror of the other.
- One panel 1.5 m wide between them, recessed 0.10 m between 0.6 m and 2.8 m. Plinth, frieze and gold band as piece A.

**Piece D: floors** (`Floor0` of both modules)

- Corridor: 3.0 × 0.2 × 8.0 m. A runner 1.6 m wide down the centre in the runner colour, with 0.7 m margins. The runner tells a player which way a corridor leads.
- Chamber: 8.0 × 0.2 × 8.0 m. A margin 0.7 m wide round the edge and the runner colour inside it.
- **The top face is flat and at the original height.** Floor pattern is colour only. Any relief in a floor would separate what the player sees from what the collision supports.

**Piece E: ceilings** (`Roof0` of both modules)

- Corridor: 3.0 × 0.2 × 8.0 m. Chamber: 8.0 × 0.2 × 8.0 m.
- Corridor: transverse beams 0.4 m wide on the same 2 m grid as the wall ribs, flush with the slab's lower face; the bays between them recessed 0.10 m upward. Ribs and beams then line up as portal frames down a corridor.
- *As built:* a chamber's beams spring from the door jambs (±1.7 m) in both directions, which frames a centre bay the width of the doors; the 2 m grid lines up with nothing in a chamber. Every ceiling also has a flush border round its edge (0.2 m visible), because a bay that reached the edge left a slit above the walls, open to the outside.

Counts for GA-1: two wall variants, two header variants, a floor and a ceiling for the corridor; eight wall variants, four header variants, a floor and a ceiling for the chamber. Section 3.3 explains why each mesh needs its own variant entry.

### 2.6 Lighting mood (for the later lighting pass, V3)

GA-1 does not change lighting. The target for V3, recorded here so that GA-1's materials are judged against it:

| Setting | Neutral today | Goa'uld target |
|---|---|---|
| Ambient colour | white | `Color(0.85, 0.72, 0.55)` |
| Ambient energy | 0.8 | 0.45 to 0.55 |
| Fixture colour | white | `Color(1.0, 0.72, 0.38)` (amber) |
| Fixture energy | 1.0 | 1.2 |
| Fixtures | none exist | at most two unshadowed lights per 8 m cell, at rib tops (2.6 m) |

Until then GA-1 is seen under white ambient at 0.8 with the mission's fixed directional light, which is brighter and flatter than the target. The palette above was chosen to keep its contrast under both.

## 3. Theme-slot audit

### 3.1 The five declared slots

`goauld.tres` declares `decoration_slots = ["wall_panels", "floor_detail", "ceiling_detail", "door_frame", "room_detail"]`. **Nothing reads that list except the catalogue export** ([`LevelCapabilityCatalogue.gd:319`](../../client/scripts/level/LevelCapabilityCatalogue.gd#L319)). The resolver decides a mesh's slot from the mesh's name ([`LevelThemeResolver.gd:187-199`](../../client/scripts/level/LevelThemeResolver.gd#L187)) and uses its own identifiers. Only `door_frame` has the same name in both.

| Declared slot | Resolver slot it corresponds to | What renders today | Reach | Gap |
|---|---|---|---|---|
| `wall_panels` | `wall`: any mesh named `Wall*` ([line 197](../../client/scripts/level/LevelThemeResolver.gd#L197)) | The neutral grey-blue slab, `Color(0.32, 0.38, 0.41)`, from `neutral.tres` `surface_material` via the fallback chain ([lines 202-214](../../client/scripts/level/LevelThemeResolver.gd#L202)) | All 15 modules; 2 walls in a corridor, 8 in the compact chamber, up to 34 in the special hall | Name differs (G-1). A wall piece needs one variant per mesh (G-4) |
| `floor_detail` | `floor`: `Floor*` ([line 189](../../client/scripts/level/LevelThemeResolver.gd#L189)) | Same neutral material | All 15 modules; 1 to 13 meshes each | Name differs (G-1). Relief is unsafe on floors (section 2.5 D) |
| `ceiling_detail` | `ceiling`: `Roof*` or `Ceiling*` ([line 191](../../client/scripts/level/LevelThemeResolver.gd#L191)) | Same neutral material | All 15 modules | Name differs (G-1) |
| `door_frame` | `door_frame`: `Header*` only ([line 193](../../client/scripts/level/LevelThemeResolver.gd#L193)) | Same neutral material | Every socket of every module has a header | Covers the lintel only. Jambs are wall ends. The door leaf is outside the theme system (G-2) |
| `room_detail` | `detail`: any other mesh ([line 199](../../client/scripts/level/LevelThemeResolver.gd#L199)) | Same neutral material | **Only the six handrails of `Room14Ramp4m`.** No other module has a detail mesh | A theme cannot add free-standing decoration to a room (G-5) |

Two further resolver slots are not in the declared list:

| Resolver slot | What it is | What renders today | Reach |
|---|---|---|---|
| `portal` | The slab that seals an unconnected socket; meshes under `Visuals/Closures` ([line 195](../../client/scripts/level/LevelThemeResolver.gd#L195)), shown only while the socket is unconnected ([`LevelModule.gd:16`](../../client/scripts/level/LevelModule.gd#L16)) | Neutral surface material | Every socket of every module |
| `prop` | Placeholder props created from a preset's `placeholder_size` ([`LevelRoomComposer.gd:312-322`](../../client/scripts/level/LevelRoomComposer.gd#L312)) | Neutral `prop_material`, `Color(0.38, 0.42, 0.44)` | All 16 presets except `stargate_dhd`; 36 placeholder props in total. Attachments that have their own scene (the gate, the DHD, the rings, one armoury piece) are not themed |

### 3.2 How a theme reaches a mesh

1. **Which theme.** An explicit resource on the room, then the room's `theme_id`, then a legacy `style`, then the room's zone, then the layout default ([lines 32-45](../../client/scripts/level/LevelThemeResolver.gd#L32)). `goauld_infiltration_01.tres` sets the layout default to `goauld` and no exceptions, so every room in the compound is already asking for this theme.
2. **Fallback chain.** `goauld` falls back to `neutral` ([lines 48-58](../../client/scripts/level/LevelThemeResolver.gd#L48)). A theme applies to a module only if one of the module's tags is in `compatible_families` ([lines 61-67](../../client/scripts/level/LevelThemeResolver.gd#L61)); `goauld` lists `corridor`, `chamber`, `adapter` and `vertical`, which covers every module.
3. **Material.** The first theme in the chain with an entry in `materials` under the slot's name wins; failing that its `prop_material` or `surface_material` ([lines 202-214](../../client/scripts/level/LevelThemeResolver.gd#L202)). `goauld.tres` has none of these, so everything resolves to neutral.
4. **Variant.** A `LevelThemeVariant` whose `slot` equals either the mesh's own name (its `visual_slot`, for example `Wall2`) or the resolver slot (`wall`) is chosen, with variants restricted by `module_ids` tried first ([lines 217-237](../../client/scripts/level/LevelThemeResolver.gd#L217)). It may set a material, a scene, or both.
5. **Scene replacement.** The scene is instanced as a child called `ThemeVisual` and the original mesh is hidden ([lines 355-368](../../client/scripts/level/LevelThemeResolver.gd#L355)). Lights inside it take the palette's fixture colour and energy ([lines 360-367](../../client/scripts/level/LevelThemeResolver.gd#L360)).
6. **What a cosmetic scene may contain.** `Node3D`, meshes, lights and decals only; no scripts and no signal connections ([lines 70-98](../../client/scripts/level/LevelThemeResolver.gd#L70)). A scene that breaks this is refused with a warning and the neutral slab stays.
7. **Reported status.** `describe` reports the first theme in the chain whose `art_status` is not `fallback` ([lines 261-278](../../client/scripts/level/LevelThemeResolver.gd#L261)); today that is `neutral` for every faction.

### 3.3 Gaps

| # | Gap | Evidence | Consequence for GA-1 and GA-2 |
|---|---|---|---|
| G-1 | The declared slot names are not the names the resolver uses, and nothing validates a material key | Section 3.1; `materials` keys are looked up by resolver slot ([line 208](../../client/scripts/level/LevelThemeResolver.gd#L208)) | A material stored under `wall_panels` is silently ignored. GA-1 uses `wall`, `floor`, `ceiling`, `door_frame`, `portal`, `prop`. Recommend that GA-1 corrects `decoration_slots` to those names and makes `validate_theme` reject unknown keys |
| G-2 | The door leaf is not themeable | `ModularDoor` builds its own panel and hard-codes two colours ([`ModularDoor.gd:28`](../../client/scripts/level/ModularDoor.gd#L28)); doors are created by `LevelAssembler.add_doors` ([line 149](../../client/scripts/level/LevelAssembler.gd#L149)), outside `Visuals` | Leaves keep their teal and brown. Against the dark palette they measure 1.9 : 1 and 2.2 : 1, which is enough to find a door, and the two stay distinguishable by hue. Acceptable for GA-1; a `door` material slot is a small resolver extension for GA-2 |
| G-3 | Only ambient light follows the palette. The background colour and a directional light are fixed | [`ModularMission.gd:242-257`](../../client/scripts/mission/ModularMission.gd#L242); the editor preview does the same | A theme cannot make a compound darker than "white ambient plus a sun". The lighting pass (V3) needs the palette to control or remove the directional light |
| G-4 | A variant scene must fill the slab's box exactly (within 2 cm) on every slot except `detail`, and a variant has one fixed transform | [Lines 334-354](../../client/scripts/level/LevelThemeResolver.gd#L334) | Relief is limited to the slab (section 1). A wall treatment needs one variant entry per mesh, with its own rotation: 2 for a corridor, 8 for the compact chamber, 22 for the long chamber, 34 for the special hall. This is data, and it should be **generated** by a tool, not typed |
| G-5 | A theme cannot add decoration that is not a replacement for an existing mesh | `apply` only visits existing meshes under `Visuals` ([line 288](../../client/scripts/level/LevelThemeResolver.gd#L288)) | Columns, braziers and statues would have to be preset attachments, which are gameplay data and the same for every faction. Out of scope until GA-2 decides between a decoration list on the theme and themed attachment scenes |
| G-6 | Status is per theme, not per module | `art_status` is one field on the theme; `describe` reads only that ([line 277](../../client/scripts/level/LevelThemeResolver.gd#L277)) | GA-1 asks for the status to move off `fallback` "for those modules only". As written, setting `authored` would claim all 15 modules. GA-1 needs `describe` to report what was applied to the module in hand (palette only, or pieces) |
| G-7 | A test asserts the current fallback | [`test_level_themes.gd:35`](../../client/tests/test_level_themes.gd#L35) expects `visual_source == "neutral"` for every faction | GA-1 must change that assertion for `goauld` on purpose, in the same commit as the theme |
| G-8 | Tall rooms are single slabs | Ramp walls are one 7.4 m piece, the transport chamber's 10.4 m, the hangar's 12 m | The frieze-at-2.8 m rule needs a second tier for these. GA-2, not GA-1 |

| G-9 | Ten modules place headers outside their own cell | *Found while building GA-1.* The north and south `Header*` meshes of `Room05` to `Room13`, `Room15` and `Room16` are centred 0.1 m beyond the cell edge, inside the slab where the adjoining room's own header is. `Room01` to `Room04` and `Room14` keep theirs inside | Invisible while both use one material; against a built lintel the two flickered. GA-1 stands the lintel's gold 5 mm proud so it wins. Moving the headers changes collision in ten modules and is a separate structural task (risk R21) |

None of these blocks GA-1. G-1, G-6 and G-7 are small changes GA-1 should make; G-4 decides how GA-1 is built (a generator).

## 4. Which rooms matter

### 4.1 Evidence

Two sources. Neither is a measure of time, and the play record is one solo session by one owner, mostly loud.

1. **The mission's data** (`goauld_infiltration.tres`): where the objectives, patrols, alarm consoles and reinforcements are.
2. **The first human session on `main`**, 14 November 2026 ([record](../reviews/2026-11-14-owner-solo-uat.md)): 119 room entries over two attempts at the infiltration mission.

| Room | Module | Entries (of 119) | Mission role |
|---|---|---|---|
| `checkpoint` | `Room04Chamber` | 14 | Patrol of two; alarm console; first fight on the loud route |
| `barracks` | `Room04Chamber` | 13 | Patrol; both reinforcement groups spawn here |
| `inner` | `Room03TJunction` | 9 | Junction to the generator and the ramp; patrol |
| `stores` | `Room04Chamber` | 8 | Quiet route; patrol; the most cover props |
| `gate` | `Room16HangarShell` | 7 | Insertion and extraction; first and last thing seen |
| `generator` | `Room10LongChamber` | 7 | Objective 1; patrol |
| `maint` | `Room02Corner` | 7 | Quiet route |
| `approach`, `approach2` | `Room01Straight` | 6 each | Loud route; patrol reaches `approach2` |
| `service`, `service2` | `Room07WideCorner` | 5, 6 | Quiet route |
| `svc_adapter` | `Room09WidthAdapter` | 6 | Quiet route |
| `armoury` | `Room04Chamber` | 6 | Dead end off the barracks |
| `up_hall` | `Room03TJunction` | 6 | Upper junction; patrol |
| `cmd_antechamber` | `Room04Chamber` | 4 | Patrol; security door to command |
| `ramp` | `Room14Ramp4m` | 2 | Only way up |
| `ring_lower`, `ring_upper` | `Room15TransportChamber` | 2 each | Dead ends; rings are inert |
| `cmd_command` | `Room11LargeChamber` | 2 | Objective 2; patrol |
| `cmd_observation` | `Room04Chamber` | 1 | Alarm console; patrol |

### 4.2 By module, which is the order art should follow

| Order | Module | Rooms in the compound | Entries | Share | Milestone |
|---|---|---|---|---|---|
| 1 | `Room04Chamber` (compact chamber) | 6 of 20 | 46 | 39% | **GA-1** |
| 2 | `Room03TJunction` | 2 | 15 | 13% | GA-2 part 1 |
| 3 | `Room01Straight` (narrow corridor) | 2 | 12 | 10% | **GA-1** |
| 4 | `Room07WideCorner` | 2 | 11 | 9% | GA-2 part 1 |
| 5 | `Room16HangarShell` (gate room) | 1 | 7 | 6% | GA-2 part 3 (tall) |
| 5 | `Room10LongChamber` (generator) | 1 | 7 | 6% | GA-2 part 2 |
| 5 | `Room02Corner` | 1 | 7 | 6% | GA-2 part 1 |
| 8 | `Room09WidthAdapter` | 1 | 6 | 5% | GA-2 part 1 |
| 9 | `Room15TransportChamber` | 2 | 4 | 3% | GA-2 part 3 (tall) |
| 10 | `Room14Ramp4m` | 1 | 2 | 2% | GA-2 part 3 (tall) |
| 10 | `Room11LargeChamber` (command) | 1 | 2 | 2% | GA-2 part 2 |

GA-1's corridor and chamber are 8 of the compound's 20 rooms and 49% of the recorded entries. The palette materials reach all 20 rooms at once, so after GA-1 nothing is left neutral grey: twelve rooms have the palette on plain slabs and eight have the pieces.

Recommended GA-2 parts, in order: (1) the remaining corridor family, which reuses pieces A, B, D and E at new lengths: T-junction, corners, wide corner, adapter; (2) the larger chambers, which reuse piece C: long chamber, large chamber; (3) the tall rooms, which need the second tier of G-8: gate room first, because every session starts and ends there.

## 5. Readability constraints from play

These are requirements on GA-1, checked against the palette in section 2.3. Contrast ratios are (L₁ + 0.05) / (L₂ + 0.05).

**The table below is calculated from stated colours. Measured values from captures are in the [kit guide](goauld-theme-kit.md#readability-measured), and two rows did not hold up:** Jaffa armour was metallic and rendered far darker than its stated gold, so against the dark walls it measured 1.1 to 1.3 : 1, worse than against neutral walls (1.9 : 1), until the armour was made matte ([D-015](../DECISIONS.md); now 3.6 to 5.0 : 1); and a door leaf against the bronze jamb beside it measures 1.0 : 1 by brightness. The markers and cover measured as predicted.

| What must stay readable | Its colour | Against neutral walls today | Against the Goa'uld wall field | Against the bronze ribs | Against gold |
|---|---|---|---|---|---|
| Suspicion marker **?** | yellow, [`JaffaAI.gd:435`](../../client/scripts/entities/JaffaAI.gd#L435) | 4.7 | 11.4 | 8.0 | 2.7 |
| Alerted marker **!** | red, [line 432](../../client/scripts/entities/JaffaAI.gd#L432) | 1.8 | 4.5 | 3.2 | 1.1 |
| Alarm runner **!!** | magenta, [line 429](../../client/scripts/entities/JaffaAI.gd#L429) | 2.0 | 4.9 | 3.4 | 1.1 |
| Jaffa armour | gold, [`JaffaGuard.tscn:11`](../../client/scenes/entities/JaffaGuard.tscn#L11) | 1.9 | 4.6 | 3.2 | 1.1 |
| Door leaf | teal, [`ModularDoor.gd:28`](../../client/scripts/level/ModularDoor.gd#L28) | 1.3 | 1.9 | 1.3 | n/a |
| Security door leaf | brown, same line | 1.1 | 2.2 | 1.6 | n/a |
| Cover props | sandstone (new) against floor and walls | 1.2 (neutral prop on neutral wall) | 3.2 | n/a | n/a |

What follows from the table:

1. **Every marker reads better against the dark palette than it does today.** *As built:* the same was predicted for the Jaffa and was false while their armour was metallic; see the note above.
2. **Gold must stay above 2.8 m.** Against gold, the red and magenta markers and the Jaffa themselves are near 1 : 1. The markers are drawn at about 2.2 to 2.7 m, so the frieze must not come lower.
3. **Doors are the weakest item** at about 2 : 1. A door is a 3 × 2.8 m shape set in a dark wall under a gold lintel, so shape and position carry it. If the human capture review finds doors hard to pick out, the remedy is the `door` slot of G-2, not a lighter wall.
4. **Cover must be findable at a glance**, because both players and Jaffa use it ([`LevelNavigator.gd:85-99`](../../client/scripts/level/LevelNavigator.gd#L85)). Props are the only light shapes at floor level. Their size and collision do not change.
5. **The floor runner must not look like an objective marker.** Mission rings and prompts are bright and saturated; the runner is a 1.3 : 1 tone change with no outline.

These are calculations on flat colours. They do not replace looking at it: GA-1's acceptance includes a capture reviewed by a person.

## 6. How the art is made (open question 7)

**Decided: option A.** The other two stay possible later, because all three deliver the same thing to the game: cosmetic scenes behind theme variants.

**A. Built in the engine by agents (chosen).** A tool writes each piece as a scene of box meshes with the palette's materials, and writes the variant entries that place them. *Needs:* nothing new; cosmetic scenes already accept exactly these node types. *Gives:* pieces that match their slab to the millimetre by construction, a change to one number regenerates the whole kit, every piece is reviewable as text, and an agent can do it today. *Risks:* it will look blocky, since shapes are boxes and prisms and surfaces are flat colour. Good enough to prove layout, rhythm and palette; not final art.

**B. Modelled assets from a modelling tool.** Meshes exported as glTF and wrapped in cosmetic scenes. *Needs:* a person who models; an import convention (scale, origin at the slab's centre, exact bounding box); a texture budget. *Gives:* curved and chamfered forms, real surface detail. *Risks:* nobody is assigned to it; a mesh whose bounding box is 3 cm out is refused by the resolver (G-4) and silently falls back to the slab; binary assets cannot be reviewed in a pull request.

**C. Both, in sequence.** Build the kit as in A, play with it, then replace the pieces that matter most with modelled versions of the same boxes. *Needs:* A now, B later, and the piece dimensions in section 2.5 kept as the contract between them. *Risks:* the procedural kit is thrown away piece by piece; that is the intent, and it is cheap.

A now does not rule out C. If an artist joins, section 2.5's boxes are their brief.

## 7. What GA-1 did with this

1. The palette is in `goauld.tres` as `materials` under the resolver's slot names (G-1), which themes all 20 rooms.
2. `tools/theme_kit.py` generates pieces A to E as cosmetic scenes and the 20 variant entries for `Room01Straight` and `Room04Chamber` (G-4).
3. `describe` reports coverage per module (G-6), `validate_theme` rejects unknown material keys (G-1), and the two tests that asserted the fallback were changed (G-7).
4. `test_goauld_theme` proves collision and navigation are identical with and without the theme; captures of the corridor, a door and the chamber are in `docs/reviews/ga1-captures/` for a person to review.
5. Lighting (G-3), door leaves (G-2), free-standing decoration (G-5), tall rooms (G-8) and the header overlap (G-9) are untouched.

Details: [Goa'uld theme kit guide](goauld-theme-kit.md).
