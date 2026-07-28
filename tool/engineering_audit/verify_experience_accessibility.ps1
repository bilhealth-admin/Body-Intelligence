param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot 'artifacts\engineering_audit'
$ReportPath = Join-Path $ReportRoot 'BIL-ENGINEERING-AUDIT-007-report.txt'
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

function Record([string]$Name, [string]$Status, [string]$Detail = '') {
    $line = "$Name`t$Status"
    if ($Detail) { $line += "`t$Detail" }
    $line | Tee-Object -FilePath $ReportPath -Append
}


function Clear-WindowsNativeAssets {
    if (-not $IsWindows) { return }

    Get-Process body_intelligence_log, flutter_tester -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Milliseconds 750

    $Targets = @(
        (Join-Path $ProjectRoot 'build\native_assets\windows'),
        (Join-Path $ProjectRoot 'build\windows')
    )

    foreach ($Target in $Targets) {
        if (-not (Test-Path -LiteralPath $Target)) { continue }

        $Removed = $false
        for ($Attempt = 1; $Attempt -le 6; $Attempt++) {
            try {
                Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction Stop
                $Removed = $true
                break
            } catch {
                if ($Attempt -eq 6) {
                    Record 'Windows native-assets cleanup' 'FAILED' $Target
                    throw "Unable to remove locked Flutter build output after $Attempt attempts: $Target"
                }
                Start-Sleep -Milliseconds (500 * $Attempt)
            }
        }

        if ($Removed) {
            Write-Host "Removed stale Windows build output: $Target"
        }
    }

    Record 'Windows native-assets cleanup' 'PASSED'
}

function Run-Flutter([string]$Name, [string[]]$Arguments) {
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        Record $Name 'FAILED' ("exit={0}" -f $LASTEXITCODE)
        throw "$Name failed"
    }
    Record $Name 'PASSED'
}

'BIL-ENGINEERING-AUDIT-007' | Set-Content -LiteralPath $ReportPath
Record 'Branch' 'INFO' ((git branch --show-current).Trim())
Record 'HEAD' 'INFO' ((git rev-parse HEAD).Trim())
Record 'Flutter command' 'INFO' ((Get-Command flutter).Source)
Record 'Dart command' 'INFO' ((Get-Command dart).Source)
Record 'Flutter test platform' 'INFO' 'Flutter test default local platform; --platform vm is unsupported'

$Required = @(
    'lib/app/localization/app_localizations.dart',
    'lib/app/router/responsive_app_shell.dart',
    'lib/shared/widgets/secondary_page_app_bar.dart',
    'lib/features/startup/startup_page.dart',
    'test/localization_test.dart',
    'test/mojibake_regression_test.dart',
    'test/localized_confidence_test.dart',
    'test/responsive_shell_test.dart',
    'test/secondary_page_navigation_test.dart',
    'test/startup_state_test.dart',
    'test/profile_experience_contract_test.dart',
    'test/welcome_responsive_test.dart',
    'test/welcome_golden_test.dart'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
    Record 'Required files' 'FAILED' ($Missing -join ', ')
    throw "Required experience/accessibility files missing: $($Missing -join ', ')"
}
Record 'Required files' 'PASSED' "$($Required.Count) files"

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot '.dart_tool\package_config.json') -PathType Leaf)) {
    Run-Flutter 'Dependency resolution' @('pub', 'get')
} else {
    Record 'Dependency resolution' 'PASSED' 'Existing package_config.json'
}

$FormatTargets = @(
    'lib/app/localization/app_localizations.dart',
    'lib/app/router/responsive_app_shell.dart',
    'lib/shared/widgets/secondary_page_app_bar.dart',
    'lib/features/startup/startup_page.dart',
    'test/localization_test.dart',
    'test/mojibake_regression_test.dart',
    'test/localized_confidence_test.dart',
    'test/responsive_shell_test.dart',
    'test/secondary_page_navigation_test.dart',
    'test/startup_state_test.dart',
    'test/profile_experience_contract_test.dart',
    'test/welcome_responsive_test.dart',
    'test/welcome_golden_test.dart'
)

Write-Host "`n=== Non-mutating Dart format gate ===" -ForegroundColor Cyan
& dart format --output=none --set-exit-if-changed @FormatTargets
if ($LASTEXITCODE -ne 0) {
    Record 'Non-mutating Dart format gate' 'FAILED'
    throw 'Non-mutating Dart format gate failed'
}
Record 'Non-mutating Dart format gate' 'PASSED'

Run-Flutter 'Flutter analyze' @('analyze', '--no-pub')

Clear-WindowsNativeAssets

$LocalizationTests = @(
    'test/localization_test.dart',
    'test/mojibake_regression_test.dart',
    'test/localized_confidence_test.dart'
)
Run-Flutter 'Localization, Arabic and mojibake integrity' (@('test', '--no-pub') + $LocalizationTests)

$ShellTests = @(
    'test/responsive_shell_test.dart',
    'test/secondary_page_navigation_test.dart',
    'test/startup_state_test.dart',
    'test/profile_experience_contract_test.dart'
)
Run-Flutter 'Responsive shell, navigation and startup integrity' (@('test', '--no-pub') + $ShellTests)

$WelcomeTests = @(
    'test/welcome_responsive_test.dart',
    'test/welcome_golden_test.dart'
)
Run-Flutter 'Welcome responsive and golden integrity' (@('test', '--no-pub') + $WelcomeTests)

Record 'Web build gate' 'NOT_APPLICABLE' 'Web is not a supported release platform in this baseline; native SQLite/FFI persistence is Windows/Android only'
Run-Flutter 'Windows debug build' @('build', 'windows', '--debug', '--no-pub')

Write-Host "`n=== Diff hygiene ===" -ForegroundColor Cyan
& git diff --check
if ($LASTEXITCODE -ne 0) {
    Record 'Diff hygiene' 'FAILED'
    throw 'Diff hygiene failed'
}
Record 'Diff hygiene' 'PASSED'
Record 'BIL-ENGINEERING-AUDIT-007' 'PASSED' 'Localization, RTL, responsive shell, navigation, startup, Welcome goldens and Windows build verified; Web explicitly excluded because native SQLite/FFI persistence is not a supported browser target'
Write-Host 'BIL-ENGINEERING-AUDIT-007 VERIFY: PASSED' -ForegroundColor Green
