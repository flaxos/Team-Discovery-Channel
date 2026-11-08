#!/usr/bin/env python3
"""Run Godot tests with timeouts; engine/script errors fail even after quit(0)."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULTS = ['test_sprint20_ads_submenu_and_remapping', 'test_keybinding_restart', 'test_elevator_replication', 'test_staircase_traversal', 'test_sgc_dual_staircase_and_elevator', 'test_jaffa_column_march',
            'test_sprint19_zoom_fade_cursor', 'test_ads_pitch_alignment',
            'test_squad_radial_wheel', 'test_keybindings_modal',
            'test_sgc_4level_elevator_and_stairs']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suites', nargs='*')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=int, default=45)
    parser.add_argument('--output', type=Path, default=Path('/tmp/tdc-tests'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    failures = []
    with tempfile.TemporaryDirectory(prefix='tdc-tests-') as data:
        env = dict(os.environ, XDG_DATA_HOME=data, XDG_CONFIG_HOME=data, XDG_CACHE_HOME=data)
        for suite in args.suites or DEFAULTS:
            log = ''
            passed = True
            phases = ['--write', '--read'] if suite == 'test_keybinding_restart' else ['']
            for phase in phases:
                try:
                    command = [args.godot, '--headless', '--fixed-fps', '60', '--path', str(ROOT / 'client'),
                               '--log-file', str(args.output.resolve() / (suite + phase + '.engine.log')),
                               '--script', 'res://tests/' + suite + '.gd']
                    if phase:
                        command += ['--', phase]
                    run = subprocess.run(command, capture_output=True, text=True,
                                         timeout=args.timeout, env=env)
                    output = run.stdout + run.stderr
                    log += output
                    passed = passed and run.returncode == 0 and not any(x in output for x in
                             ['ERROR:', 'SCRIPT ERROR', 'Assertion failed', 'WARNING: ObjectDB'])
                except subprocess.TimeoutExpired as exc:
                    log += str(exc) + '\n' + (exc.stdout or b'').decode(errors='replace')
                    passed = False
                if not passed:
                    break
            (args.output / (suite + '.log')).write_text(log)
            print(('PASS ' if passed else 'FAIL ') + suite, flush=True)
            if not passed:
                failures.append(suite)
                print(log[-4500:], flush=True)
    return bool(failures)

if __name__ == '__main__':
    sys.exit(main())
