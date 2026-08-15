[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$epicDir = $PSScriptRoot

Set-Location -LiteralPath $project

$formatLog = Join-Path $epicDir 'epic2_format.log'
$analyzeLog = Join-Path $epicDir 'epic2_analyze.log'
$testLog = Join-Path $epicDir 'epic2_tests.log'
$summaryFile = Join-Path $epicDir 'epic2_summary.txt'

Remove-Item -LiteralPath $formatLog, $analyzeLog, $testLog, $summaryFile `
  -Force -ErrorAction SilentlyContinue

$formatTargets = @('lib', 'test')
if (Test-Path -LiteralPath 'integration_test') {
  $formatTargets += 'integration_test'
}

Write-Host '=== EPIC 2 / 1 of 3: DART FORMAT ===' -ForegroundColor Cyan
& dart format @formatTargets 2>&1 | Tee-Object -FilePath $formatLog
$formatExit = $LASTEXITCODE

Write-Host '=== EPIC 2 / 2 of 3: FULL FLUTTER ANALYZE ===' -ForegroundColor Cyan
& flutter analyze 2>&1 | Tee-Object -FilePath $analyzeLog
$analyzeExit = $LASTEXITCODE

Write-Host '=== EPIC 2 / 3 of 3: FULL FLUTTER TEST ===' -ForegroundColor Cyan
& flutter test 2>&1 | Tee-Object -FilePath $testLog
$testExit = $LASTEXITCODE

function Read-NormalizedLog([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return ''
  }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  return ([System.Text.Encoding]::UTF8.GetString($bytes) -replace "`0", '')
}

$formatText = Read-NormalizedLog $formatLog
$analyzeText = Read-NormalizedLog $analyzeLog
$testText = Read-NormalizedLog $testLog

$formattedFiles = 0
$changedFiles = 0
if ($formatText -match 'Formatted\s+(\d+)\s+files?\s+\((\d+)\s+changed\)') {
  $formattedFiles = [int]$Matches[1]
  $changedFiles = [int]$Matches[2]
}

$analyzeIssueCount = 0
if ($analyzeText -match '(\d+)\s+issues?\s+found') {
  $analyzeIssueCount = [int]$Matches[1]
}
$analyzeClean = $analyzeExit -eq 0 -and $analyzeText -match 'No issues found!'

$testCount = 0
$skippedCount = 0
$testProgressMatches = [regex]::Matches($testText, '\+(\d+)(?:\s+~(\d+))?')
if ($testProgressMatches.Count -gt 0) {
  $lastProgress = $testProgressMatches[$testProgressMatches.Count - 1]
  $testCount = [int]$lastProgress.Groups[1].Value
  if ($lastProgress.Groups[2].Success) {
    $skippedCount = [int]$lastProgress.Groups[2].Value
  }
}
$testClean = $testExit -eq 0 -and $testText -match 'All tests passed!'

$gatePassed = $formatExit -eq 0 -and $analyzeClean -and $testClean
$gateResult = if ($gatePassed) { 'PASS' } else { 'FAIL' }

$summary = @(
  'BIL v1 - Epic 2 full architecture gate summary'
  "Generated: $([DateTimeOffset]::Now.ToString('o'))"
  "Project: $project"
  "FORMAT_EXIT_CODE=$formatExit"
  "FORMAT_FILES=$formattedFiles"
  "FORMAT_CHANGED=$changedFiles"
  "ANALYZE_EXIT_CODE=$analyzeExit"
  "ANALYZE_ISSUES=$analyzeIssueCount"
  "ANALYZE_CLEAN=$analyzeClean"
  "TEST_EXIT_CODE=$testExit"
  "TESTS_PASSED_COUNT=$testCount"
  "TESTS_SKIPPED_COUNT=$skippedCount"
  "TEST_CLEAN=$testClean"
  "EPIC2_GATE=$gateResult"
  ''
  'SUCCESS CRITERIA:'
  '1. FORMAT_EXIT_CODE=0'
  '2. ANALYZE_EXIT_CODE=0 and ANALYZE_CLEAN=True (No issues found!)'
  '3. TEST_EXIT_CODE=0 and TEST_CLEAN=True (All tests passed!)'
  '4. EPIC2_GATE=PASS'
)

$summary | Set-Content -LiteralPath $summaryFile -Encoding utf8
$summary | ForEach-Object { Write-Host $_ }

Write-Host '=== SAVED OUTPUTS ===' -ForegroundColor Cyan
Get-Item -LiteralPath $formatLog, $analyzeLog, $testLog, $summaryFile |
  Select-Object FullName, Length, LastWriteTime

if (-not $gatePassed) {
  exit 1
}

exit 0
