param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot 'artifacts\startup_readiness'
$ReportPath = Join-Path $ReportRoot 'BIL-STARTUP-READINESS-001-report.txt'
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$Lines = New-Object System.Collections.Generic.List[string]

function Add-Result([string]$Name, [string]$Status, [string]$Detail = '') {
    $Line = "$Name`t$Status"
    if ($Detail) { $Line += "`t$Detail" }
    $Lines.Add($Line)
    Write-Host $Line
}

function Invoke-Checked([string]$Name, [scriptblock]$Command) {
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Add-Result $Name 'FAILED' "exit=$LASTEXITCODE"
        $Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
        throw "$Name failed"
    }
    Add-Result $Name 'PASSED'
}

$Branch = (git branch --show-current).Trim()
$Head = (git rev-parse HEAD).Trim()
Add-Result 'Branch' 'INFO' $Branch
Add-Result 'HEAD' 'INFO' $Head

$Required = @(
    '.github/workflows/verify.yml',
    'android/app/build.gradle.kts',
    'android/key.properties.example',
    'android/app/src/main/kotlin/com/kadem/bil/MainActivity.kt',
    'android/app/src/main/kotlin/com/kadem/bil/BILGlobalHealthBridge.kt',
    'android/app/src/main/kotlin/com/kadem/bil/BILMedicalBleBridge.kt',
    'ios/Runner/Info.plist'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
    Add-Result 'Required files' 'FAILED' ($Missing -join ', ')
    $Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    throw "Required files missing: $($Missing -join ', ')"
}
Add-Result 'Required files' 'PASSED' "$($Required.Count) files"

$Workflow = Get-Content -LiteralPath (Join-Path $ProjectRoot '.github/workflows/verify.yml') -Raw
if ($Workflow -notmatch 'phase-3-product-excellence' -or $Workflow -match 'branches:\s*\[foundation-v2\]') {
    throw 'CI branch contract is incorrect'
}
Add-Result 'CI branch contract' 'PASSED' 'phase-3-product-excellence'

$Gradle = Get-Content -LiteralPath (Join-Path $ProjectRoot 'android/app/build.gradle.kts') -Raw
if ($Gradle -match 'signingConfigs\.getByName\("debug"\)' -or $Gradle -notmatch 'key\.properties') {
    throw 'Android release signing boundary is incorrect'
}
Add-Result 'Android release signing boundary' 'PASSED' 'debug signing prohibited; optional private key.properties supported'

$LegacyAndroidPath = Join-Path $ProjectRoot 'android/app/src/main/kotlin/com/example/body_intelligence_log'
if (Test-Path -LiteralPath $LegacyAndroidPath) {
    $LegacyFiles = @(Get-ChildItem -LiteralPath $LegacyAndroidPath -File -ErrorAction SilentlyContinue)
    if ($LegacyFiles.Count -gt 0) { throw "Legacy Android package files remain: $($LegacyFiles.Name -join ', ')" }
}
$KotlinFiles = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'android/app/src/main/kotlin/com/kadem/bil') -Filter '*.kt' -File
foreach ($File in $KotlinFiles) {
    $Text = Get-Content -LiteralPath $File.FullName -Raw
    if ($Text -notmatch '^package com\.kadem\.bil' -or $Text -match 'com\.example\.body_intelligence_log') {
        throw "Android package mismatch: $($File.FullName)"
    }
}
Add-Result 'Android native package identity' 'PASSED' 'com.kadem.bil'

$PlistPath = Join-Path $ProjectRoot 'ios/Runner/Info.plist'
[xml]$Plist = Get-Content -LiteralPath $PlistPath -Raw
$PlistText = Get-Content -LiteralPath $PlistPath -Raw
$TopLevelKeys = @($Plist.plist.dict.key | ForEach-Object { [string]$_ })
foreach ($Key in @('NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription', 'NSBluetoothAlwaysUsageDescription', 'NSBluetoothPeripheralUsageDescription')) {
    $GlobalCount = ([regex]::Matches($PlistText, "<key>$Key</key>")).Count
    $TopLevelCount = @($TopLevelKeys | Where-Object { $_ -eq $Key }).Count
    if ($GlobalCount -ne 1 -or $TopLevelCount -ne 1) {
        throw "Expected exactly one top-level $Key entry; global=$GlobalCount topLevel=$TopLevelCount"
    }
}
Add-Result 'iOS privacy usage descriptions' 'PASSED' 'unique top-level HealthKit and Bluetooth keys'

Invoke-Checked 'Flutter analyze' { flutter analyze --no-pub }
Invoke-Checked 'Startup and external-boundary tests' {
    flutter test --no-pub `
        test/startup_state_test.dart `
        test/external_policy_test.dart `
        test/auth_boundary_test.dart `
        test/release_metadata_test.dart
}
Invoke-Checked 'Android debug build' { flutter build apk --debug --no-pub }

$AllowedChanged = @(
    '.github/workflows/verify.yml',
    'android/app/build.gradle.kts',
    'android/key.properties.example',
    'android/app/src/main/kotlin/com/kadem/bil/MainActivity.kt',
    'android/app/src/main/kotlin/com/kadem/bil/BILGlobalHealthBridge.kt',
    'android/app/src/main/kotlin/com/kadem/bil/BILMedicalBleBridge.kt',
    'ios/Runner/Info.plist',
    'tool/startup_readiness/verify_startup_readiness.ps1',
    'docs/startup_readiness/BIL_STARTUP_READINESS_001.md'
)
$DeletedExpected = @(
    'android/app/src/main/kotlin/com/example/body_intelligence_log/BILGlobalHealthBridge.kt',
    'android/app/src/main/kotlin/com/example/body_intelligence_log/BILMedicalBleBridge.kt'
)
$Changed = @(git status --porcelain=v1 --untracked-files=all)
$Unexpected = @()
foreach ($Line in $Changed) {
    if ($Line.Length -lt 4) { continue }
    $Path = $Line.Substring(3).Replace('\', '/')
    if ($Path.StartsWith('artifacts/')) { continue }
    if ($Path -notin $AllowedChanged -and $Path -notin $DeletedExpected) { $Unexpected += $Line }
}
if ($Unexpected.Count -gt 0) {
    Add-Result 'Diff hygiene' 'FAILED' ($Unexpected -join ' | ')
    $Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    throw "Unexpected repository changes:`n$($Unexpected -join "`n")"
}
Add-Result 'Diff hygiene' 'PASSED'
Add-Result 'BIL-STARTUP-READINESS-001' 'PASSED' 'CI, Android release signing, native package identity, iOS privacy metadata, tests and Android debug build verified'
$Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host 'BIL-STARTUP-READINESS-001 VERIFY: PASSED' -ForegroundColor Green
