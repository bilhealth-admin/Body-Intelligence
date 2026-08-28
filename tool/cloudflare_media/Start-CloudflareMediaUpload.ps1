[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$PlanPath,
    [string]$WranglerPath,
    [ValidateSet('All', 'Recipes', 'Workouts')]
    [string]$Scope = 'All',
    [int]$MaxAttempts = 5,
    [int]$InitialRetrySeconds = 4,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
if ([string]::IsNullOrWhiteSpace($PlanPath)) {
    $PlanPath = Join-Path $RepositoryRoot 'artifacts\cloudflare_media\media_upload_plan_v1.json'
}
if ([string]::IsNullOrWhiteSpace($WranglerPath)) {
    $cached = 'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_npx\d77349f55c2be1c0\node_modules\.bin\wrangler.cmd'
    $command = Get-Command wrangler -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $WranglerPath = $command.Source
    } elseif (Test-Path -LiteralPath $cached) {
        $WranglerPath = $cached
    } else {
        throw 'Wrangler v4 was not found. Install Wrangler v4 or pass -WranglerPath.'
    }
}
if ($MaxAttempts -lt 1 -or $InitialRetrySeconds -lt 1) {
    throw 'MaxAttempts and InitialRetrySeconds must both be positive.'
}

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
if ([string]$plan.schema -ne 'bil.cloudflare-media-upload-plan.v1' -or [int]$plan.counts.total -ne 1802) {
    throw 'Refusing an unknown or incomplete Cloudflare media plan.'
}
$hardAccountCeilingBytes = [long]10000000000
$safetyPlanCeilingBytes = [long]9500000000
if ([long]$plan.limits.hardAccountCeilingBytes -ne $hardAccountCeilingBytes -or
    [long]$plan.limits.safetyPlanCeilingBytes -ne $safetyPlanCeilingBytes) {
    throw 'R2 ceiling policy is missing or changed. Refusing upload.'
}
$plannedItemBytes = [long](($plan.items | Measure-Object -Property sizeBytes -Sum).Sum)
if ([long]$plan.totalBytes -ne $plannedItemBytes -or
    $plannedItemBytes -ne [long]9257051952 -or
    $plannedItemBytes -gt $safetyPlanCeilingBytes -or
    $plannedItemBytes -ge $hardAccountCeilingBytes) {
    throw "R2 capacity guard rejected plan: declared=$($plan.totalBytes) summed=$plannedItemBytes safety=$safetyPlanCeilingBytes hard=$hardAccountCeilingBytes"
}
$planSha256 = (Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sidecarPath = "$PlanPath.sha256"
if (!(Test-Path -LiteralPath $sidecarPath -PathType Leaf)) {
    throw "Missing plan SHA-256 sidecar: $sidecarPath"
}
$sidecarSha256 = ((Get-Content -Raw -LiteralPath $sidecarPath).Trim() -split '\s+')[0].ToLowerInvariant()
if ($sidecarSha256 -ne $planSha256) {
    throw "Plan SHA-256 sidecar mismatch: expected=$sidecarSha256 actual=$planSha256"
}
foreach ($sourcePin in @(
    [pscustomobject]@{ Path = (Join-Path $RepositoryRoot ([string]$plan.source.recipeImageManifest).Replace('/', '\')); Sha256 = [string]$plan.source.recipeImageManifestSha256 },
    [pscustomobject]@{ Path = (Join-Path $RepositoryRoot ([string]$plan.source.workoutBundleRegistry).Replace('/', '\')); Sha256 = [string]$plan.source.workoutBundleRegistrySha256 }
)) {
    $actualPin = (Get-FileHash -LiteralPath $sourcePin.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualPin -ne $sourcePin.Sha256.ToLowerInvariant()) {
        throw "Authoritative source changed after planning: $($sourcePin.Path)"
    }
}
$artifactDirectory = Split-Path -Parent $PlanPath
$ledgerPath = Join-Path $artifactDirectory 'media_upload_ledger_v1.ndjson'
$runLogPath = Join-Path $artifactDirectory 'media_upload_current.log'

function Write-RunLog([string]$Message) {
    $line = "$(Get-Date -Format o) $Message"
    Add-Content -LiteralPath $runLogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Write-LedgerEvent([hashtable]$Fields) {
    $entry = [ordered]@{
        schema = 'bil.cloudflare-media-upload-ledger.v1'
        at = (Get-Date).ToUniversalTime().ToString('o')
        planSha256 = $planSha256
    }
    foreach ($key in $Fields.Keys) { $entry[$key] = $Fields[$key] }
    $line = $entry | ConvertTo-Json -Compress -Depth 5
    Add-Content -LiteralPath $ledgerPath -Value $line -Encoding UTF8
}

function Invoke-Wrangler([string[]]$Arguments, [switch]$Quiet) {
    $previousLog = $env:WRANGLER_LOG
    $previousErrorActionPreference = $ErrorActionPreference
    # `none` suppresses not only diagnostics but also several structured list
    # outputs in Wrangler. Keep normal output captured so existence checks are
    # based on authoritative command exit status and useful errors reach logs.
    $env:WRANGLER_LOG = 'log'
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $WranglerPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $env:WRANGLER_LOG = $previousLog
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if (!$Quiet -and $output.Count -gt 0) { $output | ForEach-Object { Write-Host $_ } }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join "`n") }
}

function Assert-LocalItem($Item) {
    if ([string]::IsNullOrWhiteSpace([string]$Item.objectKey) -or
        ([string]$Item.objectKey).Contains('\') -or
        ([string]$Item.objectKey).StartsWith('/') -or
        ([string]$Item.objectKey) -match '(^|/)\.\.?(/|$)') {
        throw "Unsafe object key in plan: $($Item.objectKey)"
    }
    if (!(Test-Path -LiteralPath ([string]$Item.localPath) -PathType Leaf)) {
        throw "Missing local item: $($Item.localPath)"
    }
    $size = (Get-Item -LiteralPath ([string]$Item.localPath)).Length
    if ($size -ne [long]$Item.sizeBytes) {
        throw "Local size changed after planning: $($Item.localPath)"
    }
}

$allItems = @($plan.items)
$approvedKinds = @($allItems | Group-Object kind | Select-Object -ExpandProperty Name | Sort-Object)
if (($approvedKinds -join ',') -ne 'recipe-image,workout-video' -or
    @($allItems | Where-Object kind -eq 'recipe-image').Count -ne 1500 -or
    @($allItems | Where-Object kind -eq 'workout-video').Count -ne 302) {
    throw 'Plan contains an object outside the approved 1,500 recipe + 302 workout inventory.'
}
$selectedItems = switch ($Scope) {
    'Recipes' { @($allItems | Where-Object kind -eq 'recipe-image') }
    'Workouts' { @($allItems | Where-Object kind -eq 'workout-video') }
    default { $allItems }
}
foreach ($item in $selectedItems) { Assert-LocalItem $item }
$targetCount = @($selectedItems | ForEach-Object { "$($_.bucket)/$($_.objectKey)" } | Sort-Object -Unique).Count
if ($targetCount -ne $selectedItems.Count) { throw 'Duplicate remote targets found in selected upload scope.' }

$uploaded = @{}
$createdBuckets = @{}
$knownLedgerBuckets = @{}
if (Test-Path -LiteralPath $ledgerPath) {
    foreach ($line in Get-Content -LiteralPath $ledgerPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $event = $line | ConvertFrom-Json } catch { continue }
        if ([string]$event.schema -ne 'bil.cloudflare-media-upload-ledger.v1') { continue }
        if ([string]$event.event -eq 'uploaded') {
            $key = "$($event.bucket)|$($event.objectKey)|$($event.sha256)|$($event.sizeBytes)"
            $uploaded[$key] = $true
            $knownLedgerBuckets[[string]$event.bucket] = $true
        } elseif ([string]$event.event -eq 'bucket-created') {
            $createdBuckets[[string]$event.bucket] = $true
            $knownLedgerBuckets[[string]$event.bucket] = $true
        }
    }
}

$auth = Invoke-Wrangler @('whoami') -Quiet
if ($auth.ExitCode -ne 0) {
    throw "Cloudflare authentication is not ready. Complete 'wrangler login --device' first. $($auth.Output)"
}
Write-RunLog "AUTH_OK wrangler=$WranglerPath planSha256=$planSha256 scope=$Scope selected=$($selectedItems.Count)"
Write-RunLog "R2_CAPACITY_GUARD_PASS plannedBytes=$plannedItemBytes safetyCeilingBytes=$safetyPlanCeilingBytes hardCeilingBytes=$hardAccountCeilingBytes objects=1802 metadataObjects=0"

$bucketList = Invoke-Wrangler @('r2', 'bucket', 'list') -Quiet
if ($bucketList.ExitCode -ne 0) { throw "Unable to list R2 buckets: $($bucketList.Output)" }
foreach ($bucket in @($plan.buckets)) {
    $name = [string]$bucket.name
    $bucketInfo = Invoke-Wrangler @('r2', 'bucket', 'info', $name) -Quiet
    $exists = $bucketInfo.ExitCode -eq 0
    if (!$exists) {
        if ($ValidateOnly) {
            Write-RunLog "VALIDATE_WOULD_CREATE_BUCKET bucket=$name location=$($bucket.locationHint)"
            continue
        }
        $create = Invoke-Wrangler @('r2', 'bucket', 'create', $name, '--location', [string]$bucket.locationHint) -Quiet
        if ($create.ExitCode -ne 0) { throw "Failed to create R2 bucket $name`: $($create.Output)" }
        Write-LedgerEvent @{ event = 'bucket-created'; bucket = $name; locationHint = [string]$bucket.locationHint }
        $createdBuckets[$name] = $true
        Write-RunLog "BUCKET_CREATED bucket=$name visibility=$($bucket.visibility)"
    } elseif (!$knownLedgerBuckets.ContainsKey($name) -and !$ValidateOnly) {
        throw "Safety stop: bucket '$name' already exists but this ledger has no history for it. Refusing blind overwrite."
    } else {
        Write-RunLog "BUCKET_READY bucket=$name"
    }
}

if ($ValidateOnly) {
    Write-RunLog "VALIDATION_PASS selected=$($selectedItems.Count) resumeKnown=$($uploaded.Count)"
    exit 0
}

$completed = 0
$skipped = 0
$failed = 0
$total = $selectedItems.Count
foreach ($item in $selectedItems) {
    $resumeKey = "$($item.bucket)|$($item.objectKey)|$($item.sha256)|$($item.sizeBytes)"
    if ($uploaded.ContainsKey($resumeKey)) {
        $skipped++
        continue
    }
    $success = $false
    $lastOutput = ''
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if ($attempt -eq 1) {
            $currentSha256 = (Get-FileHash -LiteralPath ([string]$item.localPath) -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($currentSha256 -ne ([string]$item.sha256).ToLowerInvariant()) {
                throw "Local SHA-256 changed after planning: $($item.localPath)"
            }
        }
        $destination = "$($item.bucket)/$($item.objectKey)"
        $result = Invoke-Wrangler @(
            'r2', 'object', 'put', $destination,
            '--remote',
            '--force',
            '--file', [string]$item.localPath,
            '--content-type', [string]$item.contentType,
            '--cache-control', [string]$item.cacheControl,
            '--content-disposition', [string]$item.contentDisposition
        ) -Quiet
        $lastOutput = $result.Output
        if ($result.ExitCode -eq 0) {
            Write-LedgerEvent @{
                event = 'uploaded'
                bucket = [string]$item.bucket
                objectKey = [string]$item.objectKey
                sha256 = [string]$item.sha256
                sizeBytes = [long]$item.sizeBytes
                kind = [string]$item.kind
                identity = [string]$item.identity
                attempt = $attempt
            }
            $completed++
            $success = $true
            $done = $completed + $skipped
            Write-RunLog "UPLOADED done=$done total=$total bucket=$($item.bucket) key=$($item.objectKey) bytes=$($item.sizeBytes) attempt=$attempt"
            break
        }
        Write-LedgerEvent @{
            event = 'attempt-failed'
            bucket = [string]$item.bucket
            objectKey = [string]$item.objectKey
            sha256 = [string]$item.sha256
            sizeBytes = [long]$item.sizeBytes
            attempt = $attempt
            exitCode = [int]$result.ExitCode
            error = (($result.Output -replace '[\r\n]+', ' ').Trim() | ForEach-Object {
                if ($_.Length -gt 1000) { $_.Substring(0, 1000) } else { $_ }
            })
        }
        if ($attempt -lt $MaxAttempts) {
            $delay = [Math]::Min(60, $InitialRetrySeconds * [Math]::Pow(2, $attempt - 1))
            Write-RunLog "RETRY bucket=$($item.bucket) key=$($item.objectKey) attempt=$attempt delaySeconds=$delay"
            Start-Sleep -Seconds $delay
        }
    }
    if (!$success) {
        $failed++
        Write-LedgerEvent @{
            event = 'failed'
            bucket = [string]$item.bucket
            objectKey = [string]$item.objectKey
            sha256 = [string]$item.sha256
            sizeBytes = [long]$item.sizeBytes
            attempts = $MaxAttempts
        }
        Write-RunLog "FAILED bucket=$($item.bucket) key=$($item.objectKey) output=$($lastOutput -replace '[\r\n]+',' ')"
        throw "Upload stopped after $MaxAttempts attempts. Re-run the same command to resume safely."
    }
}

Write-LedgerEvent @{ event = 'scope-complete'; scope = $Scope; completed = $completed; skipped = $skipped; failed = $failed; total = $total }
Write-RunLog "UPLOAD_SCOPE_COMPLETE scope=$Scope uploaded=$completed skipped=$skipped failed=$failed total=$total"
