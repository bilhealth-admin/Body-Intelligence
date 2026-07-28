param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot 'artifacts\engineering_audit'
$ReportPath = Join-Path $ReportRoot 'BIL-ENGINEERING-AUDIT-003-report.txt'
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

function Record([string]$Name, [string]$Status, [string]$Detail = '') {
    $line = "$Name`t$Status"
    if ($Detail) { $line += "`t$Detail" }
    $line | Tee-Object -FilePath $ReportPath -Append
}

'BIL-ENGINEERING-AUDIT-003' | Set-Content $ReportPath
Record 'Branch' 'INFO' ((git branch --show-current).Trim())
Record 'HEAD' 'INFO' ((git rev-parse HEAD).Trim())

$Required = @(
    'lib/features/ai_platform/services/truth_engine.dart',
    'lib/features/ai_platform/services/body_twin_engine.dart',
    'lib/features/ai_platform/services/one_best_action_engine.dart',
    'lib/features/ai_platform/services/physiological_reality_model.dart',
    'lib/features/ai_platform/services/personal_health_ai_engine.dart',
    'lib/features/ai_platform/services/truth_decision_explainer.dart',
    'lib/features/ai_platform/services/local_intelligence_reality_runtime.dart',
    'test/features/ai_platform/truth_engine_test.dart',
    'test/features/ai_platform/body_twin_engine_test.dart',
    'test/features/ai_platform/one_best_action_engine_test.dart',
    'test/features/ai_platform/physiological_reality_model_test.dart',
    'test/features/ai_platform/personal_health_ai_engine_test.dart'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
    Record 'Required files' 'FAILED' ($Missing -join ', ')
    throw "Required AI files missing: $($Missing -join ', ')"
}
Record 'Required files' 'PASSED' "$($Required.Count) files"

Write-Host "`n=== Canonical Dart formatting ===" -ForegroundColor Cyan
$FormatTargets = @(
    'lib/features/ai_platform',
    'test/features/ai_platform'
)
& dart format @FormatTargets
if ($LASTEXITCODE -ne 0) { Record 'Canonical Dart formatting' 'FAILED'; throw 'Canonical Dart formatting failed' }
Record 'Canonical Dart formatting' 'PASSED'

Write-Host "`n=== Non-mutating Dart format gate ===" -ForegroundColor Cyan
& dart format --output=none --set-exit-if-changed @FormatTargets
if ($LASTEXITCODE -ne 0) { Record 'Non-mutating Dart format gate' 'FAILED'; throw 'Non-mutating Dart format gate failed' }
Record 'Non-mutating Dart format gate' 'PASSED'

Write-Host "`n=== Flutter analyze ===" -ForegroundColor Cyan
& flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { Record 'Flutter analyze' 'FAILED'; throw 'Flutter analyze failed' }
Record 'Flutter analyze' 'PASSED'

Write-Host "`n=== AI platform test suite ===" -ForegroundColor Cyan
& flutter test --no-pub test/features/ai_platform
if ($LASTEXITCODE -ne 0) { Record 'AI platform tests' 'FAILED'; throw 'AI platform tests failed' }
Record 'AI platform tests' 'PASSED'

Write-Host "`n=== Intelligence integration tests ===" -ForegroundColor Cyan
$IntegrationTests = @(
    'test/features/ai_platform/bil_intelligence_integration_system_test.dart',
    'test/features/ai_platform/local_intelligence_runtime_system_test.dart',
    'test/features/ai_platform/local_intelligence_reality_runtime_test.dart',
    'test/dashboard_analytics_reuse_test.dart'
)
& flutter test --no-pub @IntegrationTests
if ($LASTEXITCODE -ne 0) { Record 'Intelligence integration tests' 'FAILED'; throw 'Intelligence integration tests failed' }
Record 'Intelligence integration tests' 'PASSED'

Write-Host "`n=== Determinism and evidence regression ===" -ForegroundColor Cyan
$RegressionTests = @(
    'test/features/ai_platform/truth_engine_regression_test.dart',
    'test/features/ai_platform/body_twin_engine_regression_test.dart',
    'test/features/ai_platform/one_best_action_engine_regression_test.dart',
    'test/features/ai_platform/truth_decision_explainer_regression_test.dart',
    'test/features/ai_platform/physiological_reality_model_test.dart',
    'test/features/ai_platform/personal_health_ai_engine_test.dart'
)
& flutter test --no-pub @RegressionTests
if ($LASTEXITCODE -ne 0) { Record 'AI regression tests' 'FAILED'; throw 'AI regression tests failed' }
Record 'AI regression tests' 'PASSED'

Write-Host "`n=== Diff hygiene ===" -ForegroundColor Cyan
& git diff --check
if ($LASTEXITCODE -ne 0) { Record 'Diff hygiene' 'FAILED'; throw 'Diff hygiene failed' }
Record 'Diff hygiene' 'PASSED'
Record 'BIL-ENGINEERING-AUDIT-003' 'PASSED' 'AI engines, explainability, physiological reality, Body Twin and One Best Action verified'
Write-Host 'BIL-ENGINEERING-AUDIT-003 VERIFY: PASSED' -ForegroundColor Green
