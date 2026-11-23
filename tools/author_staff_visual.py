#!/usr/bin/env python3
"""Author the original Sprint 8 staff. Inputs are the profile and material functions below.

Run with Python 3, NumPy and Pillow. Pass a staging directory and a .glb destination.
The staging glTF, buffer and lossless maps are kept for inspection and can be packed again
with gltf_to_glb.py. No downloaded geometry, scans or textures are read.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from gltf_to_glb import pack

# Front cavity floor to nose lip, then the emitter, two grip sections and butt.
# Each profile row is (axial position in metres, radius in metres, radial lobe strength).
PROFILE = [
    (-0.985, 0.000, 0), (-0.985, 0.012, 0), (-0.992, 0.015, 0),
    (-1.021, 0.015, 0), (-1.045, 0.019, 0), (-1.050, 0.022, 0),
    (-1.050, 0.027, 0.07), (-1.045, 0.030, 0.11), (-1.025, 0.032, 0.19),
    (-0.987, 0.036, 0.23), (-0.943, 0.036, 0.25), (-0.907, 0.034, 0.24),
    (-0.873, 0.031, 0.20), (-0.841, 0.025, 0.13), (-0.808, 0.020, 0.05),
    (-0.795, 0.020, 0), (-0.791, 0.025, 0), (-0.778, 0.025, 0),
    (-0.774, 0.021, 0), (-0.749, 0.021, 0), (-0.743, 0.026, 0),
    (-0.729, 0.026, 0), (-0.724, 0.021, 0), (-0.685, 0.015, 0.07),
    (-0.524, 0.015, 0.06), (-0.484, 0.016, 0),
    (-0.464, 0.022, 0), (-0.447, 0.022, 0), (-0.442, 0.019, 0),
    (-0.238, 0.019, 0), (-0.230, 0.022, 0), (-0.217, 0.022, 0),
    (-0.198, 0.015, 0.08), (-0.102, 0.015, 0.08), (-0.089, 0.019, 0),
    (-0.071, 0.021, 0), (-0.059, 0.020, 0), (0.153, 0.020, 0),
    (0.165, 0.022, 0), (0.182, 0.022, 0), (0.205, 0.016, 0.08),
    (0.398, 0.018, 0.10), (0.449, 0.027, 0.15), (0.482, 0.029, 0.16),
    (0.546, 0.026, 0.10), (0.566, 0.024, 0), (0.572, 0.026, 0),
    (0.585, 0.024, 0), (0.594, 0.019, 0), (0.594, 0.000, 0),
]
SIDES = 96
SIZE = 1024
FRONT = -1.050
BACK = 0.594


def unit(vector):
    return vector / np.linalg.norm(vector, axis=-1, keepdims=True)


def model_arrays():
    """Return one smoothly shaded mesh with cylindrical UVs and separated tip caps."""
    profile = np.array(PROFILE, dtype=np.float64)
    angle = np.linspace(0, 2 * np.pi, SIDES + 1)
    angle[-1] = 0.0
    z, r, lobe = profile.T[:, :, None]
    radius = r * (1 + lobe * np.cos(3 * angle))
    grid = np.stack([
        radius * np.cos(angle),
        radius * np.sin(angle),
        np.broadcast_to(z, radius.shape),
    ], axis=-1)
    azimuth = np.column_stack([-np.sin(angle), np.cos(angle), np.zeros_like(angle)])
    tangent = np.empty_like(grid)
    tangent[1:-1, :-1] = unit(np.roll(grid[1:-1, :-1], -1, axis=1) - np.roll(grid[1:-1, :-1], 1, axis=1))
    tangent[1:-1, -1] = tangent[1:-1, 0]
    tangent[[0, -1]] = azimuth
    along = np.gradient(grid, axis=0)
    normal = unit(np.cross(tangent, along))
    tangent4 = np.concatenate([tangent, np.ones_like(grid[:, :, :1])], axis=-1)
    u = np.broadcast_to(np.linspace(0, 1, SIDES + 1), radius.shape)
    v = np.broadcast_to((z - FRONT) / (BACK - FRONT), radius.shape)
    uv = np.stack([u, v], axis=-1)
    triangles = []
    stride = SIDES + 1
    for ring in range(len(profile) - 1):
        for side in range(SIDES):
            a = ring * stride + side
            b = a + stride
            if ring != 0:
                triangles.extend((a, a + 1, b))
            if ring != len(profile) - 2:
                triangles.extend((a + 1, b + 1, b))
    return (
        grid.reshape(-1, 3),
        normal.reshape(-1, 3),
        tangent4.reshape(-1, 4),
        uv.reshape(-1, 2),
        np.asarray(triangles, dtype="<u2"),
    )


def paint_maps(directory):
    """Bake shared bronze, grip and emitter detail into four lossless maps."""
    u = np.arange(SIZE, dtype=np.float64)[None, :] / SIZE
    z = FRONT + (np.arange(SIZE, dtype=np.float64)[:, None] / (SIZE - 1)) * (BACK - FRONT)
    rng = np.random.default_rng(823)
    grain = rng.normal(0, 0.26, (SIZE, SIZE))
    brush = 0.42 * np.cos(2 * np.pi * (78 * u + 0.5 * z)) + 0.34 * np.sin(2 * np.pi * (197 * u - 0.9 * z))
    patina = np.sin(2 * np.pi * (5 * u + 2 * z)) * np.sin(2 * np.pi * (3 * u - 8 * z))
    grip = ((-0.442 < z) & (z < -0.238)) | ((-0.059 < z) & (z < 0.153))
    bands = np.maximum.reduce([np.exp(-((z - p) / 0.004) ** 2) for p in [
        -1.046, -0.794, -0.776, -0.745, -0.728, -0.458, -0.226, -0.080, 0.171, 0.575
    ]])
    head = (-1.049 <= z) & (z < -0.84)
    channels = head * np.clip((np.cos(6 * np.pi * u + np.pi) - 0.72) * 4, 0, 1)
    tail = (z > 0.438) * np.maximum(0, np.cos(6 * np.pi * u)) ** 4
    knurl = np.cos(2 * np.pi * (24 * u + 72 * z)) * np.cos(2 * np.pi * (24 * u - 72 * z))
    height = 0.25 * brush + 0.15 * grain + 1.8 * bands - 2.2 * channels + grip * knurl * 1.6 + 1.2 * tail
    wear = np.clip(0.34 + 0.18 * patina + 0.15 * (brush + grain) + 0.3 * bands, 0, 1)
    bronze = np.array([99, 73, 45]) + wear[:, :, None] * np.array([96, 72, 42])
    bronze += tail[:, :, None] * np.array([23, 12, 4])
    bronze *= 1 - 0.66 * channels[:, :, None]
    bronze = np.where(grip[:, :, None], np.array([53, 47, 41]) + knurl[:, :, None] * 9, bronze)
    dy, dx = np.gradient(height)
    normals = unit(np.stack([-dx * 0.48, dy * 0.48, np.ones_like(dx)], axis=-1))
    ao = 0.97 - 0.31 * channels - grip * (0.05 - knurl * 0.045)
    rough = 0.53 - 0.18 * bands + 0.06 * patina + 0.22 * grip
    metal = np.broadcast_to(np.where(grip, 0.28, 0.79), grain.shape)
    orm = np.stack([ao, rough, metal], axis=-1)
    pulse = channels * np.clip((np.cos(2 * np.pi * (33 * z + 0.5)) - 0.1) * 1.2, 0, 1)
    pulse *= (z < -0.889) & (z > -1.034)
    collar = np.exp(-((z + 0.758) / 0.0035) ** 2) * np.maximum(0, np.cos(12 * np.pi * u)) ** 4
    emission = np.clip(pulse * 0.84 + collar * 0.47, 0, 1)[:, :, None] * np.array([247, 110, 23])
    images = {"bronze": bronze, "normal": (normals * 0.5 + 0.5) * 255, "orm": orm * 255, "emission": emission}
    for name, pixels in images.items():
        Image.fromarray(np.clip(np.rint(pixels), 0, 255).astype(np.uint8)).save(directory / f"{name}.png")
    return list(images)


def write_source(directory):
    positions, normals, tangents, uv, indices = model_arrays()
    maps = paint_maps(directory)
    buffer = bytearray()
    views = []
    accessors = []

    def accessor(array, layout, integer=False, bounds=False):
        encoded = np.ascontiguousarray(array, dtype="<u2" if integer else "<f4")
        offset = len(buffer)
        buffer.extend(encoded.tobytes())
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": encoded.nbytes, "target": 34963 if integer else 34962})
        record = {"bufferView": len(views) - 1, "componentType": 5123 if integer else 5126, "count": len(encoded), "type": layout}
        if bounds:
            record.update(min=encoded.min(axis=0).tolist(), max=encoded.max(axis=0).tolist())
        accessors.append(record)
        return len(accessors) - 1

    attributes = {
        "POSITION": accessor(positions, "VEC3", bounds=True),
        "NORMAL": accessor(normals, "VEC3"),
        "TANGENT": accessor(tangents, "VEC4"),
        "TEXCOORD_0": accessor(uv, "VEC2"),
    }
    primitive = {"attributes": attributes, "indices": accessor(indices, "SCALAR", integer=True), "material": 0}
    doc = {
        "asset": {"version": "2.0", "generator": "Team Discovery Channel staff visual authoring tool"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "StaffBody", "mesh": 0}],
        "meshes": [{"name": "Tri-vane plasma staff", "primitives": [primitive]}],
        "materials": [{
            "name": "Bronze and inset grip",
            "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicRoughnessTexture": {"index": 2}},
            "normalTexture": {"index": 1},
            "occlusionTexture": {"index": 2, "strength": 0.65},
            "emissiveTexture": {"index": 3},
            "emissiveFactor": [0.8, 0.8, 0.8],
        }],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 33071}],
        "textures": [{"sampler": 0, "source": index} for index in range(len(maps))],
        "images": [{"uri": f"{name}.png", "mimeType": "image/png"} for name in maps],
        "buffers": [{"uri": "staff.bin", "byteLength": len(buffer)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    (directory / "staff.bin").write_bytes(buffer)
    source = directory / "staff.gltf"
    source.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.suffix != ".glb":
        parser.error("output must end in .glb")
    args.staging.mkdir(parents=True, exist_ok=True)
    glb, embedded = pack(write_source(args.staging))
    args.output.write_bytes(glb)
    print(json.dumps({"bytes": len(glb), "sha256": hashlib.sha256(glb).hexdigest(), "embedded": embedded}, indent=2))


if __name__ == "__main__":
    main()
