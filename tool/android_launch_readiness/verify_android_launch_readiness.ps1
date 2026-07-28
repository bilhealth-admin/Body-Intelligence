param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot "artifacts\android_launch_readiness"
$ReportPath = Join-Path $ReportRoot "BIL-ANDROID-LAUNCH-READINESS-001-report.txt"
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
Remove-Item -LiteralPath $ReportPath -Force -ErrorAction SilentlyContinue

function Add-Result([string]$Name, [string]$Status, [string]$Detail = "") {
    $line = if ($Detail) { "$Name`t$Status`t$Detail" } else { "$Name`t$Status" }
    Add-Content -LiteralPath $ReportPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Invoke-Flutter([string[]]$Arguments, [string]$Name) {
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
    Add-Result $Name "PASSED"
}

$RequiredFiles = @(
    "android/app/build.gradle.kts",
    "android/app/src/main/AndroidManifest.xml",
    "android/app/src/main/kotlin/com/kadem/bil/PermissionsRationaleActivity.kt",
    "android/app/src/main/res/values/strings.xml",
    "android/app/src/main/res/values-ar/strings.xml",
    "test/android_launch_readiness/android_launch_contract_test.dart"
)
$Missing = @($RequiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_)) })
if ($Missing.Count -gt 0) { throw "Required files missing:`n$($Missing -join "`n")" }
Add-Result "Required files" "PASSED" "$($RequiredFiles.Count) files"

$Gradle = Get-Content -LiteralPath "android/app/build.gradle.kts" -Raw
$Manifest = Get-Content -LiteralPath "android/app/src/main/AndroidManifest.xml" -Raw
if ($Gradle -notmatch 'compileSdk\s*=\s*36' -or $Gradle -notmatch 'targetSdk\s*=\s*36') {
    throw "Android API 36 launch contract is missing"
}
Add-Result "Android API level" "PASSED" "compileSdk=36 targetSdk=36"

foreach ($Token in @(
    'androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE',
    'android.intent.action.VIEW_PERMISSION_USAGE',
    'android.intent.category.HEALTH_PERMISSIONS',
    'android.permission.START_VIEW_PERMISSION_USAGE'
)) {
    if (-not $Manifest.Contains($Token)) { throw "Health Connect rationale contract missing: $Token" }
}
Add-Result "Health Connect rationale" "PASSED"

Invoke-Flutter @("analyze", "--no-pub") "Flutter analyze"
Invoke-Flutter @("test", "--no-pub", "test/android_launch_readiness/android_launch_contract_test.dart", "test/features/global_platform/health_connect_runtime_test.dart") "Android launch contracts"
Invoke-Flutter @("build", "apk", "--debug", "--no-pub") "Android debug build"
Invoke-Flutter @("build", "appbundle", "--release", "--no-pub") "Android release app bundle"

$Bundle = Join-Path $ProjectRoot "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path -LiteralPath $Bundle)) { throw "Release app bundle was not created: $Bundle" }
Add-Result "Release AAB artifact" "PASSED" $Bundle

$Allowed = @(
    "android/app/build.gradle.kts",
    "android/app/src/main/AndroidManifest.xml",
    "android/app/src/main/kotlin/com/kadem/bil/PermissionsRationaleActivity.kt",
    "android/app/src/main/res/values/strings.xml",
    "android/app/src/main/res/values-ar/strings.xml",
    "test/android_launch_readiness/android_launch_contract_test.dart",
    "tool/android_launch_readiness/verify_android_launch_readiness.ps1",
    "docs/android_launch_readiness/BIL_ANDROID_LAUNCH_READINESS_001.md"
)

# Query tracked and untracked files separately. This avoids Git's directory
# collapsing for untracked content and avoids fragile porcelain substring parsing.
$TrackedChanged = @(
    git diff --name-only --diff-filter=ACDMRTUXB HEAD -- |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object { $_ }
)
$UntrackedChanged = @(
    git ls-files --others --exclude-standard -- |
        ForEach-Object { $_.Trim().Replace("\", "/") } |
        Where-Object { $_ -and -not $_.StartsWith("artifacts/") }
)
$Changed = @($TrackedChanged + $UntrackedChanged | Sort-Object -Unique)
$Unexpected = @($Changed | Where-Object { $_ -notin $Allowed })
$MissingExpected = @($Allowed | Where-Object { $_ -notin $Changed })

if ($Unexpected.Count -gt 0) {
    throw "Unexpected diff scope:`n$($Unexpected -join "`n")"
}
if ($MissingExpected.Count -gt 0) {
    throw "Expected package files are absent from diff scope:`n$($MissingExpected -join "`n")"
}
Add-Result "Diff hygiene" "PASSED"
Add-Result "BIL-ANDROID-LAUNCH-READINESS-001" "PASSED" "API 36, Health Connect rationale, debug APK and release AAB verified"
Write-Host "BIL-ANDROID-LAUNCH-READINESS-001 VERIFY: PASSED"
