"""Exercise the real certification barrier with job and evidence outcomes."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/bil_final_release_certification.yml"
JOB_RESULTS = ("STATIC", "FULL", "VISUAL", "LIVE", "STORE", "PRE_FINAL", "CLOUD_LIVE")
EVIDENCE_RESULTS = ("LIVE_EVIDENCE", "STORE_EVIDENCE")


def barrier_script():
    text = WORKFLOW.read_text(encoding="utf-8")
    job = text.split("\n  pass_1_barrier:\n", 1)[1].split("\n  static_pass_2:\n", 1)[0]
    match = re.search(r"^        run: \|\n(?P<body>(?:          .*\n|\n)+)", job, re.MULTILINE)
    if match is None:
        raise AssertionError("Certification barrier shell was not found")
    return textwrap.dedent(match.group("body"))


def bash_executable():
    if os.name == "nt":
        git = shutil.which("git")
        if git:
            candidate = Path(git).resolve().parents[1] / "bin/bash.exe"
            if candidate.is_file():
                return str(candidate)
    found = shutil.which("bash")
    if found is None:
        raise AssertionError("Bash is required to test the actual Linux certification barrier")
    return found


class CertificationBarrierTests(unittest.TestCase):
    def run_barrier(self, **changes):
        env = {key: value for key, value in os.environ.items()
               if key.upper() in ("PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP")}
        env.update({key: "success" for key in JOB_RESULTS})
        env.update({key: "PASS" for key in EVIDENCE_RESULTS})
        env.update(changes)
        return subprocess.run(
            [bash_executable(), "--noprofile", "--norc", "-e", "-o", "pipefail", "-c", barrier_script()],
            env=env, capture_output=True, text=True, timeout=15,
        )

    def test_all_required_jobs_and_actual_evidence_pass(self):
        result = self.run_barrier()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_green_jobs_with_missing_or_blocked_evidence_do_not_start_second_pass(self):
        for key in EVIDENCE_RESULTS:
            for outcome in ("NOT RUN", "FAIL", "", "success", "SKIPPED"):
                with self.subTest(key=key, outcome=outcome):
                    result = self.run_barrier(**{key: outcome})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("second pass is blocked", result.stderr)

    def test_failed_cancelled_or_skipped_jobs_remain_blocking(self):
        for key in JOB_RESULTS:
            for outcome in ("failure", "cancelled", "skipped", ""):
                with self.subTest(key=key, outcome=outcome):
                    self.assertNotEqual(self.run_barrier(**{key: outcome}).returncode, 0)


if __name__ == "__main__":
    unittest.main()
