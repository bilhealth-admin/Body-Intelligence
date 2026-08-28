[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$PlanPath,
    [string]$LedgerPath,
    [string]$RunLogPath,
    [switch]$FullLocalHashValidation,
    [int]$StaleAfterMinutes = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
$artifactDirectory = Join-Path $RepositoryRoot 'artifacts\cloudflare_media'
if ([string]::IsNullOrWhiteSpace($PlanPath)) {
    $PlanPath = Join-Path $artifactDirectory 'media_upload_plan_v1.json'
}
if ([string]::IsNullOrWhiteSpace($LedgerPath)) {
    $LedgerPath = Join-Path $artifactDirectory 'media_upload_ledger_v1.ndjson'
}
if ([string]::IsNullOrWhiteSpace($RunLogPath)) {
    $RunLogPath = Join-Path $artifactDirectory 'media_upload_current.log'
}
if ($StaleAfterMinutes -lt 1) { throw 'StaleAfterMinutes must be positive.' }

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-SafeObjectKey([string]$ObjectKey) {
    if ([string]::IsNullOrWhiteSpace($ObjectKey) -or
        $ObjectKey.Contains('\') -or
        $ObjectKey.StartsWith('/') -or
        $ObjectKey.EndsWith('/') -or
        $ObjectKey -match '(^|/)\.\.?(/|$)' -or
        $ObjectKey -match '[\x00-\x1f\x7f]') {
        throw "Unsafe object key: $ObjectKey"
    }
}

if (!(Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
    Write-Host "UPLOAD_WATCHDOG_WAITING reason=plan-missing path=$PlanPath"
    return
}

$planSha256 = Get-Sha256 $PlanPath
$sidecarPath = "$PlanPath.sha256"
if (!(Test-Path -LiteralPath $sidecarPath -PathType Leaf)) {
    throw "Plan SHA-256 sidecar is missing: $sidecarPath"
}
$sidecarText = (Get-Content -Raw -LiteralPath $sidecarPath).Trim()
$sidecarSha256 = ($sidecarText -split '\s+')[0].ToLowerInvariant()
if ($sidecarSha256 -ne $planSha256) {
    throw "Plan SHA-256 sidecar mismatch: expected=$sidecarSha256 actual=$planSha256"
}

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
if ([string]$plan.schema -ne 'bil.cloudflare-media-upload-plan.v1') {
    throw "Unexpected plan schema: $($plan.schema)"
}
$items = @($plan.items)
if ($items.Count -ne 1802 -or [int]$plan.counts.total -ne 1802 -or
    [int]$plan.counts.recipeImages -ne 1500 -or [int]$plan.counts.workoutVideos -ne 302 -or
    [int]$plan.counts.uniqueWorkoutPayloads -ne 301) {
    throw 'Plan inventory counts do not match the approved 1500 recipe + 302 workout inventory.'
}
if ([long]$plan.totalBytes -ne 9257051952L) {
    throw "Plan total byte count is not authoritative: expected=9257051952 actual=$($plan.totalBytes)"
}
if ([long]$plan.limits.safetyPlanCeilingBytes -ne 9500000000L -or
    [long]$plan.limits.hardAccountCeilingBytes -ne 10000000000L -or
    [long]$plan.totalBytes -gt [long]$plan.limits.safetyPlanCeilingBytes -or
    [long]$plan.totalBytes -ge [long]$plan.limits.hardAccountCeilingBytes) {
    throw "R2 safety ceiling policy missing or exceeded: planned=$($plan.totalBytes) safety=$($plan.limits.safetyPlanCeilingBytes) hard=$($plan.limits.hardAccountCeilingBytes)"
}

$expectedBuckets = @('bil-premium-workouts-2026-v1', 'bil-recipes-2026-v1')
$actualBuckets = @($plan.buckets | ForEach-Object { [string]$_.name } | Sort-Object -Unique)
if ($actualBuckets.Count -ne 2 -or @($actualBuckets | Where-Object { $_ -notin $expectedBuckets }).Count -gt 0) {
    throw "Unexpected bucket set: $($actualBuckets -join ',')"
}

$itemByTarget = @{}
$calculatedBytes = 0L
$recipeCount = 0
$workoutCount = 0
$workoutPayloads = @{}
foreach ($item in $items) {
    $bucket = [string]$item.bucket
    $objectKey = [string]$item.objectKey
    Assert-SafeObjectKey $objectKey
    if ($bucket -notin $expectedBuckets) { throw "Unexpected bucket on item: $bucket" }
    $target = "$bucket/$objectKey"
    if ($itemByTarget.ContainsKey($target)) { throw "Duplicate bucket/object target: $target" }
    $itemByTarget[$target] = $item
    $calculatedBytes += [long]$item.sizeBytes
    if ([string]$item.kind -eq 'recipe-image') { $recipeCount++ }
    elseif ([string]$item.kind -eq 'workout-video') {
        $workoutCount++
        $workoutPayloads[[string]$item.sha256] = $true
    } else { throw "Unexpected media kind: $($item.kind)" }
    if (!(Test-Path -LiteralPath ([string]$item.localPath) -PathType Leaf)) {
        throw "Local media is missing: $($item.localPath)"
    }
    $localBytes = (Get-Item -LiteralPath ([string]$item.localPath)).Length
    if ($localBytes -ne [long]$item.sizeBytes) {
        throw "Local byte mismatch: target=$target expected=$($item.sizeBytes) actual=$localBytes"
    }
    if ($FullLocalHashValidation) {
        $localSha256 = Get-Sha256 ([string]$item.localPath)
        if ($localSha256 -ne ([string]$item.sha256).ToLowerInvariant()) {
            throw "Local SHA-256 mismatch: target=$target expected=$($item.sha256) actual=$localSha256"
        }
    }
}
if ($calculatedBytes -ne 9257051952L -or $recipeCount -ne 1500 -or
    $workoutCount -ne 302 -or $workoutPayloads.Count -ne 301) {
    throw 'Calculated plan inventory differs from the approved inventory.'
}

$sourcePins = @(
    [pscustomobject]@{
        RelativePath = [string]$plan.source.recipeImageManifest
        Sha256 = ([string]$plan.source.recipeImageManifestSha256).ToLowerInvariant()
    },
    [pscustomobject]@{
        RelativePath = [string]$plan.source.workoutBundleRegistry
        Sha256 = ([string]$plan.source.workoutBundleRegistrySha256).ToLowerInvariant()
    }
)
foreach ($pin in $sourcePins) {
    $sourcePath = Join-Path $RepositoryRoot $pin.RelativePath.Replace('/', '\')
    if ((Get-Sha256 $sourcePath) -ne $pin.Sha256) {
        throw "Pinned source changed after plan generation: $($pin.RelativePath)"
    }
}

$uploadedByTarget = @{}
$failedAttemptsByTarget = @{}
$terminalFailures = @{}
$duplicateUploadEvents = [System.Collections.Generic.List[string]]::new()
$invalidLedgerLines = [System.Collections.Generic.List[int]]::new()
$scopeCompleteEvents = 0
if (Test-Path -LiteralPath $LedgerPath -PathType Leaf) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $LedgerPath) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $event = $line | ConvertFrom-Json } catch {
            $invalidLedgerLines.Add($lineNumber)
            continue
        }
        if ([string]$event.schema -ne 'bil.cloudflare-media-upload-ledger.v1' -or
            ([string]$event.planSha256).ToLowerInvariant() -ne $planSha256) {
            $invalidLedgerLines.Add($lineNumber)
            continue
        }
        $eventName = [string]$event.event
        if ($eventName -eq 'bucket-created') { continue }
        if ($eventName -eq 'scope-complete') { $scopeCompleteEvents++; continue }
        $target = "$($event.bucket)/$($event.objectKey)"
        if (!$itemByTarget.ContainsKey($target)) {
            throw "Ledger references a target outside the plan at line $lineNumber`: $target"
        }
        $planned = $itemByTarget[$target]
        if ([string]$event.sha256 -ne [string]$planned.sha256 -or
            [long]$event.sizeBytes -ne [long]$planned.sizeBytes) {
            throw "Ledger evidence differs from plan at line $lineNumber`: $target"
        }
        switch ($eventName) {
            'uploaded' {
                if ($uploadedByTarget.ContainsKey($target)) { $duplicateUploadEvents.Add($target) }
                $uploadedByTarget[$target] = $event
                # A later success resolves a terminal failure from an earlier
                # resumable run while preserving the append-only audit trail.
                [void]$terminalFailures.Remove($target)
            }
            'attempt-failed' {
                if (!$failedAttemptsByTarget.ContainsKey($target)) { $failedAttemptsByTarget[$target] = 0 }
                $failedAttemptsByTarget[$target]++
            }
            'failed' { $terminalFailures[$target] = $event }
            default { $invalidLedgerLines.Add($lineNumber) }
        }
    }
}

if ($invalidLedgerLines.Count -gt 0) {
    throw "Invalid/untrusted ledger lines: $($invalidLedgerLines -join ',')"
}
if ($duplicateUploadEvents.Count -gt 0) {
    throw "Duplicate successful upload events detected (resume invariant broken): $($duplicateUploadEvents -join ',')"
}

$uploadedBytes = 0L
foreach ($target in $uploadedByTarget.Keys) { $uploadedBytes += [long]$itemByTarget[$target].sizeBytes }
$remainingObjects = 1802 - $uploadedByTarget.Count
$remainingBytes = 9257051952L - $uploadedBytes
$retryTargetCount = $failedAttemptsByTarget.Count
$retryAttemptCount = [long](($failedAttemptsByTarget.Values | Measure-Object -Sum).Sum)
if ($null -eq $retryAttemptCount) { $retryAttemptCount = 0L }

$processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -match 'Start-CloudflareMediaUpload\.ps1|wrangler(?:\.cmd)?\s+r2\s+object\s+put'
})
$uploadRunning = $processes.Count -gt 0
$logAgeMinutes = $null
if (Test-Path -LiteralPath $RunLogPath -PathType Leaf) {
    $logAgeMinutes = [Math]::Round(((Get-Date) - (Get-Item -LiteralPath $RunLogPath).LastWriteTime).TotalMinutes, 2)
}
$stale = $uploadRunning -and $null -ne $logAgeMinutes -and $logAgeMinutes -ge $StaleAfterMinutes

Write-Host ("UPLOAD_WATCHDOG_OK planSha256={0} objects={1}/1802 bytes={2}/9257051952 remainingObjects={3} remainingBytes={4} retryTargets={5} retryAttempts={6} terminalFailures={7} scopeCompleteEvents={8} uploadRunning={9} logAgeMinutes={10} stale={11} fullLocalHash={12}" -f `
    $planSha256, $uploadedByTarget.Count, $uploadedBytes, $remainingObjects, $remainingBytes,
    $retryTargetCount, $retryAttemptCount, $terminalFailures.Count, $scopeCompleteEvents,
    $uploadRunning, $logAgeMinutes, $stale, [bool]$FullLocalHashValidation)

if ($terminalFailures.Count -gt 0) {
    Write-Warning "Terminal upload failures remain in ledger: $($terminalFailures.Keys -join ',')"
}
if ($stale) {
    Write-Warning "Upload process appears stale: last log update was $logAgeMinutes minutes ago."
}
