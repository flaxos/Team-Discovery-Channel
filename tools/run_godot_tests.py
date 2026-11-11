#!/usr/bin/env python3
"""Strict, reproducible Godot 4.4.1 test runner (headless, not graphical UAT)."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ENGINE_VERSION = '4.4.1'
FAST = (
    'test_sprint20_ads_submenu_and_remapping', 'test_keybinding_restart',
    'test_ads_pitch_alignment', 'test_squad_radial_wheel', 'test_keybindings_modal',
    'test_gate_lifecycle_and_modes', 'test_difficulty_menu_and_sync',
    'test_mission_restart_cleanup',
)
MULTIPLAYER = (
    'test_gate_client_authority', 'test_difficulty_menu_and_sync',
    'test_elevator_replication', 'test_netcode_smoke', 'test_sprint5_dedicated_smoke',
    'test_modular_security', 'test_modular_extraction_dedicated',
)
FATAL = re.compile(r'(?:SCRIPT ERROR:|(?:^|\n)ERROR:|Assertion failed|WARNING: ObjectDB|AddressSanitizer|Segmentation fault)', re.MULTILINE)
ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def failed_output(output: str) -> bool:
    return bool(FATAL.search(ANSI.sub('', output)))


def execute(command: list[str], timeout: float, env: dict[str, str], log: Path) -> dict:
    start = time.monotonic()
    try:
        run = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=env)
        output = run.stdout + run.stderr
        result = {'passed': run.returncode == 0 and not failed_output(output),
                  'returncode': run.returncode, 'timed_out': False}
    except subprocess.TimeoutExpired as exc:
        def decode(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
        output = decode(exc.stdout) + decode(exc.stderr) + f'\nTIMEOUT after {timeout:g}s\n'
        result = {'passed': False, 'returncode': None, 'timed_out': True}
    except OSError as exc:
        output = f'Could not execute {command[0]}: {exc}\n'
        result = {'passed': False, 'returncode': None, 'timed_out': False}
    log.write_text(output)
    result.update(command=command, duration_s=round(time.monotonic() - start, 3), log=str(log), output=output)
    return result


def inventory(project: Path) -> list[str]:
    return sorted(path.stem for path in (project / 'tests').glob('test_*.gd'))


def select_suites(project: Path, profile: str, explicit: list[str]) -> list[str]:
    all_suites = inventory(project)
    if explicit:
        selected = [name.removesuffix('.gd') for name in explicit]
        missing = [name for name in selected if name not in all_suites]
        if missing:
            raise ValueError('Unknown suites: ' + ', '.join(missing))
        return list(dict.fromkeys(selected))
    if profile == 'full':
        return all_suites
    if profile == 'fast':
        return [name for name in FAST if name in all_suites]
    return sorted(name for name in all_suites if name in MULTIPLAYER or
                  any(tag in name for tag in ('multiplayer', 'combat_authority', 'state_replication', 'mission_replication')))


def write_reports(output: Path, records: list[dict], args: argparse.Namespace, version: str, excluded: list[str]):
    report = {'started_utc': args.started_utc, 'engine_version': version, 'required_engine': ENGINE_VERSION,
              'project': str(args.project), 'profile': args.profile, 'skip_import': args.skip_import,
              'graphical_uat': False, 'excluded_from_this_run': excluded,
              'passed': bool(records) and all(item['passed'] for item in records),
              'results': [{key: value for key, value in item.items() if key != 'output'} for item in records]}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    suite = ET.Element('testsuite', name='Godot headless', tests=str(len(records)),
                       failures=str(sum(not item['passed'] for item in records)))
    for item in records:
        case = ET.SubElement(suite, 'testcase', name=item['name'], time=str(item['duration_s']))
        if not item['passed']:
            failure = ET.SubElement(case, 'failure', message='Timeout' if item['timed_out'] else 'Exit or engine/script error')
            failure.text = item['output'][-12000:]
        ET.SubElement(case, 'system-out').text = str(item['log'])
    ET.ElementTree(suite).write(output / 'junit.xml', encoding='utf-8', xml_declaration=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suites', nargs='*', help='Explicit test names; default profile is full discovery')
    parser.add_argument('--profile', choices=['fast', 'full', 'multiplayer'], default='full')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--project', type=Path, default=ROOT / 'client')
    parser.add_argument('--timeout', type=float, default=180, help='Per test process timeout in seconds')
    parser.add_argument('--import-timeout', type=float, default=120)
    parser.add_argument('--output', type=Path, default=ROOT / 'build' / 'test-results' / 'godot')
    parser.add_argument('--skip-import', action='store_true', help='Diagnostic only; CI never uses this')
    parser.add_argument('--list', action='store_true', help='List selected suites without executing')
    args = parser.parse_args(argv)
    args.project = args.project.resolve()
    args.output = args.output.resolve()
    args.started_utc = dt.datetime.now(dt.timezone.utc).isoformat()
    if args.timeout <= 0 or args.import_timeout <= 0:
        parser.error('Timeouts must be positive')
    if not (args.project / 'project.godot').is_file():
        parser.error('Project must contain project.godot')
    try:
        selected = select_suites(args.project, args.profile, args.suites)
    except ValueError as exc:
        parser.error(str(exc))
    if not selected:
        parser.error('No suites selected')
    if args.list:
        print('\n'.join(selected))
        return 0
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    excluded = [name for name in inventory(args.project) if name not in selected]
    with tempfile.TemporaryDirectory(prefix='tdc-tests-') as data:
        # Suites that shell out to repository tools must find the same engine this runner was given.
        env = dict(os.environ, XDG_DATA_HOME=data, XDG_CONFIG_HOME=data, XDG_CACHE_HOME=data,
                   GODOT=shutil.which(args.godot) or args.godot)
        version_result = execute([args.godot, '--version'], 15, env, args.output / 'version.log')
        version = version_result['output'].strip()
        if not version_result['passed'] or not re.match(r'^4\.4\.1(?:[.\s-]|$)', version):
            version_result.update(name='engine-version', passed=False)
            records.append(version_result)
            print(f'FAIL engine-version: expected {ENGINE_VERSION}, got {version!r}', flush=True)
        else:
            if not args.skip_import:
                imported = execute([args.godot, '--headless', '--editor', '--path', str(args.project), '--quit',
                                    '--log-file', str(args.output / 'import.engine.log')],
                                   args.import_timeout, env, args.output / 'import.log')
                imported['name'] = 'project-import'
                records.append(imported)
                print(('PASS ' if imported['passed'] else 'FAIL ') + 'project-import', flush=True)
            if all(item['passed'] for item in records):
                for name in selected:
                    phases = ['--write', '--read'] if name == 'test_keybinding_restart' else ['']
                    for phase in phases:
                        label = name + phase
                        command = [args.godot, '--headless', '--fixed-fps', '60', '--path', str(args.project),
                                   '--log-file', str(args.output / (label + '.engine.log')),
                                   '--script', 'res://tests/' + name + '.gd']
                        if phase:
                            command += ['--', phase]
                        result = execute(command, args.timeout, env, args.output / (label + '.log'))
                        result['name'] = label
                        records.append(result)
                        print(('PASS ' if result['passed'] else 'FAIL ') + label, flush=True)
                        if not result['passed']:
                            print(result['output'][-3000:], flush=True)
                            break
    write_reports(args.output, records, args, version, excluded)
    return 0 if records and all(item['passed'] for item in records) else 1


if __name__ == '__main__':
    raise SystemExit(main())
