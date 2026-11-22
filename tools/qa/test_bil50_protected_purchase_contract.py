"""Current purchase source byte, context, and live Crystal routing regressions."""
from pathlib import Path
import subprocess
import tempfile
import unittest

import bil49_protected_purchase_contract as old
import bil50_protected_purchase_contract as gate
from bil_purchase_historical_fixture import historical_workflow

ROOT = Path(__file__).resolve().parents[2]


def push(head):
    return dict(BIL_PURCHASE_EVENT_NAME='push', BIL_PURCHASE_SOURCE_BRANCH=gate.SOURCE_BRANCH,
                BIL_PURCHASE_SOURCE_SHA=head, BIL_PURCHASE_EVENT_SHA=head,
                BIL_PURCHASE_REF='refs/heads/' + gate.SOURCE_BRANCH, BIL_PURCHASE_REF_NAME=gate.SOURCE_BRANCH)


class CurrentPurchaseSourceTests(unittest.TestCase):
    def test_actual_current_working_files_have_independently_fixed_blobs(self):
        self.assertEqual(dict(gate.PROTECTED50), {
            gate.STORE: 'f8f6dcec3f8779eb5e7de0fc9e8e29526d5c01dd',
            gate.PRESS: '653d424ddb6cca8adeb0d394f5c8f8866da3792d',
        })
        gate.validate_observed({path: gate.git(ROOT, 'hash-object', path) for path in gate.PROTECTED50})
        with self.assertRaises(ValueError):
            old.validate_observed(dict(gate.PROTECTED50))

    def test_missing_extra_legacy_and_mutated_entries_fail(self):
        for path in gate.PROTECTED50:
            for value in ('0' * 40, '', None, True):
                with self.subTest(path=path, value=value), self.assertRaises(ValueError):
                    gate.validate_observed({**gate.PROTECTED50, path: value})
            with self.subTest(missing=path), self.assertRaises(ValueError):
                gate.validate_observed({p: h for p, h in gate.PROTECTED50.items() if p != path})
        for bad in (dict(old.PROTECTED49), {**gate.PROTECTED50, 'unexpected': '0' * 40}):
            with self.assertRaises(ValueError):
                gate.validate_observed(bad)
        with self.assertRaises(TypeError):
            gate.PROTECTED50[gate.STORE] = old.PROTECTED49[gate.STORE]

    def test_current_crystal_routes_only_the_current_guard_and_keeps_old_guards(self):
        actual = (ROOT / '.github/workflows/bil39-crystal.yml').read_text('utf-8')
        prior = historical_workflow(49)
        old_step = 'python3 tools/qa/bil49_protected_purchase_contract.py'
        new_step = 'python3 tools/qa/bil50_protected_purchase_contract.py'
        self.assertEqual(prior.count(old_step), 1)
        self.assertEqual(actual.count(new_step), 1)
        route = 'elif [[ "$BIL_PURCHASE_SOURCE_BRANCH" == "' + gate.SOURCE_BRANCH + '" ]]; then'
        self.assertIn(route + '\n            ' + new_step, actual)
        # The current source-protection block must retain both prior version routes,
        # the exact context expressions and both fallback literal guards.
        def block(workflow):
            start = workflow.index('      - name: Protect versioned purchase CTA')
            end = workflow.index('      - name: Check scoped Dart formatting', start)
            return workflow[start:end]
        self.assertEqual(block(actual), block(prior).replace(old_step, new_step))

    def test_real_git_context_tree_and_working_checkout(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'core.hooksPath=disabled-test-hooks', '-C', str(root), *args],
                                               text=True).strip()
            def commit():
                git('-c', 'user.name=Purchase QA', '-c', 'user.email=qa@localhost',
                    '-c', 'commit.gpgSign=false', 'commit', '-qm', 'owned fixture')
                return git('rev-parse', 'HEAD')
            git('init', '-q')
            git('config', 'core.autocrlf', 'false')
            for path in gate.PROTECTED50:
                file = root / path
                file.parent.mkdir(parents=True, exist_ok=True)
                # Use tracked canonical bytes so a Windows checkout may use its configured EOL.
                file.write_bytes(subprocess.check_output(['git', '-C', str(ROOT), 'cat-file', 'blob', 'HEAD:' + path]))
            git('add', '.')
            head = commit()
            receipt = gate.verify50(root, push(head))
            self.assertEqual(receipt['source_sha'], head)
            self.assertEqual(receipt['status'], 'VERSION50_PROTECTED_SOURCE_ONLY_PASS')
            self.assertEqual(receipt['protected_blobs'], dict(gate.PROTECTED50))
            self.assertIs(receipt['signing_approved'], False)
            self.assertIs(receipt['store_submission_approved'], False)
            for change in ({'BIL_PURCHASE_EVENT_NAME': 'pull_request_target'},
                           {'BIL_PURCHASE_SOURCE_BRANCH': 'main'}, {'BIL_PURCHASE_REF': 'refs/heads/main'},
                           {'BIL_PURCHASE_SOURCE_SHA': '0' * 40}, {'BIL_PURCHASE_SOURCE_SHA': '0' * 40,
                            'BIL_PURCHASE_EVENT_SHA': '0' * 40}):
                with self.subTest(change=change), self.assertRaises(ValueError):
                    gate.verify50(root, {**push(head), **change})
            marker = root / 'untracked'
            marker.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'checkout changed'):
                gate.verify50(root, push(head))
            marker.unlink()
            for path in gate.PROTECTED50:
                with self.subTest(dirty_path=path):
                    clean_head = git('rev-parse', 'HEAD')
                    target = root / path
                    original = target.read_bytes()
                    target.write_bytes(original + b'changed')
                    with self.assertRaisesRegex(ValueError, 'checkout changed'):
                        gate.verify50(root, push(clean_head))
                    target.write_bytes(original)
                for absent in (False, True):
                    with self.subTest(path=path, absent=absent):
                        if absent:
                            target.unlink()
                        else:
                            target.write_bytes(original + b'changed')
                        git('add', '--', path)
                        changed_head = commit()
                        with self.assertRaisesRegex(ValueError, 'protected path|tree entry'):
                            gate.verify50(root, push(changed_head))
                        git('checkout', head, '--', path)
                        commit()


if __name__ == '__main__':
    unittest.main()
