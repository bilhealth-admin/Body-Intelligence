"""Execute coverage verification against real isolated files and receipts."""
import copy
import hashlib
from collections import Counter
from unittest import mock
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


    def test_runtime_coverage_rejects_old_stride_even_with_matching_execution_keys(self):
        names = sorted(self.files)
        plans = [full.plan(self.files, sha=SHA, index=i, total=8) for i in range(8)]
        index = next((i for i in range(8) if plans[i]['files'] != names[i::8]), None)
        self.assertIsNotNone(index, 'The varied-length fixture must exercise runtime membership')
        selected = names[index::8]
        forged = dict(plans[index], files=selected,
                      selected_hashes={name: self.files[name] for name in selected})
        (self.artifacts / str(index) / 'plan.json').write_text(json.dumps(forged), encoding='utf-8')
        self.write_receipt(index, files={name: {'success': 1} for name in selected})
        with self.assertRaisesRegex(ValueError, 'partition differs'):
            self.check()

    def test_runtime_coverage_rejects_a_selected_source_hash_substitution(self):
        path = self.artifacts / '0/plan.json'
        plan = json.loads(path.read_text())
        plan['selected_hashes'][plan['files'][0]] = '0' * 64
        path.write_text(json.dumps(plan), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'partition differs'):
            self.check()

    def test_runtime_membership_cannot_replace_a_missing_execution_receipt(self):
        (self.artifacts / '4/receipt.json').unlink()
        with self.assertRaises((ValueError, OSError)):
            self.check()

class RuntimeHistoryAndLptTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.history_bytes = full.RUNTIME_HISTORY_PATH.read_bytes()
        cls.document = json.loads(cls.history_bytes)

    def assert_history_rejected(self, mutate):
        document = copy.deepcopy(self.document)
        mutate(document)
        with self.assertRaises(ValueError):
            full._validate_runtime_history(document)

    def test_reviewed_history_preserves_failed_cancelled_and_unobserved_provenance(self):
        self.assertEqual(hashlib.sha256(self.history_bytes).hexdigest(), full.RUNTIME_HISTORY_SHA256)
        self.assertEqual(self.document['qualification'], 'HISTORICAL_FAILED_CANCELLED_SCHEDULING_ONLY')
        self.assertEqual(self.document['provenance']['source_sha'], '6f10400b09f709048491f413ab8a3caf4135ab29')
        self.assertEqual(self.document['provenance']['run_id'], 44478006427)
        self.assertEqual(self.document['provenance']['source_data_sha256'],
                         '00f061e128a28b9f58da46346ba3653e8dd7cbaa8a5ce7b05f266a71be6b7527')
        validated = full._load_runtime_history()
        self.assertEqual(len(validated['records']), 1646)
        self.assertEqual(validated['default_ms'], 60000)
        self.assertEqual(Counter(row['observation_class'] for row in validated['records'].values()), {
            'complete_file_in_closed_shard': 1440,
            'closed_started_tests_in_cancelled_shard': 160,
            'censored_active_file': 1,
            'not_started': 45,
        })
        cancelled = [part for part in self.document['provenance']['artifacts'] if part['outcome'] == 'CANCELLED']
        self.assertEqual(len(cancelled), 1)
        self.assertFalse(cancelled[0]['receipt_present'])
        self.assertFalse(cancelled[0]['protocol_done'])
        self.assertEqual(cancelled[0]['planned_files'] - cancelled[0]['started_files'], 45)

    def test_history_cannot_relabel_incomplete_work_as_a_qualifying_pass(self):
        mutations = [
            lambda d: d.__setitem__('qualification', 'PASS'),
            lambda d: d.__setitem__('schema', 'unknown'),
            lambda d: d.__setitem__('extra_unreviewed', True),
            lambda d: d['provenance']['artifacts'][0].__setitem__('outcome', 'PASS'),
            lambda d: d['provenance']['artifacts'][0].__setitem__('outcome', []),
            lambda d: d['provenance']['artifacts'][3].__setitem__('receipt_present', True),
            lambda d: d['provenance']['artifacts'][3].__setitem__('protocol_done', True),
            lambda d: d['provenance']['artifacts'][0].__setitem__('started_files', 205),
            lambda d: d['provenance']['artifacts'].pop(),
            lambda d: d['provenance']['artifacts'][1].__setitem__('index', 0),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(mutation=index):
                self.assert_history_rejected(mutate)

    def test_history_rejects_bad_source_run_environment_and_artifact_provenance(self):
        mutations = [
            lambda d: d['provenance'].__setitem__('source_sha', 'g' * 40),
            lambda d: d['provenance'].__setitem__('controller_sha', 'a' * 39),
            lambda d: d['provenance'].__setitem__('run_id', True),
            lambda d: d['provenance'].__setitem__('run_id', 0),
            lambda d: d['provenance'].__setitem__('source_data_sha256', 'not-a-hash'),
            lambda d: d['provenance'].__setitem__('inventory_sha256', '0' * 64),
            lambda d: d['provenance']['environment'].__setitem__('platform', 'ubuntu-latest'),
            lambda d: d['provenance']['environment'].__setitem__('suite_concurrency', 2),
            lambda d: d['provenance']['environment'].__setitem__('jobs', 7),
            lambda d: d['provenance']['environment'].__setitem__('flutter', 'unstable'),
            lambda d: d['provenance']['artifacts'][0].__setitem__('archive_sha256', 'x' * 64),
            lambda d: d['provenance']['artifacts'][0].__setitem__('plan_sha256', ''),
            lambda d: d['provenance']['artifacts'][0].__setitem__('index', False),
            lambda d: d['provenance']['artifacts'][1].__setitem__('archive_sha256', d['provenance']['artifacts'][0]['archive_sha256']),
            lambda d: d['provenance']['artifacts'][1].__setitem__('plan_sha256', d['provenance']['artifacts'][0]['plan_sha256']),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(mutation=index):
                self.assert_history_rejected(mutate)

    def test_history_rejects_duplicate_colliding_and_noncanonical_paths(self):
        self.assert_history_rejected(lambda d: d['files'].append(copy.deepcopy(d['files'][0])))
        def collide(document):
            first = document['files'][0]['path']
            document['files'][1]['path'] = first[:5] + first[5].swapcase() + first[6:]
        self.assert_history_rejected(collide)
        for path in ['../test/a_test.dart', '/test/a_test.dart', 'test/../a_test.dart',
                     'test//a_test.dart', 'test/x/./a_test.dart', 'test/x\\a_test.dart',
                     'test/a\n_test.dart', 'test/not_a_suite.dart']:
            with self.subTest(path=path):
                self.assert_history_rejected(lambda d, path=path: d['files'][0].__setitem__('path', path))
        self.assert_history_rejected(lambda d: d['files'][0].__setitem__('source_sha256', '0' * 63))
        self.assert_history_rejected(lambda d: d.__setitem__('files', []))

    def test_history_rejects_malformed_or_reclassified_duration_observations(self):
        def change_kind(document, kind, field, value):
            row = next(row for row in document['files'] if row['observation_class'] == kind)
            row[field] = value
        for value in [-1, 1.5, float('nan'), float('inf'), True, None]:
            for kind, field in [('complete_file_in_closed_shard', 'elapsed_ms'),
                                ('closed_started_tests_in_cancelled_shard', 'elapsed_ms'),
                                ('censored_active_file', 'elapsed_lower_bound_ms')]:
                with self.subTest(kind=kind, value=value):
                    self.assert_history_rejected(lambda d, k=kind, f=field, v=value: change_kind(d, k, f, v))
        for kind, field, value in [
                ('not_started', 'elapsed_ms', 1),
                ('complete_file_in_closed_shard', 'elapsed_lower_bound_ms', 1),
                ('censored_active_file', 'elapsed_ms', 1),
                ('closed_started_tests_in_cancelled_shard', 'observation_class', 'complete_file_in_closed_shard'),
                ('complete_file_in_closed_shard', 'part', 3),
                ('not_started', 'observation_class', 'unknown'),
                ('not_started', 'observation_class', [])]:
            with self.subTest(kind=kind, field=field):
                self.assert_history_rejected(lambda d, k=kind, f=field, v=value: change_kind(d, k, f, v))

    def test_default_uses_nearest_rank_p95_without_undercounting_the_boundary(self):
        document = copy.deepcopy(self.document)
        completed = [row for row in document['files'] if row['observation_class'] == 'complete_file_in_closed_shard']
        self.assertEqual(len(completed), 1440)
        for row in completed:
            row['elapsed_ms'] = 1000
        for row in completed[-72:]:
            row['elapsed_ms'] = 100000
        self.assertEqual(full._validate_runtime_history(document)['default_ms'], 60000)
        completed[-73]['elapsed_ms'] = 100000
        self.assertEqual(full._validate_runtime_history(document)['default_ms'], 200000)

    def test_weights_keep_censored_changed_and_new_files_conservative(self):
        kinds = [
            ('complete', 'complete_file_in_closed_shard', 2000, None),
            ('zero', 'complete_file_in_closed_shard', 0, None),
            ('unchanged_heavy', 'complete_file_in_closed_shard', 2800000, None),
            ('partial', 'closed_started_tests_in_cancelled_shard', 40000, None),
            ('censored', 'censored_active_file', None, 90000),
            ('unstarted', 'not_started', None, None),
            ('changed_heavy', 'complete_file_in_closed_shard', 2800000, None),
            ('changed_small', 'complete_file_in_closed_shard', 2000, None),
            ('changed_partial', 'closed_started_tests_in_cancelled_shard', 1200000, None),
            ('changed_censored', 'censored_active_file', None, 2800000),
        ]
        records = {'test/' + label + '_test.dart': {
            'path': 'test/' + label + '_test.dart', 'source_sha256': 'a' * 64,
            'part': 0, 'observation_class': kind, 'elapsed_ms': elapsed,
            'elapsed_lower_bound_ms': lower,
        } for label, kind, elapsed, lower in kinds}
        files = {name: 'a' * 64 for name in records}
        for label, _, _, _ in kinds:
            if label.startswith('changed_'):
                files['test/' + label + '_test.dart'] = 'b' * 64
        files['test/new_test.dart'] = 'c' * 64
        self.assertEqual(full._runtime_weights(files, {'records': records, 'default_ms': 60000}), {
            'test/complete_test.dart': 2000, 'test/zero_test.dart': 1,
            'test/unchanged_heavy_test.dart': 2800000,
            'test/partial_test.dart': 80000, 'test/censored_test.dart': 150000,
            'test/unstarted_test.dart': 60000, 'test/changed_heavy_test.dart': 60000,
            'test/changed_small_test.dart': 60000, 'test/changed_partial_test.dart': 60000,
            'test/changed_censored_test.dart': 60000, 'test/new_test.dart': 60000,
        })
        unknown = copy.deepcopy(records['test/complete_test.dart'])
        unknown['observation_class'] = 'not-a-reviewed-class'
        for digest in ('a' * 64, 'b' * 64):
            with self.subTest(source_digest=digest), self.assertRaises(ValueError):
                full._runtime_weights({'test/complete_test.dart': digest},
                                      {'records': {'test/complete_test.dart': unknown}, 'default_ms': 60000})

    def test_corrupt_history_bytes_fail_pin_even_when_json_and_membership_are_identical(self):
        with tempfile.TemporaryDirectory(prefix='bil39-history-pin-') as folder:
            root = Path(folder)
            path = root / 'tools/qa/history.json'
            path.parent.mkdir(parents=True)
            path.write_bytes(self.history_bytes)
            # Only the owned location is redirected; the reviewed SHA pin is never patched.
            with mock.patch.object(full, 'ROOT', root), mock.patch.object(full, 'RUNTIME_HISTORY_PATH', path):
                before = full._load_runtime_history()
                path.write_bytes(self.history_bytes + b'\n')
                self.assertEqual(json.loads(path.read_bytes()), self.document)
                with self.assertRaisesRegex(ValueError, 'reviewed SHA256 pin'):
                    full._load_runtime_history()
                self.assertEqual(len(before['records']), 1646)

    def test_duplicate_json_keys_are_not_silently_overwritten(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            json.loads('{"schema":1,"schema":2}', object_pairs_hook=full._unique_json_object)

    def test_lpt_is_deterministic_under_input_permutations_and_equal_weight_ties(self):
        files = {'test/case_%02d_test.dart' % i: 'a' * 64 for i in range(32)}
        weights = {name: 100 for name in files}
        first = full._lpt_partitions(files, weights, 8)
        reverse = full._lpt_partitions(dict(reversed(list(files.items()))),
                                       dict(reversed(list(weights.items()))), 8)
        self.assertEqual(first, reverse)
        self.assertEqual(Counter(name for part in first for name in part), Counter(files.keys()))
        self.assertTrue(all(part and part == sorted(part) for part in first))
        self.assertEqual([len(part) for part in first], [4] * 8)
        self.assertEqual([part[0] for part in first], sorted(files)[:8])

    def test_a_skewed_indivisible_file_is_isolated_without_skipping_other_files(self):
        files = {'test/case_%02d_test.dart' % i: 'a' * 64 for i in range(32)}
        heavy = sorted(files)[0]
        weights = {name: 1 for name in files}
        weights[heavy] = 1000
        parts = full._lpt_partitions(files, weights, 8)
        self.assertEqual(next(part for part in parts if heavy in part), [heavy])
        self.assertEqual(Counter(name for part in parts for name in part), Counter(files.keys()))
        self.assertEqual(len(parts), 8)
        self.assertTrue(all(parts))
        self.assertEqual(max(sum(weights[name] for name in part) for part in parts), 1000)
        self.assertLessEqual(max(len(part) for part in parts if heavy not in part), 5)

    def test_lpt_rejects_invalid_membership_hash_paths_weights_and_job_counts(self):
        files = {'test/a_test.dart': 'a' * 64, 'test/b_test.dart': 'b' * 64}
        invalid = [
            (files, {'test/a_test.dart': 1}, 2),
            (files, {**{name: 1 for name in files}, 'test/extra_test.dart': 1}, 2),
            (files, {name: 0 for name in files}, 2),
            (files, {name: -1 for name in files}, 2),
            (files, {name: True for name in files}, 2),
            (files, {name: float('nan') for name in files}, 2),
            (files, {name: 1 for name in files}, True),
            (files, {name: 1 for name in files}, 3),
            ({'test/../a_test.dart': 'a' * 64}, {'test/../a_test.dart': 1}, 1),
            ({'test/a_test.dart': 'x' * 64}, {'test/a_test.dart': 1}, 1),
            ({'test/a_test.dart': 'a' * 64, 'test/A_test.dart': 'b' * 64},
             {'test/a_test.dart': 1, 'test/A_test.dart': 1}, 2),
        ]
        for index, args in enumerate(invalid):
            with self.subTest(mutation=index), self.assertRaises(ValueError):
                full._lpt_partitions(*args)

    def test_argv_exact_boundary_is_accepted_but_one_extra_character_fails(self):
        name = 'test/' + 'a' * (26000 - 3 - len('test/_test.dart')) + '_test.dart'
        self.assertEqual(len(name) + 3, 26000)
        self.assertEqual(full._lpt_partitions({name: 'a' * 64}, {name: 1}, 1), [[name]])
        longer = name.replace('test/', 'test/b', 1)
        with self.assertRaisesRegex(ValueError, 'argv budget'):
            full._lpt_partitions({longer: 'a' * 64}, {longer: 1}, 1)

    def test_no_fit_under_argv_budget_fails_instead_of_omitting_a_file(self):
        names = ['test/' + letter * (14000 - 3 - len('test/_test.dart')) + '_test.dart'
                 for letter in 'abc']
        self.assertTrue(all(len(name) + 3 == 14000 for name in names))
        files = {name: 'a' * 64 for name in names}
        with self.assertRaisesRegex(ValueError, 'argv budget'):
            full._lpt_partitions(files, {name: 1 for name in files}, 2)



if __name__ == '__main__':
    unittest.main()
