import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('check_samples', Path(__file__).parents[2] / 'bin/check_samples.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class EmptyShardTests(unittest.TestCase):
    def test_irrelevant_shard_and_required_samples(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, samples in [('kept', ['a']), ('empty', ['a'])]:
                (root / name).mkdir()
                (root / name / 'samples.json').write_text(json.dumps({'shard': name, 'samples': samples}))
            (root / 'kept/genotypes.zarr.zip').touch()
            module.check_samples([root / 'kept', root / 'empty'])
            (root / 'empty/samples.json').write_text(json.dumps({'shard': 'empty', 'samples': ['b']}))
            with self.assertRaisesRegex(ValueError, 'remove 1 required samples'):
                module.check_samples([root / 'kept', root / 'empty'])
            with self.assertRaisesRegex(ValueError, 'No usable genotype caches'):
                module.check_samples([root / 'empty'])


if __name__ == '__main__':
    unittest.main()
