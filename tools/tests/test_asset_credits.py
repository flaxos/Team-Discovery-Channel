"""Distribution must retain complete credit coverage and the full original licence texts."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('sync_asset_credits', REPO/'tools/sync_asset_credits.py')
credits = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(credits)


class AssetCredits(unittest.TestCase):
    def fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        repo = Path(temporary.name)
        (repo/'client/assets').mkdir(parents=True)
        (repo/'credits/licenses').mkdir(parents=True)
        (repo/'client/assets/example.glb').write_bytes(b'synthetic coverage fixture')
        (repo/'credits/licenses/CC-BY-4.0.txt').write_text('Exact fixture licence text\n"quoted"\n')
        (repo/'credits/ATTRIBUTIONS.md').write_text(
            '| Asset File | Title | Creator | Source URL | Licence | Use |\n'
            '| `client/assets/example.glb` | Example | Artist | https://example.com/model | '
            '[CC BY 4.0](licenses/CC-BY-4.0.txt) | Visual |\n'
            '- **Modifications:** Repacked without gameplay changes.\n')
        return repo

    def test_all_shipped_models_and_full_licences_are_current(self):
        resource, count = credits.build_credits()
        self.assertGreaterEqual(count, 7)
        self.assertEqual((REPO/credits.OUTPUT).read_text(), resource)
        self.assertIn('Rotuma', resource)
        self.assertIn('CC-BY-4.0.txt', resource)

    def test_uncredited_binary_and_missing_licence_fail(self):
        repo = self.fixture()
        resource, count = credits.build_credits(repo)
        self.assertEqual(count, 1)
        self.assertIn('Exact fixture licence text\\n\\"quoted\\"', resource)
        uncredited = repo/'client/assets/uncredited.glb'
        uncredited.write_bytes(b'fixture')
        with self.assertRaisesRegex(ValueError, 'coverage'):
            credits.build_credits(repo)
        uncredited.unlink()
        (repo/'credits/licenses/CC-BY-4.0.txt').unlink()
        with self.assertRaises(ValueError):
            credits.build_credits(repo)

    def test_source_change_updates_distribution_and_missing_modification_fails(self):
        repo = self.fixture()
        before, _ = credits.build_credits(repo)
        path = repo/'credits/ATTRIBUTIONS.md'
        path.write_text(path.read_text().replace('Artist','Different artist'))
        after, _ = credits.build_credits(repo)
        self.assertNotEqual(before, after)
        self.assertIn('Different artist', after)
        path.write_text(path.read_text().split('- **Modifications:')[0])
        with self.assertRaisesRegex(ValueError, 'modification'):
            credits.build_credits(repo)


if __name__ == '__main__':
    unittest.main()
