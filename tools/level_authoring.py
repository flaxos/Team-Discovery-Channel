#!/usr/bin/env python3
"""Shared JSON CLI for native Godot LevelLayout authoring; standard library only."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'client'
PREFIX = 'TDC_AUTHOR_RESULT '
FATAL = re.compile(r'(?:SCRIPT ERROR:|(?:^|\n)ERROR:|WARNING: ObjectDB|Segmentation fault)')


def error(code: str, reason: str, remedy: str = 'See docs/maps/ai-level-authoring.md.') -> dict:
    return {'ok': False, 'version': 1, 'errors': [{'code': code, 'reason': reason,
            'instance_ids': [], 'socket_ids': [], 'remedy': remedy}]}


def resource_path(value: str) -> str:
    if value.startswith(('res://', 'user://')):
        return value
    path = Path(value).resolve()
    try:
        return 'res://' + path.relative_to(PROJECT).as_posix()
    except ValueError:
        return str(path)


def run_engine(godot: str, request: dict, timeout: float = 180) -> dict:
    with tempfile.TemporaryDirectory(prefix='tdc-author-') as tmp:
        path = Path(tmp) / 'request.json'
        path.write_text(json.dumps(request), encoding='utf-8')
        try:
            result = subprocess.run([godot, '--headless', '--fixed-fps', '60', '--path', str(PROJECT),
                '--script', 'res://scripts/level/author_level.gd', '--', '--request', str(path)],
                capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return error('timeout', f'Godot authoring operation exceeded {timeout:g} seconds.')
        output = result.stdout + result.stderr
        response = None
        for line in result.stdout.splitlines():
            if line.startswith(PREFIX):
                response = json.loads(line[len(PREFIX):])
        if response is None:
            response = error('engine_failure', 'Godot did not return an authoring response.')
        if response.get('ok') and (result.returncode or FATAL.search(output)):
            response = error('engine_diagnostics', 'The operation produced engine/script errors.')
        if not response.get('ok'):
            response['engine_log'] = output[-12000:]
        return response


def prepare(godot: str) -> dict:
    try:
        version = subprocess.run([godot, '--version'], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return error('engine_unavailable', str(exc))
    if version.returncode or not re.match(r'^4\.4\.1(?:[.\s-]|$)', version.stdout):
        return error('engine_version', 'This project requires Godot 4.4.1.')
    try:
        result = subprocess.run([godot, '--headless', '--editor', '--path', str(PROJECT), '--quit'],
                                capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return error('import_timeout', 'Godot project import exceeded 120 seconds.')
    output = result.stdout + result.stderr
    if result.returncode or FATAL.search(output):
        response = error('import_failed', 'Project import failed; fix the reported scripts/assets.')
        response['engine_log'] = output[-12000:]
        return response
    return {'ok': True, 'version': 1, 'engine': version.stdout.strip(), 'prepared': str(PROJECT)}


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__, epilog='One JSON result is printed. Requests are disposable; .tres layouts remain authoritative. See docs/maps/ai-level-authoring.md.')
    result.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    sub = result.add_subparsers(dest='command', required=True)
    sub.add_parser('prepare', help='Import the project and verify Godot 4.4.1.')
    catalogue = sub.add_parser('catalogue', help='Discover live modules, presets, themes and composites.')
    catalogue.add_argument('--detail', action='store_true')
    catalogue.add_argument('--search', default='')
    catalogue.add_argument('--kind', choices=['all', 'module', 'preset', 'theme', 'composite'], default='all')
    catalogue.add_argument('--output', help='Write a generated JSON snapshot; never a geometry source.')
    catalogue.add_argument('--verify', help='Reject a stale generated snapshot.')
    apply = sub.add_parser('apply', help='Transactionally create/edit a native layout from a disposable JSON request.')
    apply.add_argument('--request', required=True)
    apply.add_argument('--layout', help='Existing input .tres; omit when request includes create.')
    apply.add_argument('--output', required=True)
    apply.add_argument('--overwrite', action='store_true')
    for name in ['inspect', 'validate']:
        command = sub.add_parser(name)
        command.add_argument('--layout', required=True)
    build = sub.add_parser('build', help='Validate, bake and export through the shared Godot pipeline.')
    build.add_argument('--layout', required=True)
    build.add_argument('--output', required=True)
    build.add_argument('--nav-output', required=True)
    preview = sub.add_parser('preview', help='Launch the existing player preview or capture a rendered overview.')
    source = preview.add_mutually_exclusive_group(required=True)
    source.add_argument('--layout')
    source.add_argument('--scene', help='Previously built scene; avoids a redundant rebuild.')
    preview.add_argument('--capture', help='Save PNG and exit; requires a working graphical display.')
    preview.add_argument('--timeout', type=float, default=45)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == 'prepare':
            response = prepare(args.godot)
        else:
            if not (PROJECT / '.godot/global_script_class_cache.cfg').exists():
                response = prepare(args.godot)
                if not response['ok']:
                    print(json.dumps(response, ensure_ascii=False))
                    return 1
            request: dict = {'command': args.command}
            for key in ['layout', 'output', 'nav_output', 'verify']:
                value = getattr(args, key, None)
                if value:
                    request[key] = resource_path(value) if key != 'verify' else str(Path(value).resolve())
            if args.command == 'catalogue':
                request.update(detail=args.detail, search=args.search, kind=args.kind)
                if args.output:
                    output = Path(args.output).resolve()
                    output.parent.mkdir(parents=True, exist_ok=True)
                    request['output'] = str(output)
            if args.command == 'apply':
                request['transaction'] = json.loads(Path(args.request).read_text(encoding='utf-8'))
                request['overwrite'] = args.overwrite
            if args.command == 'preview':
                if args.layout:
                    tag = uuid.uuid4().hex
                    built = run_engine(args.godot, {'command': 'build', 'layout': resource_path(args.layout),
                        'output': f'user://author_preview_{tag}.tscn', 'nav_output': f'user://author_preview_{tag}.tres'})
                    if not built['ok']:
                        print(json.dumps(built, ensure_ascii=False))
                        return 1
                    scene = built['scene']
                else:
                    scene = resource_path(args.scene)
                command = [args.godot, '--windowed', '--resolution', '1280x720', '--path', str(PROJECT), 'res://addons/modular_editor/preview.tscn', '--', '--scene', scene]
                if args.capture:
                    output = Path(args.capture).resolve()
                    output.parent.mkdir(parents=True, exist_ok=True)
                    command += ['--capture', '--capture-output', str(output)]
                    result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
                    log = result.stdout + result.stderr
                    response = {'ok': True, 'version': 1, 'scene': scene, 'capture': str(output)} if not result.returncode and not FATAL.search(log) and output.is_file() else error('preview_failed', 'Rendered capture failed; use a graphical display or xvfb-run.')
                    if not response['ok']:
                        response['engine_log'] = log[-12000:]
                else:
                    log_path = Path(tempfile.gettempdir()) / f'tdc-preview-{uuid.uuid4().hex}.log'
                    with log_path.open('w') as log:
                        process = subprocess.Popen(command, stdout=log, stderr=log)
                    response = {'ok': True, 'version': 1, 'pid': process.pid, 'scene': scene, 'log': str(log_path)}
            else:
                response = run_engine(args.godot, request)
        print(json.dumps(response, ensure_ascii=False))
        return 0 if response.get('ok') else 1
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print(json.dumps(error('request_failed', str(exc)), ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
