$ErrorActionPreference = 'Continue'

$project = (Get-Location).Path
$artifactDir = Join-Path $project 'artifacts\release\epic2'
$formatLog = Join-Path $artifactDir 'epic2_decision_contract_format.log'
$analyzeLog = Join-Path $artifactDir 'epic2_decision_contract_analyze.log'
$testLog = Join-Path $artifactDir 'epic2_decision_contract_test.log'
$summaryFile = Join-Path $artifactDir 'epic2_decision_contract_summary.txt'
$testFile = 'test/features/dashboard/presentation/dashboard_decision_explanation_route_test.dart'

New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

& dart format $testFile 2>&1 | Tee-Object -FilePath $formatLog
$formatExitCode = $LASTEXITCODE

& flutter analyze $testFile 2>&1 | Tee-Object -FilePath $analyzeLog
$analyzeExitCode = $LASTEXITCODE
$analyzeText = Get-Content -LiteralPath $analyzeLog -Raw
$analyzeClean = $analyzeExitCode -eq 0 -and $analyzeText -match 'No issues found!'

& flutter test $testFile --timeout 30s 2>&1 | Tee-Object -FilePath $testLog
$testExitCode = $LASTEXITCODE
$testText = Get-Content -LiteralPath $testLog -Raw
$testClean = $testExitCode -eq 0 -and $testText -match 'All tests passed!'

$gatePass = $formatExitCode -eq 0 -and $analyzeClean -and $testClean
$summary = @(
  'BIL v1 - Epic 2 decision contract recheck summary'
  "Generated: $((Get-Date).ToString('o'))"
  "PROJECT=$project"
  "FORMAT_EXIT_CODE=$formatExitCode"
  "ANALYZE_EXIT_CODE=$analyzeExitCode"
  "ANALYZE_CLEAN=$analyzeClean"
  "TEST_EXIT_CODE=$testExitCode"
  "TEST_CLEAN=$testClean"
  "EPIC2_DECISION_CONTRACT_RECHECK=$(if ($gatePass) { 'PASS' } else { 'FAIL' })"
  "FORMAT_LOG=$formatLog"
  "ANALYZE_LOG=$analyzeLog"
  "TEST_LOG=$testLog"
)

$summary | Set-Content -LiteralPath $summaryFile -Encoding UTF8
$summary | ForEach-Object { Write-Host $_ }

if (-not $gatePass) { exit 1 }
exit 0
