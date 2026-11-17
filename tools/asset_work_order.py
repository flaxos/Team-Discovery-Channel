#!/usr/bin/env python3
"""Validate asset requests, not licences, engine fit or visual acceptance."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[1]
SCHEMA = REPO / 'docs/assets/asset-work-order.schema.json'


def read_json(path):
    def constant(value):
        raise ValueError(f'Non-finite JSON number: {value}')

    def pairs(entries):
        result = {}
        for key, value in entries:
            if key in result:
                raise ValueError(f'Duplicate JSON key: {key}')
            result[key] = value
        return result

    return json.loads(Path(path).read_text(), parse_constant=constant, object_pairs_hook=pairs)


def project_path(value, repo):
    path = (repo / 'client' / value[6:]) if value.startswith('res://') else repo / value
    path = path.resolve()
    if not path.is_relative_to(repo.resolve()):
        raise ValueError(f'Reference escapes checkout: {value}')
    return path


def validate_work_order(path, *, require_ready=False, repo=REPO):
    try:
        from jsonschema import Draft202012Validator, FormatChecker
    except ImportError as error:
        raise ValueError('Work-order validation needs: python3 -m pip install -r tools/requirements.txt') from error
    path, repo = Path(path), Path(repo)
    schema = read_json(SCHEMA)
    order = read_json(path)
    Draft202012Validator.check_schema(schema)
    errors = [f'{"/".join(map(str, e.absolute_path)) or "$"}: {e.message}'
              for e in Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(order)]
    if not errors:
        # JSON Schema cannot compare coordinates/LOD budgets or resolve repository files.
        def finite(value):
            if isinstance(value, float) and not math.isfinite(value):
                errors.append('Numbers must be finite')
            elif isinstance(value, dict):
                for child in value.values():
                    finite(child)
            elif isinstance(value, list):
                for child in value:
                    finite(child)
        finite(order)
        target = order['target']
        bounds = target['bounds_m']
        if bounds and any(a >= b for a, b in zip(bounds['min_m'], bounds['max_m'])):
            errors.append('Target bounds must have positive extents on every axis')
        geometry = order['geometry']
        if geometry:
            lods = geometry['lod_triangle_limits']
            if lods[0] > geometry['max_lod0_triangles'] or any(a <= b for a, b in zip(lods, lods[1:])):
                errors.append('LOD limits must decrease and fit the LOD0 budget')
        names = [a['name'] for a in target['anchors']]
        if len(names) != len(set(names)):
            errors.append('Anchor names must be unique')
        if require_ready and order['status'] != 'ready_for_intake':
            errors.append('A GLB intake requires a ready_for_intake work order')
        references = [target['scene']]
        if order['status'] == 'ready_for_intake':
            references.append(target['measurement_evidence'])
            if '<' in target['visual_branch'] or '>' in target['visual_branch']:
                errors.append('Resolve template visual branches before intake')
            if order['rig']:
                references += [order['rig']['profile_ref'], order['rig']['rest_pose_ref']]
        for reference in references:
            try:
                if not project_path(reference, repo).is_file():
                    errors.append(f'Reference does not exist: {reference}')
            except ValueError as error:
                errors.append(str(error))
    return {
        'ok': not errors, 'scope': 'Request validation only; no licence or engine/art approval',
        'asset_id': order.get('asset_id') if isinstance(order, dict) else None,
        'status': order.get('status') if isinstance(order, dict) else None,
        'work_order_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'schema_sha256': hashlib.sha256(SCHEMA.read_bytes()).hexdigest(),
        'errors': errors,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work_order', type=Path)
    parser.add_argument('--require-ready', action='store_true')
    args = parser.parse_args(argv)
    try:
        report = validate_work_order(args.work_order, require_ready=args.require_ready)
    except (OSError, ValueError, TypeError, RecursionError, OverflowError) as error:
        report = {'ok': False, 'errors': [str(error)]}
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
