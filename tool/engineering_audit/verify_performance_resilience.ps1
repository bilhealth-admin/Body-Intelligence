param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot 'artifacts\engineering_audit'
$ReportPath = Join-Path $ReportRoot 'BIL-ENGINEERING-AUDIT-006-report.txt'
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

function Record([string]$Name, [string]$Status, [string]$Detail = '') {
    $line = "$Name`t$Status"
    if ($Detail) { $line += "`t$Detail" }
    $line | Tee-Object -FilePath $ReportPath -Append
}

'BIL-ENGINEERING-AUDIT-006' | Set-Content $ReportPath
Record 'Branch' 'INFO' ((git branch --show-current).Trim())
Record 'HEAD' 'INFO' ((git rev-parse HEAD).Trim())

$Required = @(
    'lib/app/services/performance_budgets.dart',
    'test/performance_budget_test.dart',
    'test/performance_samples_regression_test.dart',
    'test/support/performance_samples.dart',
    'lib/features/nutrition/repositories/mobile_catalog_food_repository.dart',
    'test/features/nutrition/mobile_catalog_food_repository_test.dart',
    'lib/features/ai_platform/services/decision_memory_store.dart',
    'test/features/ai_platform/decision_memory_store_test.dart',
    'test/features/ai_platform/decision_memory_store_regression_test.dart',
    'test/local_recovery_service_test.dart'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
    Record 'Required files' 'FAILED' ($Missing -join ', ')
    throw "Required performance/resilience files missing: $($Missing -join ', ')"
}
Record 'Required files' 'PASSED' "$($Required.Count) files"

$FormatTargets = @(
    'lib/app/services/performance_budgets.dart',
    'test/performance_budget_test.dart',
    'test/performance_samples_regression_test.dart',
    'test/support/performance_samples.dart',
    'lib/features/nutrition/repositories/mobile_catalog_food_repository.dart',
    'test/features/nutrition/mobile_catalog_food_repository_test.dart',
    'lib/features/ai_platform/services/decision_memory_store.dart',
    'test/features/ai_platform/decision_memory_store_test.dart',
    'test/features/ai_platform/decision_memory_store_regression_test.dart',
    'test/local_recovery_service_test.dart'
)

Write-Host "`n=== Canonical Dart formatting ===" -ForegroundColor Cyan
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

Write-Host "`n=== Performance budgets ===" -ForegroundColor Cyan
& flutter test --no-pub 'test/performance_budget_test.dart' 'test/performance_samples_regression_test.dart'
if ($LASTEXITCODE -ne 0) { Record 'Performance budgets' 'FAILED'; throw 'Performance budget tests failed' }
Record 'Performance budgets' 'PASSED'

Write-Host "`n=== Mobile catalog runtime scalability contract ===" -ForegroundColor Cyan
& flutter test --no-pub 'test/features/nutrition/mobile_catalog_food_repository_test.dart'
if ($LASTEXITCODE -ne 0) { Record 'Mobile catalog runtime' 'FAILED'; throw 'Mobile catalog runtime tests failed' }
Record 'Mobile catalog runtime' 'PASSED'

Write-Host "`n=== Decision Memory store resilience ===" -ForegroundColor Cyan
$DecisionTests = @(
    'test/features/ai_platform/decision_memory_store_test.dart',
    'test/features/ai_platform/decision_memory_store_regression_test.dart'
)
& flutter test --no-pub @DecisionTests
if ($LASTEXITCODE -ne 0) { Record 'Decision Memory resilience' 'FAILED'; throw 'Decision Memory resilience tests failed' }
Record 'Decision Memory resilience' 'PASSED'

Write-Host "`n=== Local recovery runtime ===" -ForegroundColor Cyan
& flutter test --no-pub 'test/local_recovery_service_test.dart'
if ($LASTEXITCODE -ne 0) { Record 'Local recovery runtime' 'FAILED'; throw 'Local recovery runtime tests failed' }
Record 'Local recovery runtime' 'PASSED'

Write-Host "`n=== Android debug build ===" -ForegroundColor Cyan
& flutter build apk --debug --no-pub
if ($LASTEXITCODE -ne 0) { Record 'Android debug build' 'FAILED'; throw 'Android debug build failed' }
Record 'Android debug build' 'PASSED'

Write-Host "`n=== Diff hygiene ===" -ForegroundColor Cyan
& git diff --check
if ($LASTEXITCODE -ne 0) { Record 'Diff hygiene' 'FAILED'; throw 'Diff hygiene failed' }
Record 'Diff hygiene' 'PASSED'
Record 'BIL-ENGINEERING-AUDIT-006' 'PASSED' 'Performance budgets, memory-sensitive stores, catalog runtime, recovery and Android resilience verified'
Write-Host 'BIL-ENGINEERING-AUDIT-006 VERIFY: PASSED' -ForegroundColor Green
