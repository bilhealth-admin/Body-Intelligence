"""Exercise the real final gate while full shards overlap the focused phases."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ('SOURCE_RESULT', 'P0_RESULT', 'FOCUSED_RESULT', 'BROAD_RESULT',
           'SHARDS_RESULT', 'TOOLS_RESULT')


class ParallelShardGateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / '.github/workflows/verify.yml').read_text(encoding='utf-8')
        cls.final = cls.source.split('\n  flutter:\n', 1)[1]
        body = cls.final.split('        run: |\n', 1)[1]
        lines = []
        for line in body.splitlines():
            if line.strip() and not line.startswith(' ' * 10):
                break
            lines.append(line[10:])
        cls.script = '\n'.join(lines) + '\n'
        windows_bash = Path('C:/Program Files/Git/bin/bash.exe')
        cls.bash = str(windows_bash) if os.name == 'nt' and windows_bash.is_file() else shutil.which('bash')
        if cls.bash is None:
            raise RuntimeError('Real Bash is required for the final CI gate regression')

    def run_gate(self, **updates):
        environment = {**os.environ, 'BASH_ENV': '/dev/null',
                       **{name: 'success' for name in RESULTS}, **updates}
        return subprocess.run([self.bash, '--noprofile', '--norc', '-e', '-o', 'pipefail'],
                              input=self.script, text=True, env=environment,
                              capture_output=True, timeout=10)

    def test_parallel_shards_still_wait_for_source_and_final_gate_waits_for_every_phase(self):
        shards = self.source.split('\n  shards:\n', 1)[1].split('\n  integration-tools:', 1)[0]
        self.assertRegex(shards, r'(?m)^    needs: source$')
        self.assertIn('shard: [0, 1, 2, 3, 4, 5, 6, 7]', shards)
        needs = re.search(r'(?m)^    needs: \[([^]]+)\]$', self.final)
        self.assertIsNotNone(needs)
        self.assertEqual({value.strip() for value in needs.group(1).split(',')},
                         {'source', 'p0', 'focused', 'broad', 'shards', 'integration-tools'})

    def test_actual_aggregate_script_accepts_only_all_success(self):
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('All quality gates passed.', result.stdout)

    def test_failed_cancelled_or_skipped_phase_is_rejected_by_actual_script(self):
        for phase in RESULTS:
            for status in ('failure', 'cancelled', 'skipped'):
                with self.subTest(phase=phase, status=status):
                    result = self.run_gate(**{phase: status})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn('All quality gates passed.', result.stdout)


if __name__ == '__main__':
    unittest.main()
