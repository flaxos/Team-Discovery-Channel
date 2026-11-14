#!/usr/bin/env python3
"""Generate the Goa'uld cosmetic kit (roadmap GA-1) from the module scenes.

Every piece replaces one structural slab and fills exactly that slab's box, so
collision, sockets and navigation are untouched (decision D-010). Relief is cut
into the 0.2 m slab; nothing stands in front of it. The design, with the reason
for each number, is docs/maps/goauld-visual-brief.md.

    python3 tools/theme_kit.py            # write the kit
    python3 tools/theme_kit.py --check    # fail if the committed kit is stale

Standard library only. The output is plain Godot text resources:

    client/resources/level_themes/goauld.tres        the theme: palette and variants
    client/resources/level_themes/goauld/*.tres      one material per palette role
    client/scenes/level/themes/goauld/*.tscn         one scene per distinct piece
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "client"
MODULE_SCENES = CLIENT / "scenes/level/modules"
THEME_FILE = CLIENT / "resources/level_themes/goauld.tres"
MATERIAL_DIR = CLIENT / "resources/level_themes/goauld"
SCENE_DIR = CLIENT / "scenes/level/themes/goauld"

# Modules that receive built pieces. Every other module gets the palette only.
MODULES = {"room01": "Room01Straight.tscn", "room04": "Room04Chamber.tscn"}

# name: (albedo, metallic, roughness). Values and contrast checks: brief, section 2.3.
# Nothing is metallic: a mission has no sky or reflection probe, so a metallic surface
# loses its albedo and gold renders the same dull brown as bronze. Sheen is roughness only.
PALETTE = {
    "basalt": ((0.16, 0.13, 0.11), 0.0, 0.85),
    "bronze": ((0.30, 0.22, 0.13), 0.0, 0.5),
    "gold": ((0.66, 0.49, 0.18), 0.0, 0.35),
    "floor_margin": ((0.11, 0.10, 0.10), 0.0, 0.45),
    "floor_runner": ((0.21, 0.18, 0.14), 0.0, 0.6),
    "ceiling": ((0.08, 0.07, 0.07), 0.0, 0.9),
    "portal": ((0.13, 0.11, 0.10), 0.0, 0.7),
    "prop": ((0.50, 0.43, 0.32), 0.0, 0.8),
}
# Resolver slot -> material used on slabs that have no built piece.
SLOT_MATERIALS = {
    "wall": "basalt",
    "floor": "floor_runner",
    "ceiling": "ceiling",
    "door_frame": "bronze",
    "portal": "portal",
    "detail": "bronze",
    "prop": "prop",
}

RELIEF = 0.10  # depth of every recess, cut into the 0.2 m slab
RIB = 0.4  # rib and beam width
GRID = (-3.0, -1.0, 1.0, 3.0)  # rib centres, measured from the module centre
PLINTH_TOP = 0.6  # metres above the floor
FRIEZE_BASE = 2.8  # door-head height; gold never comes below this
BAND = (3.04, 3.16)  # the gold band, metres above the floor
CARTOUCHE = 1.0  # width of the gold block on a lintel
LINTEL_RELIEF = 0.04
# Ten modules place their north and south headers 0.2 m outside their own cell, in the slab
# the adjoining room's lintel occupies (brief, gap G-9). The lintel's gold therefore stands
# 5 mm proud of the slab, inside the resolver's 1 cm tolerance, so it is drawn in front of
# such a header instead of flickering against it, and stops 2 cm short of the soffit.
PROUD = 0.005
SOFFIT_GAP = 0.02
RUNNER = 1.6  # width of a corridor's floor runner
MARGIN = 0.7  # visible floor margin in a room
BORDER = 0.2  # flush ceiling border that shows inside the walls
CLEARANCE = 0.3  # least panel width left beside a grid rib
EPS = 1e-6


@dataclass(frozen=True)
class Box:
    """An axis-aligned box in a piece's own frame: centre, size, material, node name."""

    name: str
    centre: tuple[float, float, float]
    size: tuple[float, float, float]
    material: str

    def low(self) -> tuple[float, ...]:
        return tuple(c - s / 2 for c, s in zip(self.centre, self.size))

    def high(self) -> tuple[float, ...]:
        return tuple(c + s / 2 for c, s in zip(self.centre, self.size))


@dataclass(frozen=True)
class Slab:
    """One structural mesh of a module scene, in module coordinates."""

    name: str
    slot: str
    position: tuple[float, float, float]
    size: tuple[float, float, float]

    def low(self) -> tuple[float, ...]:
        return tuple(p - s / 2 for p, s in zip(self.position, self.size))

    def high(self) -> tuple[float, ...]:
        return tuple(p + s / 2 for p, s in zip(self.position, self.size))


def span(name: str, material: str, x: tuple, y: tuple, z: tuple) -> Box:
    """A box from its (low, high) extent on each axis."""
    return Box(
        name,
        tuple((a + b) / 2 for a, b in (x, y, z)),
        tuple(b - a for a, b in (x, y, z)),
        material,
    )


def slot_of(name: str, parent: str) -> str:
    """The resolver's rule (LevelThemeResolver.slot), so both always agree."""
    lower = name.lower()
    if lower.startswith("floor"):
        return "floor"
    if lower.startswith(("roof", "ceiling")):
        return "ceiling"
    if lower.startswith("header"):
        return "door_frame"
    if parent.endswith("Closures"):
        return "portal"
    if lower.startswith("wall"):
        return "wall"
    return "detail"


def read_slabs(scene: Path) -> list[Slab]:
    """Themed meshes of a module scene: name, slot, position and declared dimensions."""
    slabs = []
    pattern = re.compile(
        r'\[node name="([^"]+)" type="MeshInstance3D" parent="(Visuals[^"]*)"\]\n((?:(?!\[).*\n)*)'
    )
    for name, parent, body in pattern.findall(scene.read_text()):
        position = re.search(r"^position = Vector3\(([^)]*)\)", body, re.M)
        size = re.search(r"^metadata/dimensions = Vector3\(([^)]*)\)", body, re.M)
        if size is None:
            continue
        slabs.append(
            Slab(
                name,
                slot_of(name, parent),
                tuple(float(v) for v in position.group(1).split(",")) if position else (0.0, 0.0, 0.0),
                tuple(float(v) for v in size.group(1).split(",")),
            )
        )
    return slabs


def overlaps(a: Slab, b: Slab) -> bool:
    return all(al < bh - EPS and bl < ah - EPS for al, ah, bl, bh in zip(a.low(), a.high(), b.low(), b.high()))


# --- Orientation ------------------------------------------------------------------------
# Walls and lintels are authored once, facing +X with their length along Z, and turned
# about Y to face the room. turn is in quarter-turns; ROTATIONS holds the basis rows as
# Godot writes a Transform3D, and where the piece's own +Z axis ends up in the module.
ROTATIONS = {
    0: ((1, 0, 0, 0, 1, 0, 0, 0, 1), (2, 1)),  # faces +X; length runs +Z
    1: ((0, 0, 1, 0, 1, 0, -1, 0, 0), (0, 1)),  # faces -Z; length runs +X
    2: ((-1, 0, 0, 0, 1, 0, 0, 0, -1), (2, -1)),  # faces -X; length runs -Z
    3: ((0, 0, -1, 0, 1, 0, 1, 0, 0), (0, -1)),  # faces +Z; length runs -X
}


def facing(slab: Slab) -> int:
    """Quarter-turns that point the piece's +X at the module centre."""
    thin = 0 if slab.size[0] < slab.size[2] else 2
    inward = -1 if slab.position[thin] > 0 else 1
    if thin == 0:
        return 0 if inward > 0 else 2
    return 3 if inward > 0 else 1


# --- Pieces -----------------------------------------------------------------------------
def wall_piece(slab: Slab, walls: list[Slab], extent: tuple[float, float]) -> tuple[list[Box], int, str]:
    """A wall in its own frame (room towards +X, length along Z), its turn, and what its
    two ends meet ("edge", "jamb" or "corner"), which names the scene."""
    turn = facing(slab)
    axis, sign = ROTATIONS[turn][1]
    thin = 2 - axis if axis in (0, 2) else 0
    length = slab.size[axis]
    height = slab.size[1]
    floor = -height / 2  # the slab stands on the floor
    half = length / 2
    centre = slab.position[axis]

    def local(module_coordinate: float) -> float:
        return sign * (module_coordinate - centre)

    # What each end of the slab meets, in the piece's own -Z / +Z order.
    ends = {}
    for end in (-1, 1):
        module_end = centre + sign * end * half
        kind = "jamb"
        for other in walls:
            other_thin = 0 if other.size[0] < other.size[2] else 2
            if other is not slab and other_thin != thin and overlaps(slab, other):
                reach = (other.low()[axis], other.high()[axis])
                if reach[0] - EPS <= module_end <= reach[1] + EPS:
                    kind = "corner"
        if kind == "jamb" and abs(abs(module_end) - extent[0 if axis == 0 else 1]) < 0.01:
            kind = "edge"
        ends[end] = kind

    # Ribs: a jamb beside an opening, a pier in a corner (0.2 m of it is inside the other
    # wall), and the 2 m grid wherever a full rib fits with a panel either side.
    ribs: list[tuple[float, float, str]] = []
    free_low, free_high = -half, half
    for end, kind in ends.items():
        if kind == "jamb":
            ribs.append((end * half - (RIB if end > 0 else 0), end * half + (RIB if end < 0 else 0), "Jamb"))
        elif kind == "corner":
            width = RIB + slab.size[thin]
            ribs.append((end * half - (width if end > 0 else 0), end * half + (width if end < 0 else 0), "Pier"))
        else:
            continue
        if end < 0:
            free_low = ribs[-1][1]
        else:
            free_high = ribs[-1][0]
    for grid in GRID:
        z = local(grid)
        if z - RIB / 2 >= free_low + CLEARANCE - EPS and z + RIB / 2 <= free_high - CLEARANCE + EPS:
            ribs.append((z - RIB / 2, z + RIB / 2, "Rib"))
    ribs.sort()

    depth = slab.size[thin]
    back = (-depth / 2, depth / 2 - RELIEF)
    front = (depth / 2 - RELIEF, depth / 2)
    plinth = (floor, floor + PLINTH_TOP)
    panel = (floor + PLINTH_TOP, floor + FRIEZE_BASE)
    boxes: list[Box] = []
    # Back of the slab: stone behind the panels, bronze where a jamb's reveal shows.
    cursor = -half
    index = 0
    for low, high, kind in ribs:
        if kind != "Jamb":
            continue
        if low > cursor + EPS:
            boxes.append(span("Back%d" % index, "basalt", back, (floor, floor + height), (cursor, low)))
            index += 1
        boxes.append(span("Reveal%d" % index, "bronze", back, (floor, floor + height), (low, high)))
        index += 1
        cursor = high
    if cursor < half - EPS:
        boxes.append(span("Back%d" % index, "basalt", back, (floor, floor + height), (cursor, half)))
    # Front 0.10 m: plinth, ribs, frieze with its gold band. Panels are the gaps.
    boxes.append(span("Plinth", "bronze", front, plinth, (-half, half)))
    for index, (low, high, kind) in enumerate(ribs):
        boxes.append(span("%s%d" % (kind, index), "bronze", front, panel, (low, high)))
    boxes.append(span("FriezeLower", "bronze", front, (floor + FRIEZE_BASE, floor + BAND[0]), (-half, half)))
    boxes.append(span("Band", "gold", front, (floor + BAND[0], floor + BAND[1]), (-half, half)))
    boxes.append(span("FriezeUpper", "bronze", front, (floor + BAND[1], floor + height), (-half, half)))
    return boxes, turn, "%s_%s" % (ends[-1], ends[1])


def lintel_piece(slab: Slab) -> tuple[list[Box], int]:
    """A door lintel in its own frame (room towards +X, width along Z) and its turn."""
    turn = facing(slab)
    axis, _sign = ROTATIONS[turn][1]
    thin = 2 - axis
    width = slab.size[axis]
    height = slab.size[1]
    depth = slab.size[thin]
    half = width / 2
    base = slab.position[1] - height / 2  # metres above the floor
    back = (-depth / 2, depth / 2 - LINTEL_RELIEF)
    front = (depth / 2 - LINTEL_RELIEF, depth / 2 + PROUD)
    band = (BAND[0] - base - height / 2, BAND[1] - base - height / 2)
    key = CARTOUCHE / 2
    return (
        [
            span("Back", "bronze", back, (-height / 2, height / 2), (-half, half)),
            span("Cartouche", "gold", front, (-height / 2 + SOFFIT_GAP, height / 2), (-key, key)),
            span("BandA", "gold", front, band, (-half, -key)),
            span("BandB", "gold", front, band, (key, half)),
        ],
        turn,
    )


def is_passage(slab: Slab) -> bool:
    """A floor or ceiling of a corridor (3 m wide) rather than of a room."""
    return min(slab.size[0], slab.size[2]) <= 3.0 + EPS


def floor_piece(slab: Slab) -> list[Box]:
    """Colour only: every box is the full slab thickness, so the walking surface is flat."""
    x, t, z = (s / 2 for s in slab.size)
    full = (-t, t)
    if is_passage(slab):
        r = RUNNER / 2
        if slab.size[2] >= slab.size[0]:
            return [
                span("MarginA", "floor_margin", (-x, -r), full, (-z, z)),
                span("Runner", "floor_runner", (-r, r), full, (-z, z)),
                span("MarginB", "floor_margin", (r, x), full, (-z, z)),
            ]
        return [
            span("MarginA", "floor_margin", (-x, x), full, (-z, -r)),
            span("Runner", "floor_runner", (-x, x), full, (-r, r)),
            span("MarginB", "floor_margin", (-x, x), full, (r, z)),
        ]
    # A room: the walls stand on the outer 0.2 m; a margin shows inside them.
    inset = 0.2 + MARGIN
    return [
        span("MarginNorth", "floor_margin", (-x, x), full, (-z, -z + inset)),
        span("MarginSouth", "floor_margin", (-x, x), full, (z - inset, z)),
        span("MarginWest", "floor_margin", (-x, -x + inset), full, (-z + inset, z - inset)),
        span("MarginEast", "floor_margin", (x - inset, x), full, (-z + inset, z - inset)),
        span("Runner", "floor_runner", (-x + inset, x - inset), full, (-z + inset, z - inset)),
    ]


def ceiling_piece(slab: Slab, jambs: list[float]) -> list[Box]:
    """A coffered ceiling: beams flush with the slab's lower face, the bays between them
    recessed upward. A flush border runs round the whole slab, because the walls and
    lintels stop at the slab's lower face: a bay that reached the edge would leave a slit
    above them, open to whatever is outside."""
    x, t, z = (s / 2 for s in slab.size)
    boxes = [span("Bays", "ceiling", (-x, x), (-t + RELIEF, t), (-z, z))]
    beam = (-t, -t + RELIEF)
    passage = is_passage(slab)
    # A room's slab also covers its 0.2 m walls; a passage's sits between them.
    edge = BORDER if passage else BORDER + 0.2
    boxes += [
        span("BorderNorth", "bronze", (-x, x), beam, (-z, -z + edge)),
        span("BorderSouth", "bronze", (-x, x), beam, (z - edge, z)),
        span("BorderWest", "bronze", (-x, -x + edge), beam, (-z + edge, z - edge)),
        span("BorderEast", "bronze", (x - edge, x), beam, (-z + edge, z - edge)),
    ]
    inner_x, inner_z = x - edge, z - edge
    if passage:
        along_z = slab.size[2] >= slab.size[0]
        for index, grid in enumerate(GRID):
            low, high = grid - RIB / 2, grid + RIB / 2
            if along_z:
                boxes.append(span("Beam%d" % index, "bronze", (-inner_x, inner_x), beam, (low, high)))
            else:
                boxes.append(span("Beam%d" % index, "bronze", (low, high), beam, (-inner_z, inner_z)))
        return boxes
    # A room: beams spring from the door jambs in both directions. Those along X run
    # through; those along Z are cut where they cross, so no two boxes share a volume.
    lines = sorted(jambs)
    for index, line in enumerate(lines):
        boxes.append(span("BeamX%d" % index, "bronze", (-inner_x, inner_x), beam, (line - RIB / 2, line + RIB / 2)))
    cuts = [-inner_z] + [edge_z for line in lines for edge_z in (line - RIB / 2, line + RIB / 2)] + [inner_z]
    for index, line in enumerate(lines):
        for part in range(0, len(cuts), 2):
            boxes.append(
                span("BeamZ%d_%d" % (index, part // 2), "bronze", (line - RIB / 2, line + RIB / 2), beam, (cuts[part], cuts[part + 1]))
            )
    return boxes


# --- Godot text -------------------------------------------------------------------------
def number(value: float) -> str:
    text = ("%.4f" % value).rstrip("0").rstrip(".")
    return "0" if text in ("", "-0") else text


def vector(values) -> str:
    return "Vector3(%s)" % ", ".join(number(v) for v in values)


def material_text(name: str) -> str:
    colour, metallic, roughness = PALETTE[name]
    return (
        '[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\n'
        "albedo_color = Color(%s, 1)\nmetallic = %s\nroughness = %s\n"
        % (", ".join(number(c) for c in colour), number(metallic), number(roughness))
    )


def scene_text(root: str, boxes: list[Box]) -> str:
    used = sorted({box.material for box in boxes})
    lines = ["[gd_scene format=3]", ""]
    for name in used:
        lines.append(
            '[ext_resource type="StandardMaterial3D" path="res://resources/level_themes/goauld/%s.tres" id="%s"]'
            % (name, name)
        )
    lines.append("")
    for index, box in enumerate(boxes):
        lines += [
            '[sub_resource type="BoxMesh" id="m%d"]' % index,
            'material = ExtResource("%s")' % box.material,
            "size = %s" % vector(box.size),
            "",
        ]
    lines += ['[node name="%s" type="Node3D"]' % root, ""]
    for index, box in enumerate(boxes):
        lines += [
            '[node name="%s" type="MeshInstance3D" parent="."]' % box.name,
            "position = %s" % vector(box.centre),
            'mesh = SubResource("m%d")' % index,
            "",
        ]
    return "\n".join(lines).rstrip("\n") + "\n"


def theme_text(variants: list[dict]) -> str:
    lines = [
        '[gd_resource type="Resource" script_class="LevelVisualTheme" format=3]',
        "",
        '[ext_resource type="Script" path="res://scripts/level/LevelVisualTheme.gd" id="1"]',
        '[ext_resource type="Resource" path="res://resources/level_themes/neutral_lighting.tres" id="2"]',
        '[ext_resource type="Script" path="res://scripts/level/LevelThemeVariant.gd" id="3"]',
    ]
    for name in sorted(set(SLOT_MATERIALS.values())):
        lines.append(
            '[ext_resource type="StandardMaterial3D" path="res://resources/level_themes/goauld/%s.tres" id="%s"]'
            % (name, name)
        )
    lines.append("")
    for index, variant in enumerate(variants):
        lines += [
            '[sub_resource type="Resource" id="v%d"]' % index,
            'script = ExtResource("3")',
            'id = &"%s"' % variant["id"],
            'slot = &"%s"' % variant["slot"],
            'module_ids = PackedStringArray("%s")' % variant["module"],
            'scene_path = "res://scenes/level/themes/goauld/%s.tscn"' % variant["scene"],
            "local_transform = Transform3D(%s, 0, 0, 0)" % ", ".join(str(v) for v in ROTATIONS[variant["turn"]][0]),
            "",
        ]
    materials = ", ".join('"%s": ExtResource("%s")' % (slot, SLOT_MATERIALS[slot]) for slot in sorted(SLOT_MATERIALS))
    lines += [
        "[resource]",
        'script = ExtResource("1")',
        'id = &"goauld"',
        'display_name = "Goa’uld"',
        'description = "Fortified base or ship: dark stone carried on heavy bronze ribs, with gold kept to a band above door-head height."',
        'synonyms = PackedStringArray("goauld", "jaffa", "pyramid", "mothership")',
        'fallback_id = &"neutral"',
        'compatible_families = PackedStringArray("corridor", "chamber", "adapter", "vertical")',
        'lighting = ExtResource("2")',
        "materials = {%s}" % materials,
        'variants = Array[ExtResource("3")]([%s])' % ", ".join('SubResource("v%d")' % i for i in range(len(variants))),
        "decoration_slots = PackedStringArray(%s)" % ", ".join('"%s"' % slot for slot in sorted(SLOT_MATERIALS)),
        'art_status = "authored"',
    ]
    return "\n".join(lines) + "\n"


# --- Assembly ---------------------------------------------------------------------------
def build() -> tuple[dict[Path, str], list[dict], dict[str, tuple[Slab, list[Box], int]]]:
    """Every file of the kit, the variant table, and each piece with the slab it replaces."""
    files: dict[Path, str] = {}
    variants: list[dict] = []
    pieces: dict[str, tuple[Slab, list[Box], int]] = {}
    scenes: dict[str, str] = {}  # scene text -> scene name, so identical pieces are shared
    for name in PALETTE:
        files[MATERIAL_DIR / (name + ".tres")] = material_text(name)
    for module_id, scene_file in MODULES.items():
        slabs = read_slabs(MODULE_SCENES / scene_file)
        walls = [slab for slab in slabs if slab.slot == "wall"]
        extent = (
            max(abs(v) for slab in slabs for v in (slab.low()[0], slab.high()[0])),
            max(abs(v) for slab in slabs for v in (slab.low()[2], slab.high()[2])),
        )
        # Door jamb lines, from the lintels: where the room's ceiling beams spring.
        jambs = sorted(
            {
                round(sign * (max(slab.size[0], slab.size[2]) / 2 + RIB / 2), 4)
                for slab in slabs
                if slab.slot == "door_frame"
                for sign in (-1, 1)
            }
        )
        for slab in slabs:
            turn = 0
            if slab.slot == "wall":
                boxes, turn, ends = wall_piece(slab, walls, extent)
                kind = "wall"
            elif slab.slot == "door_frame":
                boxes, turn = lintel_piece(slab)
                kind = "lintel"
            elif slab.slot == "floor":
                boxes, kind = floor_piece(slab), "floor"
            elif slab.slot == "ceiling":
                boxes, kind = ceiling_piece(slab, jambs), "ceiling"
            else:
                continue  # sealed openings take the palette only
            size = slab.size if turn % 2 == 0 else (slab.size[2], slab.size[1], slab.size[0])
            stem = "%s_%s" % (kind, "x".join(str(round(v * 100)) for v in size))
            if kind == "wall":
                stem += "_" + ends
            text = scene_text(kind.capitalize(), boxes)
            if text not in scenes:
                taken = set(scenes.values())
                scene_name = stem
                suffix = ord("b")
                while scene_name in taken:
                    scene_name = "%s_%s" % (stem, chr(suffix))
                    suffix += 1
                scenes[text] = scene_name
                files[SCENE_DIR / (scene_name + ".tscn")] = text
            variant_id = "%s_%s" % (module_id, slab.name)
            variants.append(
                {"id": variant_id, "slot": slab.name, "module": module_id, "scene": scenes[text], "turn": turn}
            )
            pieces[variant_id] = (slab, boxes, turn)
    files[THEME_FILE] = theme_text(variants)
    return files, variants, pieces


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="Fail if the committed kit differs from the generator.")
    args = parser.parse_args()
    files, variants, _pieces = build()
    generated = {path for path in files}
    stale = [path for path, text in files.items() if not path.is_file() or path.read_text() != text]
    extra = [
        path
        for folder, pattern in ((MATERIAL_DIR, "*.tres"), (SCENE_DIR, "*.tscn"))
        if folder.is_dir()
        for path in folder.glob(pattern)
        if path not in generated
    ]
    if args.check:
        for path in stale + extra:
            print("stale: %s" % path.relative_to(ROOT))
        return 1 if stale or extra else 0
    for path in extra:
        path.unlink()
    for path in stale:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(files[path])
    print(
        "Goa'uld kit: %d files (%d rewritten, %d removed), %d variants on %s"
        % (len(files), len(stale), len(extra), len(variants), ", ".join(MODULES))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
