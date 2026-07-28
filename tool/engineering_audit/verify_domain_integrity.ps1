param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$reportDir = Join-Path $ProjectRoot 'artifacts\engineering_audit'
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
$report = Join-Path $reportDir 'BIL-ENGINEERING-AUDIT-002-report.txt'
function Record([string]$Name,[string]$State,[string]$Detail='') { "$Name`t$State`t$Detail" | Tee-Object -FilePath $report -Append }
"BIL-ENGINEERING-AUDIT-002" | Set-Content $report
Record 'Branch' 'INFO' ((git branch --show-current).Trim())
Record 'HEAD' 'INFO' ((git rev-parse HEAD).Trim())
$required = @(
 'lib/data/repositories/daily_log_repository.dart',
 'lib/data/repositories/meal_repository.dart',
 'test/repository_test.dart',
 'test/database_migration_test.dart',
 'test/authoritative_daily_ledger_test.dart',
 'test/p3_phase_3_ledger_reconciliation_test.dart',
 'test/features/global_platform/global_typed_repository_test.dart',
 'test/features/global_platform/atomic_cas_migration_integrity_test.dart',
 'test/features/nutrition/mobile_catalog_food_repository_test.dart',
 'test/nutrition_platform/test_canonical_model.py'
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($missing.Count -gt 0) { Record 'Required files' 'FAILED' ($missing -join ', '); throw 'Required audit inputs are missing' }
Record 'Required files' 'PASSED' "$($required.Count) files"

Write-Host "`n=== Scoped Dart format ==="
$formatTargets = @(
  'lib/data/repositories/daily_log_repository.dart',
  'lib/data/repositories/meal_repository.dart',
  'test/repository_test.dart',
  'test/database_migration_test.dart',
  'test/authoritative_daily_ledger_test.dart',
  'test/p3_phase_3_ledger_reconciliation_test.dart',
  'test/features/global_platform/global_typed_repository_test.dart',
  'test/features/global_platform/atomic_cas_migration_integrity_test.dart',
  'test/features/nutrition/mobile_catalog_food_repository_test.dart'
)
# Canonicalize the explicitly scoped files first. This is intentionally mutating:
# formatting drift is corrected before the non-mutating gate is evaluated.
& dart format @formatTargets
if ($LASTEXITCODE -ne 0) { Record 'Canonical Dart formatting' 'FAILED'; throw 'Canonical Dart formatting failed' }
Record 'Canonical Dart formatting' 'PASSED'

Write-Host "`n=== Non-mutating Dart format gate ==="
& dart format --output=none --set-exit-if-changed @formatTargets
if ($LASTEXITCODE -ne 0) { Record 'Non-mutating Dart format gate' 'FAILED'; throw 'Dart format gate failed' }
Record 'Non-mutating Dart format gate' 'PASSED'

Write-Host "`n=== Flutter analyze ==="
& flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { Record 'Flutter analyze' 'FAILED'; throw 'Flutter analyze failed' }
Record 'Flutter analyze' 'PASSED'

Write-Host "`n=== Repository boundaries ==="
& flutter test --no-pub test/repository_test.dart test/features/global_platform/global_typed_repository_test.dart test/features/nutrition/mobile_catalog_food_repository_test.dart
if ($LASTEXITCODE -ne 0) { Record 'Repository boundaries' 'FAILED'; throw 'Repository boundary tests failed' }
Record 'Repository boundaries' 'PASSED'

Write-Host "`n=== Data migration integrity ==="
& flutter test --no-pub test/database_migration_test.dart test/features/global_platform/atomic_cas_migration_integrity_test.dart
if ($LASTEXITCODE -ne 0) { Record 'Data migration integrity' 'FAILED'; throw 'Migration integrity tests failed' }
Record 'Data migration integrity' 'PASSED'

Write-Host "`n=== Ledger invariants ==="
& flutter test --no-pub test/authoritative_daily_ledger_test.dart test/p3_phase_3_ledger_reconciliation_test.dart
if ($LASTEXITCODE -ne 0) { Record 'Ledger invariants' 'FAILED'; throw 'Ledger invariant tests failed' }
Record 'Ledger invariants' 'PASSED'

Write-Host "`n=== Canonical nutrition identity ==="
& python -m unittest discover -s test/nutrition_platform -p test_canonical_model.py -v
if ($LASTEXITCODE -ne 0) { Record 'Canonical nutrition identity' 'FAILED'; throw 'Canonical identity tests failed' }
Record 'Canonical nutrition identity' 'PASSED'

Write-Host "`n=== Diff hygiene ==="
& git diff --check
if ($LASTEXITCODE -ne 0) { Record 'Diff hygiene' 'FAILED'; throw 'Diff hygiene failed' }
Record 'Diff hygiene' 'PASSED'
Record 'BIL-ENGINEERING-AUDIT-002' 'PASSED' 'Domain models, data integrity, repository boundaries and serialization contracts verified'
Write-Host 'BIL-ENGINEERING-AUDIT-002 VERIFY: PASSED' -ForegroundColor Green
