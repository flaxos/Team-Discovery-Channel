#!/usr/bin/env python3
"""Downscale oversized embedded PNG/JPEG textures inside a binary glTF 2.0 (.glb).

Preserves every non-image bufferView byte bit-for-bit identically, re-normalizes
tangent-space RGB vectors for images referenced by material normalTextures, aligns
all bufferViews on 4-byte boundaries, and emits a valid self-contained GLB.
"""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
import struct
import sys

import numpy as np
from PIL import Image


def _normal_image_indices(document: dict) -> set[int]:
    textures = document.get('textures', [])
    indices: set[int] = set()
    for material in document.get('materials', []):
        normal_info = material.get('normalTexture')
        if not isinstance(normal_info, dict):
            continue
        tex_idx = normal_info.get('index')
        if isinstance(tex_idx, int) and 0 <= tex_idx < len(textures):
            src_idx = textures[tex_idx].get('source')
            if isinstance(src_idx, int):
                indices.add(src_idx)
    return indices


def _resize_image_bytes(raw: bytes, mime: str, max_size: int, is_normal: bool) -> tuple[bytes, bool]:
    with Image.open(io.BytesIO(raw)) as img:
        w, h = img.size
        if max(w, h) <= max_size:
            return raw, False
        scale = max_size / float(max(w, h))
        new_w = max(1, round(w * scale))
        new_h = max(1, round(h * scale))
        mode = img.mode
        resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        if is_normal:
            rgb_img = resized.convert('RGB')
            arr = np.asarray(rgb_img, dtype=np.float32) / 127.5 - 1.0
            norms = np.linalg.norm(arr, axis=2, keepdims=True)
            norms = np.maximum(norms, 1e-6)
            arr = arr / norms
            out_rgb = np.clip(np.rint((arr + 1.0) * 127.5), 0.0, 255.0).astype(np.uint8)
            if 'A' in mode:
                alpha = resized.getchannel('A')
                resized = Image.fromarray(out_rgb, mode='RGB')
                resized.putalpha(alpha)
            else:
                resized = Image.fromarray(out_rgb, mode='RGB')
        buf = io.BytesIO()
        if mime == 'image/jpeg':
            if resized.mode not in ('RGB', 'L'):
                resized = resized.convert('RGB')
            resized.save(buf, format='JPEG', quality=90, optimize=True)
        else:
            resized.save(buf, format='PNG', optimize=True)
        return buf.getvalue(), True


def downscale_glb(src_path: Path, dst_path: Path, max_size: int = 1024) -> dict[str, int]:
    """Read `src_path` GLB, downscale textures exceeding `max_size`, write `dst_path`."""
    data = src_path.read_bytes()
    magic, version, total_len = struct.unpack_from('<4sII', data, 0)
    if magic != b'glTF' or version != 2 or total_len != len(data):
        raise ValueError(f'Invalid GLB header in {src_path}')

    offset = 12
    document = None
    bin_chunk = b''
    while offset < len(data):
        chunk_len, chunk_kind = struct.unpack_from('<I4s', data, offset)
        offset += 8
        payload = data[offset:offset + chunk_len]
        offset += chunk_len
        if chunk_kind == b'JSON' and document is None:
            document = json.loads(payload.decode('utf-8'))
        elif chunk_kind == b'BIN\x00':
            bin_chunk = payload

    if not isinstance(document, dict):
        raise ValueError(f'Missing JSON chunk in {src_path}')

    views = document.get('bufferViews', [])
    images = document.get('images', [])
    normal_images = _normal_image_indices(document)

    view_to_image: dict[int, tuple[int, str]] = {}
    for img_idx, image in enumerate(images):
        bv_idx = image.get('bufferView')
        if isinstance(bv_idx, int):
            mime = image.get('mimeType', 'image/png')
            view_to_image[bv_idx] = (img_idx, mime)

    new_bin = bytearray()
    resized_count = 0
    bytes_before = len(bin_chunk)

    for bv_idx, bv in enumerate(views):
        if bv.get('buffer', 0) != 0:
            raise ValueError('Only single-buffer GLBs are supported')
        old_off = int(bv.get('byteOffset', 0))
        old_len = int(bv['byteLength'])
        chunk = bin_chunk[old_off:old_off + old_len]

        if bv_idx in view_to_image:
            img_idx, mime = view_to_image[bv_idx]
            chunk, changed = _resize_image_bytes(
                chunk, mime, max_size, img_idx in normal_images
            )
            if changed:
                resized_count += 1

        while len(new_bin) % 4 != 0:
            new_bin.append(0)
        bv['byteOffset'] = len(new_bin)
        bv['byteLength'] = len(chunk)
        new_bin.extend(chunk)

    while len(new_bin) % 4 != 0:
        new_bin.append(0)

    buffers = document.get('buffers', [])
    if buffers:
        buffers[0]['byteLength'] = len(new_bin)

    json_bytes = json.dumps(document, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
    while len(json_bytes) % 4 != 0:
        json_bytes += b' '

    total_out = 12 + 8 + len(json_bytes) + 8 + len(new_bin)
    out = bytearray()
    out.extend(struct.pack('<4sII', b'glTF', 2, total_out))
    out.extend(struct.pack('<I4s', len(json_bytes), b'JSON'))
    out.extend(json_bytes)
    out.extend(struct.pack('<I4s', len(new_bin), b'BIN\x00'))
    out.extend(new_bin)
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    dst_path.write_bytes(bytes(out))

    return {
        'images_resized': resized_count,
        'bin_bytes_before': bytes_before,
        'bin_bytes_after': len(new_bin),
        'file_bytes_before': len(data),
        'file_bytes_after': len(out),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='Source .glb file')
    parser.add_argument('--max-size', type=int, default=1024, help='Max image dimension (px)')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--output', type=Path, help='Output .glb path')
    group.add_argument('--in-place', action='store_true', help='Overwrite input .glb')
    args = parser.parse_args(argv)

    dst = args.input if args.in_place else args.output
    stats = downscale_glb(args.input, dst, max_size=args.max_size)
    print(
        f"Downscaled {stats['images_resized']} image(s): "
        f"{stats['file_bytes_before'] // 1024} KiB -> {stats['file_bytes_after'] // 1024} KiB"
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
