#!/usr/bin/env python3
"""Prepare the measured Sprint 19 tactical skin and its in-place animation set."""
import argparse
from io import BytesIO
import json
from pathlib import Path
import re
import struct

from PIL import Image

from gltf_to_glb import BIN_CHUNK, GLB_MAGIC, JSON_CHUNK

CLIPS = {
    'idle', 'walk', 'run', 'crouch_idle', 'crouch_walk', 'aim_idle',
    'aim_walk', 'aim_crouch_idle', 'aim_crouch_walk', 'ready_idle', 'ready_walk', 'ready_run',
    'shoot', 'downed', 'prone_crawl', 'death', 'revive_kneel', 'revived',
}
LOOPED = CLIPS - {'shoot', 'death', 'revived'}
# The source bone arrays use centimetres and the target uses a 0.9144 m basis.
# The hip-to-left-foot rest lengths in Godot are 1.077571 and 0.927841 m.
HIP_SCALE = (0.01 / 0.914404273) * (0.927841 / 1.077571)
POSITION_SCALE = 0.000001


class Glb:
    def __init__(self, path):
        data = path.read_bytes()
        magic, version, size, json_size, json_type = struct.unpack_from('<5I', data)
        binary_size, binary_type = struct.unpack_from('<2I', data, 20 + json_size)
        if (magic, version, size, json_type, binary_type) != (GLB_MAGIC, 2, len(data), JSON_CHUNK, BIN_CHUNK):
            raise ValueError(f'Unrecognized GLB: {path}')
        self.document = json.loads(data[20:20 + json_size])
        self.blob = bytearray(data[28 + json_size:28 + json_size + binary_size])
        self.views = self.document['bufferViews']
        self.accessors = self.document['accessors']

    def view(self, index):
        descriptor = self.views[index]
        start = descriptor.get('byteOffset', 0)
        return bytes(self.blob[start:start + descriptor['byteLength']])

    def samples(self, index, components):
        accessor = self.accessors[index]
        view = self.views[accessor['bufferView']]
        if accessor['componentType'] != 5126 or accessor.get('sparse'):
            raise ValueError('Expected packed FLOAT accessor')
        start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        width = components * 4
        return [struct.unpack_from(f'<{components}f', self.blob, start + row * view.get('byteStride', width))
                for row in range(accessor['count'])]

    def view_bytes(self, data):
        self.blob.extend(bytes(-len(self.blob) % 4))
        index = len(self.views)
        self.views.append(dict(buffer=0, byteOffset=len(self.blob), byteLength=len(data)))
        self.blob.extend(data)
        return index

    def add_samples(self, rows, shape, bounds=False):
        components = len(rows[0])
        payload = b''.join(struct.pack(f'<{components}f', *row) for row in rows)
        accessor = dict(bufferView=self.view_bytes(payload), componentType=5126, count=len(rows), type=shape)
        if bounds:
            columns = tuple(zip(*rows))
            accessor.update(min=[min(c) for c in columns], max=[max(c) for c in columns])
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def edit_samples(self, index, rows):
        accessor = self.accessors[index]
        view = self.views[accessor['bufferView']]
        start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        width = len(rows[0]) * 4
        for offset, row in enumerate(rows):
            struct.pack_into(f'<{len(row)}f', self.blob, start + offset * view.get('byteStride', width), *row)
        if 'min' in accessor:
            columns = tuple(zip(*rows))
            accessor.update(min=[min(c) for c in columns], max=[max(c) for c in columns])

    def save(self, path):
        # Copy referenced views in order to discard the replaced WebP bytes.
        blob = bytearray()
        for index, view in enumerate(self.views):
            payload = self.view(index)
            blob.extend(bytes(-len(blob) % 4))
            view['byteOffset'] = len(blob)
            blob.extend(payload)
        blob.extend(bytes(-len(blob) % 4))
        self.document['buffers'][0]['byteLength'] = len(blob)
        data = json.dumps(self.document, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
        data += b' ' * (-len(data) % 4)
        chunks = struct.pack('<II', len(data), JSON_CHUNK) + data + struct.pack('<II', len(blob), BIN_CHUNK) + blob
        path.write_bytes(struct.pack('<III', GLB_MAGIC, 2, len(chunks) + 12) + chunks)


def normalize_body(body):
    doc = body.document
    positions = {primitive['attributes']['POSITION'] for mesh in doc['meshes'] for primitive in mesh['primitives']}
    for index in positions:
        body.edit_samples(index, [tuple(value * POSITION_SCALE for value in row) for row in body.samples(index, 3)])
    bind = doc['skins'][0]['inverseBindMatrices']
    transforms = body.samples(bind, 16)
    # Positions shrink by a million. Compensate in the first three matrix columns
    # so the weighted skinned position is unchanged. The translation stays in metres.
    body.edit_samples(bind, [tuple(value / POSITION_SCALE if column < 12 else value
                                  for column, value in enumerate(row)) for row in transforms])
    hide = {index for index, node in enumerate(doc['nodes']) if 'mesh' in node and
            ('skin' not in node or 'HeadphonesT' in {
                doc['materials'][p['material']]['name'] for p in doc['meshes'][node['mesh']]['primitives']
            })}
    for index in hide:
        doc['nodes'][index].pop('mesh')
        doc['nodes'][index].pop('skin', None)
    for node in doc['nodes']:
        if 'children' in node:
            children = [index for index in node['children'] if index not in hide]
            if children:
                node['children'] = children
            else:
                node.pop('children')
    for image in doc['images']:
        index = image['bufferView']
        decoded = Image.open(BytesIO(body.view(index)))
        png = BytesIO()
        decoded.save(png, format='PNG')
        new_index = body.view_bytes(png.getvalue())
        body.views[index] = body.views.pop(new_index)
        image['mimeType'] = 'image/png'
    for texture in doc['textures']:
        texture['source'] = texture.pop('extensions')['EXT_texture_webp']['source']
    doc['extensionsUsed'] = [name for name in doc['extensionsUsed'] if name != 'EXT_texture_webp']
    doc.pop('extensionsRequired')


def bone_label(name):
    return re.sub(r'_\d+$', '', name).removeprefix('mixamorig:')


def attach_clips(body, donor):
    target = {bone_label(node['name']): index for index, node in enumerate(body.document['nodes'])
              if node.get('name', '').startswith('mixamorig:')}
    source_nodes = donor.document['nodes']
    clips = []
    time_accessors = {}
    for source in donor.document['animations']:
        name = source['name']
        if name not in CLIPS:
            continue
        clip = dict(name=name, extras={'loop': name in LOOPED}, channels=[], samplers=[])
        for channel in source['channels']:
            node = source_nodes[channel['target']['node']]
            if not node.get('name', '').startswith('mixamorig:'):
                continue
            bone = bone_label(node['name'])
            path = channel['target']['path']
            if bone not in target or (path != 'rotation' and (bone, path) != ('Hips', 'translation')):
                continue
            sampler = source['samplers'][channel['sampler']]
            source_times = sampler['input']
            if source_times not in time_accessors:
                time_accessors[source_times] = body.add_samples(donor.samples(source_times, 1), 'SCALAR', bounds=True)
            if path == 'rotation':
                rows = donor.samples(sampler['output'], 4)
                # The armatures' parent axes differ by 180 degrees about X.
                if bone == 'Hips':
                    rows = [(w, -z, y, -x) for x, y, z, w in rows]
                output = body.add_samples(rows, 'VEC4')
            else:
                rows = [(x * HIP_SCALE, -y * HIP_SCALE, -z * HIP_SCALE)
                        for x, y, z in donor.samples(sampler['output'], 3)]
                output = body.add_samples(rows, 'VEC3')
            clip['channels'].append(dict(sampler=len(clip['samplers']), target=dict(node=target[bone], path=path)))
            clip['samplers'].append(dict(input=time_accessors[source_times], output=output, interpolation=sampler.get('interpolation', 'LINEAR')))
        clips.append(clip)
    if {clip['name'] for clip in clips} != CLIPS:
        raise ValueError('Animation source is missing required clips.')
    body.document['animations'] = clips


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('body', type=Path)
    parser.add_argument('motion', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.resolve() in (args.body.resolve(), args.motion.resolve()):
        parser.error('Write the prepared GLB to a separate path.')
    body = Glb(args.body)
    normalize_body(body)
    attach_clips(body, Glb(args.motion))
    body.save(args.output)


if __name__ == '__main__':
    main()
