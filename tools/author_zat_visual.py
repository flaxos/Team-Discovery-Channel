#!/usr/bin/env python3
"""Build the original loop-frame Zat visual with Python, NumPy and Pillow.

Takes a staging directory and a destination .glb. No external model or image inputs.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from gltf_to_glb import pack

# Rows are x, y, z and the lateral and in-plane radii in the weapon's local metres.
UPPER = [
    (0, -.035, .105, 0, 0), (0, -.031, .096, .016, .021),
    (0, -.009, .083, .023, .020), (0, .025, .060, .026, .018),
    (0, .049, .020, .029, .019), (0, .054, -.025, .030, .018),
    (0, .046, -.064, .024, .015), (0, .037, -.109, .018, .010),
    (0, .043, -.148, .021, .012), (0, .05, -.176, .021, .016),
    (0, .05, -.194, .017, .014), (0, .05, -.199, .015, .012),
    (0, .05, -.200, .010, .008), (0, .05, -.200, 0, 0),
]
LOWER = [
    (0, -.016, .093, 0, 0), (0, -.041, .071, .021, .014),
    (0, -.052, .032, .024, .016), (0, -.056, -.008, .024, .015),
    (0, -.049, -.045, .022, .015), (0, -.037, -.071, .018, .012),
    (0, -.015, -.095, .016, .010), (0, .009, -.110, .013, .011),
    (0, .036, -.113, .011, .010), (0, .041, -.115, 0, 0),
]
RAIL = [
    (.014, .016, .048, 0, 0), (.022, .011, .034, .006, .004),
    (.024, .004, .007, .007, .005), (.022, -.001, -.028, .007, .005),
    (.019, .003, -.061, .006, .004), (.016, .014, -.093, .005, .003),
    (.012, .033, -.118, 0, 0),
]
SIDES = 32
SUBSTEPS = 4
SIZE = 1024


def unit(values):
    length = np.linalg.norm(values, axis=-1, keepdims=True)
    return values / np.maximum(length, 1e-12)


def smooth_profile(rows):
    """Cubic interpolation with exactly preserved ends and soft curved shoulders."""
    p = np.asarray(rows, dtype=np.float64)
    padded = np.concatenate([p[:1], p, p[-1:]])
    t = np.arange(0, 1, 1 / SUBSTEPS)[:, None]
    segments = []
    for i in range(1, len(p)):
        a, b, c, d = padded[i - 1:i + 3]
        segments.append(b + .5 * t * (
            c - a + t * (2*a - 5*b + 4*c - d + t * (3*(b - c) + d - a))
        ))
    curve = np.concatenate([*segments, p[-1:]])
    curve[:, 3:] = np.maximum(curve[:, 3:], 0.0)
    return curve


def sweep(rows, interval, front_tip=False):
    profile = smooth_profile(rows)
    centre = profile[:, :3]
    along = unit(np.gradient(centre, axis=0))
    # Keep the muzzle rim square to -Z at the fixed aperture.
    if front_tip:
        centre[:, 2] = np.maximum(centre[:, 2], -.200)
        along[-(SUBSTEPS + 1):] = (0, 0, -1)
    side = np.broadcast_to([1.0, 0.0, 0.0], along.shape)
    cross = unit(np.cross(along, side))
    side = unit(np.cross(cross, along))
    theta = np.linspace(0, 2*np.pi, SIDES + 1)
    theta[-1] = 0.0
    cos, sin = np.cos(theta)[None, :, None], np.sin(theta)[None, :, None]
    radius_x = profile[:, 3, None, None]
    radius_y = profile[:, 4, None, None]
    # Flatten the shoulders slightly while keeping the two ends closed.
    form = 1 + 0.06 * np.cos(4 * theta)[None, :, None]
    grid = centre[:, None, :] + form * (cos * side[:, None, :] * radius_x + sin * cross[:, None, :] * radius_y)
    tangent = np.empty_like(grid)
    tangent[1:-1, :-1] = unit(np.roll(grid[1:-1, :-1], -1, axis=1) - np.roll(grid[1:-1, :-1], 1, axis=1))
    tangent[1:-1, -1] = tangent[1:-1, 0]
    tangent[0] = -sin[0] * side[0] + cos[0] * cross[0]
    tangent[-1] = -sin[0] * side[-1] + cos[0] * cross[-1]
    normal = unit(np.cross(tangent, np.gradient(grid, axis=0)))
    normal[0] = -along[0]
    normal[-1] = along[-1]
    tangents = np.concatenate([tangent, np.ones_like(grid[:, :, :1])], axis=-1)
    u = np.broadcast_to(np.linspace(0, 1, SIDES + 1), grid.shape[:2])
    v = np.broadcast_to(np.linspace(*interval, len(profile))[:, None], u.shape)
    indices = []
    for ring in range(len(profile) - 1):
        for side_index in range(SIDES):
            a = ring * (SIDES + 1) + side_index
            b = a + SIDES + 1
            if ring > 0:
                indices.extend((a, a + 1, b))
            if ring < len(profile) - 2:
                indices.extend((a + 1, b + 1, b))
    uv = np.stack([u, v], axis=-1)
    return grid.reshape(-1, 3), normal.reshape(-1, 3), tangents.reshape(-1, 4), uv.reshape(-1, 2), np.array(indices)


def make_mesh():
    mirror = [(-x, y, z, rx, ry) for x, y, z, rx, ry in RAIL]
    parts = [sweep(UPPER, (.025, .50), True), sweep(LOWER, (.53, .75)),
             sweep(RAIL, (.80, .97)), sweep(mirror, (.80, .97))]
    offsets = np.cumsum([0] + [len(part[0]) for part in parts[:-1]])
    attributes = [np.concatenate(columns) for columns in zip(*(part[:4] for part in parts))]
    indices = np.concatenate([part[4] + offset for part, offset in zip(parts, offsets)])
    return *attributes, indices


def paint(directory):
    u = np.arange(SIZE)[None, :] / SIZE
    v = np.arange(SIZE)[:, None] / (SIZE - 1)
    grain = np.random.default_rng(909).normal(0, .16, (SIZE, SIZE))
    burnish = np.sin(2*np.pi*(5*u + 8*v)) * np.sin(2*np.pi*(3*u - 6*v))
    brush = .32*np.sin(2*np.pi*(153*u + 4*v)) + grain
    fluting = np.cos(2*np.pi*(6*u - 2*v))
    band = np.maximum.reduce([np.exp(-((v-p)/.003)**2) for p in [.115, .205, .315, .448, .465, .658]])
    engraving = np.maximum(0, np.cos(2*np.pi*(8*u + 36*v)))**12 * ((.32 < v) & (v < .422))
    grip = (.535 < v) & (v < .649)
    diamond = np.sin(2*np.pi*(18*u + 90*v)) * np.sin(2*np.pi*(18*u - 90*v))
    rail = (v > .775)
    windows = rail * np.clip((np.cos(2*np.pi*(v-.82)*24) - .1) * 2, 0, 1) * ((.81 < v) & (v < .957))
    port = np.exp(-((v-.492)/.003)**2)
    height = .37*brush + 1.3*band - .8*engraving + .2*fluting + .95*grip*diamond - .38*windows
    wear = np.clip(.44 + .19*burnish + .12*brush + .33*band, 0, 1)
    bronze = np.array([94, 73, 42]) + wear[:, :, None] * np.array([97, 76, 45])
    bronze *= 1 - (.22*engraving)[:, :, None]
    bronze = np.where(grip[:, :, None], np.array([40, 47, 47]) + 10*diamond[:, :, None], bronze)
    bronze = np.where(rail[:, :, None], np.array([32, 51, 58]) + 12*fluting[:, :, None], bronze)
    glow = np.broadcast_to(np.maximum(windows*.83, port*.64), grain.shape)
    bronze += glow[:, :, None] * np.array([12, 78, 91])
    dy, dx = np.gradient(height)
    normal = unit(np.stack([-.7*dx, .7*dy, np.ones_like(dx)], axis=-1))
    orm = np.stack([.96-.24*engraving-.06*grip*diamond, .49-.21*band+.066*burnish+.22*grip,
                    np.broadcast_to(np.where(grip | rail, .28, .76), grain.shape)], axis=-1)
    emission = glow[:, :, None] * np.array([34, 186, 219])
    maps = {"bronze": bronze, "normal": (normal*.5+.5)*255, "orm": orm*255, "emission": emission}
    for name, pixels in maps.items():
        Image.fromarray(np.clip(np.rint(pixels), 0, 255).astype(np.uint8)).save(directory / f"{name}.png")
    return list(maps)


def build(directory):
    vertices, normals, tangents, uv, indices = make_mesh()
    maps = paint(directory)
    data = bytearray()
    views, accessors = [], []

    def add(values, layout, integer=False):
        array = np.ascontiguousarray(values, dtype="<u2" if integer else "<f4")
        views.append({"buffer": 0, "byteOffset": len(data), "byteLength": array.nbytes, "target": 34963 if integer else 34962})
        data.extend(array.tobytes())
        item = {"bufferView": len(views)-1, "count": len(array), "type": layout, "componentType": 5123 if integer else 5126}
        accessors.append(item)
        return len(accessors)-1

    attrs = {"POSITION": add(vertices, "VEC3"), "NORMAL": add(normals, "VEC3"),
             "TANGENT": add(tangents, "VEC4"), "TEXCOORD_0": add(uv, "VEC2")}
    accessors[0].update(min=vertices.astype("<f4").min(axis=0).tolist(), max=vertices.astype("<f4").max(axis=0).tolist())
    primitive = {"attributes": attrs, "indices": add(indices, "SCALAR", True), "material": 0}
    doc = {
        "asset": {"version": "2.0", "generator": "Team Discovery Channel Zat visual authoring tool"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "ZatBody", "mesh": 0}],
        "meshes": [{"name": "Loop-frame ion sidearm", "primitives": [primitive]}],
        "materials": [{
            "name": "Bronze with cyan dielectric channels",
            "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicRoughnessTexture": {"index": 2}},
            "normalTexture": {"index": 1}, "occlusionTexture": {"index": 2, "strength": .7},
            "emissiveTexture": {"index": 3}, "emissiveFactor": [.8, .8, .8],
        }],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 33071}],
        "textures": [{"sampler": 0, "source": index} for index in range(len(maps))],
        "images": [{"uri": f"{name}.png", "mimeType": "image/png"} for name in maps],
        "buffers": [{"uri": "zat.bin", "byteLength": len(data)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    (directory / "zat.bin").write_bytes(data)
    source = directory / "zat.gltf"
    source.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return pack(source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.suffix != ".glb":
        parser.error("output must end in .glb")
    args.staging.mkdir(parents=True, exist_ok=True)
    glb, embedded = build(args.staging)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(glb)
    print(json.dumps({"bytes": len(glb), "sha256": hashlib.sha256(glb).hexdigest(), "embedded": embedded}, indent=2))


if __name__ == "__main__":
    main()
