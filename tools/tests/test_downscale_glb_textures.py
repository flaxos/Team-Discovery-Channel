"""Tests for tools/downscale_glb_textures.py."""
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import asset_intake  # noqa: E402
import downscale_glb_textures as downscaler  # noqa: E402


def _make_png(color: tuple[int, int, int], size: int = 2048) -> bytes:
    arr = np.full((size, size, 3), color, dtype=np.uint8)
    buf = io.BytesIO()
    Image.fromarray(arr, mode='RGB').save(buf, format='PNG')
    return buf.getvalue()


def _build_test_glb(path: Path) -> bytes:
    """Create a valid self-contained GLB with 1 geometry bufferView + 2 2K PNGs."""
    # Geometry bufferView: 3 float32 positions (36 bytes) + 3 uint16 indices (6 bytes) + 2B pad.
    geom_bytes = struct.pack('<9f3H', 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0, 1, 2) + b'\x00\x00'
    albedo_png = _make_png((200, 140, 80), 2048)
    normal_png = _make_png((180, 128, 220), 2048)

    bin_buf = bytearray()
    bv0_off = 0
    bin_buf.extend(geom_bytes)
    while len(bin_buf) % 4 != 0:
        bin_buf.append(0)

    bv1_off = len(bin_buf)
    bin_buf.extend(albedo_png)
    while len(bin_buf) % 4 != 0:
        bin_buf.append(0)

    bv2_off = len(bin_buf)
    bin_buf.extend(normal_png)
    while len(bin_buf) % 4 != 0:
        bin_buf.append(0)

    doc = {
        'asset': {'version': '2.0'},
        'buffers': [{'byteLength': len(bin_buf)}],
        'bufferViews': [
            {'buffer': 0, 'byteOffset': bv0_off, 'byteLength': len(geom_bytes)},
            {'buffer': 0, 'byteOffset': bv1_off, 'byteLength': len(albedo_png)},
            {'buffer': 0, 'byteOffset': bv2_off, 'byteLength': len(normal_png)},
        ],
        'accessors': [
            {
                'bufferView': 0,
                'byteOffset': 0,
                'componentType': 5126,
                'count': 3,
                'type': 'VEC3',
                'min': [0.0, 0.0, 0.0],
                'max': [1.0, 1.0, 0.0],
            },
            {
                'bufferView': 0,
                'byteOffset': 36,
                'componentType': 5123,
                'count': 3,
                'type': 'SCALAR',
            },
        ],
        'images': [
            {'bufferView': 1, 'mimeType': 'image/png', 'name': 'albedo'},
            {'bufferView': 2, 'mimeType': 'image/png', 'name': 'normal'},
        ],
        'textures': [{'source': 0}, {'source': 1}],
        'materials': [
            {
                'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}},
                'normalTexture': {'index': 1},
            }
        ],
        'meshes': [
            {'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0}]}
        ],
        'nodes': [{'mesh': 0}],
        'scenes': [{'nodes': [0]}],
        'scene': 0,
    }
    json_bytes = json.dumps(doc, separators=(',', ':')).encode('utf-8')
    while len(json_bytes) % 4 != 0:
        json_bytes += b' '

    total = 12 + 8 + len(json_bytes) + 8 + len(bin_buf)
    glb = (
        struct.pack('<4sII', b'glTF', 2, total)
        + struct.pack('<I4s', len(json_bytes), b'JSON')
        + json_bytes
        + struct.pack('<I4s', len(bin_buf), b'BIN\x00')
        + bytes(bin_buf)
    )
    path.write_bytes(glb)
    return geom_bytes


class DownscaleGlbTexturesTest(unittest.TestCase):
    def test_downscales_2k_images_preserves_geometry_and_normalizes(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            src = tmp_dir / 'fixture.glb'
            dst = tmp_dir / 'fixture_1k.glb'
            geom_bytes = _build_test_glb(src)

            stats = downscaler.downscale_glb(src, dst, max_size=1024)
            self.assertEqual(stats['images_resized'], 2)
            self.assertLess(stats['file_bytes_after'], stats['file_bytes_before'])

            report = asset_intake.inspect_glb(dst)
            self.assertEqual(report['errors'], [])

            out_data = dst.read_bytes()
            jlen, _ = struct.unpack_from('<II', out_data, 12)
            out_doc = json.loads(out_data[20:20 + jlen])
            bin_start = 20 + jlen + 8

            bv0 = out_doc['bufferViews'][0]
            out_geom = out_data[bin_start + bv0['byteOffset']:bin_start + bv0['byteOffset'] + bv0['byteLength']]
            self.assertEqual(out_geom, geom_bytes)

            for img_idx, bv_idx in ((0, 1), (1, 2)):
                bv = out_doc['bufferViews'][bv_idx]
                raw = out_data[bin_start + bv['byteOffset']:bin_start + bv['byteOffset'] + bv['byteLength']]
                with Image.open(io.BytesIO(raw)) as im:
                    self.assertEqual(im.size, (1024, 1024))
                    if img_idx == 1:
                        center = np.asarray(im, dtype=np.float32)[512, 512] / 127.5 - 1.0
                        self.assertAlmostEqual(float(np.linalg.norm(center)), 1.0, places=2)


if __name__ == '__main__':
    unittest.main()
