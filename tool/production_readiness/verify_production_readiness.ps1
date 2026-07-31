param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$reportDir = Join-Path $ProjectRoot 'artifacts/production_readiness'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$report = Join-Path $reportDir 'BIL-PRODUCTION-READINESS-001-report.txt'
Remove-Item $report -Force -ErrorAction SilentlyContinue
function Add-Result([string]$Name,[string]$Status,[string]$Detail='') { "$Name`t$Status`t$Detail" | Tee-Object -FilePath $report -Append }
function Run-Flutter([string[]]$Args,[string]$Name) { & flutter @Args; if ($LASTEXITCODE -ne 0) { Add-Result $Name 'FAILED' "exit=$LASTEXITCODE"; throw "$Name failed" }; Add-Result $Name 'PASSED' }
$required = @(
 'pubspec.yaml','android/app/src/main/AndroidManifest.xml','android/app/src/main/res/xml/locales_config.xml',
 'ios/Runner/Info.plist','test/production_readiness/production_metadata_contract_test.dart'
)
$missing=@($required|?{-not(Test-Path -LiteralPath (Join-Path $ProjectRoot $_))})
if($missing.Count){Add-Result 'Required files' 'FAILED' ($missing -join ', ');throw "Missing required files: $($missing -join ', ')"}
Add-Result 'Required files' 'PASSED' "$($required.Count) files"
$manifest=Get-Content 'android/app/src/main/AndroidManifest.xml' -Raw
if($manifest -notmatch 'android:localeConfig="@xml/locales_config"' -or $manifest -notmatch 'android:supportsRtl="true"'){throw 'Android locale metadata missing'}
if($manifest -notmatch 'android.hardware.bluetooth_le" android:required="false"'){throw 'BLE optional feature declaration missing'}
Add-Result 'Android manifest production metadata' 'PASSED'
[xml](Get-Content 'ios/Runner/Info.plist' -Raw) | Out-Null
Add-Result 'iOS plist XML' 'PASSED'
Run-Flutter @('analyze','--no-pub') 'Flutter analyze'
Run-Flutter @('test','--no-pub','test/release_metadata_test.dart','test/localization_test.dart','test/mojibake_regression_test.dart','test/production_readiness/production_metadata_contract_test.dart') 'Production metadata and localization tests'
Run-Flutter @('build','apk','--debug','--no-pub') 'Android debug build'
$tracked=@(git diff --name-only)
$allowed=@('pubspec.yaml','android/app/src/main/AndroidManifest.xml','android/app/src/main/res/xml/locales_config.xml','ios/Runner/Info.plist','test/production_readiness/production_metadata_contract_test.dart','tool/production_readiness/verify_production_readiness.ps1','docs/production_readiness/BIL_PRODUCTION_READINESS_001.md')
$bad=@($tracked|?{$_ -notin $allowed -and $_ -notmatch '^(linux|macos|windows)/flutter/generated_'})
if($bad.Count){Add-Result 'Diff hygiene' 'FAILED' ($bad -join ', ');throw "Unexpected tracked changes: $($bad -join ', ')"}
Add-Result 'Diff hygiene' 'PASSED'
Add-Result 'BIL-PRODUCTION-READINESS-001' 'PASSED' 'Locale metadata, BLE capability honesty, release metadata, localization, analysis and Android debug build verified'
Write-Host 'BIL-PRODUCTION-READINESS-001 VERIFY: PASSED'
