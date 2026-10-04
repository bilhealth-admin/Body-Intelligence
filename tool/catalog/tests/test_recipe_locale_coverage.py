import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

path = Path(__file__).parents[1] / 'audit_recipe_locale_coverage.py'
spec = importlib.util.spec_from_file_location('recipe_locale_audit', path)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def sample():
    value = {'title': 'Example recipe', 'ingredients': ['100 g lentils'],
             'steps': ['Prepare the specified ingredient.'],
             'translationStatus': 'machine-translated'}
    record = {'canonicalId': 'fixture', 'contentFingerprint': 'example',
              'primaryLocale': 'en', 'ingredients': [{}], 'method': [{}],
              'localizations': {locale: copy.deepcopy(value) for locale in audit.LOCALES}}
    entry = {'canonical_id': 'fixture', 'content_fingerprint': 'example',
             'localized_titles': {locale: value['title'] for locale in audit.LOCALES}}
    return record, entry


class CoverageTests(unittest.TestCase):
    def test_exact_25_including_language_variants(self):
        self.assertEqual(len(audit.LOCALES), 25)
        self.assertEqual(len(set(audit.LOCALES)), 25)
        self.assertTrue({'pt-BR', 'pt-PT', 'zh-Hans', 'zh-Hant'}.issubset(audit.LOCALES))

    def test_complete_shape_is_accepted_without_claiming_accuracy(self):
        audit.validate_record(*sample())

    def test_missing_any_of_25_locales_is_rejected(self):
        for locale in audit.LOCALES:
            with self.subTest(locale=locale):
                record, entry = sample()
                del record['localizations'][locale]
                with self.assertRaises(ValueError):
                    audit.validate_record(record, entry)

    def test_empty_title_ingredient_step_or_status_is_rejected(self):
        for locale in audit.LOCALES:
            for key in ['title', 'ingredients', 'steps', 'translationStatus']:
                with self.subTest(locale=locale, key=key):
                    record, entry = sample()
                    record['localizations'][locale][key] = ''
                    with self.assertRaises(ValueError):
                        audit.validate_record(record, entry)

    def test_wrong_ingredient_or_step_count_is_rejected(self):
        for key in ['ingredients', 'steps']:
            record, entry = sample()
            record['localizations']['ar'][key].append('Unexpected extra item')
            with self.assertRaises(ValueError):
                audit.validate_record(record, entry)

    def test_stale_index_title_is_rejected(self):
        record, entry = sample()
        entry['localized_titles']['ar'] = 'Stale'
        with self.assertRaises(ValueError):
            audit.validate_record(record, entry)

    def test_fingerprint_mismatch_is_rejected(self):
        record, entry = sample()
        entry['content_fingerprint'] = 'changed'
        with self.assertRaises(ValueError):
            audit.validate_record(record, entry)

    def test_duplicate_json_key_is_rejected(self):
        with self.assertRaises(ValueError):
            json.loads('{"ar": 1, "ar": 2}', object_pairs_hook=audit._object)

    def test_hash_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'data.json').write_text('{}')
            with self.assertRaises(ValueError):
                audit._read(root, 'data.json', 2, '0' * 64)

    def test_path_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):
                audit._read(Path(temp), '../outside.json')


if __name__ == '__main__':
    unittest.main()
