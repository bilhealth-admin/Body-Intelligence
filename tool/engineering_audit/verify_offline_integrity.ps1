param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot 'artifacts\engineering_audit'
$ReportPath = Join-Path $ReportRoot 'BIL-ENGINEERING-AUDIT-004-report.txt'
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

function Record([string]$Name, [string]$Status, [string]$Detail = '') {
    $line = "$Name`t$Status"
    if ($Detail) { $line += "`t$Detail" }
    $line | Tee-Object -FilePath $ReportPath -Append
}

'BIL-ENGINEERING-AUDIT-004' | Set-Content $ReportPath
Record 'Branch' 'INFO' ((git branch --show-current).Trim())
Record 'HEAD' 'INFO' ((git rev-parse HEAD).Trim())

$Required = @(
    'lib/features/cloud_platform/services/offline_first_cloud_platform.dart',
    'lib/features/cloud_platform/services/durable_offline_first_cloud_platform.dart',
    'lib/features/cloud_platform/services/cloud_conflict_resolver.dart',
    'lib/features/cloud_platform/services/cloud_backup_restore_engine.dart',
    'lib/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart',
    'lib/features/cloud_platform/domain/cloud_sync_models.dart',
    'lib/app/services/local_recovery_service.dart',
    'lib/engine/recovery_engine.dart',
    'lib/engine/sync_conflict_engine.dart',
    'test/features/cloud_platform/offline_first_cloud_platform_test.dart',
    'test/features/cloud_platform/durable_cloud_runtime_test.dart',
    'test/features/cloud_platform/cloud_conflict_resolver_regression_test.dart',
    'test/features/cloud_platform/cloud_backup_restore_system_test.dart',
    'test/local_recovery_service_test.dart'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
    Record 'Required files' 'FAILED' ($Missing -join ', ')
    throw "Required offline/sync files missing: $($Missing -join ', ')"
}
Record 'Required files' 'PASSED' "$($Required.Count) files"

Write-Host "`n=== Canonical Dart formatting ===" -ForegroundColor Cyan
$FormatTargets = @(
    'lib/features/cloud_platform',
    'lib/app/services/local_recovery_service.dart',
    'lib/engine/recovery_engine.dart',
    'lib/engine/sync_conflict_engine.dart',
    'test/features/cloud_platform',
    'test/local_recovery_service_test.dart',
    'test/daily_log_recovery_test.dart',
    'test/analytics_recovery_test.dart'
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

Write-Host "`n=== Offline-first cloud runtime ===" -ForegroundColor Cyan
$OfflineTests = @(
    'test/features/cloud_platform/offline_first_cloud_platform_test.dart',
    'test/features/cloud_platform/durable_cloud_runtime_test.dart',
    'test/features/cloud_platform/sqlite_cloud_platform_store_test.dart'
)
& flutter test --no-pub @OfflineTests
if ($LASTEXITCODE -ne 0) { Record 'Offline-first runtime' 'FAILED'; throw 'Offline-first runtime tests failed' }
Record 'Offline-first runtime' 'PASSED'

Write-Host "`n=== Conflict resolution and contracts ===" -ForegroundColor Cyan
$ConflictTests = @(
    'test/features/cloud_platform/cloud_conflict_resolver_regression_test.dart',
    'test/features/cloud_platform/cloud_platform_contract_regression_test.dart',
    'test/features/cloud_platform/cloud_platform_closure_regression_test.dart'
)
& flutter test --no-pub @ConflictTests
if ($LASTEXITCODE -ne 0) { Record 'Conflict resolution' 'FAILED'; throw 'Conflict resolution tests failed' }
Record 'Conflict resolution' 'PASSED'

Write-Host "`n=== Backup, restore and recovery ===" -ForegroundColor Cyan
$RecoveryTests = @(
    'test/features/cloud_platform/cloud_backup_restore_system_test.dart',
    'test/local_recovery_service_test.dart',
    'test/daily_log_recovery_test.dart',
    'test/analytics_recovery_test.dart',
    'test/onboarding_recovery_test.dart'
)
& flutter test --no-pub @RecoveryTests
if ($LASTEXITCODE -ne 0) { Record 'Recovery and restore' 'FAILED'; throw 'Recovery and restore tests failed' }
Record 'Recovery and restore' 'PASSED'

Write-Host "`n=== Global atomic persistence regression ===" -ForegroundColor Cyan
$AtomicTests = @(
    'test/features/global_platform/atomic_cas_migration_integrity_test.dart',
    'test/features/global_platform/global_typed_repository_test.dart',
    'test/features/global_platform/cloud_ai_privacy_recovery_system_test.dart'
)
& flutter test --no-pub @AtomicTests
if ($LASTEXITCODE -ne 0) { Record 'Atomic persistence regression' 'FAILED'; throw 'Atomic persistence tests failed' }
Record 'Atomic persistence regression' 'PASSED'

Write-Host "`n=== Diff hygiene ===" -ForegroundColor Cyan
& git diff --check
if ($LASTEXITCODE -ne 0) { Record 'Diff hygiene' 'FAILED'; throw 'Diff hygiene failed' }
Record 'Diff hygiene' 'PASSED'
Record 'BIL-ENGINEERING-AUDIT-004' 'PASSED' 'Offline-first runtime, synchronization, conflict resolution, recovery, replay and persistence integrity verified'
Write-Host 'BIL-ENGINEERING-AUDIT-004 VERIFY: PASSED' -ForegroundColor Green
