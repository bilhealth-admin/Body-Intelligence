"""Exercise real Git CRLF checkout and the production byte guards in isolation."""
from __future__ import annotations

from contextlib import contextmanager
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import bil_candidate_owner_runner as candidate
from bil_internal_testflight_source import validate_helpers
import build_home_smart_plan_prescriptions as projection

ROOT = Path(__file__).resolve().parents[2]
HELPER = '.github/scripts/bil_ios37_native_integration.sh'


def job_source():
    workflow = (ROOT / '.github/workflows/verify.yml').read_text(encoding='utf-8')
    return workflow.split('\n  integration-tools:\n', 1)[1].split('\n  flutter:\n', 1)[0]


class WindowsCheckoutBytesTest(unittest.TestCase):
    def git(self, *args, cwd, env):
        result = subprocess.run(['git', *args], cwd=cwd, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                check=True)
        return result.stdout

    @contextmanager
    def checkout(self, *, apply_workflow_configuration):
        self.assertIsNotNone(shutil.which('git'), 'Real Git is required; no skipped byte guard')
        with tempfile.TemporaryDirectory(prefix='bil39-checkout-') as directory:
            root = Path(directory).resolve()
            config = root / 'fixture-global.gitconfig'
            config.write_bytes(b'[core]\n\tautocrlf = true\n')
            environment = {**os.environ, 'GIT_CONFIG_GLOBAL': str(config),
                           'GIT_CONFIG_NOSYSTEM': '1'}
            source = root / 'source'
            source.mkdir()
            self.git('init', '--quiet', '--initial-branch=fixture', cwd=source, env=environment)
            self.git('config', 'core.autocrlf', 'false', cwd=source, env=environment)
            payload = {
                'owner.py': Path(candidate.owner.__file__).read_bytes(),
                'native.sh': (ROOT / HELPER).read_bytes(),
                'home.json': projection.DESTINATION.read_bytes(),
                'warmups.json': projection.WARMUPS.read_bytes(),
            }
            for name, content in payload.items():
                self.assertNotIn(b'\r\n', content, 'Reviewed source is LF: ' + name)
                (source / name).write_bytes(content)
            self.git('add', '.', cwd=source, env=environment)
            self.git('-c', 'user.name=BIL checkout fixture', '-c', 'user.email=fixture@example.invalid',
                     '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'fixture',
                     cwd=source, env=environment)
            if apply_workflow_configuration:
                job = job_source()
                checkout_position = job.index('uses: actions/checkout@')
                commands = re.findall(r'git config --global core\.(autocrlf|eol) (\S+)',
                                      job[:checkout_position])
                self.assertEqual(commands, [('autocrlf', 'false'), ('eol', 'lf')],
                                 'The actual QA job must set LF before checkout')
                for option, value in commands:
                    # --global writes only the disposable GIT_CONFIG_GLOBAL above.
                    self.git('config', '--global', 'core.' + option, value,
                             cwd=root, env=environment)
            target = root / 'checkout'
            self.git('clone', '--quiet', '--no-hardlinks', '--no-checkout',
                     str(source), str(target), cwd=root, env=environment)
            self.git('checkout', '--quiet', 'HEAD', cwd=target, env=environment)
            yield target, payload

    def test_windows_default_checkout_reproduces_real_digest_rejections(self):
        with self.checkout(apply_workflow_configuration=False) as (target, payload):
            for name, original in payload.items():
                current = (target / name).read_bytes()
                self.assertIn(b'\r\n', current)
                self.assertNotEqual(current, original)
            with self.assertRaisesRegex(RuntimeError, 'Original owner runner changed'):
                candidate.verify_original(target / 'owner.py')
            with self.assertRaisesRegex(ValueError, 'Unreviewed native or build helper'):
                validate_helpers([HELPER], lambda _: (target / 'native.sh').read_bytes())

    def test_actual_workflow_checkout_preserves_bytes_and_tampering_is_still_denied(self):
        with self.checkout(apply_workflow_configuration=True) as (target, payload):
            for name, expected in payload.items():
                self.assertEqual((target / name).read_bytes(), expected, name)
            candidate.verify_original(target / 'owner.py')
            validate_helpers([HELPER], lambda _: (target / 'native.sh').read_bytes())
            with (target / 'owner.py').open('ab') as stream:
                stream.write(b'# altered fixture\n')
            with self.assertRaisesRegex(RuntimeError, 'Original owner runner changed'):
                candidate.verify_original(target / 'owner.py')
            with (target / 'native.sh').open('ab') as stream:
                stream.write(b'# altered fixture\n')
            with self.assertRaisesRegex(ValueError, 'Unreviewed native or build helper'):
                validate_helpers([HELPER], lambda _: (target / 'native.sh').read_bytes())


if __name__ == '__main__':
    unittest.main()
