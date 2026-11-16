"""Packing must change only the container, never the embedded bytes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / 'gltf_to_glb.py'
SPEC = importlib.util.spec_from_file_location('gltf_to_glb', TOOL)
packer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packer)
INTAKE_SPEC = importlib.util.spec_from_file_location('asset_intake', TOOL.parent / 'asset_intake.py')
intake = importlib.util.module_from_spec(INTAKE_SPEC)
INTAKE_SPEC.loader.exec_module(intake)

GEOMETRY = struct.pack('<9f', 0, 0, 0, 1, 0, 0, 0, 1, 0) + struct.pack('<3H', 0, 1, 2) + b'\0\0'
IMAGE = b'\xff\xd8\xff\xe0 not really a jpeg but bytes must survive \xff\xd9'


def write_source(folder: Path, image_uri: str = 'textures/diff%201k.jpg') -> Path:
    (folder / 'textures').mkdir()
    (folder / 'mesh.bin').write_bytes(GEOMETRY)
    (folder / 'textures' / 'diff 1k.jpg').write_bytes(IMAGE)
    document = {
        'asset': {'version': '2.0', 'generator': 'unit test'},
        'buffers': [{'uri': 'mesh.bin', 'byteLength': 42}],
        'bufferViews': [{'buffer': 0, 'byteLength': 36, 'target': 34962},
                        {'buffer': 0, 'byteOffset': 36, 'byteLength': 6, 'target': 34963}],
        'accessors': [{'bufferView': 0, 'count': 3, 'componentType': 5126, 'type': 'VEC3',
                       'min': [0, 0, 0], 'max': [1, 1, 0]},
                      {'bufferView': 1, 'count': 3, 'componentType': 5123, 'type': 'SCALAR'}],
        'images': [{'uri': image_uri, 'mimeType': 'image/jpeg', 'name': 'diff'}],
        'textures': [{'source': 0}],
        'materials': [{'alphaMode': 'BLEND', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}}}],
        'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0}]}],
        'nodes': [{'mesh': 0}], 'scenes': [{'nodes': [0]}], 'scene': 0,
    }
    source = folder / 'model.gltf'
    source.write_text(json.dumps(document))
    return source


def chunks(data: bytes):
    magic, version, length = struct.unpack_from('<III', data)
    assert (magic, version, length) == (packer.GLB_MAGIC, 2, len(data))
    json_length, _ = struct.unpack_from('<II', data, 12)
    document = json.loads(data[20:20 + json_length])
    bin_length, _ = struct.unpack_from('<II', data, 20 + json_length)
    start = 28 + json_length
    return document, data[start:start + bin_length]


class PackTests(unittest.TestCase):
    def test_bytes_survive_and_intake_accepts_result(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = write_source(Path(tmp))
            before = source.read_bytes()
            data, embedded = packer.pack(source)
            self.assertEqual(before, source.read_bytes())
            document, blob = chunks(data)
            self.assertEqual(blob[:len(GEOMETRY)], GEOMETRY)
            view = document['bufferViews'][document['images'][0]['bufferView']]
            self.assertEqual(blob[view['byteOffset']:view['byteOffset'] + view['byteLength']], IMAGE)
            self.assertNotIn('uri', document['images'][0])
            self.assertEqual(document['buffers'], [{'byteLength': len(blob)}])
            self.assertEqual(document['materials'][0]['alphaMode'], 'BLEND')
            self.assertEqual([item['sha256'] for item in embedded],
                             [hashlib.sha256(GEOMETRY).hexdigest(), hashlib.sha256(IMAGE).hexdigest()])
            packed = Path(tmp) / 'out' / 'model.glb'
            self.assertEqual(packer.main([str(source), str(packed)]), 0)
            report = intake.inspect_glb(packed)
            self.assertTrue(report['ok'], report)
            self.assertEqual(report['external_dependencies'], [])
            self.assertTrue(report['images'][0]['declared_embedded'])

    def test_refuses_paths_outside_source(self):
        for uri in ('../secret.jpg', '/etc/passwd', 'https://example.invalid/a.jpg', 'data:image/jpeg;base64,AA=='):
            with tempfile.TemporaryDirectory() as tmp:
                source = write_source(Path(tmp), uri)
                with self.assertRaises(packer.PackError):
                    packer.pack(source)

    def test_output_must_differ_from_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = write_source(Path(tmp))
            with self.assertRaises(SystemExit):
                packer.main([str(source), str(source)])


if __name__ == '__main__':
    unittest.main()
