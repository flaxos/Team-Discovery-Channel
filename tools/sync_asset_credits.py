#!/usr/bin/env python3
"""Build exportable Godot credits from credits/ATTRIBUTIONS.md and its licence texts."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

REPO = Path(__file__).resolve().parents[1]
OUTPUT = Path('client/resources/asset_credits.tres')


def plain(text):
    def link(match):
        label, url = match.groups()
        return f'{label} ({url})' if url.startswith('http') else label
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link, text).replace('**', '').replace('`', '')


def build_credits(repo=REPO):
    repo = Path(repo)
    manifest = repo / 'credits/ATTRIBUTIONS.md'
    source = manifest.read_text()
    entries, group = [], []
    for line in source.splitlines():
        if line.lower().startswith('| asset file |'):
            group = []
        elif line.startswith('| `client/assets/'):
            cells = [c.strip() for c in line.strip('|').split('|')]
            if len(cells) < 6:
                raise ValueError('Malformed attribution row: ' + line)
            entry = {'file': cells[0].strip('`'), 'title': plain(cells[1]),
                     'creator': plain(cells[2]), 'source': plain(cells[3]),
                     'licence': plain(cells[4]), 'changes': []}
            if not all(entry[k] for k in ('title', 'creator', 'source', 'licence')):
                raise ValueError('Incomplete attribution: ' + entry['file'])
            if not re.search(r'https?://', entry['source']):
                raise ValueError('Attribution needs an exact source URL: ' + entry['file'])
            entries.append(entry)
            group.append(entry)
        elif line.startswith(('- **Modifications:', '- **Changes:', '- **Underlying rights:')):
            for entry in group:
                entry['changes'].append(plain(line.removeprefix('- ')))
    files = [e['file'] for e in entries]
    binaries = {str(p.relative_to(repo)) for p in (repo / 'client/assets').rglob('*.glb')}
    if len(files) != len(set(files)) or set(files) != binaries:
        raise ValueError(f'Credits/binary coverage differs: missing={sorted(binaries-set(files))}, '
                         f'unknown={sorted(set(files)-binaries)}, duplicates={len(files)-len(set(files))}')
    for entry in entries:
        if 'CC BY' in entry['licence'] and not any(c.startswith(('Modifications:', 'Changes:')) for c in entry['changes']):
            raise ValueError('CC BY entry lacks modification notice: ' + entry['file'])
    licenses = {p.name: p.read_text() for p in sorted((repo / 'credits/licenses').glob('*.txt'))}
    if not licenses:
        raise ValueError('No full licence texts found')
    referenced = set(re.findall(r'\]\(licenses/([^/)]+\.txt)\)', source))
    if not referenced <= licenses.keys():
        raise ValueError('Missing full licence texts: ' + ', '.join(sorted(referenced-licenses.keys())))
    chunks = ['COMMUNITY ASSET CREDITS', 'Thank you to the artists whose work appears in this game. '
              'Full licence texts are available in this window.']
    for entry in entries:
        chunks.append('\n'.join([entry['title'], 'Creator: ' + entry['creator'],
                                 'Source: ' + entry['source'], 'Licence: ' + entry['licence'],
                                 *entry['changes']]))
    text = '\n\n'.join(chunks) + '\n'
    # A referenced .tres is included by Godot resource export; raw .txt filtering is unnecessary.
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    resource = ('[gd_resource type="Resource" format=3]\n\n[resource]\n'
                'metadata/attributions = ' + quote(text) + '\n'
                'metadata/licenses = ' + quote(licenses) + '\n'
                'metadata/asset_files = ' + quote(files) + '\n'
                'metadata/source_sha256 = ' + quote(hashlib.sha256(manifest.read_bytes()).hexdigest()) + '\n')
    return resource, len(entries)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail if the committed resource is stale')
    args = parser.parse_args(argv)
    try:
        resource, count = build_credits()
        output = REPO / OUTPUT
        if args.check:
            if not output.is_file() or output.read_text() != resource:
                raise ValueError('Exported credits are stale; run python3 tools/sync_asset_credits.py')
        else:
            output.write_text(resource)
        print(f'Asset credits: {count} models, full licence texts included; {"current" if args.check else "generated"}')
        return 0
    except (OSError, ValueError) as error:
        print(f'Asset credits: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
