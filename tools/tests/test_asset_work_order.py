"""Intake must consume a validated request without treating it as art/licence approval."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('asset_work_order', REPO / 'tools/asset_work_order.py')
orders = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(orders)


class AssetWorkOrders(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'request.json'
        self.order = json.loads((REPO / 'docs/assets/asset-work-order-rigid.example.json').read_text())

    def validate(self, mutate=None, ready=False):
        order = copy.deepcopy(self.order)
        if mutate:
            mutate(order)
        self.path.write_text(json.dumps(order))
        return orders.validate_work_order(self.path, require_ready=ready)

    def ready_order(self):
        self.order['status'] = 'ready_for_intake'
        self.order['target'].update(measurement_status='measured',
            measurement_evidence='docs/assets/ai-asset-workflow.md',
            visual_branch='WeaponHolder/MP5/WeaponModel/ImportedGLB',
            bounds_m={'min_m': [-1, -1, -1], 'max_m': [1, 1, 1]})
        self.order['target']['anchors'][0]['position_m'] = [0, 0.01, -0.36]
        self.order['acquisition']['selected_source'] = {'page': 'https://example.com/fixture',
            'creator': 'Synthetic fixture', 'licence': 'Unverified request',
            'archive_terms_status': 'unverified', 'intake_record': None}

    def test_draft_is_valid_but_cannot_be_consumed_as_intake(self):
        self.assertTrue(self.validate()['ok'])
        self.assertFalse(self.validate(ready=True)['ok'])

    def test_runtime_conventions_unknown_fields_and_path_escapes_rejected(self):
        mutations = [lambda o: o.update(approved=True),
                     lambda o: o['materials'][0].update(normal_convention='directx'),
                     lambda o: o['materials'][0].update(data_encoding='jpeg'),
                     lambda o: o['materials'][0].update(orm_layout={'r':'metallic','g':'roughness','b':'ao'}),
                     lambda o: o['target'].update(scene='res://../outside.tscn'),
                     lambda o: o.update(kind='rigged_character'),
                     lambda o: o['materials'][0].update(alpha='mask')]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                self.assertFalse(self.validate(mutate)['ok'])

    def test_physical_comparisons_and_references_are_checked(self):
        self.ready_order()
        self.assertTrue(self.validate(ready=True)['ok'])
        for mutate in [lambda o: o['target']['bounds_m'].update(max_m=[-2,1,1]),
                       lambda o: o['geometry'].update(lod_triangle_limits=[5,10]),
                       lambda o: o['target'].update(measurement_evidence='build/does-not-exist.json'),
                       lambda o: o['target']['anchors'].append(copy.deepcopy(o['target']['anchors'][0])),
                       lambda o: o['target'].update(visual_branch='<unresolved>')]:
            self.assertFalse(self.validate(mutate, ready=True)['ok'])

    def test_duplicate_and_nonfinite_json_are_rejected(self):
        for text in ['{"asset_id":"one","asset_id":"two"}', '{"value":NaN}']:
            self.path.write_text(text)
            with self.assertRaises(ValueError):
                orders.validate_work_order(self.path)
        self.path.write_text(json.dumps(self.order).replace('"max_unique_texture_mib": 64', '"max_unique_texture_mib": 1e400'))
        self.assertFalse(orders.validate_work_order(self.path)['ok'])

    def test_intake_cli_refuses_drafts_and_cannot_overwrite_work_order(self):
        self.validate()
        before = self.path.read_bytes()
        asset = REPO / 'client/assets/weapons/mp5_silenced.glb'
        command = [sys.executable, str(REPO/'tools/asset_intake.py'), str(asset), '--work-order', str(self.path)]
        refused = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn('ready_for_intake', json.loads(refused.stdout)['errors'][0])
        alias = self.path.with_name('alias.json')
        alias.hardlink_to(self.path)
        refused = subprocess.run(command+['--output',str(alias)], capture_output=True, text=True)
        self.assertNotEqual(refused.returncode, 0)
        self.assertEqual(self.path.read_bytes(), before)

    def test_intake_records_request_hash_and_enforces_mesh_budget(self):
        self.ready_order()
        self.validate()
        asset = REPO / 'client/assets/weapons/mp5_silenced.glb'
        command = [sys.executable, str(REPO/'tools/asset_intake.py'), str(asset), '--work-order', str(self.path)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(len(json.loads(result.stdout)['work_order']['work_order_sha256']), 64)
        self.order['geometry'].update(max_lod0_triangles=1,lod_triangle_limits=[1])
        self.validate()
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('budget', json.loads(result.stdout)['errors'][0])


if __name__ == '__main__':
    unittest.main()
