"""Behavioral tests for the audit's evidence plumbing (no product execution)."""

import json
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

from run_code_tests import flutter_test_command, MIXED_NAMES, VISUAL_CALL
import write_diff_inventory


ROOT = Path(__file__).resolve().parents[2]


class ShellFreeTestSelectionTest(unittest.TestCase):
    def test_filters_are_passed_to_native_dart_not_cmd_or_a_batch_file(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'Flutter SDK with spaces' / 'bin'
            dart = binary / 'cache/dart-sdk/bin' / ('dart.exe' if os.name == 'nt' else 'dart')
            snapshot = binary / 'cache/flutter_tools.snapshot'
            dart.parent.mkdir(parents=True)
            dart.touch()
            snapshot.touch()
            command = flutter_test_command(str(binary / 'flutter.bat'))
            self.assertEqual(command[:3], [str(dart.resolve()), str(snapshot.resolve()), 'test'])
            self.assertFalse(any(arg.endswith('.bat') or arg == 'cmd.exe' for arg in command))
            for pattern in MIXED_NAMES.values():
                # Windows' native argv round-trip does not interpret regex |/()
                # operators; a batch-file entrypoint would reintroduce cmd parsing.
                result = subprocess.run(
                    [os.sys.executable, '-c', 'import json,sys;print(json.dumps(sys.argv[1:]))',
                     *command, '--name', pattern], capture_output=True, text=True, check=True)
                self.assertEqual(json.loads(result.stdout)[-2:], ['--name', pattern])

    def test_missing_sdk_does_not_fall_back_to_an_unsafe_batch_entrypoint(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                flutter_test_command(str(Path(directory) / 'flutter.bat'))

    def test_binary_evidence_verification_requires_explicit_classification(self):
        self.assertIsNotNone(VISUAL_CALL.search('await verifyVisualReferenceEvidence(manifest);'))


class DiffInventoryTest(unittest.TestCase):
    def test_staging_preserves_added_and_moved_paths_and_lf(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            backup = root / 'backup'
            backup.mkdir()
            (backup / 'manifest.csv').write_text('Path,State,Bytes,SHA256\n', encoding='utf-8')
            (root / 'added.dart').write_text('const answer = 42;\n', encoding='utf-8')
            (root / 'existing.dart').write_text('const answer = 41;\n', encoding='utf-8')
            output = root / write_diff_inventory.OUTPUT
            output.parent.mkdir(parents=True)
            answers = {
                ('ls-tree', '-r', '--name-only', '-z', 'HEAD'): ['existing.dart', 'old.dart', ''],
                ('diff', 'HEAD', '--no-renames', '--name-only', '-z'): ['added.dart', 'existing.dart', 'old.dart', ''],
                ('ls-files', '--others', '--exclude-standard', '-z'): [''],
            }
            with mock.patch.object(write_diff_inventory, 'ROOT', root), \
                 mock.patch.object(write_diff_inventory, 'git', side_effect=lambda *a: answers[a]), \
                 mock.patch('sys.argv', ['write_diff_inventory.py', str(backup)]), \
                 redirect_stdout(io.StringIO()):
                write_diff_inventory.main()
            data = output.read_bytes()
            self.assertNotIn(b'\r', data)
            self.assertIn('| `added.dart` | added |', data.decode('utf-8'))
            self.assertIn('| `existing.dart` | modified |', data.decode('utf-8'))
            self.assertIn('| `old.dart` | deleted/moved |', data.decode('utf-8'))


class AnalysisDiagnosticRenderingTest(unittest.TestCase):
    def test_actual_diagnostic_loop_preserves_warning_and_error_details(self):
        source = (ROOT / "tool/release/run_analysis_server.ps1").read_text(encoding="utf-8")
        start = source.index("  $allErrors = @()")
        end = source.index('  Write-Output "ANALYSIS_COMPLETED=', start)
        loop = source[start:end]
        command = """
$ErrorActionPreference = 'Stop'
$errors = @([pscustomobject]@{params=[pscustomobject]@{
  file='source.dart'; errors=@(
    [pscustomobject]@{location=[pscustomobject]@{startLine=7};severity='ERROR';type='COMPILE_TIME_ERROR';message='actual compiler error'},
    [pscustomobject]@{location=[pscustomobject]@{startLine=9};severity='WARNING';type='STATIC_WARNING';message='actual warning'}
  )
}})
""" + loop + "\nConvertTo-Json -InputObject @($allErrors) -Compress\n"
        powershell = shutil.which("pwsh") or shutil.which("powershell.exe")
        self.assertIsNotNone(powershell, "PowerShell is required to verify its diagnostic runner")
        result = subprocess.run([powershell, "-NoProfile", "-NonInteractive", "-Command", command],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        diagnostics = json.loads(result.stdout)
        self.assertEqual([d["Severity"] for d in diagnostics], ["ERROR", "WARNING"])
        self.assertEqual([d["Line"] for d in diagnostics], [7, 9])
        self.assertEqual([d["File"] for d in diagnostics], ["source.dart", "source.dart"])
        self.assertEqual(diagnostics[0]["Message"], "actual compiler error")


if __name__ == "__main__":
    unittest.main()
