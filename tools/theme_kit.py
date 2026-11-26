#!/usr/bin/env python3
"""Generate the Goa'uld cosmetic kit (GA-1 and GA-2 corridor family) from module scenes.

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
MODULES = {
    "room01": "Room01Straight.tscn",
    "room02": "Room02Corner.tscn",
    "room03": "Room03TJunction.tscn",
    "room04": "Room04Chamber.tscn",
    "room05": "Room05XJunction.tscn",
    "room06": "Room06WideStraight.tscn",
    "room07": "Room07WideCorner.tscn",
    "room08": "Room08WideJunction.tscn",
    "room09": "Room09WidthAdapter.tscn",
    "room10": "Room10LongChamber.tscn",
    "room16": "Room16HangarShell.tscn",
    "room11": "Room11LargeChamber.tscn",
}

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
# Finish both faces: a neighbouring offset header can expose its back to this room.
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


def touches(a: Slab, b: Slab) -> bool:
    return all(al <= bh + EPS and bl <= ah + EPS for al, ah, bl, bh in zip(a.low(), a.high(), b.low(), b.high()))


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
    tall = height >= 10
    floor = -height / 2  # the slab stands on the floor
    half = length / 2
    centre = slab.position[axis]
    def local(module_coordinate: float) -> float:
        return sign * (module_coordinate - centre)

    # What each end of the slab meets, in the piece's own -Z / +Z order.
    ends = {}
    pier_widths = {}
    for end in (-1, 1):
        module_end = centre + sign * end * half
        kind = "jamb"
        for other in walls:
            other_thin = 0 if other.size[0] < other.size[2] else 2
            if other is not slab and other_thin != thin and touches(slab, other):
                reach = (other.low()[axis], other.high()[axis])
                if reach[0] - EPS <= module_end <= reach[1] + EPS:
                    kind = "corner"
                    pier_widths[end] = RIB + (slab.size[thin] if overlaps(slab, other) else 0.0)
        if kind == "jamb" and abs(abs(module_end) - extent[0 if axis == 0 else 1]) < 0.01:
            kind = "edge"
        ends[end] = kind

    # Ribs: a jamb beside an opening, a pier in a corner (0.2 m of it is inside the other
    # wall when they overlap), and the 2 m grid wherever a full rib fits with a panel either side.
    ribs: list[tuple[float, float, str]] = []
    free_low, free_high = -half, half
    for end, kind in ends.items():
        if kind == "jamb":
            width = min(RIB, half) if length < .4 else RIB
            ribs.append((end * half - (width if end > 0 else 0), end * half + (width if end < 0 else 0), "Jamb"))
        elif kind == "corner":
            width = min(pier_widths[end], half) if length < .4 else pier_widths[end]
            ribs.append((end * half - (width if end > 0 else 0), end * half + (width if end < 0 else 0), "Pier"))
        else:
            continue
        if end < 0:
            free_low = ribs[-1][1]
        else:
            free_high = ribs[-1][0]
    grid_lines = [4 * i for i in range(-int(half / 4), int(half / 4) + 1)] if tall else [local(grid) for grid in GRID]
    for z in grid_lines:
        if z - RIB / 2 >= free_low + CLEARANCE - EPS and z + RIB / 2 <= free_high - CLEARANCE + EPS:
            ribs.append((z - RIB / 2, z + RIB / 2, "Rib"))
    ribs.sort()

    depth = slab.size[thin]
    back = (-depth / 2, depth / 2 - RELIEF)
    front = (depth / 2 - RELIEF, depth / 2)
    plinth = (floor, floor + PLINTH_TOP)
    panel = (floor + PLINTH_TOP, floor + FRIEZE_BASE)
    boxes: list[Box] = []
    # Wrap the finish around a jamb/corner end. Perpendicular source slabs can
    # overlap or butt together: a basalt end cap over a bronze/gold front flickers
    # at their shared face. Equal finishes at the join keep that face consistent.
    cursor = -half
    index = 0
    for low, high, kind in ribs:
        if kind not in ("Jamb", "Pier"):
            continue
        if low > cursor + EPS:
            boxes.append(span("Back%d" % index, "basalt", back, (floor, floor + height), (cursor, low)))
            index += 1
        boxes.append(span("Reveal%d" % index, "bronze", back, (floor, floor + BAND[0]), (low, high)))
        boxes.append(span("RevealBand%d" % index, "gold", back, (floor + BAND[0], floor + BAND[1]), (low, high)))
        boxes.append(span("RevealUpper%d" % index, "bronze", back, (floor + BAND[1], floor + height), (low, high)))
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
    if tall:
        boxes.extend([
            span("FriezeUpper", "bronze", front, (floor + BAND[1], floor + 3.48), (-half, half)),
            span("UpperBand", "gold", front, (floor + 10.08, floor + 10.22), (-half, half)),
            span("Crown", "bronze", front, (floor + 10.22, floor + height), (-half, half)),
        ])
        for index, (low, high, _kind) in enumerate(ribs):
            boxes.append(span("UpperRib%d" % index, "bronze", front, (floor + 3.48, floor + 10.08), (low, high)))
    else:
        boxes.append(span("FriezeUpper", "bronze", front, (floor + BAND[1], floor + height), (-half, half)))
    if slab.name == "Wall15" and tall and length > 30:
        # The cabinet doors and lintel sit in the recess between the -12 m and -8 m ribs.
        service_back = (back[1], front[1] - .035)
        for index, start in enumerate((-11.2, -10.1, -9.0)):
            boxes.append(span("ServiceDoor%d" % index, "portal", service_back,
                              (floor + .76, floor + 2.14), (start, start + .72)))
            boxes.append(span("ServicePull%d" % index, "bronze", (service_back[1], front[1]),
                              (floor + 1.10, floor + 1.21), (start + .25, start + .47)))
        boxes.append(span("ServiceLintel", "bronze", front, (floor + 2.14, floor + 2.32), (-11.38, -8.24)))
    if slab.name == "Wall26" and length == 5.0 and height == 3.4:
        # A recessed raceway between the jamb and the first rib of the long chamber.
        boxes.append(span("ServiceChannel", "portal", (back[1], front[1] - .032),
                          (floor + 1.48, floor + 2.42), (-1.65, .45)))
        for index, y in enumerate((1.68, 1.93, 2.18)):
            boxes.append(span("ServiceRail%d" % index, "bronze", (front[1] - .032, front[1]),
                              (floor + y, floor + y + .065), (-1.54, .33)))
    if slab.name == "Wall34" and slab.position == (11.9, 1.7, 4.0):
        # A stepped bronze seal sits in the command chamber's eastern wall recess.
        relief_face = front[1] - .028
        boxes.append(span("SealPanel", "portal", (back[1], relief_face),
                          (floor + .85, floor + 2.72), (-1.78, .62)))
        for index, (width, y) in enumerate(((1.72, 1.26), (1.25, 1.54), (.76, 1.82), (.3, 2.10))):
            boxes.append(span("SealTier%d" % index, "bronze", (relief_face, front[1]),
                              (floor + y, floor + y + .16), (-.58 - width / 2, -.58 + width / 2)))
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
    reverse = (-depth / 2 - PROUD, -depth / 2)
    band_height = BAND if base < BAND[0] else (base + .08, base + .22)
    band = (band_height[0] - base - height / 2, band_height[1] - base - height / 2)
    key = CARTOUCHE / 2
    return (
        [
            span("Back", "bronze", back, (-height / 2, height / 2), (-half, half)),
            span("Cartouche", "gold", front, (-height / 2 + SOFFIT_GAP, height / 2), (-key, key)),
            span("BandA", "gold", front, band, (-half, -key)),
            span("BandB", "gold", front, band, (key, half)),
            span("CartoucheBack", "gold", reverse, (-height / 2 + SOFFIT_GAP, height / 2), (-key, key)),
            span("BandBackA", "gold", reverse, band, (-half, -key)),
            span("BandBackB", "gold", reverse, band, (key, half)),
        ],
        turn,
    )


def is_passage(slab: Slab) -> bool:
    """A floor or ceiling of a corridor (3 m or 6 m wide) rather than of a room."""
    return min(slab.size[0], slab.size[2]) <= 6.0 + EPS


def passage_along_z(slab: Slab) -> bool:
    """Whether a passage floor or ceiling slab runs along the module's Z axis."""
    return abs(slab.position[0]) < EPS and slab.size[0] in (3.0, 6.0)


def corridor_floor(slab: Slab, openings: list[Slab]) -> list[Box]:
    """Clip connected runner arms to this floor slab, then tile without overlapping faces.

    The headers supply the real branch directions. A short north/south branch must
    continue into an east/west centre slab; choosing a runner from each slab's long
    axis alone leaves a dark break at a corner or junction.
    """
    r = RUNNER / 2
    runners = [(-r, r, -r, r)]
    for opening in openings:
        if opening.size[0] < opening.size[2]:
            x, z = opening.position[0], opening.position[2]
            reach = x + (opening.size[0] / 2 if x > 0 else -opening.size[0] / 2)
            runners.append((min(0.0, reach), max(0.0, reach), z - r, z + r))
        else:
            x, z = opening.position[0], opening.position[2]
            reach = z + (opening.size[2] / 2 if z > 0 else -opening.size[2] / 2)
            runners.append((x - r, x + r, min(0.0, reach), max(0.0, reach)))
    x0, _, z0 = slab.low()
    x1, _, z1 = slab.high()
    xs = sorted({x0, x1} | {v for rect in runners for v in rect[:2] if x0 < v < x1})
    zs = sorted({z0, z1} | {v for rect in runners for v in rect[2:] if z0 < v < z1})
    # Merge equal neighbouring cells, first along rows, then across rows. The result
    # stays a small set of disjoint boxes, including at a four-way crossing.
    rectangles: list[tuple[float, float, float, float, str]] = []
    active: dict[tuple[float, float, str], int] = {}
    for za, zb in zip(zs, zs[1:]):
        row: list[tuple[float, float, str]] = []
        for xa, xb in zip(xs, xs[1:]):
            cx, cz = (xa + xb) / 2, (za + zb) / 2
            material = "floor_runner" if any(a <= cx <= b and c <= cz <= d for a, b, c, d in runners) else "floor_margin"
            if row and row[-1][2] == material:
                row[-1] = (row[-1][0], xb, material)
            else:
                row.append((xa, xb, material))
        next_active = {}
        for xa, xb, material in row:
            key = (xa, xb, material)
            if key in active:
                index = active[key]
                previous = rectangles[index]
                rectangles[index] = (xa, xb, previous[2], zb, material)
            else:
                index = len(rectangles)
                rectangles.append((xa, xb, za, zb, material))
            next_active[key] = index
        active = next_active
    return [
        span(("Runner" if material == "floor_runner" else "Margin") + str(index), material,
             (xa - slab.position[0], xb - slab.position[0]), (-slab.size[1] / 2, slab.size[1] / 2),
             (za - slab.position[2], zb - slab.position[2]))
        for index, (xa, xb, za, zb, material) in enumerate(rectangles)
    ]


def floor_piece(slab: Slab, openings: list[Slab] | None = None) -> list[Box]:
    """Colour only: every box is the full slab thickness, so the walking surface is flat."""
    x, t, z = (s / 2 for s in slab.size)
    full = (-t, t)
    if min(x, z) <= .4:
        return [span("PortalFloor", "floor_runner", (-x, x), full, (-z, z))]
    if openings is not None:
        return corridor_floor(slab, openings)
    if is_passage(slab):
        r = RUNNER / 2
        if passage_along_z(slab):
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
    if min(x, z) <= .4:
        return [span("PortalRoof", "ceiling", (-x, x), (-t, t), (-z, z))]
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
        along_z = passage_along_z(slab)
        axis = 2 if along_z else 0
        limit = inner_z if along_z else inner_x
        centre = slab.position[axis]
        index = 0
        for grid in GRID:
            low, high = grid - centre - RIB / 2, grid - centre + RIB / 2
            if low >= -limit + CLEARANCE - EPS and high <= limit - CLEARANCE + EPS:
                if along_z:
                    boxes.append(span("Beam%d" % index, "bronze", (-inner_x, inner_x), beam, (low, high)))
                else:
                    boxes.append(span("Beam%d" % index, "bronze", (low, high), beam, (-inner_z, inner_z)))
                index += 1
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
        openings = [slab for slab in slabs if slab.slot == "door_frame"]
        extent = (
            max(abs(v) for slab in walls for v in (slab.low()[0], slab.high()[0])),
            max(abs(v) for slab in walls for v in (slab.low()[2], slab.high()[2])),
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
                boxes = floor_piece(slab, openings if module_id not in ("room01", "room04", "room16") else None)
                kind = "floor"
            elif slab.slot == "ceiling":
                boxes, kind = ceiling_piece(slab, jambs), "ceiling"
            else:
                continue  # sealed openings take the palette only
            if any(min(box.size) <= EPS for box in boxes):
                raise ValueError("Nonpositive cosmetic box in %s/%s" % (module_id, slab.name))
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
