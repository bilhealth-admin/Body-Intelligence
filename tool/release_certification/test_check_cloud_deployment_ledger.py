import copy
import hashlib
from pathlib import Path
import tempfile
import unittest

from check_cloud_deployment_ledger import validate


class DeploymentLedgerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / '001_initial.sql').write_bytes(b'select 1;\r\n')
        self.remote = [{'version': '20261018', 'name': 'initial', 'statements_md5': 'a' * 32}]
        self.policy = {'deployed_ledger': copy.deepcopy(self.remote),
                       'local_sql_sha256_lf': {'001_initial.sql': hashlib.sha256(b'select 1;\n').hexdigest()},
                       'scope': 'ledger only'}

    def test_historical_timestamp_alias_and_windows_newlines(self):
        result = validate(self.policy, {'rows': self.remote}, self.root)
        self.assertEqual(result['status'], 'PASS')
        self.assertFalse(result['runtime_verified'])

    def test_changed_remote_sql_rejected(self):
        self.remote[0]['statements_md5'] = 'b' * 32
        with self.assertRaisesRegex(ValueError, 'Deployed'):
            validate(self.policy, self.remote, self.root)

    def test_unknown_or_deleted_remote_migration_rejected(self):
        for rows in ([], self.remote + [{'version': '20261019', 'name': 'extra', 'statements_md5': 'c' * 32}]):
            with self.assertRaises(ValueError):
                validate(self.policy, rows, self.root)

    def test_modified_or_added_local_sql_rejected(self):
        (self.root / '001_initial.sql').write_text('select 2;\n')
        with self.assertRaisesRegex(ValueError, 'Local'):
            validate(self.policy, self.remote, self.root)

    def test_duplicate_remote_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            validate(self.policy, self.remote * 2, self.root)


if __name__ == '__main__':
    unittest.main()
