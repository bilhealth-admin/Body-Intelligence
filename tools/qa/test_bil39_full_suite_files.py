"""Execute coverage verification against real isolated files and receipts."""
import json
from pathlib import Path
import tempfile
import unittest

import bil39_full_suite_files as full

SHA = 'a' * 40


class FullFilePartitionTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='bil39-file-partition-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name) / 'source'
        self.artifacts = Path(self.folder.name) / 'artifacts'
        for index in range(35):
            path = self.root / 'test' / ('nested' if index % 2 else '') / f'case {index}_test.dart'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'// Independent suite {index}\n', encoding='utf-8')
        (self.root / 'test/not_a_suite.dart').write_text('// Not a test suite')
        self.files = full.inventory(self.root)
        for index in range(8):
            target = self.artifacts / str(index)
            target.mkdir(parents=True)
            (target / 'plan.json').write_text(json.dumps(full.plan(
                self.files, sha=SHA, index=index, total=8)), encoding='utf-8')
            self.write_receipt(index)

    def write_receipt(self, index, **changes):
        selected = full.plan(self.files, sha=SHA, index=index, total=8)['files']
        value = {'source_sha': SHA, 'status': 'PASS', 'process_exit': 0,
                 'protocol_success': True, 'error_events': 0, 'in_progress': [],
                 'unexpected_skips': [], 'counts': {'success': 4, 'failure': 0, 'error': 0},
                 'files': {name: {'success': 1} for name in selected}}
        value.update(changes)
        (self.artifacts / str(index) / 'receipt.json').write_text(json.dumps(value), encoding='utf-8')

    def check(self):
        return full.verify(self.root, self.artifacts, sha=SHA, total=8)

    def test_plan_alone_cannot_prove_missing_or_substituted_actual_test_execution(self):
        selected = full.plan(self.files, sha=SHA, index=0, total=8)['files']
        for files in ({}, {name: {'success': 1} for name in selected[1:]},
                      {**{name: {'success': 1} for name in selected}, 'test/unplanned_test.dart': {'success': 1}}):
            with self.subTest(files=files):
                self.write_receipt(0, files=files)
                with self.assertRaisesRegex(ValueError, 'Actual executed files'):
                    self.check()

    def test_every_real_test_file_is_selected_exactly_once_with_nested_and_space_paths(self):
        self.assertEqual(len(self.files), 35)
        result = self.check()
        self.assertEqual(result['test_files'], 35)
        self.assertEqual(result['counts']['success'], 32)
        self.assertEqual(result['missing_files'], 0)
        self.assertEqual(result['duplicate_files'], 0)
        self.assertEqual(self.check(), result)

    def test_missing_part_cannot_certify_complete_execution(self):
        (self.artifacts / '7/plan.json').unlink()
        with self.assertRaises(ValueError):
            self.check()

    def test_repeated_index_or_added_or_omitted_file_is_rejected(self):
        path = self.artifacts / '1/plan.json'
        original = json.loads(path.read_text())
        mutations = [dict(original, index=0), dict(original, files=original['files'][:-1]),
                     dict(original, files=[*original['files'], 'test/foreign_test.dart'])]
        for value in mutations:
            with self.subTest(value=value):
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    self.check()
        path.write_text(json.dumps(original))

    def test_changed_test_source_after_execution_is_rejected(self):
        (self.root / next(iter(self.files))).write_text('// Changed after test\n')
        with self.assertRaises(ValueError):
            self.check()

    def test_failed_incomplete_wrong_sha_or_unexpected_skip_receipt_is_rejected(self):
        for changes in [dict(source_sha='b' * 40), dict(status='FAIL'), dict(process_exit=1),
                        dict(protocol_success=False), dict(error_events=1),
                        dict(in_progress=[3]), dict(unexpected_skips=[{'name': 'hidden'}]),
                        dict(counts={'success': 0}), dict(counts={'success': 4, 'failure': 1}),
                        dict(counts={'success': 4, 'error': 1})]:
            with self.subTest(changes=changes):
                self.write_receipt(2, **changes)
                with self.assertRaises(ValueError):
                    self.check()
        self.write_receipt(2)

    def test_invalid_index_empty_inventory_or_oversized_argv_is_rejected(self):
        for index, total in [(-1, 8), (8, 8), (0, 0), (0, 64)]:
            with self.subTest(index=index, total=total), self.assertRaises(ValueError):
                full.plan(self.files, sha=SHA, index=index, total=total)
        with self.assertRaises(ValueError):
            full.inventory(self.artifacts)
        with self.assertRaises(ValueError):
            full.plan({'test/' + 'a' * 27000 + '_test.dart': '0' * 64}, sha=SHA, index=0, total=1)

    def test_skip_cannot_be_hidden_by_a_forged_empty_unexpected_skip_list(self):
        self.write_receipt(3, skips=[{'name': 'not reviewed', 'reason': 'ignore'}],
                           counts={'success': 4, 'skip': 1})
        with self.assertRaises(ValueError):
            self.check()


if __name__ == '__main__':
    unittest.main()
