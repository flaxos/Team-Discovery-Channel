"""Tests for tools/downscale_glb_textures.py."""
import io
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

try:
    from PIL import Image
except ImportError:
    Image = None

TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import asset_intake  # noqa: E402
import downscale_glb_textures as downscaler  # noqa: E402


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    body = tag + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)


def _make_1x1_png(color: tuple[int, int, int]) -> bytes:
    ihdr = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
    idat = zlib.compress(b'\x00' + bytes(color))
    return b'\x89PNG\r\n\x1a\n' + _png_chunk(b'IHDR', ihdr) + _png_chunk(b'IDAT', idat) + _png_chunk(b'IEND', b'')


def _make_large_png(color: tuple[int, int, int], size: int = 2048) -> bytes:
    buf = io.BytesIO()
    Image.new('RGB', (size, size), color).save(buf, format='PNG')
    return buf.getvalue()


def _build_test_glb(path: Path, albedo_png: bytes, normal_png: bytes) -> bytes:
    """Create a valid self-contained GLB with 1 geometry bufferView + 2 PNG images."""
    geom_bytes = struct.pack('<9f3H', 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0, 1, 2) + b'\x00\x00'

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
    def test_passthrough_small_png_and_normal_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            src = tmp_dir / 'small.glb'
            dst = tmp_dir / 'small_out.glb'
            albedo_png = _make_1x1_png((200, 140, 80))
            normal_png = _make_1x1_png((128, 128, 255))
            geom_bytes = _build_test_glb(src, albedo_png, normal_png)

            stats = downscaler.downscale_glb(src, dst, max_size=1024)
            self.assertEqual(stats['images_resized'], 0)

            report = asset_intake.inspect_glb(dst)
            self.assertEqual(report['errors'], [])

            out_data = dst.read_bytes()
            jlen, _ = struct.unpack_from('<II', out_data, 12)
            out_doc = json.loads(out_data[20:20 + jlen])
            self.assertEqual(downscaler._normal_image_indices(out_doc), {1})

            bin_start = 20 + jlen + 8
            bv0 = out_doc['bufferViews'][0]
            out_geom = out_data[bin_start + bv0['byteOffset']:bin_start + bv0['byteOffset'] + bv0['byteLength']]
            self.assertEqual(out_geom, geom_bytes)

    @unittest.skipIf(Image is None, 'Pillow is optional in CI runner-contract')
    def test_downscales_2k_images_preserves_geometry_and_normalizes(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            src = tmp_dir / 'fixture.glb'
            dst = tmp_dir / 'fixture_1k.glb'
            geom_bytes = _build_test_glb(
                src,
                _make_large_png((200, 140, 80), 2048),
                _make_large_png((180, 128, 220), 2048),
            )

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
                        r, g, b = im.getpixel((512, 512))
                        nx = r / 127.5 - 1.0
                        ny = g / 127.5 - 1.0
                        nz = b / 127.5 - 1.0
                        self.assertAlmostEqual(math.sqrt(nx * nx + ny * ny + nz * nz), 1.0, places=2)


if __name__ == '__main__':
    unittest.main()
