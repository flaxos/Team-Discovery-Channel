"""Intake must preserve sources and distinguish declarations from engine acceptance."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / 'asset_intake.py'
SPEC = importlib.util.spec_from_file_location('asset_intake', TOOL)
intake = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(intake)
REPO = TOOL.parent.parent


def triangle():
    return {
        'asset': {'version': '2.0'},
        'buffers': [{'byteLength': 42}],
        'bufferViews': [{'buffer': 0, 'byteLength': 36},
                        {'buffer': 0, 'byteOffset': 36, 'byteLength': 6}],
        'accessors': [{'bufferView': 0, 'count': 3, 'componentType': 5126, 'type': 'VEC3',
                       'min': [0, 0, 0], 'max': [1, 1, 0]},
                      {'bufferView': 1, 'count': 3, 'componentType': 5123, 'type': 'SCALAR'}],
        'meshes': [{'name': 'Triangle', 'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1}]}],
        'nodes': [{'name': 'Mesh', 'mesh': 0, 'scale': [2, 2, 2]}, {'name': 'Hips'}],
        'skins': [{'joints': [1]}], 'animations': [{'name': 'Idle'}],
        'materials': [{'pbrMetallicRoughness': {'metallicFactor': 1}}],
    }


def glb(document):
    source = json.dumps(document).encode()
    source += b' ' * (-len(source) % 4)
    binary = bytes(44)
    chunks = struct.pack('<I4s', len(source), b'JSON') + source
    chunks += struct.pack('<I4s', len(binary), b'BIN\x00') + binary
    return struct.pack('<4sII', b'glTF', 2, len(chunks) + 12) + chunks


class AssetIntake(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'candidate.glb'

    def inspect(self, document):
        self.path.write_bytes(glb(document))
        return intake.inspect_glb(self.path)

    def test_inventory_preserves_file_and_labels_local_declared_bounds(self):
        report = self.inspect(triangle())
        self.assertTrue(report['ok'])
        self.assertEqual(report['sha256'], hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.assertEqual(report['declared_triangles_unique_meshes'], 1)
        self.assertEqual(report['meshes'][0]['primitives'][0]['mesh_local_declared_bounds']['size'], [1, 1, 0])
        self.assertEqual(report['skins'][0]['joint_indices'], [1])
        self.assertEqual(report['node_names'][1], 'Hips')
        self.assertEqual(report['animation_names'], ['Idle'])
        self.assertTrue(any('D-015' in reason for reason in report['manual_review']))

    def test_external_data_is_reported_without_being_read(self):
        document = triangle()
        document['images'] = [{'uri': '../../missing/texture.png'}]
        report = self.inspect(document)
        self.assertFalse(report['ok'])
        self.assertEqual(report['external_dependencies'][0]['uri'], '../../missing/texture.png')

    def test_data_uri_is_self_contained_and_required_extensions_need_review(self):
        document = triangle()
        document['images'] = [{'uri': 'data:image/png;base64,AA=='}]
        document['extensionsRequired'] = ['KHR_materials_unlit']
        report = self.inspect(document)
        self.assertTrue(report['ok'])
        self.assertTrue(report['images'][0]['declared_embedded'])
        self.assertIn('KHR_materials_unlit', report['required_extensions'])

    def test_strips_and_instancing_are_not_reported_as_scene_triangle_cost(self):
        document = triangle()
        document['accessors'][1]['count'] = 6
        document['meshes'][0]['primitives'][0]['mode'] = 5
        document['nodes'].append(copy.deepcopy(document['nodes'][0]))
        self.assertEqual(self.inspect(document)['declared_triangles_unique_meshes'], 4)

    def test_bad_counts_bounds_and_indices_fail(self):
        for field, value in [('count', -1), ('count', True), ('min', [0, 0]), ('max', [-1, 1, 1])]:
            with self.subTest(field=field, value=value):
                document = triangle()
                document['accessors'][0][field] = value
                with self.assertRaises(intake.IntakeError):
                    self.inspect(document)
        document = triangle()
        document['meshes'][0]['primitives'][0]['attributes']['POSITION'] = 100
        with self.assertRaises(intake.IntakeError):
            self.inspect(document)

    def test_truncation_missing_binary_and_buffer_overflow_fail(self):
        source = glb(triangle())
        for bad in (source[:8], source[:-1], source.replace(b'BIN\x00', b'OTHER'[:4])):
            with self.subTest(size=len(bad)):
                self.path.write_bytes(bad)
                with self.assertRaises(intake.IntakeError):
                    intake.inspect_glb(self.path)
        document = triangle()
        document['bufferViews'][1]['byteLength'] = 100
        with self.assertRaises(intake.IntakeError):
            self.inspect(document)

    def test_cli_errors_are_json_and_cannot_overwrite_source_or_hardlink(self):
        self.path.write_bytes(glb(triangle()))
        before = self.path.read_bytes()
        alias = self.path.with_name('alias.glb')
        alias.hardlink_to(self.path)
        for target in (self.path, alias):
            result = subprocess.run([sys.executable, str(TOOL), str(self.path), '--output', str(target)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.path.read_bytes(), before)
        self.path.write_bytes(b'invalid')
        result = subprocess.run([sys.executable, str(TOOL), str(self.path)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)['ok'])
        self.assertNotIn('Traceback', result.stderr)

    def test_non_finite_json_is_rejected(self):
        for number in (float('nan'), float('inf')):
            document = triangle()
            document['materials'][0]['pbrMetallicRoughness']['metallicFactor'] = number
            with self.assertRaises(intake.IntakeError):
                self.inspect(document)

    def test_large_and_overflowing_bounds_fail_without_tracebacks(self):
        for low, high in ((0, 10**400), (-1e308, 1e308)):
            document = triangle()
            document['accessors'][0].update(min=[low, 0, 0], max=[high, 1, 0])
            self.path.write_bytes(glb(document))
            result = subprocess.run([sys.executable, str(TOOL), str(self.path)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(json.loads(result.stdout)['ok'])
            self.assertNotIn('Traceback', result.stderr)

    def test_excessively_nested_json_returns_structured_error(self):
        source = b'{"asset":{"version":"2.0"},"extras":' + b'[' * 20000 + b'0' + b']' * 20000 + b'}'
        source += b' ' * (-len(source) % 4)
        self.path.write_bytes(struct.pack('<4sII', b'glTF', 2, len(source) + 20) + struct.pack('<I4s', len(source), b'JSON') + source)
        result = subprocess.run([sys.executable, str(TOOL), str(self.path)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)['ok'])
        self.assertNotIn('Traceback', result.stderr)

    def test_shared_joint_names_are_not_amplified_into_every_skin(self):
        document = triangle()
        document['nodes'][1]['name'] = 'a' * 1024
        document['skins'] = [{'joints': [1]} for _i in range(1000)]
        report = self.inspect(document)
        self.assertLess(len(json.dumps(report)), 200000)

    def test_missing_embedded_image_view_is_rejected(self):
        document = triangle()
        document['images'] = [{'bufferView': 999, 'mimeType': 'image/png'}]
        with self.assertRaises(intake.IntakeError):
            self.inspect(document)

    def test_unwritable_report_destination_is_a_json_failure(self):
        self.path.write_bytes(glb(triangle()))
        before = self.path.read_bytes()
        result = subprocess.run([sys.executable, str(TOOL), str(self.path), '--output', str(self.path / 'report.json')], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)['ok'])
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(self.path.read_bytes(), before)

    def test_existing_weapon_files_have_embedded_data(self):
        for name in ('p90_smg.glb', 'mp5_silenced.glb'):
            report = intake.inspect_glb(REPO / 'client/assets/weapons' / name)
            self.assertTrue(report['ok'], report['errors'])
            self.assertGreater(report['declared_triangles_unique_meshes'], 0)


if __name__ == '__main__':
    unittest.main()
