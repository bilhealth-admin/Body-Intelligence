[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$artifactDir = Join-Path $project 'artifacts\release\epic2'
$log = Join-Path $artifactDir 'epic2_targeted_architecture.log'
$summary = Join-Path $artifactDir 'epic2_targeted_architecture_summary.txt'
$tests = @(
  'test/architecture_source_file_size_guard_test.dart',
  'test/dashboard_epic3/epic_e3_source_contract_test.dart',
  'test/dashboard_mobile_first/epic_e1_reset_source_contract_test.dart',
  'test/dashboard_mobile_first/epic_e2_source_contract_test.dart',
  'test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart',
  'test/features/dashboard/architecture/dashboard_epic_closure_contract_test.dart',
  'test/home_intelligence/home_visual_bio_parity_contract_test.dart',
  'test/dashboard_analytics_reuse_test.dart',
  'test/quick_add_routing_contract_test.dart',
  'test/features/nutrition/usda_search_quality_r2_contract_test.dart'
)

Push-Location $project
try {
  '=== BIL v1 EPIC 2 TARGETED ARCHITECTURE GATE ===' |
    Set-Content -LiteralPath $log -Encoding utf8
  & flutter test --no-pub @tests --timeout 30s 2>&1 |
    Tee-Object -FilePath $log -Append
  $testExit = $LASTEXITCODE
  # Native Flutter output can be appended as UTF-16LE by Windows PowerShell
  # after the UTF-8 heading. Decode the raw bytes and remove interleaved NULs
  # so the success marker is detected reliably in this mixed-encoding log.
  $logBytes = [System.IO.File]::ReadAllBytes($log)
  $logText = [System.Text.Encoding]::UTF8.GetString($logBytes) -replace "`0", ''
  $clean = $testExit -eq 0 -and $logText -match 'All tests passed!'
  $gate = if ($clean) { 'PASS' } else { 'FAIL' }
  @(
    'BIL v1 - Epic 2 targeted architecture summary'
    "Generated: $([DateTimeOffset]::Now.ToString('o'))"
    "PROJECT=$project"
    "TEST_EXIT_CODE=$testExit"
    "TEST_CLEAN=$clean"
    "EPIC2_TARGETED_ARCHITECTURE_GATE=$gate"
    "LOG_FILE=$log"
    ''
    'SUCCESS CRITERIA:'
    '1. TEST_EXIT_CODE=0'
    '2. TEST_CLEAN=True'
    '3. EPIC2_TARGETED_ARCHITECTURE_GATE=PASS'
  ) | Set-Content -LiteralPath $summary -Encoding utf8
  Get-Content -LiteralPath $summary
  exit $testExit
}
finally {
  Pop-Location
}
