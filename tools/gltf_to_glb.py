#!/usr/bin/env python3
"""Pack a staged .gltf (+ .bin + images) into one self-contained .glb without re-encoding.

Every buffer and image is copied byte for byte into the GLB binary chunk. Only the
container changes: buffer views are re-pointed at the single chunk and images reference
buffer views instead of relative files. Vertex, index, material and texture data are not
altered, so the source hashes recorded at intake still describe the packed contents.

Only plain relative file URIs inside the source directory are accepted; absolute paths,
parent traversal, network and data URIs are refused.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
from urllib.parse import unquote, urlparse

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


class PackError(ValueError):
    pass


def _resolve(base: Path, uri: str) -> Path:
    if not isinstance(uri, str) or not uri or uri.startswith('data:') or urlparse(uri).scheme:
        raise PackError(f'unsupported URI: {uri!r}')
    relative = Path(unquote(uri))
    if relative.is_absolute() or '..' in relative.parts:
        raise PackError(f'URI leaves the source directory: {uri!r}')
    path = (base / relative).resolve()
    if base.resolve() not in path.parents:
        raise PackError(f'URI leaves the source directory: {uri!r}')
    if not path.is_file():
        raise PackError(f'missing file for URI: {uri!r}')
    return path


def pack(source: Path) -> tuple[bytes, list[dict]]:
    """Return GLB bytes and the list of embedded files (uri, size, sha256)."""
    document = json.loads(source.read_text(encoding='utf-8'))
    base = source.parent
    blob = bytearray()
    embedded: list[dict] = []

    def append(data: bytes) -> int:
        blob.extend(b'\0' * (-len(blob) % 4))
        offset = len(blob)
        blob.extend(data)
        return offset

    def record(uri: str, data: bytes) -> None:
        embedded.append({'uri': uri, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})

    offsets = []
    for buffer in document.get('buffers', []):
        if 'uri' not in buffer:
            raise PackError('source already has a URI-less (GLB) buffer')
        data = _resolve(base, buffer['uri']).read_bytes()
        if len(data) < buffer.get('byteLength', 0):
            raise PackError(f'buffer {buffer["uri"]!r} is shorter than its byteLength')
        record(buffer['uri'], data)
        offsets.append(append(data))
    for view in document.get('bufferViews', []):
        view['byteOffset'] = view.get('byteOffset', 0) + offsets[view['buffer']]
        view['buffer'] = 0
    views = document.setdefault('bufferViews', [])
    for image in document.get('images', []):
        if 'uri' not in image:
            continue
        if 'mimeType' not in image:
            raise PackError(f'image {image["uri"]!r} needs a mimeType to be embedded')
        data = _resolve(base, image['uri']).read_bytes()
        record(image['uri'], data)
        views.append({'buffer': 0, 'byteOffset': append(data), 'byteLength': len(data)})
        del image['uri']
        image['bufferView'] = len(views) - 1
    blob.extend(b'\0' * (-len(blob) % 4))
    if blob:
        document['buffers'] = [{'byteLength': len(blob)}]
    else:
        document.pop('buffers', None)

    text = json.dumps(document, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
    text += b' ' * (-len(text) % 4)
    chunks = struct.pack('<II', len(text), JSON_CHUNK) + text
    if blob:
        chunks += struct.pack('<II', len(blob), BIN_CHUNK) + bytes(blob)
    return struct.pack('<III', GLB_MAGIC, 2, 12 + len(chunks)) + chunks, embedded


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Staged .gltf file (not modified)')
    parser.add_argument('output', type=Path, help='Destination .glb (must not be the source)')
    args = parser.parse_args(argv)
    if args.output.resolve() == args.source.resolve() or args.output.suffix.lower() != '.glb':
        parser.error('output must be a different .glb path')
    try:
        data, embedded = pack(args.source)
    except (OSError, ValueError, KeyError, IndexError) as exc:
        print(f'gltf_to_glb: {exc}', file=sys.stderr)
        return 1
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    print(json.dumps({'output': str(args.output), 'size': len(data),
                      'sha256': hashlib.sha256(data).hexdigest(), 'embedded': embedded}, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
