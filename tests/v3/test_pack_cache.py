import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

spec = importlib.util.spec_from_file_location('pack_cache', Path(__file__).parents[2] / 'bin/pack_cache.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackCacheTests(unittest.TestCase):
    def test_merge_and_reject_duplicate_leaf(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = []
            for name in ('a', 'b'):
                path = root / f'{name}.zip'
                with zipfile.ZipFile(path, 'w') as archive:
                    archive.writestr('genotypes.zarr/zarr.json', json.dumps({'node_type': 'group'}))
                    archive.writestr(f'genotypes.zarr/set/1/{name}/zarr.json', '{}')
                    archive.writestr(f'genotypes.zarr/set/1/{name}/genotypes/c/0', b'genotypes')
                inputs.append(path)
            module.pack(root / 'merged.zip', inputs)
            with zipfile.ZipFile(root / 'merged.zip') as archive:
                self.assertEqual(len(archive.namelist()), 5)
            with self.assertRaisesRegex(ValueError, 'Duplicate cache leaf'):
                module.pack(root / 'duplicate.zip', inputs + [inputs[0]])

    def test_reject_inconsistent_ancestor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = []
            for value in (1, 2):
                path = root / f'{value}.zip'
                with zipfile.ZipFile(path, 'w') as archive:
                    archive.writestr('genotypes.zarr/zarr.json', json.dumps({'value': value}))
                inputs.append(path)
            with self.assertRaisesRegex(ValueError, 'inconsistent metadata'):
                module.pack(root / 'bad.zip', inputs)


if __name__ == '__main__':
    unittest.main()
