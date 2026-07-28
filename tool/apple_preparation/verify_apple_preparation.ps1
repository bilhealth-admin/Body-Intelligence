param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference='Stop'
Set-Location $ProjectRoot
$report=Join-Path $ProjectRoot 'artifacts\apple_preparation\BIL-APPLE-PREPARATION-001-report.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $report) | Out-Null
$lines=@()
function Pass([string]$n,[string]$d=''){ $script:lines += "$n`tPASSED`t$d"; Write-Host "$n`tPASSED`t$d" }
$required=@('ios/Runner.xcodeproj/project.pbxproj','ios/Runner/PrivacyInfo.xcprivacy','ios/Runner/en.lproj/InfoPlist.strings','ios/Runner/ar.lproj/InfoPlist.strings','ios/Runner/Info.plist','ios/Runner/Runner.entitlements')
$missing=@($required|?{-not(Test-Path $_)})
if($missing){throw "Missing Apple preparation files:`n$($missing -join "`n")"}; Pass 'Required files' "$($required.Count) files"
$pbx=Get-Content 'ios/Runner.xcodeproj/project.pbxproj' -Raw
if($pbx -match 'IPHONEOS_DEPLOYMENT_TARGET = 13\.0;' -or ([regex]::Matches($pbx,'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').Count -lt 3)){throw 'iOS deployment target is not consistently 15.0'}; Pass 'iOS deployment target' '15.0'
python -c "import plistlib; [plistlib.load(open(p,'rb')) for p in ['ios/Runner/Info.plist','ios/Runner/Runner.entitlements','ios/Runner/PrivacyInfo.xcprivacy']]"; if($LASTEXITCODE){throw 'Apple plist validation failed'}; Pass 'Apple plist validation'
if($pbx -notmatch 'PrivacyInfo.xcprivacy in Resources' -or $pbx -notmatch 'InfoPlist.strings in Resources'){throw 'Apple resources are not linked to Runner'}; Pass 'Runner resource linkage'
flutter analyze --no-pub; if($LASTEXITCODE){throw 'Flutter analyze failed'}; Pass 'Flutter analyze'
flutter test --no-pub test/apple_preparation/apple_preparation_contract_test.dart; if($LASTEXITCODE){throw 'Apple preparation contracts failed'}; Pass 'Apple preparation contracts'
$allowed=@('ios/Runner.xcodeproj/project.pbxproj','ios/Runner/PrivacyInfo.xcprivacy','ios/Runner/en.lproj/InfoPlist.strings','ios/Runner/ar.lproj/InfoPlist.strings','test/apple_preparation/apple_preparation_contract_test.dart','tool/apple_preparation/verify_apple_preparation.ps1','docs/apple_preparation/BIL_APPLE_PREPARATION_001.md','docs/apple_preparation/PRIVACY_POLICY_DRAFT.md','docs/apple_preparation/APP_PRIVACY_DRAFT.md')
$changed=@(git diff --name-only)+@(git ls-files --others --exclude-standard)
$unexpected=@($changed|?{$_ -notin $allowed -and $_ -notlike 'artifacts/*'})
if($unexpected){throw "Unexpected diff scope:`n$($unexpected -join "`n")"}; Pass 'Diff hygiene'
$lines | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host 'BIL-APPLE-PREPARATION-001 VERIFY: PASSED'
