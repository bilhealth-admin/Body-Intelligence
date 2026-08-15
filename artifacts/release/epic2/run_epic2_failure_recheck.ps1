$ErrorActionPreference = 'Continue'

$project = (Get-Location).Path
$outputDir = Join-Path $project 'artifacts\release\epic2'
$formatLog = Join-Path $outputDir 'epic2_failure_recheck_format.log'
$analyzeLog = Join-Path $outputDir 'epic2_failure_recheck_analyze.log'
$testLog = Join-Path $outputDir 'epic2_failure_recheck_tests.log'
$summaryFile = Join-Path $outputDir 'epic2_failure_recheck_summary.txt'

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$formatTargets = @(
  'lib/features/dashboard/widgets/dashboard_signal_orb.dart',
  'lib/features/dashboard/widgets/premium_dashboard_command_center.dart',
  'lib/features/wellness/presentation/wellness_tools_pages.dart',
  'test/home_intelligence/home_body_twin_color_injection_r25_contract_test.dart',
  'test/home_intelligence/home_static_body_twin_primary_pages_r26_contract_test.dart',
  'test/premium_ui/premium_surface_hierarchy_test.dart',
  'test/product_owner_review_closure_contract_test.dart',
  'test/product_owner_visual_review_r6_contract_test.dart'
)

& dart format @formatTargets 2>&1 | Tee-Object -FilePath $formatLog
$formatExitCode = $LASTEXITCODE

& flutter analyze `
  lib/features/dashboard `
  lib/features/wellness `
  test/home_intelligence/home_body_twin_color_injection_r25_contract_test.dart `
  test/home_intelligence/home_static_body_twin_primary_pages_r26_contract_test.dart `
  test/premium_ui/premium_surface_hierarchy_test.dart `
  test/product_owner_review_closure_contract_test.dart `
  test/product_owner_visual_review_r6_contract_test.dart `
  2>&1 | Tee-Object -FilePath $analyzeLog
$analyzeExitCode = $LASTEXITCODE

$tests = @(
  'test/home_intelligence/home_body_twin_color_injection_r25_contract_test.dart',
  'test/home_intelligence/home_static_body_twin_primary_pages_r26_contract_test.dart',
  'test/premium_ui/premium_surface_hierarchy_test.dart',
  'test/product_owner_review_closure_contract_test.dart',
  'test/product_owner_visual_review_r6_contract_test.dart',
  'test/weight_history_test.dart',
  'test/timezone_selection_test.dart'
)

& flutter test @tests --timeout 30s 2>&1 | Tee-Object -FilePath $testLog
$testExitCode = $LASTEXITCODE

$analyzeText = if (Test-Path -LiteralPath $analyzeLog) {
  Get-Content -LiteralPath $analyzeLog -Raw
} else {
  ''
}
$testText = if (Test-Path -LiteralPath $testLog) {
  Get-Content -LiteralPath $testLog -Raw
} else {
  ''
}

$analyzeClean = $analyzeExitCode -eq 0 -and $analyzeText -match 'No issues found!'
$testClean = $testExitCode -eq 0 -and $testText -match 'All tests passed!'
$gatePass = $formatExitCode -eq 0 -and $analyzeClean -and $testClean

$summary = @(
  'BIL v1 - Epic 2 failure recheck summary',
  "Generated: $((Get-Date).ToString('o'))",
  "PROJECT=$project",
  "FORMAT_EXIT_CODE=$formatExitCode",
  "ANALYZE_EXIT_CODE=$analyzeExitCode",
  "ANALYZE_CLEAN=$analyzeClean",
  "TEST_EXIT_CODE=$testExitCode",
  "TEST_CLEAN=$testClean",
  "EPIC2_FAILURE_RECHECK=$(if ($gatePass) { 'PASS' } else { 'FAIL' })",
  "FORMAT_LOG=$formatLog",
  "ANALYZE_LOG=$analyzeLog",
  "TEST_LOG=$testLog"
)

$summary | Set-Content -LiteralPath $summaryFile -Encoding UTF8
$summary | ForEach-Object { Write-Host $_ }

if (-not $gatePass) {
  exit 1
}

exit 0
