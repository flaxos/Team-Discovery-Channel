#!/usr/bin/env python3
"""Fit the CC0 MakeHuman head, eye and hair sources as one civilian visual.

Use the pinned MakeHuman base and the named system-pack members documented in the
Sprint 26 intake record. Pillow is used only to crop and reduce the prepared maps.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
from math import sqrt
from pathlib import Path
import struct

from PIL import Image
from gltf_to_glb import pack

# MakeHuman uses decimetres and +Z forward. The cut sits inside the rig's collar.
NECK_CUT = 5.94
PROFILE_Z = 0.62
MESHES = (
    ("Face", "base.obj", None, "young_lightskinned_male_diffuse3.png", 1024, 0.87),
    ("Eyes", "high-poly.obj", "high-poly.mhclo", "brown_eye.png", 256, 0.3),
    ("Hair", "short01.obj", "short01.mhclo", "short01_diffuse.png", 512, 0.8),
)


def read_obj(path: Path, group: str | None = None):
    vertices, uvs, faces = [], [], []
    current_group = ""
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        kind, *data = fields
        if kind == "v":
            vertices.append(tuple(map(float, data[:3])))
        elif kind == "vt":
            u, v = map(float, data[:2])
            uvs.append((u, 1.0 - v))
        elif kind == "g":
            current_group = data[0]
        elif kind == "f" and (group is None or current_group == group):
            faces.append([tuple(int(n) - 1 for n in ref.split("/")[:2]) for ref in data])
    return vertices, uvs, faces


def conform_proxy(path: Path, base):
    scale_axes = {"x_scale": 0, "y_scale": 1, "z_scale": 2}
    scale = [1.0, 1.0, 1.0]
    fitted = []
    reading_vertices = False
    for line in path.read_text().splitlines():
        fields = line.partition("#")[0].split()
        if not fields:
            continue
        key = fields[0]
        if key in scale_axes:
            axis = scale_axes[key]
            first, second = map(int, fields[1:3])
            scale[axis] = abs(base[first][axis] - base[second][axis]) / float(fields[3])
        elif key == "verts":
            reading_vertices = True
        elif reading_vertices and key.isdecimal():
            if len(fields) == 1:
                fitted.append(base[int(key)])
                continue
            indices = list(map(int, fields[:3]))
            weights = list(map(float, fields[3:6]))
            offset = list(map(float, fields[6:9]))
            fitted.append(tuple(
                sum(base[index][axis] * weight for index, weight in zip(indices, weights))
                + offset[axis] * scale[axis] for axis in range(3)
            ))
        elif reading_vertices:
            break
    return fitted


def vector_subtract(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def head_geometry(vertices, faces):
    positions = [(-x * .1, (y - NECK_CUT) * .1, (PROFILE_Z - z) * .1) for x, y, z in vertices]
    normals = defaultdict(lambda: [0.0, 0.0, 0.0])
    triangles = []
    for face in faces:
        for i in range(1, len(face) - 1):
            triangle = (face[0], face[i], face[i + 1])
            a, b, c = (positions[ref[0]] for ref in triangle)
            area_normal = cross(vector_subtract(b, a), vector_subtract(c, a))
            if sum(n * n for n in area_normal) < 1e-21:
                continue
            triangles.append(triangle)
            for vertex, _ in triangle:
                for axis in range(3):
                    normals[vertex][axis] += area_normal[axis]
    indexed = {}
    indices = []
    for face in triangles:
        indices.extend(indexed.setdefault(ref, len(indexed)) for ref in face)
    unit_normals = []
    for point, _ in indexed:
        normal = normals[point]
        length = sqrt(sum(n * n for n in normal))
        unit_normals.append(tuple(n / length for n in normal) if length > 0 else (0, 1, 0))
    return [positions[v] for v, _ in indexed], unit_normals, [uv for _, uv in indexed], indices


def prepare_texture(source: Path, output: Path, uvs, size: int, alpha: bool):
    with Image.open(source) as image_file:
        image = image_file.convert("RGBA" if alpha else "RGB")
    w, h = image.size
    start_u = max(0, int(w * min(u for u, _ in uvs)) - 4)
    start_v = max(0, int(h * min(v for _, v in uvs)) - 4)
    end_u = min(w, int(w * max(u for u, _ in uvs)) + 5)
    end_v = min(h, int(h * max(v for _, v in uvs)) + 5)
    image = image.crop((start_u, start_v, end_u, end_v))
    image = image.resize((size, size), Image.Resampling.LANCZOS)
    image.save(output)
    return [((u * w - start_u) / (end_u - start_u), (v * h - start_v) / (end_v - start_v)) for u, v in uvs]


def add_accessor(doc, payload, rows, kind, component, fmt, *, bounds=False):
    byte_offset = len(payload)
    values = [element for row in rows for element in row]
    data = struct.pack("<" + fmt * len(values), *values)
    payload.extend(data)
    payload.extend(b"\0" * (-len(payload) % 4))
    view = len(doc["bufferViews"])
    doc["bufferViews"].append({"buffer": 0, "byteOffset": byte_offset, "byteLength": len(data),
                               "target": 34963 if kind == "SCALAR" else 34962})
    entry = {"bufferView": view, "componentType": component, "count": len(rows), "type": kind}
    if bounds:
        entry["min"] = [min(axis) for axis in zip(*rows)]
        entry["max"] = [max(axis) for axis in zip(*rows)]
    doc["accessors"].append(entry)
    return len(doc["accessors"]) - 1


def prepare(source: Path, staging: Path, output: Path) -> None:
    base, _, _ = read_obj(source / "base.obj", "body")
    staging.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    document = {key: [] for key in (
        "accessors", "bufferViews", "images", "textures", "materials", "meshes", "nodes"
    )}
    document.update(asset={"version": "2.0"}, scenes=[{"nodes": [0, 1, 2]}], scene=0)
    payload = bytearray()
    for index, (name, obj, proxy, texture, resolution, roughness) in enumerate(MESHES):
        vertices, uvs, faces = read_obj(source / obj, "body" if proxy is None else None)
        if proxy is None:
            faces = [face for face in faces if all(vertices[vertex][1] >= NECK_CUT for vertex, _ in face)]
        else:
            fitted = conform_proxy(source / proxy, base)
            if len(fitted) != len(vertices):
                raise ValueError(f"{proxy} maps {len(fitted)} of {len(vertices)} vertices")
            vertices = fitted
        positions, normals, uv_indices, indices = head_geometry(vertices, faces)
        map_file = staging / f"{name.lower()}.png"
        uv_map = prepare_texture(source / texture, map_file, [uvs[i] for i in uv_indices], resolution, name == "Hair")
        document["images"].append({"uri": map_file.name, "mimeType": "image/png"})
        document["textures"].append({"source": index})
        material = {"name": name, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": index}, "metallicFactor": 0, "roughnessFactor": roughness
        }}
        if name == "Hair":
            material.update(alphaMode="MASK", alphaCutoff=0.43, doubleSided=True)
        document["materials"].append(material)
        primitive = {"material": index, "attributes": {
            "POSITION": add_accessor(document, payload, positions, "VEC3", 5126, "f", bounds=True),
            "NORMAL": add_accessor(document, payload, normals, "VEC3", 5126, "f"),
            "TEXCOORD_0": add_accessor(document, payload, uv_map, "VEC2", 5126, "f"),
        }, "indices": add_accessor(document, payload, [(i,) for i in indices], "SCALAR", 5123, "H")}
        document["meshes"].append({"name": name, "primitives": [primitive]})
        document["nodes"].append({"name": name, "mesh": index})
        print(f"{name}: {len(indices) // 3} triangles; {len(positions)} vertices")
    (staging / "head.bin").write_bytes(payload)
    document["buffers"] = [{"uri": "head.bin", "byteLength": len(payload)}]
    gltf = staging / "head.gltf"
    gltf.write_text(json.dumps(document))
    glb, _ = pack(gltf)
    output.write_bytes(glb)
    print(f"{output}: {len(glb)} bytes; SHA-256 {hashlib.sha256(glb).hexdigest()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "staging", "output"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    prepare(args.source, args.staging, args.output)
