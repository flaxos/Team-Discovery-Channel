#!/usr/bin/env python3
"""Inspect a staged GLB without importing, executing or rewriting it.

This is an intake inventory, not a glTF validator, licence clearance or Godot acceptance.
Counts and bounds come from JSON declarations; scene transforms/skins are not evaluated.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys


class IntakeError(ValueError):
    pass


def _finite_float(text):
    value = float(text)
    if not math.isfinite(value):
        raise IntakeError('Non-finite JSON number')
    return value


def _invalid_constant(text):
    raise IntakeError(f'Invalid JSON constant: {text}')


def _finite_number(value):
    if type(value) not in (int, float):
        return False
    try:
        return math.isfinite(value)
    except OverflowError:
        return False


def _integer(value, label):
    if type(value) is not int or value < 0:
        raise IntakeError(f'{label} must be a nonnegative integer')
    return value


def _index(items, value, label):
    index = _integer(value, label)
    if index >= len(items):
        raise IntakeError(f'{label} is out of range')
    return items[index]


def read_glb(path: Path):
    """Read only JSON; skip binary chunks and hash the whole original file separately."""
    size = path.stat().st_size
    document = None
    binary_length = None
    with path.open('rb') as stream:
        header = stream.read(12)
        if len(header) != 12:
            raise IntakeError('Truncated GLB header')
        magic, version, declared_size = struct.unpack('<4sII', header)
        if magic != b'glTF' or version != 2:
            raise IntakeError('Expected a binary glTF 2.0 file')
        if declared_size != size:
            raise IntakeError('GLB declared length differs from file size')
        chunk_number = 0
        while stream.tell() < size:
            chunk_header = stream.read(8)
            if len(chunk_header) != 8:
                raise IntakeError('Truncated GLB chunk header')
            length, kind = struct.unpack('<I4s', chunk_header)
            if length % 4 or length > size - stream.tell():
                raise IntakeError('Invalid GLB chunk length or alignment')
            if chunk_number == 0 and kind != b'JSON':
                raise IntakeError('The first GLB chunk must contain JSON')
            if kind == b'JSON':
                if document is not None:
                    raise IntakeError('Duplicate GLB JSON chunk')
                if length > 32 * 1024 * 1024:
                    raise IntakeError('JSON chunk exceeds this inspector’s 32 MiB limit')
                document = json.loads(stream.read(length).decode('utf-8'),
                                      parse_float=_finite_float, parse_constant=_invalid_constant)
            elif kind == b'BIN\x00':
                if binary_length is not None:
                    raise IntakeError('Duplicate GLB binary chunk')
                binary_length = length
                stream.seek(length, 1)
            else:
                stream.seek(length, 1)  # Unknown GLB chunks are allowed by the specification.
            chunk_number += 1
    if not isinstance(document, dict) or document.get('asset', {}).get('version') != '2.0':
        raise IntakeError('Missing glTF 2.0 asset declaration')
    return document, binary_length


def inspect_glb(path: Path):
    document, binary_length = read_glb(path)
    errors = []
    review = []
    external = []
    buffers = document.get('buffers', [])
    views = document.get('bufferViews', [])
    accessors = document.get('accessors', [])
    for group in ('buffers', 'images'):
        for index, entry in enumerate(document.get(group, [])):
            uri = entry.get('uri')
            if uri is not None and not (isinstance(uri, str) and uri.startswith('data:')):
                external.append({'kind': group, 'index': index, 'uri': uri})
    if external:
        errors.append('Asset references external data; stage a self-contained GLB before intake')
    for index, buffer in enumerate(buffers):
        length = _integer(buffer.get('byteLength'), f'buffer {index} length')
        if 'uri' not in buffer:
            if index != 0 or binary_length is None or not 0 <= binary_length - length <= 3:
                raise IntakeError('Embedded buffer does not match the GLB binary chunk')
    for index, view in enumerate(views):
        buffer = _index(buffers, view.get('buffer'), f'bufferView {index} buffer')
        offset = _integer(view.get('byteOffset', 0), 'bufferView offset')
        length = _integer(view.get('byteLength'), 'bufferView length')
        if offset + length > buffer['byteLength']:
            raise IntakeError(f'bufferView {index} exceeds its declared buffer')
    for image in document.get('images', []):
        if 'bufferView' in image:
            _index(views, image['bufferView'], 'image bufferView')

    meshes = []
    total_triangles = 0
    for mesh_index, mesh in enumerate(document.get('meshes', [])):
        primitives = []
        for primitive in mesh.get('primitives', []):
            attributes = primitive.get('attributes', {})
            position = _index(accessors, attributes.get('POSITION'), 'POSITION accessor')
            vertices = _integer(position.get('count'), 'vertex count')
            source = _index(accessors, primitive['indices'], 'index accessor') if 'indices' in primitive else position
            count = _integer(source.get('count'), 'index/vertex count')
            mode = _integer(primitive.get('mode', 4), 'primitive mode')
            if mode > 6:
                raise IntakeError('Unknown primitive mode')
            triangles = count // 3 if mode == 4 else max(0, count - 2) if mode in (5, 6) else 0
            if mode == 4 and count % 3:
                errors.append(f'Mesh {mesh_index} triangle list count is not divisible by three')
            bounds = None
            if 'min' in position and 'max' in position:
                low, high = position['min'], position['max']
                if not all(isinstance(v, list) and len(v) == 3 for v in (low, high)):
                    raise IntakeError('POSITION bounds must contain three components')
                if not all(_finite_number(v) for v in low + high):
                    raise IntakeError('POSITION bounds must be finite numbers')
                if any(a > b for a, b in zip(low, high)):
                    raise IntakeError('POSITION bounds are inverted')
                size = [b - a for a, b in zip(low, high)]
                if not all(_finite_number(v) for v in size):
                    raise IntakeError('POSITION bound extents must be finite numbers')
                bounds = {'min': low, 'max': high, 'size': size}
            total_triangles += triangles
            primitives.append({
                'mode': mode, 'declared_vertices': vertices, 'declared_triangles': triangles,
                'attributes': sorted(attributes), 'mesh_local_declared_bounds': bounds,
                'morph_targets': len(primitive.get('targets', [])),
            })
        meshes.append({'name': mesh.get('name', f'mesh_{mesh_index}'), 'primitives': primitives})

    nodes = document.get('nodes', [])
    skins = []
    for index, skin in enumerate(document.get('skins', [])):
        joints = skin.get('joints', [])
        for joint in joints:
            _index(nodes, joint, 'skin joint')
        skins.append({'name': skin.get('name', f'skin_{index}'),
                      'joint_indices': joints})  # Resolve names via node_names, without duplicating them.
    materials = []
    for index, material in enumerate(document.get('materials', [])):
        pbr = material.get('pbrMetallicRoughness', {})
        materials.append({
            'name': material.get('name', f'material_{index}'),
            'metallic_factor': pbr.get('metallicFactor', 1.0),
            'roughness_factor': pbr.get('roughnessFactor', 1.0),
            'normal_texture': 'normalTexture' in material,
            'double_sided': material.get('doubleSided', False),
            'alpha_mode': material.get('alphaMode', 'OPAQUE'),
        })
    if any(material['metallic_factor'] != 0 for material in materials):
        review.append('Metallic materials require the mission-lighting/D-015 wrapper review')
    if document.get('extensionsRequired'):
        review.append('Required extensions need an actual Godot 4.4.1 import check')
    review.append('Verify transformed dimensions, source forward axis, sockets and visual quality in Godot')
    if skins or document.get('animations'):
        review.append('Verify rest pose, retargeting, root motion and raw-asset redistribution terms')
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return {
        'ok': not errors, 'file': str(path), 'bytes': path.stat().st_size, 'sha256': digest.hexdigest(),
        'scope': 'GLB JSON declarations only; no full validation, engine import or licence clearance',
        'generator': document['asset'].get('generator', ''),
        'declared_triangles_unique_meshes': total_triangles, 'meshes': meshes,
        'node_names': [node.get('name', '') for node in nodes], 'skins': skins,
        'animation_names': [animation.get('name', '') for animation in document.get('animations', [])],
        'images': [{'name': image.get('name', ''), 'mime_type': image.get('mimeType', ''),
                    'declared_embedded': 'bufferView' in image or str(image.get('uri', '')).startswith('data:')}
                   for image in document.get('images', [])],
        'materials': materials, 'required_extensions': document.get('extensionsRequired', []),
        'external_dependencies': external, 'errors': errors, 'manual_review': review,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path, help='Staged binary glTF 2.0; never modified')
    parser.add_argument('--output', type=Path, help='Write the same JSON report to this path')
    parser.add_argument('--work-order', type=Path, help='Validate a ready request before inspecting this GLB')
    args = parser.parse_args(argv)
    for source in [args.file, args.work_order]:
        if source and args.output and (args.output.resolve() == source.resolve() or (
            args.output.exists() and source.exists() and args.output.samefile(source)
        )):
            parser.error('Report path must differ from the source asset and work order')
    try:
        order_report = None
        if args.work_order:
            from asset_work_order import validate_work_order, read_json
            order_report = validate_work_order(args.work_order, require_ready=True)
            if not order_report['ok']:
                raise IntakeError('; '.join(order_report['errors']))
        report = inspect_glb(args.file)
        if order_report:
            report['work_order'] = order_report
            order = read_json(args.work_order)
            geometry = order['geometry']
            if geometry:
                if report['declared_triangles_unique_meshes'] > geometry['max_lod0_triangles']:
                    report['errors'].append('Declared unique mesh triangles exceed the work-order LOD0 budget')
                if len(report['materials']) > geometry['max_materials']:
                    report['errors'].append('Material count exceeds the work-order budget')
            if order['kind'] in ('rigid_model', 'material_set') and (report['skins'] or report['animation_names']):
                report['errors'].append('Rigid/material request cannot silently consume a rig or animation')
            report['ok'] = not report['errors']
        rendered = json.dumps(report, indent=2, allow_nan=False) + '\n'
    except (OSError, ValueError, TypeError, KeyError, AttributeError,
            OverflowError, RecursionError, struct.error) as error:
        report = {'ok': False, 'file': str(args.file), 'errors': [str(error)]}
        rendered = json.dumps(report, indent=2) + '\n'
    if args.output:
        try:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered)
        except OSError as error:
            report = {'ok': False, 'file': str(args.file), 'errors': [f'Cannot write report: {error}']}
            rendered = json.dumps(report, indent=2) + '\n'
    sys.stdout.write(rendered)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
