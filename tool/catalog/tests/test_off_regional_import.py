import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest

path = Path(__file__).parents[1] / 'off_regional_import.py'
spec = importlib.util.spec_from_file_location('off_import', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def sample():
    return {'code': '3017624010701', 'product_name': 'Fixture', 'product_name_ar': 'اختبار',
            'product_type': 'food', 'countries_tags': ['en:iraq'], 'quantity': '100 g',
            'last_modified_t': 1,
            'nutriments': {'energy-kcal_100g': 200, 'proteins_100g': 10,
                          'carbohydrates_100g': 20, 'fat_100g': 8}}


class ImportTests(unittest.TestCase):
    def test_all_gtin_forms_same_identity(self):
        self.assertEqual(module.gtin('036000291452'), module.gtin('0036000291452'))
        self.assertIsNone(module.gtin('3017624010702'))
        self.assertIsNone(module.gtin('00000000'))

    def test_preserves_source_and_unverified_flag(self):
        p, status = module.normalize(sample())
        self.assertEqual(status, 'accepted_for_review')
        self.assertFalse(p['verified'])
        self.assertEqual(p['license'], 'ODbL-1.0')
        self.assertEqual(p['names']['ar'], 'اختبار')
        self.assertIsNone(p['nutrients']['potassium'])

    def test_missing_core_is_quarantined(self):
        p = sample()
        del p['nutriments']['proteins_100g']
        self.assertEqual(module.normalize(p)[1], 'incomplete_core')

    def test_mass_volume_never_assumed_equal(self):
        for quantity in ('500 ml', '1 l', '200 مل'):
            p = sample()
            p['quantity'] = quantity
            self.assertEqual(module.normalize(p)[1], 'volume_basis_needs_review')

    def test_kj_conversion(self):
        p = sample()
        del p['nutriments']['energy-kcal_100g']
        p['nutriments']['energy-kj_100g'] = 418.4
        self.assertAlmostEqual(module.normalize(p)[0]['nutrients']['calories'], 100)

    def test_bad_nutrient_never_becomes_zero(self):
        for value in (True, '', -1, float('nan'), 'infinity'):
            self.assertIsNone(module.amount(value))
        self.assertEqual(module.amount(0), 0)

    def test_non_food_and_wrong_market_rejected(self):
        p = sample()
        p['product_type'] = 'beauty'
        self.assertEqual(module.normalize(p)[1], 'non_food')
        p = sample()
        p['countries_tags'] = ['en:france']
        self.assertEqual(module.normalize(p)[1], 'outside_target_markets')

    def test_implausible_values_quarantined(self):
        p = sample()
        p['nutriments']['proteins_100g'] = 1000
        self.assertEqual(module.normalize(p)[1], 'implausible_core')

    def test_build_separate_pack_deduplicates_and_preserves_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            second = sample()
            second['code'] = '03017624010701'
            report = module.build_catalog(iter([sample(), second]), output)
            self.assertEqual(report['unique_products'], 1)
            self.assertEqual(report['nutrition_complete_mass_basis_products'], 1)
            self.assertEqual(report['barcode_forms'], 2)
            self.assertFalse(report['published_to_app'])
            with sqlite3.connect(output / 'off-iraq-jordan-review.sqlite') as db:
                self.assertLess(db.execute('SELECT quality_score FROM food').fetchone()[0], 75)
                self.assertEqual(db.execute("SELECT count(*) FROM food_fts WHERE food_fts MATCH 'اختبار'").fetchone()[0], 1)
                self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
            self.assertTrue((output / 'LICENSE-AND-ATTRIBUTION.txt').exists())
            with self.assertRaises(ValueError):
                module.build_catalog([], output)


if __name__ == '__main__':
    unittest.main()
