"""Real local ZIP fixtures and metadata negatives; not a GitHub execution claim."""
import hashlib
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
import zipfile

import bil39_full_suite_artifacts as artifact

SHA = 'a' * 40


class LatestShardArtifactsTest(unittest.TestCase):
    def row(self, index, *, identity=100, created='2026-10-27T01:00:00Z'):
        return {'id': identity + index, 'name': f'bil39-full-shard-{index}-{SHA}',
            'created_at': created, 'expired': False, 'size_in_bytes': 1000,
            'digest': 'sha256:' + '0' * 64,
            'workflow_run': {'head_sha': SHA, 'id': 123, 'head_branch': artifact.BRANCH}}

    def test_newer_retry_is_selected_by_time_even_when_its_id_is_lower(self):
        rows = [self.row(index) for index in range(8)]
        old = self.row(1, identity=500, created='2026-10-27T00:00:00Z')
        rows.insert(0, old)
        chosen = artifact.select(rows, sha=SHA, run_id=123, total=8)
        self.assertEqual(len(chosen), 8)
        self.assertEqual(chosen[1]['id'], 101)
        self.assertEqual(chosen[1]['superseded_artifact_ids'], [501])
        self.assertEqual(len(rows), 9, 'Historical metadata must remain intact')

    def test_missing_or_ambiguous_latest_artifact_is_rejected(self):
        rows = [self.row(index) for index in range(8)]
        with self.assertRaises(ValueError):
            artifact.select(rows[:-1], sha=SHA, run_id=123, total=8)
        with self.assertRaises(ValueError):
            artifact.select([*rows, self.row(1, identity=300)], sha=SHA, run_id=123, total=8)

    def test_wrong_source_run_branch_lifetime_size_and_digest_are_rejected(self):
        for field, value in [('expired', True), ('size_in_bytes', artifact.MAX_ZIP + 1),
            ('size_in_bytes', 0), ('id', '../other'), ('digest', None), ('created_at', '2026-10-27')]:
            rows = [self.row(index) for index in range(8)]
            rows[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                artifact.select(rows, sha=SHA, run_id=123, total=8)
        for field, value in [('head_sha', 'b' * 40), ('id', 124), ('head_branch', 'main')]:
            rows = [self.row(index) for index in range(8)]
            rows[0]['workflow_run'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                artifact.select(rows, sha=SHA, run_id=123, total=8)

    def zip_fixture(self, *, names=None, linked=False):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as output:
            for name in names or sorted(artifact.MEMBERS):
                info = zipfile.ZipInfo(name)
                if linked:
                    info.create_system = 3
                    info.external_attr = (stat.S_IFLNK | 0o777) << 16
                output.writestr(info, json.dumps({'fixture': name}))
        return data.getvalue()

    def extract_fixture(self, data, *, expected=None):
        folder = tempfile.TemporaryDirectory(prefix='bil39-artifact-zip-')
        self.addCleanup(folder.cleanup)
        root = Path(folder.name)
        archive = root / 'fixture.zip'
        archive.write_bytes(data)
        digest = expected or 'sha256:' + hashlib.sha256(data).hexdigest()
        artifact.extract(archive, root / 'selected', digest=digest)
        return root / 'selected'

    def test_digest_verified_archive_extracts_exactly_the_three_real_files(self):
        output = self.extract_fixture(self.zip_fixture())
        self.assertEqual({path.name for path in output.iterdir()}, artifact.MEMBERS)
        self.assertEqual(json.loads((output / 'plan.json').read_text())['fixture'], 'plan.json')

    def test_tampered_zip_or_unexpected_member_is_not_accepted(self):
        with self.assertRaises(ValueError):
            self.extract_fixture(self.zip_fixture(), expected='sha256:' + '0' * 64)
        for names in [['../plan.json', 'events.jsonl', 'receipt.json'], ['plan.json', 'receipt.json']]:
            with self.subTest(names=names), self.assertRaises(ValueError):
                self.extract_fixture(self.zip_fixture(names=names))
        with self.assertRaises(ValueError):
            self.extract_fixture(self.zip_fixture(linked=True))


if __name__ == '__main__':
    unittest.main()
