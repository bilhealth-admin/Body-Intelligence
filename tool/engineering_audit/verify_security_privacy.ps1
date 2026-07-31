param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot 'artifacts\engineering_audit'
$ReportPath = Join-Path $ReportRoot 'BIL-ENGINEERING-AUDIT-005-report.txt'
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

function Record([string]$Name, [string]$Status, [string]$Detail = '') {
    $line = "$Name`t$Status"
    if ($Detail) { $line += "`t$Detail" }
    $line | Tee-Object -FilePath $ReportPath -Append
}

'BIL-ENGINEERING-AUDIT-005' | Set-Content $ReportPath
Record 'Branch' 'INFO' ((git branch --show-current).Trim())
Record 'HEAD' 'INFO' ((git rev-parse HEAD).Trim())

$Required = @(
    'lib/features/global_platform/security/global_secure_vault.dart',
    'lib/features/cloud_platform/services/cloud_privacy_lifecycle_engine.dart',
    'lib/features/ai_platform/domain/decision_memory_retention.dart',
    'lib/features/ai_platform/services/decision_memory_retention_engine.dart',
    'lib/features/auth/login_page.dart',
    'test/auth_boundary_test.dart',
    'test/features/global_platform/cloud_ai_privacy_recovery_system_test.dart',
    'test/features/global_platform/global_security_regression_test.dart',
    'test/features/ai_platform/decision_memory_retention_engine_test.dart',
    'test/features/ai_platform/decision_memory_retention_engine_regression_test.dart'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
    Record 'Required files' 'FAILED' ($Missing -join ', ')
    throw "Required security/privacy files missing: $($Missing -join ', ')"
}
Record 'Required files' 'PASSED' "$($Required.Count) files"

Write-Host "`n=== High-confidence secret scan ===" -ForegroundColor Cyan
$Tracked = @(git ls-files)
$SecretPatterns = @(
    '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
    'AKIA[0-9A-Z]{16}',
    'ASIA[0-9A-Z]{16}',
    'gh[pousr]_[A-Za-z0-9]{30,}',
    'sk_live_[A-Za-z0-9]{16,}',
    'AIza[0-9A-Za-z_-]{35}'
)
$SecretHits = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $Tracked) {
    if ($relative -match '(^|/)(build|artifacts|\.dart_tool|\.gradle)/') { continue }
    $path = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    try { $text = Get-Content -LiteralPath $path -Raw -ErrorAction Stop } catch { continue }
    foreach ($pattern in $SecretPatterns) {
        if ($text -match $pattern) {
            $SecretHits.Add("$relative :: $pattern")
        }
    }
}
if ($SecretHits.Count -gt 0) {
    Record 'Secret signatures' 'FAILED' ($SecretHits -join '; ')
    throw "High-confidence secret material found:`n$($SecretHits -join "`n")"
}
Record 'Secret signatures' 'PASSED' 'No private keys or high-confidence provider tokens found in tracked files'

Write-Host "`n=== Canonical Dart formatting ===" -ForegroundColor Cyan
$FormatTargets = @(
    'lib/features/global_platform/security',
    'lib/features/cloud_platform/services/cloud_privacy_lifecycle_engine.dart',
    'lib/features/ai_platform/domain/decision_memory_retention.dart',
    'lib/features/ai_platform/services/decision_memory_retention_engine.dart',
    'lib/features/auth',
    'test/auth_boundary_test.dart',
    'test/features/global_platform/cloud_ai_privacy_recovery_system_test.dart',
    'test/features/global_platform/global_security_regression_test.dart',
    'test/features/ai_platform/decision_memory_retention_engine_test.dart',
    'test/features/ai_platform/decision_memory_retention_engine_regression_test.dart'
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

Write-Host "`n=== Authentication boundary ===" -ForegroundColor Cyan
& flutter test --no-pub 'test/auth_boundary_test.dart'
if ($LASTEXITCODE -ne 0) { Record 'Authentication boundary' 'FAILED'; throw 'Authentication boundary tests failed' }
Record 'Authentication boundary' 'PASSED'

Write-Host "`n=== Cloud privacy and redaction ===" -ForegroundColor Cyan
& flutter test --no-pub 'test/features/global_platform/cloud_ai_privacy_recovery_system_test.dart'
if ($LASTEXITCODE -ne 0) { Record 'Cloud privacy and redaction' 'FAILED'; throw 'Cloud privacy/redaction tests failed' }
Record 'Cloud privacy and redaction' 'PASSED'

Write-Host "`n=== Security primitives ===" -ForegroundColor Cyan
& flutter test --no-pub 'test/features/global_platform/global_security_regression_test.dart'
if ($LASTEXITCODE -ne 0) { Record 'Security primitives' 'FAILED'; throw 'Security primitive tests failed' }
Record 'Security primitives' 'PASSED'

Write-Host "`n=== Decision Memory retention ===" -ForegroundColor Cyan
$RetentionTests = @(
    'test/features/ai_platform/decision_memory_retention_engine_test.dart',
    'test/features/ai_platform/decision_memory_retention_engine_regression_test.dart'
)
& flutter test --no-pub @RetentionTests
if ($LASTEXITCODE -ne 0) { Record 'Decision Memory retention' 'FAILED'; throw 'Decision Memory retention tests failed' }
Record 'Decision Memory retention' 'PASSED'

Write-Host "`n=== Diff hygiene ===" -ForegroundColor Cyan
& git diff --check
if ($LASTEXITCODE -ne 0) { Record 'Diff hygiene' 'FAILED'; throw 'Diff hygiene failed' }
Record 'Diff hygiene' 'PASSED'
Record 'BIL-ENGINEERING-AUDIT-005' 'PASSED' 'Security boundaries, secrets hygiene, privacy gates, retention and local data protection verified'
Write-Host 'BIL-ENGINEERING-AUDIT-005 VERIFY: PASSED' -ForegroundColor Green
