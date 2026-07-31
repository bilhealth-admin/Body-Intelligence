param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ReportDir = Join-Path $ProjectRoot 'artifacts\google_play_preparation'
$ReportPath = Join-Path $ReportDir 'BIL-GOOGLE-PLAY-PREPARATION-001-report.txt'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Lines = [System.Collections.Generic.List[string]]::new()
function Record([string]$Name, [string]$State, [string]$Detail = '') {
    $line = "$Name`t$State"
    if ($Detail) { $line += "`t$Detail" }
    Write-Host $line
    $Lines.Add($line)
}
function Run-Flutter([string[]]$Arguments, [string]$Name) {
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) { Record $Name 'FAILED' "exit=$LASTEXITCODE"; throw "$Name failed" }
    Record $Name 'PASSED'
}

$Required = @(
    'pubspec.yaml',
    'lib/app/theme/bil_flagship_theme.dart',
    'test/google_play_preparation/google_play_preparation_contract_test.dart',
    'docs/google_play_preparation/BIL_GOOGLE_PLAY_PREPARATION_001.md',
    'docs/google_play_preparation/DATA_SAFETY_DRAFT.md',
    'docs/google_play_preparation/HEALTH_APPS_DECLARATION_DRAFT.md',
    'docs/google_play_preparation/PRIVACY_POLICY_REQUIREMENTS.md',
    'docs/google_play_preparation/STORE_LISTING_INVENTORY.md'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) { Record 'Required files' 'FAILED' ($Missing -join ', '); throw "Required files missing" }
Record 'Required files' 'PASSED' "$($Required.Count) files"

$Pubspec = Get-Content -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -Raw
$Theme = Get-Content -LiteralPath (Join-Path $ProjectRoot 'lib/app/theme/bil_flagship_theme.dart') -Raw
if ($Pubspec -match '(?m)^\s*google_fonts:' -or $Theme -match 'GoogleFonts\.|package:google_fonts') {
    Record 'Offline typography' 'FAILED' 'Runtime Google Fonts dependency remains'
    throw 'Runtime Google Fonts dependency remains'
}
if ($Pubspec -notmatch 'family:\s*NotoNaskhArabic' -or $Theme -notmatch "fontFamily:\s*'NotoNaskhArabic'") {
    Record 'Offline typography' 'FAILED' 'Bundled Arabic font is not wired'
    throw 'Bundled Arabic font is not wired'
}
Record 'Offline typography' 'PASSED' 'No runtime HTTP font dependency'

$ForbiddenTracked = @(
    git ls-files -- 'android/key.properties' 'android/app/*.jks' 'android/app/*.keystore' 'android/app/google-services.json'
)
if ($ForbiddenTracked.Count -gt 0) { Record 'Credential hygiene' 'FAILED' ($ForbiddenTracked -join ', '); throw 'Private Android credentials are tracked' }
Record 'Credential hygiene' 'PASSED'

Run-Flutter @('analyze','--no-pub') 'Flutter analyze'
Run-Flutter @('test','--no-pub','test/google_play_preparation/google_play_preparation_contract_test.dart','test/android_launch_readiness/android_launch_contract_test.dart') 'Google Play preparation contracts'
Run-Flutter @('build','appbundle','--release','--no-pub') 'Android release app bundle'

$Aab = Join-Path $ProjectRoot 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path -LiteralPath $Aab -PathType Leaf)) { Record 'Release AAB artifact' 'FAILED'; throw 'Release AAB missing' }
Record 'Release AAB artifact' 'PASSED' $Aab

$Allowed = @(
    'pubspec.yaml',
    'lib/app/theme/bil_flagship_theme.dart',
    'test/google_play_preparation/google_play_preparation_contract_test.dart',
    'tool/google_play_preparation/verify_google_play_preparation.ps1',
    'docs/google_play_preparation/BIL_GOOGLE_PLAY_PREPARATION_001.md',
    'docs/google_play_preparation/DATA_SAFETY_DRAFT.md',
    'docs/google_play_preparation/HEALTH_APPS_DECLARATION_DRAFT.md',
    'docs/google_play_preparation/PRIVACY_POLICY_REQUIREMENTS.md',
    'docs/google_play_preparation/STORE_LISTING_INVENTORY.md'
)
$Changed = @(
    git diff --name-only
    git ls-files --others --exclude-standard
) | Where-Object { $_ -and -not $_.StartsWith('artifacts/') } | Sort-Object -Unique
$Unexpected = @($Changed | Where-Object { $_ -notin $Allowed })
if ($Unexpected.Count -gt 0) { Record 'Diff hygiene' 'FAILED' ($Unexpected -join ', '); throw "Unexpected diff scope" }
Record 'Diff hygiene' 'PASSED'

Record 'BIL-GOOGLE-PLAY-PREPARATION-001' 'PASSED' 'Offline typography and truthful Play declaration inventory verified'
$Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host 'BIL-GOOGLE-PLAY-PREPARATION-001 VERIFY: PASSED'
