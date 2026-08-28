[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [int]$PollSeconds = 60,
    [int]$StaleAfterMinutes = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
if ($PollSeconds -lt 20) { throw 'PollSeconds must be at least 20.' }
if ($StaleAfterMinutes -lt 2) { throw 'StaleAfterMinutes must be at least 2.' }

$artifactDirectory = Join-Path $RepositoryRoot 'artifacts\cloudflare_media'
$planPath = Join-Path $artifactDirectory 'media_upload_plan_v1.json'
$ledgerPath = Join-Path $artifactDirectory 'media_upload_ledger_v1.ndjson'
$uploadLogPath = Join-Path $artifactDirectory 'media_upload_current.log'
$watchdogLogPath = Join-Path $artifactDirectory 'media_upload_watchdog.log'
$validatorPath = Join-Path $PSScriptRoot 'Test-CloudflareMediaUploadState.ps1'

function Write-WatchdogLog([string]$Message) {
    $line = "$(Get-Date -Format o) $Message"
    Add-Content -LiteralPath $watchdogLogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Read-LedgerEvents {
    if (!(Test-Path -LiteralPath $ledgerPath -PathType Leaf)) { return @() }
    $events = [System.Collections.Generic.List[object]]::new()
    $invalid = 0
    foreach ($line in Get-Content -LiteralPath $ledgerPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $events.Add(($line | ConvertFrom-Json)) } catch { $invalid++ }
    }
    if ($invalid -gt 0) {
        Start-Sleep -Seconds 1
        $events.Clear()
        foreach ($line in Get-Content -LiteralPath $ledgerPath) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $events.Add(($line | ConvertFrom-Json))
        }
    }
    return @($events)
}

$preflightOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validatorPath 2>&1)
if ($LASTEXITCODE -ne 0 -or ($preflightOutput -join "`n") -notmatch 'UPLOAD_WATCHDOG_OK') {
    Write-WatchdogLog "WATCHDOG_ALERT preflightFailed output=$($preflightOutput -join ' ')"
    exit 2
}
$planSha256 = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-WatchdogLog "WATCHDOG_STARTED planSha256=$planSha256 pollSeconds=$PollSeconds staleAfterMinutes=$StaleAfterMinutes"

while ($true) {
    $events = @(Read-LedgerEvents)
    $trustedEvents = @($events | Where-Object {
        [string]$_.schema -eq 'bil.cloudflare-media-upload-ledger.v1' -and
        ([string]$_.planSha256).ToLowerInvariant() -eq $planSha256
    })
    $uploadedEvents = @($trustedEvents | Where-Object event -eq 'uploaded')
    $uploadedTargets = @($uploadedEvents | ForEach-Object { "$($_.bucket)/$($_.objectKey)" })
    $uniqueUploadedTargets = @($uploadedTargets | Sort-Object -Unique)
    $duplicateUploadedTargets = @($uploadedTargets | Group-Object | Where-Object Count -gt 1)
    $retryEvents = @($trustedEvents | Where-Object event -eq 'attempt-failed')
    # A terminal failure stops one uploader run, but the same append-only
    # ledger is intentionally reused by the next resumable run. Treat a
    # later successful upload for that target as resolving the old failure.
    $unresolvedTerminalFailures = @{}
    foreach ($event in $trustedEvents) {
        $target = "$($event.bucket)/$($event.objectKey)"
        if ([string]$event.event -eq 'failed') {
            $unresolvedTerminalFailures[$target] = $event
        } elseif ([string]$event.event -eq 'uploaded') {
            [void]$unresolvedTerminalFailures.Remove($target)
        }
    }
    $terminalFailures = @($unresolvedTerminalFailures.Values)
    $scopeComplete = @($trustedEvents | Where-Object event -eq 'scope-complete')
    $uploadedBytes = [long](($uploadedEvents | Measure-Object sizeBytes -Sum).Sum)

    $uploadProcesses = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -match 'Start-CloudflareMediaUpload\.ps1'
    })
    $logAgeMinutes = $null
    if (Test-Path -LiteralPath $uploadLogPath -PathType Leaf) {
        $logAgeMinutes = [Math]::Round(((Get-Date) - (Get-Item -LiteralPath $uploadLogPath).LastWriteTime).TotalMinutes, 2)
    }
    $stale = $uploadProcesses.Count -gt 0 -and $null -ne $logAgeMinutes -and $logAgeMinutes -ge $StaleAfterMinutes

    Write-WatchdogLog "WATCHDOG_STATUS uploaded=$($uniqueUploadedTargets.Count)/1802 bytes=$uploadedBytes/9257051952 retries=$($retryEvents.Count) failures=$($terminalFailures.Count) processes=$($uploadProcesses.Count) logAgeMinutes=$logAgeMinutes stale=$stale"

    if ($duplicateUploadedTargets.Count -gt 0) {
        Write-WatchdogLog "WATCHDOG_ALERT duplicateSuccessfulTargets=$($duplicateUploadedTargets.Name -join ',')"
        exit 3
    }
    if ($terminalFailures.Count -gt 0) {
        Write-WatchdogLog "WATCHDOG_ALERT terminalFailures=$($terminalFailures.Count) lastKey=$($terminalFailures[-1].objectKey)"
        exit 4
    }
    if ($stale) {
        Write-WatchdogLog "WATCHDOG_ALERT staleUpload logAgeMinutes=$logAgeMinutes"
        exit 5
    }
    if ($uniqueUploadedTargets.Count -eq 1802 -and $scopeComplete.Count -gt 0) {
        if ($uploadedBytes -ne 9257051952L) {
            Write-WatchdogLog "WATCHDOG_ALERT completionByteMismatch actual=$uploadedBytes expected=9257051952"
            exit 6
        }
        Write-WatchdogLog 'WATCHDOG_COMPLETE objects=1802 bytes=9257051952'
        exit 0
    }
    if ($uploadProcesses.Count -eq 0) {
        Write-WatchdogLog "WATCHDOG_ALERT uploaderProcessMissing uploaded=$($uniqueUploadedTargets.Count)/1802"
        exit 7
    }
    Start-Sleep -Seconds $PollSeconds
}
