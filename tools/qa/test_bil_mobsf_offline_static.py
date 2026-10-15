import json
import unittest

from bil_mobsf_offline_static import summarize


class MobSFReportTest(unittest.TestCase):
    def fixture(self):
        return {'package_name': 'com.bilhealth.bodyintelligencelog', 'version_code': '33',
                'manifest_analysis': {'manifest_findings': [{'rule': 'debug', 'severity': 'high',
                                      'description': 'private-synthetic-value'}]},
                'code_analysis': {'findings': {'example-rule': {'metadata': {'severity': 'warning'},
                                  'files': {'Example.java': 5}, 'code': 'private-synthetic-value'}}},
                'permissions': {'android.permission.CAMERA': {'description': 'private-synthetic-value'}},
                'secrets': ['private-synthetic-value']}

    def test_public_metadata_excludes_matched_values(self):
        result = summarize(self.fixture())
        self.assertNotIn('private-synthetic-value', json.dumps(result))
        self.assertFalse(result['internet_enabled_in_scanner'])
        self.assertEqual(result['manifest_findings'][0]['severity'], 'high')
        self.assertEqual(result['code_findings'][0]['affected_files_count'], 1)

    def test_wrong_package_or_build_cannot_be_certified(self):
        for changes in [{'package_name': 'other.app'}, {'version_code': '32'}]:
            with self.assertRaises(ValueError):
                summarize(self.fixture() | changes)

    def test_missing_core_sections_are_not_empty_clean_results(self):
        for key in ['manifest_analysis', 'code_analysis', 'permissions']:
            value = self.fixture()
            del value[key]
            with self.assertRaises(ValueError):
                summarize(value)


if __name__ == '__main__':
    unittest.main()
