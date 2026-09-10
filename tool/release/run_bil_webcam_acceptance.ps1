[CmdletBinding()]
param(
    [ValidateSet('Inspect', 'Configure', 'Run', 'Restore')]
    [string]$Mode = 'Inspect',
    [string]$AvdName = 'BIL_Pixel_7_API_35',
    [string]$Serial = 'emulator-5554',
    [switch]$AllowDeviceExecution
)

$ErrorActionPreference = 'Stop'
if (-not $AllowDeviceExecution) {
    throw 'Device execution is opt-in and forbidden during a code-only audit.'
}
$sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { 'C:\Android\SDK' }
$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
$emulator = Join-Path $sdkRoot 'emulator\emulator.exe'
$avdConfig = Join-Path $env:USERPROFILE ".android\avd\$AvdName.avd\config.ini"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\artifacts\runtime_evidence')
)
$csvPath = Join-Path $evidenceRoot 'BIL_WEBCAM_ACCEPTANCE_RESULTS.csv'

foreach ($required in @($adb, $emulator, $avdConfig)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required path is missing: $required"
    }
}

$cameraLines = Select-String -LiteralPath $avdConfig -Pattern '^hw.camera.(back|front)='
Write-Output "AVD=$AvdName"
Write-Output "AVD_CONFIG=$avdConfig"
$cameraLines | ForEach-Object { Write-Output $_.Line }

if ($Mode -eq 'Restore') {
    $backup = "$avdConfig.pre-webcam.bak"
    if (-not (Test-Path -LiteralPath $backup)) {
        throw "No webcam configuration backup exists: $backup"
    }
    Copy-Item -LiteralPath $backup -Destination $avdConfig -Force
    Write-Output "RESTORED_AVD_CONFIG=$avdConfig"
    exit 0
}

if ($Mode -eq 'Inspect') {
    & $emulator -webcam-list 2>&1
    Write-Output 'INSPECT_ONLY=TRUE'
    Write-Output 'NEXT=Run this script with -Mode Configure only when all non-camera closure checks are complete.'
    exit 0
}

if ($Mode -eq 'Configure') {
    $backup = "$avdConfig.pre-webcam.bak"
    if (-not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $avdConfig -Destination $backup
    }
    $config = Get-Content -LiteralPath $avdConfig -Raw
    $config = [regex]::Replace($config, '(?m)^hw\.camera\.back=.*$', 'hw.camera.back=webcam0')
    Set-Content -LiteralPath $avdConfig -Value $config -Encoding UTF8
    Write-Output "CONFIGURED_BACK_CAMERA=webcam0"
    Write-Output "BACKUP=$backup"
    Write-Output 'NEXT=Cold-start the AVD, verify the camera preview, then run with -Mode Run.'
    exit 0
}

New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
& $emulator -webcam-list 2>&1 |
    Tee-Object -FilePath (Join-Path $evidenceRoot 'webcam-acceptance-list.txt')

$connected = & $adb devices
if ($connected -notmatch [regex]::Escape($Serial)) {
    throw "Expected device $Serial is not connected. Cold-start $AvdName after Configure mode."
}

$cameraPermission = & $adb -s $Serial shell dumpsys package com.bilhealth.bodyintelligencelog |
    Select-String 'android.permission.CAMERA: granted=true'
if (-not $cameraPermission) {
    throw 'BIL camera permission is not granted on the target emulator.'
}

$cases = @(
    1..10 | ForEach-Object { [pscustomobject]@{ case_id = "food-clear-$('{0:d2}' -f $_)"; category = 'food_clear' } }
) + @(
    1..5 | ForEach-Object { [pscustomobject]@{ case_id = "food-hard-$('{0:d2}' -f $_)"; category = 'food_hard' } }
) + @(
    1..5 | ForEach-Object { [pscustomobject]@{ case_id = "non-food-$('{0:d2}' -f $_)"; category = 'non_food' } }
) + @(
    1..5 | ForEach-Object { [pscustomobject]@{ case_id = "barcode-food-known-$('{0:d2}' -f $_)"; category = 'barcode_food_known' } }
) + @(
    1..3 | ForEach-Object { [pscustomobject]@{ case_id = "barcode-non-food-$('{0:d2}' -f $_)"; category = 'barcode_non_food' } }
) + @(
    1..3 | ForEach-Object { [pscustomobject]@{ case_id = "barcode-cache-miss-$('{0:d2}' -f $_)"; category = 'barcode_cache_miss' } }
)

if (-not (Test-Path -LiteralPath $csvPath)) {
    'timestamp_utc,case_id,category,camera_input_source,recognized_item,food_nonfood,barcode_result,cache_hit,gemini_fallback,model,input_tokens,output_tokens,latency_ms,cost_usd,success,quota_consumed,dedup_prevented,notes,evidence_file' |
        Set-Content -LiteralPath $csvPath -Encoding UTF8
}

foreach ($case in $cases) {
    Write-Host "`nCASE $($case.case_id) [$($case.category)]" -ForegroundColor Cyan
    Write-Host 'Present the assigned item to the laptop webcam and finish the in-app review/result flow.'
    Read-Host 'Press Enter after the result is visible' | Out-Null

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    $shot = Join-Path $evidenceRoot "webcam-$($case.case_id)-$stamp.png"
    $remoteShot = "/sdcard/$($case.case_id).png"
    & $adb -s $Serial shell screencap -p $remoteShot | Out-Null
    & $adb -s $Serial pull $remoteShot $shot | Out-Null
    & $adb -s $Serial shell rm $remoteShot | Out-Null

    $recognized = Read-Host 'recognized_item (short label)'
    $foodNonfood = Read-Host 'food/non-food (food|non-food|unknown)'
    $barcode = Read-Host 'barcode_result (GTIN/result or n/a)'
    $cache = Read-Host 'cache_hit (true|false|n/a)'
    $fallback = Read-Host 'gemini_fallback (true|false)'
    $model = Read-Host 'model (from server telemetry or n/a)'
    $inputTokens = Read-Host 'input_tokens (integer or 0)'
    $outputTokens = Read-Host 'output_tokens (integer or 0)'
    $latency = Read-Host 'latency_ms (integer)'
    $cost = Read-Host 'cost_usd (decimal or 0)'
    $success = Read-Host 'success (PASS|FAIL)'
    $quota = Read-Host 'quota_consumed (number)'
    $dedup = Read-Host 'dedup_prevented (true|false)'
    $notes = Read-Host 'notes (optional)'

    $row = [pscustomobject]@{
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
        case_id = $case.case_id
        category = $case.category
        camera_input_source = 'android_emulator_host_webcam0'
        recognized_item = $recognized
        food_nonfood = $foodNonfood
        barcode_result = $barcode
        cache_hit = $cache
        gemini_fallback = $fallback
        model = $model
        input_tokens = $inputTokens
        output_tokens = $outputTokens
        latency_ms = $latency
        cost_usd = $cost
        success = $success
        quota_consumed = $quota
        dedup_prevented = $dedup
        notes = $notes
        evidence_file = $shot
    }
    $row | Export-Csv -LiteralPath $csvPath -Append -NoTypeInformation -Encoding UTF8
}

$rows = Import-Csv -LiteralPath $csvPath
. (Join-Path $PSScriptRoot 'webcam_result_contract.ps1')
$failed = @($rows | Where-Object success -ne 'PASS')
Write-Output "TOTAL_CASES=$($rows.Count)"
Write-Output "PASS=$($rows.Count - $failed.Count)"
Write-Output "FAIL=$($failed.Count)"
Write-Output "RESULTS=$csvPath"
if ($rows.Count -ne 31 -or $failed.Count -gt 0) { exit 1 }
if (-not (Test-BilWebcamResultContract -Rows $rows -Cases $cases)) {
    throw 'Incomplete/duplicate case identities or missing/invalid telemetry.'
}
Write-Output 'REAL_CAMERA_ACCEPTANCE=PASS'
