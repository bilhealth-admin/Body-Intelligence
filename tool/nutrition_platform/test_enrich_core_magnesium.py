from contextlib import closing
import hashlib
from pathlib import Path
import sqlite3
import tempfile
import unittest
import zipfile

from enrich_core_magnesium import enrich


class MagnesiumEnrichmentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog = self.root / 'original.sqlite'
        with closing(sqlite3.connect(self.catalog)) as db:
            db.executescript("""
                CREATE TABLE foods(fdc_id INTEGER,description TEXT,source_dataset TEXT,energy_kcal REAL);
                INSERT INTO foods VALUES(1,'Tomato','sr_legacy',18),(2,'Unknown','sr_legacy',42);
                CREATE TABLE catalog_metadata(key TEXT PRIMARY KEY,value TEXT);
                INSERT INTO catalog_metadata VALUES('catalog_version','old');
            """)
        self.archive = self.root / 'source.zip'
        self.write_archive()
        self.manifest = {
            'base_catalog_sha256': self.sha(self.catalog), 'version': 'test-v2',
            'sources': [{'dataset': 'sr_legacy', 'file': 'source.zip',
                         'sha256': self.sha(self.archive), 'bytes': self.archive.stat().st_size}],
        }

    def sha(self, path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def write_archive(self, name='Tomato', amount='0', extra=''):
        with zipfile.ZipFile(self.archive, 'w') as archive:
            archive.writestr('food.csv', f'fdc_id,description\n1,{name}\n2,Unknown\n')
            archive.writestr('food_nutrient.csv',
                             f'fdc_id,nutrient_id,amount\n1,1090,{amount}\n' + extra)

    def build(self):
        return enrich(self.catalog, self.root, self.root / 'result.sqlite', self.manifest)

    def refresh_archive_pin(self):
        self.manifest['sources'][0].update(
            sha256=self.sha(self.archive), bytes=self.archive.stat().st_size)

    def test_known_zero_and_missing_remain_distinct_without_changing_original(self):
        before = self.catalog.read_bytes()
        proof = self.build()
        self.assertEqual(self.catalog.read_bytes(), before)
        self.assertEqual(proof['magnesium_rows'], 1)
        with closing(sqlite3.connect(self.root / 'result.sqlite')) as db:
            self.assertEqual(db.execute('SELECT energy_kcal,magnesium_mg FROM foods ORDER BY fdc_id').fetchall(),
                             [(18, 0), (42, None)])

    def test_different_food_name_at_same_identifier_is_rejected(self):
        self.write_archive(name='Unrelated food')
        self.refresh_archive_pin()
        with self.assertRaisesRegex(ValueError, 'identity mismatch'):
            self.build()
        self.assertFalse((self.root / 'result.sqlite').exists())

    def test_conflicting_or_nonfinite_measurements_are_rejected(self):
        for amount, extra in [('NaN', ''), ('11', '1,1090,22\n')]:
            with self.subTest(amount=amount):
                self.write_archive(amount=amount, extra=extra)
                self.refresh_archive_pin()
                with self.assertRaises(ValueError):
                    self.build()

    def test_changed_archive_or_catalog_fails_closed(self):
        self.write_archive(amount='99')
        with self.assertRaisesRegex(ValueError, 'archive fingerprint mismatch'):
            self.build()
        self.refresh_archive_pin()
        self.manifest['base_catalog_sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'catalog fingerprint mismatch'):
            self.build()

    def test_output_cannot_replace_existing_input_or_other_file(self):
        with self.assertRaisesRegex(ValueError, 'new file'):
            enrich(self.catalog, self.root, self.catalog, self.manifest)
        output = self.root / 'result.sqlite'
        output.write_bytes(b'preserve')
        with self.assertRaisesRegex(ValueError, 'new file'):
            self.build()
        self.assertEqual(output.read_bytes(), b'preserve')


if __name__ == '__main__':
    unittest.main()
