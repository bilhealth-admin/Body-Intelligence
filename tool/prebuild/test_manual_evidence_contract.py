"""Pure row/telemetry tests. Does not invoke the recovered device/media tools."""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ManualEvidenceContractTest(unittest.TestCase):
    def test_monitor_lock_is_exclusive_and_reusable_without_running_monitor(self):
        script = (ROOT/'tool/release/monitor_workout_video_gym_completion.ps1').read_text(encoding='utf-8')
        # Extract the standalone locking function, not the media-monitor body.
        begin = script.index('function Open-BilMonitorLock(')
        function = script[begin:script.index('\n}', begin)+2]
        with tempfile.TemporaryDirectory(prefix='bil-lock-contract-') as folder:
            lock = str(Path(folder)/'unit-test.lock').replace("'", "''")
            command = function+f"\n$path='{lock}'\n"+'''
$first = Open-BilMonitorLock $path
$blocked = $false
try {
  try { $unexpected = Open-BilMonitorLock $path; $unexpected.Dispose() }
  catch [IO.IOException] { $blocked = $true }
} finally { $first.Dispose() }
$replacement = Open-BilMonitorLock $path
$replacement.Dispose()
@{blocked=$blocked;reusable=$true} | ConvertTo-Json -Compress
'''
            powershell=shutil.which('pwsh') or shutil.which('powershell.exe')
            result=subprocess.run([powershell,'-NoProfile','-NonInteractive','-Command',command],
                                  capture_output=True,text=True,timeout=30,check=True)
            self.assertEqual(json.loads(result.stdout), dict(blocked=True,reusable=True))

    def test_duplicate_rows_and_missing_telemetry_cannot_be_called_pass(self):
        script = (ROOT/'tool/release/run_bil_webcam_acceptance.ps1').read_text(encoding='utf-8')
        # Extract only the literal case-list assignment, never execute the tool.
        cases = script[script.index('$cases = @('):script.index('if (-not (Test-Path -LiteralPath $csvPath))')]
        validator=(ROOT/'tool/release/webcam_result_contract.ps1').read_text(encoding='utf-8')
        command=validator+'\n'+cases+'''
$rows = @($cases | ForEach-Object { [pscustomobject]@{
  case_id=$_.case_id; category=$_.category; success='PASS';
  camera_input_source='android_emulator_host_webcam0'; timestamp_utc='2026-09-10T00:00:00Z';
  recognized_item='fixture'; food_nonfood='food'; barcode_result='n/a'; evidence_file='not-opened.png';
  input_tokens='10'; output_tokens='5'; latency_ms='120'; cost_usd='0.001'; quota_consumed='10';
  gemini_fallback='true'; dedup_prevented='false'; cache_hit='false'; model='fixture-model'
}})
$valid = Test-BilWebcamResultContract $rows $cases
$duplicate = @($rows[0]) * 31
$duplicatesRejected = -not (Test-BilWebcamResultContract $duplicate $cases)
$rows[0].latency_ms=''
$missingRejected = -not (Test-BilWebcamResultContract $rows $cases)
$rows[0].latency_ms='NaN'
$nanRejected = -not (Test-BilWebcamResultContract $rows $cases)
$rows[0].latency_ms='120'
$rows[0].model='n/a'
$modelRejected = -not (Test-BilWebcamResultContract $rows $cases)
@{valid=$valid; duplicatesRejected=$duplicatesRejected;missingRejected=$missingRejected;
nanRejected=$nanRejected;modelRejected=$modelRejected} | ConvertTo-Json -Compress
'''
        powershell=shutil.which('pwsh') or shutil.which('powershell.exe')
        result=subprocess.run([powershell,'-NoProfile','-NonInteractive','-Command',command],
                              capture_output=True,text=True,timeout=30,check=True)
        self.assertEqual(json.loads(result.stdout), dict(valid=True,duplicatesRejected=True,
            missingRejected=True,nanRejected=True,modelRejected=True))
