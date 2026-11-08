"""Runner failure contracts, independent of installed Godot and game fixtures."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

RUNNER = Path(__file__).resolve().parents[1] / 'run_godot_tests.py'
SPEC = importlib.util.spec_from_file_location('runner', RUNNER)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RunnerContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='runner-contract-')
        self.root = Path(self.temp.name)
        (self.root / 'tests').mkdir()
        (self.root / 'project.godot').write_text('config_version=5\n')
        for name in ['test_pass', 'test_failure', 'test_crash', 'test_timeout', 'test_keybinding_restart']:
            (self.root / 'tests' / (name + '.gd')).write_text('fixture\n')
        self.fake = self.root / 'godot'
        self.fake.write_text('''#!/usr/bin/env python3
import os, pathlib, sys, time
if '--version' in sys.argv:
    print(os.environ.get('FAKE_VERSION', '4.4.1.stable.fixture')); sys.exit(0)
if '--editor' in sys.argv:
    print('SCRIPT ERROR: fixture import failure' if os.environ.get('FAKE_IMPORT_ERROR') else 'Imported'); sys.exit(0)
script = sys.argv[sys.argv.index('--script') + 1]
if script.endswith('test_failure.gd'): print('SCRIPT ERROR: Assertion failed: deliberate failure'); print('ALL PASSED'); sys.exit(0)
if script.endswith('test_crash.gd'): sys.exit(139)
if script.endswith('test_timeout.gd'): time.sleep(2)
if script.endswith('test_keybinding_restart.gd'):
    marker = pathlib.Path(os.environ['XDG_DATA_HOME']) / 'persisted'
    if '--write' in sys.argv: marker.write_text('saved')
    else: assert marker.read_text() == 'saved'
print('PASS fixture')
''')
        self.fake.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def run_fixture(self, suite, extra=(), env=None):
        output = self.root / 'results'
        command = [sys.executable, str(RUNNER), '--project', str(self.root), '--godot', str(self.fake),
                   '--output', str(output), '--timeout', '0.2', suite, *extra]
        result = subprocess.run(command, capture_output=True, text=True, env=dict(os.environ, **(env or {})), timeout=10)
        return result, json.loads((output / 'summary.json').read_text())

    def test_success_and_artifacts(self):
        result, report = self.run_fixture('test_pass')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(report['passed'])
        self.assertFalse(report['graphical_uat'])
        self.assertEqual(ET.parse(self.root / 'results/junit.xml').getroot().attrib['failures'], '0')

    def test_assertion_with_zero_exit_fails(self):
        result, report = self.run_fixture('test_failure')
        self.assertEqual(result.returncode, 1)
        self.assertFalse(report['passed'])
        self.assertIn('ALL PASSED', (self.root / 'results/test_failure.log').read_text())

    def test_import_error_with_zero_exit_fails_before_tests(self):
        result, report = self.run_fixture('test_pass', env={'FAKE_IMPORT_ERROR': '1'})
        self.assertEqual(result.returncode, 1)
        self.assertEqual([entry['name'] for entry in report['results']], ['project-import'])

    def test_wrong_engine_is_rejected(self):
        result, report = self.run_fixture('test_pass', env={'FAKE_VERSION': '4.5.stable.fixture'})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report['results'][0]['name'], 'engine-version')

    def test_crash_fails(self):
        result, report = self.run_fixture('test_crash')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report['results'][-1]['returncode'], 139)

    def test_timeout_fails(self):
        result, report = self.run_fixture('test_timeout')
        self.assertEqual(result.returncode, 1)
        self.assertTrue(report['results'][-1]['timed_out'])

    def test_persistence_uses_two_processes_with_shared_isolated_user_data(self):
        result, report = self.run_fixture('test_keybinding_restart')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([entry['name'] for entry in report['results']][-2:],
                         ['test_keybinding_restart--write', 'test_keybinding_restart--read'])

    def test_full_inventory_excludes_nothing(self):
        self.assertEqual(runner.select_suites(self.root, 'full', []), runner.inventory(self.root))

    def test_ansi_engine_error_is_not_hidden(self):
        self.assertTrue(runner.failed_output('\x1b[31mERROR: bad\x1b[0m'))


if __name__ == '__main__':
    unittest.main()
