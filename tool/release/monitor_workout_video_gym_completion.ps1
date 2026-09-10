[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$GeneratorProcessId,

    [ValidateRange(10, 300)]
    [int]$PollSeconds = 30,

    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$planPath = Join-Path $projectRoot 'tool\workout_media\pipeline\contracts\gym_six_month_video_plan.json'
$runtimeRoot = 'G:\BIL_Workout_Media\bulk_1000_gym_six_month'
$processedRoot = Join-Path $runtimeRoot 'processed'
$stateRoot = Join-Path $runtimeRoot 'state'
$generatorLock = Join-Path $stateRoot 'bulk_1000.run.lock'
$monitorLock = Join-Path $stateRoot 'gym_validation_monitor.lock'
$evidenceRoot = Join-Path $projectRoot 'artifacts\qa'

if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
    throw 'Gym-plan manifest is missing.'
}
if (-not (Test-Path -LiteralPath $processedRoot -PathType Container)) {
    throw 'Gym-plan processed directory is missing.'
}

$preflightPlan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$preflightIds = @(
    $preflightPlan.generation_queue |
        ForEach-Object { ([string]$_.exercise_id) -replace '--', '-' }
)
if ($preflightIds.Count -ne 102 -or
    @($preflightIds | Sort-Object -Unique).Count -ne 102) {
    throw 'Gym-plan manifest must resolve to exactly 102 unique filenames.'
}
$ffprobePath = (Get-Command ffprobe -ErrorAction Stop).Source
if ($PreflightOnly) {
    Write-Host 'GYM_VALIDATION_MONITOR_PREFLIGHT=PASS'
    Write-Host "EXPECTED_COUNT=$($preflightIds.Count)"
    Write-Host 'STATE_MUTATED=False'
    exit 0
}

function Open-BilMonitorLock([string]$Path) {
    # Hold the OS file handle for the full run. Check-then-write PID files let
    # simultaneous monitors both proceed and produce contradictory evidence.
    return [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
}

New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
try {
    $monitorLease = Open-BilMonitorLock $monitorLock
} catch [IO.IOException] {
    # A locked file means another monitor owns this run; other I/O errors
    # (missing volume, disk full, etc.) must not be reported as success.
    if (($_.Exception.HResult -band 0xffff) -notin @(32, 33)) { throw }
    Write-Host 'GYM_VALIDATION_MONITOR_ALREADY_RUNNING=True'
    exit 0
}

try {
    $monitorLease.SetLength(0)
    $pidBytes = [Text.Encoding]::UTF8.GetBytes([string]$PID)
    $monitorLease.Write($pidBytes, 0, $pidBytes.Length)
    $monitorLease.Flush()
    Write-Host "GYM_VALIDATION_MONITOR=WAITING generator_pid=$GeneratorProcessId"
    $observedGeneratorIds = [Collections.Generic.HashSet[int]]::new()
    [void]$observedGeneratorIds.Add($GeneratorProcessId)
    $idlePolls = 0
    while ($true) {
        if (Test-Path -LiteralPath $generatorLock -PathType Leaf) {
            $lockText = (Get-Content -LiteralPath $generatorLock -Raw -Encoding UTF8).Trim()
            if ($lockText -match '^pid=(\d+)$') {
                [void]$observedGeneratorIds.Add([int]$Matches[1])
            }
        }
        $activeGeneratorIds = @(
            $observedGeneratorIds |
                Where-Object {
                    $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue)
                }
        )
        $completedCount = @(
            Get-ChildItem -LiteralPath $processedRoot -File -Filter '*.mp4' |
                Where-Object Length -gt 0
        ).Count
        if ($activeGeneratorIds.Count -gt 0) {
            $idlePolls = 0
        } else {
            $idlePolls++
        }
        if ($completedCount -eq 102 -and $idlePolls -ge 1) {
            break
        }
        # Require two idle observations so a transient wrapper restart cannot
        # turn a resumable 74/102 checkpoint into a false final failure.
        if ($idlePolls -ge 2) {
            break
        }
        Start-Sleep -Seconds $PollSeconds
    }

    # Let the final atomic move and ledger write settle before taking a snapshot.
    Start-Sleep -Seconds 5

    $expectedIds = $preflightIds

    $files = @(
        Get-ChildItem -LiteralPath $processedRoot -File -Filter '*.mp4' |
            Where-Object Length -gt 0
    )
    $actualIds = @($files | Select-Object -ExpandProperty BaseName)
    $missing = @($expectedIds | Where-Object { $actualIds -cnotcontains $_ })
    $unexpected = @($actualIds | Where-Object { $expectedIds -cnotcontains $_ })

    $ffprobe = $ffprobePath
    $contractFailures = [Collections.Generic.List[object]]::new()
    $fileEvidence = [Collections.Generic.List[object]]::new()
    foreach ($file in $files | Sort-Object Name) {
        $probeText = & $ffprobe -v error -select_streams v:0 -count_frames `
            -show_entries stream=width,height,r_frame_rate,nb_read_frames,duration `
            -of json -- $file.FullName 2>$null
        if ($LASTEXITCODE -ne 0) {
            $contractFailures.Add([ordered]@{
                file = $file.Name
                reason = 'ffprobe_failed'
            })
            continue
        }
        $stream = @((($probeText -join "`n") | ConvertFrom-Json).streams)[0]
        $duration = [double]::Parse(
            [string]$stream.duration,
            [Globalization.CultureInfo]::InvariantCulture
        )
        $frames = [int]$stream.nb_read_frames
        $valid = (
            [int]$stream.width -eq 720 -and
            [int]$stream.height -eq 1280 -and
            [string]$stream.r_frame_rate -ceq '30/1' -and
            $frames -eq 300 -and
            [math]::Abs($duration - 10.0) -le 0.02
        )
        $evidence = [ordered]@{
            file = $file.Name
            bytes = $file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            width = [int]$stream.width
            height = [int]$stream.height
            fps = [string]$stream.r_frame_rate
            frames = $frames
            duration_seconds = $duration
            contract_pass = $valid
        }
        $fileEvidence.Add($evidence)
        if (-not $valid) {
            $contractFailures.Add($evidence)
        }
    }

    $passed = (
        $files.Count -eq 102 -and
        $missing.Count -eq 0 -and
        $unexpected.Count -eq 0 -and
        $contractFailures.Count -eq 0
    )
    New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
    $stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
    $reportPath = Join-Path $evidenceRoot "workout_video_gym_validation_$stamp.json"
    $temporaryPath = "$reportPath.tmp"
    [ordered]@{
        schema_version = 1
        generated_at_utc = [datetime]::UtcNow.ToString('o')
        generator_process_id = $GeneratorProcessId
        observed_generator_process_ids = @($observedGeneratorIds | Sort-Object)
        expected_count = 102
        actual_count = $files.Count
        missing = $missing
        unexpected = $unexpected
        contract_failure_count = $contractFailures.Count
        contract_failures = $contractFailures
        files = $fileEvidence
        status = $(if ($passed) { 'PASS' } else { 'INCOMPLETE_OR_FAILED' })
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $reportPath

    Write-Host "GYM_VIDEO_VALIDATION_STATUS=$(if ($passed) { 'PASS' } else { 'INCOMPLETE_OR_FAILED' })"
    Write-Host "GYM_VIDEO_VALIDATION_REPORT=$reportPath"
    if (-not $passed) {
        exit 2
    }
} finally {
    # Leave an inert PID file: deleting after releasing the handle could remove
    # a replacement monitor's lock. Process exit also releases the OS lock.
    $monitorLease.Dispose()
}
