"""The Goa'uld kit's rules, checked on the generator's own geometry without the engine.

Each rule is from docs/maps/goauld-visual-brief.md. The engine-side suite
(client/tests/test_goauld_theme.gd) proves the built level; this one proves the pieces.
"""
import importlib.util
import itertools
from pathlib import Path
import sys
import unittest

KIT = Path(__file__).resolve().parents[1] / 'theme_kit.py'
SPEC = importlib.util.spec_from_file_location('theme_kit', KIT)
kit = importlib.util.module_from_spec(SPEC)
sys.modules['theme_kit'] = kit  # dataclasses resolve annotations through sys.modules
SPEC.loader.exec_module(kit)

STEP = 0.05  # sampling grid for coverage checks, in metres


def luminance(colour):
    """Relative luminance of an sRGB colour, as the brief tabulates it."""
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in colour]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(a, b):
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def local_size(slab, turn):
    return slab.size if turn % 2 == 0 else (slab.size[2], slab.size[1], slab.size[0])


def samples(low, high):
    count = max(1, round((high - low) / STEP))
    return [low + (index + 0.5) * (high - low) / count for index in range(count)]


def covers(boxes, axes, point):
    """Whether any box contains the point on the two given axes."""
    return any(
        all(box.low()[axis] - 1e-6 <= value <= box.high()[axis] + 1e-6 for axis, value in zip(axes, point))
        for box in boxes
    )


class GoauldKit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.variants, cls.pieces = kit.build()

    def of_slot(self, slot):
        return {name: piece for name, piece in self.pieces.items() if piece[0].slot == slot}

    def test_committed_kit_matches_the_generator(self):
        stale = [str(path.relative_to(kit.ROOT)) for path, text in self.files.items()
                 if not path.is_file() or path.read_text() != text]
        self.assertEqual(stale, [], 'Run python3 tools/theme_kit.py')
        for folder, pattern in ((kit.MATERIAL_DIR, '*.tres'), (kit.SCENE_DIR, '*.tscn')):
            extra = [path.name for path in folder.glob(pattern) if path not in self.files]
            self.assertEqual(extra, [], 'Files the generator no longer writes')

    def test_every_structural_slab_of_the_pieced_modules_has_a_variant(self):
        for module_id, scene in kit.MODULES.items():
            wanted = {slab.name for slab in kit.read_slabs(kit.MODULE_SCENES / scene) if slab.slot != 'portal'}
            got = {variant['slot'] for variant in self.variants if variant['module'] == module_id}
            self.assertEqual(got, wanted, module_id)
        self.assertEqual(len(self.variants), 20)
        self.assertEqual(len({variant['id'] for variant in self.variants}), len(self.variants))

    def test_each_piece_fills_exactly_its_slab(self):
        # The resolver refuses a piece whose bounds differ from the slab by 2 cm (D-010).
        # Only a lintel's gold leaves the slab, and only by the 5 mm that keeps it in front
        # of a neighbouring module's header (gap G-9).
        for name, (slab, boxes, turn) in self.pieces.items():
            size = local_size(slab, turn)
            for axis in range(3):
                proud = kit.PROUD if slab.slot == 'door_frame' and axis == 0 else 0.0
                self.assertAlmostEqual(min(box.low()[axis] for box in boxes), -size[axis] / 2, 6, name)
                self.assertAlmostEqual(max(box.high()[axis] for box in boxes), size[axis] / 2 + proud, 6, name)
        self.assertLess(kit.PROUD, 0.01, 'Inside the tolerance LevelThemeResolver.apply allows')

    def test_no_two_boxes_of_a_piece_share_volume(self):
        # Overlapping boxes put two faces in one plane, which flickers.
        for name, (_slab, boxes, _turn) in self.pieces.items():
            for a, b in itertools.combinations(boxes, 2):
                shared = all(al < bh - 1e-6 and bl < ah - 1e-6
                             for al, ah, bl, bh in zip(a.low(), a.high(), b.low(), b.high()))
                self.assertFalse(shared, '%s: %s overlaps %s' % (name, a.name, b.name))

    def test_no_piece_can_be_seen_through(self):
        # Looking along its thin axis, a piece covers its whole slab.
        for name, (slab, boxes, turn) in self.pieces.items():
            size = local_size(slab, turn)
            thin = min(range(3), key=lambda axis: size[axis])
            axes = [axis for axis in range(3) if axis != thin]
            for u in samples(-size[axes[0]] / 2, size[axes[0]] / 2):
                for v in samples(-size[axes[1]] / 2, size[axes[1]] / 2):
                    self.assertTrue(covers(boxes, axes, (u, v)), '%s is open at %s' % (name, (u, v)))

    def test_ceilings_are_flush_all_round_their_edge(self):
        # Walls and lintels end at the slab's lower face. A recess that reached the edge
        # would leave a slit above them, open to the outside.
        for name, (slab, boxes, _turn) in self.of_slot('ceiling').items():
            x, t, z = (s / 2 for s in slab.size)
            flush = [box for box in boxes if abs(box.low()[1] + t) < 1e-6]
            ring = kit.BORDER if kit.is_passage(slab) else kit.BORDER + 0.2
            for u in samples(-x, x):
                for v in samples(-z, z):
                    if x - abs(u) < ring - 1e-6 or z - abs(v) < ring - 1e-6:
                        self.assertTrue(covers(flush, (0, 2), (u, v)), '%s: slit at %s' % (name, (u, v)))
            self.assertTrue(any(box.low()[1] > -t + 1e-6 for box in boxes), name + ' has recessed bays')

    def test_floors_are_colour_only(self):
        # Relief in a floor would separate what is seen from what the collision supports.
        for name, (slab, boxes, _turn) in self.of_slot('floor').items():
            for box in boxes:
                self.assertAlmostEqual(box.size[1], slab.size[1], 6, name)
                self.assertAlmostEqual(box.centre[1], 0.0, 6, name)

    def test_relief_stays_inside_the_slab_and_leaves_a_back(self):
        for name, (slab, boxes, turn) in self.of_slot('wall').items():
            depth = local_size(slab, turn)[0]
            back = [box for box in boxes if abs(box.low()[0] + depth / 2) < 1e-6]
            self.assertTrue(all(box.size[0] >= depth - kit.RELIEF - 1e-6 for box in back), name)
            self.assertAlmostEqual(depth - kit.RELIEF, 0.10, 6)

    def test_gold_stays_above_door_head_height(self):
        # Against gold the Jaffa and the red and magenta markers are near 1:1.
        for name, (slab, boxes, _turn) in self.pieces.items():
            for box in boxes:
                if box.material == 'gold':
                    self.assertGreaterEqual(slab.position[1] + box.low()[1], kit.FRIEZE_BASE - 1e-6,
                                            '%s/%s' % (name, box.name))

    def test_gold_is_an_accent_on_walls(self):
        for name, (slab, boxes, turn) in self.of_slot('wall').items():
            size = local_size(slab, turn)
            gold = sum(box.size[1] * box.size[2] for box in boxes if box.material == 'gold')
            self.assertLessEqual(gold / (size[1] * size[2]), 0.15, name)
            self.assertGreater(gold, 0, name)

    def test_wall_rhythm(self):
        slab, boxes, _turn = self.pieces['room01_Wall2']
        ribs = sorted(box.centre[2] for box in boxes if box.name.startswith('Rib'))
        self.assertEqual(ribs, [-3.0, -1.0, 1.0, 3.0], 'A 2 m grid from the module centre')
        for name in ('room04_Wall2', 'room04_Wall7'):
            kinds = sorted(box.name.rstrip('0123456789') for box in self.pieces[name][1]
                           if box.name.startswith(('Rib', 'Pier', 'Jamb')))
            self.assertEqual(kinds, ['Jamb', 'Pier'], name)

    def test_palette_keeps_play_readable(self):
        colour = {name: values[0] for name, values in kit.PALETTE.items()}
        # Dark below the frieze; only gold and props are light.
        for name in ('basalt', 'bronze', 'floor_margin', 'floor_runner', 'ceiling', 'portal'):
            self.assertLessEqual(luminance(colour[name]), 0.05, name)
        # Cover is the light shape at floor level.
        for surface in ('floor_margin', 'floor_runner', 'basalt'):
            self.assertGreaterEqual(contrast(colour['prop'], colour[surface]), 2.5, surface)
        # The Jaffa (JaffaGuard.tscn) and the awareness markers (JaffaAI.gd) against the walls.
        seen = {'jaffa': (0.68, 0.52, 0.22), 'suspicious': (1.0, 0.85, 0.2),
                'alerted': (1.0, 0.25, 0.15), 'alarm runner': (1.0, 0.2, 0.75)}
        for name, value in seen.items():
            self.assertGreaterEqual(contrast(value, colour['basalt']), 4.0, name)
            self.assertGreaterEqual(contrast(value, colour['bronze']), 3.0, name)
        # Nothing is metallic: without reflections a metallic surface loses its colour.
        self.assertTrue(all(values[1] == 0.0 for values in kit.PALETTE.values()))

    def test_jaffa_armour_is_not_metallic(self):
        # Decision D-015: with nothing to reflect, metallic armour rendered dark olive and
        # measured 1.1 to 1.3:1 against these walls. Matte, it measures about 5:1.
        for scene in ('JaffaGuard.tscn', 'JaffaShockGuard.tscn'):
            text = (kit.CLIENT / 'scenes/entities' / scene).read_text()
            values = [float(line.split('=')[1]) for line in text.splitlines() if line.startswith('metallic')]
            self.assertTrue(values and all(value == 0.0 for value in values), scene)

    def test_slot_names_are_the_resolvers(self):
        source = (kit.CLIENT / 'scripts/level/LevelThemeResolver.gd').read_text()
        line = next(text for text in source.splitlines() if text.startswith('const SLOTS'))
        for slot in kit.SLOT_MATERIALS:
            self.assertIn('"%s"' % slot, line)


if __name__ == '__main__':
    unittest.main()
