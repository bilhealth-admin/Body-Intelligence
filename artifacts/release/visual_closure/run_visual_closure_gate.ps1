$ErrorActionPreference = 'Continue'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location -LiteralPath $project

function Invoke-Logged([scriptblock]$Command, [string]$Path) {
  & $Command 2>&1 |
    ForEach-Object { $_.ToString() } |
    Tee-Object -FilePath $Path |
    Out-Host
  return [int]$LASTEXITCODE
}

function Read-Log([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    return Get-Content -LiteralPath $Path -Raw
  }
  return ''
}

$formatLog = Join-Path $PSScriptRoot 'visual_closure_format.log'
$reviewLog = Join-Path $PSScriptRoot 'visual_closure_review.log'
$goldenLog = Join-Path $PSScriptRoot 'visual_closure_goldens.log'
$analyzeLog = Join-Path $PSScriptRoot 'visual_closure_analyze.log'
$testsLog = Join-Path $PSScriptRoot 'visual_closure_tests.log'
$buildLog = Join-Path $PSScriptRoot 'visual_closure_android_build.log'
$summaryFile = Join-Path $PSScriptRoot 'visual_closure_summary.txt'

$formatTargets = @(
  'lib/features/dashboard/widgets/dashboard_guide_orb.dart',
  'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
  'lib/features/nutrition/presentation/food_catalog_overview.dart',
  'lib/features/wellness/presentation/professional_content_library_page.dart',
  'lib/features/wellness/presentation/wellness_library_page.dart',
  'test/epic3_visual_matrix_golden_test.dart',
  'test/epic8_weekly_report_golden_test.dart',
  'test/visual_closure/actual_data_pages_golden_test.dart',
  'test/visual_closure/actual_production_pages_golden_test.dart',
  'test/visual_closure/visual_evidence_font.dart',
  'tool/visual_reference_evidence_verifier.dart',
  'tool/visual_reference_manifest.dart',
  'tool/visual_reference_review_audit.dart'
)

$visualTests = @(
  'test/visual_closure/actual_production_pages_golden_test.dart',
  'test/visual_closure/actual_data_pages_golden_test.dart',
  'test/epic3_visual_matrix_golden_test.dart',
  'test/epic8_weekly_report_golden_test.dart'
)

$formatExit = Invoke-Logged { & dart format @formatTargets } $formatLog
$reviewExit = Invoke-Logged {
  & dart run tool/visual_reference_review_audit.dart
} $reviewLog
$reviewText = Read-Log $reviewLog
$reviewClean = $reviewExit -eq 0 -and
  $reviewText -match 'VISUAL_MANUAL_REVIEW=PASS' -and
  $reviewText -match 'REVIEWED_REFERENCES=177' -and
  $reviewText -match 'UNVERIFIED_REFERENCES=0' -and
  $reviewText -match 'EXTERNAL_VALIDATION_PENDING=0'

if (-not $reviewClean) {
  @"
BIL v1 - 177-reference visual closure final gate summary
Generated: $(Get-Date -Format o)
Project: $project
FORMAT_EXIT_CODE=$formatExit
FORMAT_CLEAN=$($formatExit -eq 0)
VISUAL_REVIEW_EXIT_CODE=$reviewExit
VISUAL_REVIEW_CLEAN=False
REVIEWED_REFERENCES=$(if ($reviewText -match 'REVIEWED_REFERENCES=(\d+)') { $Matches[1] } else { 'unknown' })
UNVERIFIED_REFERENCES=$(if ($reviewText -match 'UNVERIFIED_REFERENCES=(\d+)') { $Matches[1] } else { 'unknown' })
EXTERNAL_VALIDATION_PENDING=$(if ($reviewText -match 'EXTERNAL_VALIDATION_PENDING=(\d+)') { $Matches[1] } else { 'unknown' })
GOLDEN_VERIFY_CLEAN=NOT_RUN
ANALYZE_CLEAN=NOT_RUN
TEST_CLEAN=NOT_RUN
ANDROID_BUILD_CLEAN=NOT_RUN
VISUAL_CLOSURE_GATE=FAIL

The gate stopped before tests and build because visual-equivalence approval is incomplete.
"@ | Set-Content -LiteralPath $summaryFile -Encoding utf8
  Get-Content -LiteralPath $summaryFile
  exit 1
}
$goldenExit = Invoke-Logged {
  & flutter test @visualTests --timeout 60s
} $goldenLog
$analyzeExit = Invoke-Logged { & flutter analyze } $analyzeLog
$testExit = Invoke-Logged { & flutter test --timeout 30s } $testsLog
$buildExit = Invoke-Logged { & flutter build apk --debug } $buildLog

$formatClean = $formatExit -eq 0
$goldenClean = $goldenExit -eq 0 -and
  (Read-Log $goldenLog) -match 'All tests passed!'
$analyzeClean = $analyzeExit -eq 0 -and
  (Read-Log $analyzeLog) -match 'No issues found!'
$testText = Read-Log $testsLog
$testClean = $testExit -eq 0 -and $testText -match 'All tests passed!'
$buildClean = $buildExit -eq 0 -and
  (Read-Log $buildLog) -match 'Built build\\app\\outputs\\flutter-apk\\app-debug.apk'
$passed = 0
$skipped = 0
$matches = [regex]::Matches($testText, '\+(\d+)(?:\s+~(\d+))?: All tests passed!')
if ($matches.Count -gt 0) {
  $last = $matches[$matches.Count - 1]
  $passed = [int]$last.Groups[1].Value
  if ($last.Groups[2].Success) { $skipped = [int]$last.Groups[2].Value }
}
$gate = if (
  $formatClean -and $reviewClean -and $goldenClean -and
  $analyzeClean -and $testClean -and $buildClean
) { 'PASS' } else { 'FAIL' }

@"
BIL v1 - 177-reference visual closure final gate summary
Generated: $(Get-Date -Format o)
Project: $project
FORMAT_EXIT_CODE=$formatExit
FORMAT_CLEAN=$formatClean
VISUAL_REVIEW_EXIT_CODE=$reviewExit
VISUAL_REVIEW_CLEAN=$reviewClean
REVIEWED_REFERENCES=177
UNVERIFIED_REFERENCES=$(if ($reviewText -match 'UNVERIFIED_REFERENCES=(\d+)') { $Matches[1] } else { 'unknown' })
EXTERNAL_VALIDATION_PENDING=$(if ($reviewText -match 'EXTERNAL_VALIDATION_PENDING=(\d+)') { $Matches[1] } else { 'unknown' })
GOLDEN_VERIFY_EXIT_CODE=$goldenExit
GOLDEN_VERIFY_CLEAN=$goldenClean
ANALYZE_EXIT_CODE=$analyzeExit
ANALYZE_CLEAN=$analyzeClean
TEST_EXIT_CODE=$testExit
TESTS_PASSED_COUNT=$passed
TESTS_SKIPPED_COUNT=$skipped
TEST_CLEAN=$testClean
ANDROID_BUILD_EXIT_CODE=$buildExit
ANDROID_BUILD_CLEAN=$buildClean
VISUAL_CLOSURE_GATE=$gate

SUCCESS CRITERIA:
1. FORMAT_CLEAN=True
2. VISUAL_REVIEW_CLEAN=True only when all 177 references have explicit visual-equivalence approval and no external validation remains pending
3. GOLDEN_VERIFY_CLEAN=True
4. ANALYZE_CLEAN=True
5. TEST_CLEAN=True
6. ANDROID_BUILD_CLEAN=True
7. VISUAL_CLOSURE_GATE=PASS
"@ | Set-Content -LiteralPath $summaryFile -Encoding utf8

Get-Content -LiteralPath $summaryFile
exit $(if ($gate -eq 'PASS') { 0 } else { 1 })
