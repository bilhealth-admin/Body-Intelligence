"""Behavioral subprocess tests for fixture discovery and accident isolation."""
import importlib.util
import os
from pathlib import Path
import shutil
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('fixture_inventory', Path(__file__).with_name('bil_security_fixture_inventory.py'))
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


class FixtureInventoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.root = self.base / 'source'
        self.root.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, relative, content):
        file = self.root / relative
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content, encoding='utf-8')
        return file

    def test_discovers_both_test_forms_without_running_live_scripts(self):
        self.write('tool/shared/new_guard.test.mjs', '')
        self.write('tool/release/old_guard_test.mjs', '')
        self.write('tool/release/run_live_e2e.mjs', 'throw Error("must not execute");')
        self.write('supabase/tests/destructive_test.mjs', 'throw Error("separate lane");')
        self.write('tools/qa/native_pg_fixture/node_modules/foreign/foreign.test.mjs', 'throw Error("dependency test");')
        self.assertEqual([p.as_posix() for p in inventory.discover(self.root)],
                         ['tool/release/old_guard_test.mjs', 'tool/shared/new_guard.test.mjs'])

    def test_live_named_test_is_unassigned_failure_not_silent_skip(self):
        self.write('tool/release/backend_live_test.mjs', '')
        with self.assertRaisesRegex(ValueError, 'separate reviewed lane'):
            inventory.discover(self.root)

    @unittest.skipUnless(shutil.which('node'), 'Node must be present')
    def test_actual_child_has_no_secret_cannot_network_or_write_source(self):
        self.write('tool/shared/probe.test.mjs', r'''
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import requireDns from 'node:dns';
import {spawnSync} from 'node:child_process';
assert.equal(process.env.SUPABASE_SERVICE_ROLE_KEY, undefined);
assert.throws(() => fetch('https://attacker.invalid'), /BIL_FIXTURE_NETWORK_DENIED/);
assert.throws(() => net.connect(55479, '127.0.0.1'), /BIL_FIXTURE_NETWORK_DENIED/);
assert.throws(() => requireDns.resolveTxt('attacker.invalid', () => {}), /BIL_FIXTURE_NETWORK_DENIED/);
assert.throws(() => fs.writeFileSync(new URL('./source-mutation.txt', import.meta.url), 'bad'), {code:'ERR_ACCESS_DENIED'});
fs.writeFileSync(path.join(os.tmpdir(), 'permitted-fixture.txt'), 'ok');
const child=spawnSync(process.execPath,['-e',"require('node:net').connect(443,'attacker.invalid')"],{encoding:'utf8'});
assert.notEqual(child.status, 0);
assert.match(child.stderr, /BIL_FIXTURE_NETWORK_DENIED/);
const warning=spawnSync(process.execPath,['-e',"process.emitWarning('real-fixture-security-diagnostic','SecurityWarning')"],{encoding:'utf8'});
assert.match(warning.stderr,/real-fixture-security-diagnostic/);
''')
        old = os.environ.get('SUPABASE_SERVICE_ROLE_KEY')
        os.environ['SUPABASE_SERVICE_ROLE_KEY'] = 'synthetic-must-not-reach-child'
        try:
            result = inventory.run(self.root, self.base / 'evidence', shutil.which('node'),
                guard=Path(__file__).with_name('bil_fixture_network_deny.cjs'))
        finally:
            if old is None:
                os.environ.pop('SUPABASE_SERVICE_ROLE_KEY', None)
            else:
                os.environ['SUPABASE_SERVICE_ROLE_KEY'] = old
        self.assertEqual(result['status'], 'PASS')
        self.assertFalse((self.root / 'tool/shared/source-mutation.txt').exists())

    @unittest.skipUnless(shutil.which('node'), 'Node must be present')
    def test_real_assertion_failure_is_preserved(self):
        self.write('tool/shared/fail.test.mjs', 'import assert from "node:assert/strict"; assert.equal(1,2);')
        result = inventory.run(self.root, self.base / 'evidence', shutil.which('node'),
            guard=Path(__file__).with_name('bil_fixture_network_deny.cjs'))
        self.assertEqual(result['status'], 'FAIL')
        self.assertNotEqual(result['files'][0]['exit_code'], 0)

    @unittest.skipUnless(shutil.which('node'), 'Node must be present')
    def test_real_skipped_case_cannot_be_reported_as_pass(self):
        self.write('tool/shared/skipped.test.mjs', 'import test from "node:test"; test("critical", {skip:true}, () => {});')
        result = inventory.run(self.root, self.base / 'evidence', shutil.which('node'),
            guard=Path(__file__).with_name('bil_fixture_network_deny.cjs'))
        self.assertEqual(result['status'], 'FAIL')
        self.assertEqual(result['files'][0]['counts']['skipped'], 1)


if __name__ == '__main__':
    unittest.main()
