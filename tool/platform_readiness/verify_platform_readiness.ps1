param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportDirectory = Join-Path $ProjectRoot 'artifacts\platform_readiness'
$ReportPath = Join-Path $ReportDirectory 'BIL-PLATFORM-READINESS-001-report.txt'
New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
Set-Content -LiteralPath $ReportPath -Value 'BIL-PLATFORM-READINESS-001'

function Add-Result([string]$Name, [string]$Status, [string]$Detail = '') {
    $Line = "$Name`t$Status"
    if ($Detail) { $Line += "`t$Detail" }
    Add-Content -LiteralPath $ReportPath -Value $Line
    Write-Host $Line
}

$RequiredFiles = @(
    'lib/app/environment/platform_readiness.dart',
    'lib/app/environment/release_configuration_validator.dart',
    'test/platform_readiness/platform_readiness_contract_test.dart',
    'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'ios/Runner/Info.plist'
)
$Missing = @($RequiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_)) })
if ($Missing.Count -gt 0) { throw "Required files missing:`n$($Missing -join "`n")" }
Add-Result 'Required files' 'PASSED' "$($RequiredFiles.Count) files"

& flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed' }
Add-Result 'Flutter analyze' 'PASSED'

& flutter test --no-pub test/platform_readiness/platform_readiness_contract_test.dart test/external_policy_test.dart test/release_metadata_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Platform readiness tests failed' }
Add-Result 'Platform readiness contracts' 'PASSED'

& flutter build apk --debug --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Android debug build failed' }
Add-Result 'Android debug build' 'PASSED'

$Forbidden = @(
    git diff --name-only -- . ':!lib/app/environment/platform_readiness.dart' ':!lib/app/environment/release_configuration_validator.dart' ':!test/platform_readiness/platform_readiness_contract_test.dart' ':!tool/platform_readiness/verify_platform_readiness.ps1' ':!docs/platform_readiness/BIL_PLATFORM_READINESS_001.md'
)
$Forbidden = @($Forbidden | Where-Object { $_ -and $_ -notmatch '^(linux|macos|windows)/flutter/generated_' })
if ($Forbidden.Count -gt 0) { throw "Forbidden diff detected:`n$($Forbidden -join "`n")" }
Add-Result 'Diff hygiene' 'PASSED'

Add-Result 'BIL-PLATFORM-READINESS-001' 'PASSED' 'Capability honesty and release configuration boundaries verified'
Write-Host 'BIL-PLATFORM-READINESS-001 VERIFY: PASSED'
