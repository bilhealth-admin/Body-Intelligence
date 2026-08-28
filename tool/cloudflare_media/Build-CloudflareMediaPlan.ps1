[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$WorkoutMediaRoot = 'G:\BIL_Workout_Media',
    [string]$OutputPath,
    [switch]$SkipHashValidation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepositoryRoot 'artifacts\cloudflare_media\media_upload_plan_v1.json'
}

$recipeManifestPath = Join-Path $RepositoryRoot 'assets\catalogs\recipes\v1\recipe-images.json'
$bundleRegistryPath = Join-Path $RepositoryRoot 'artifacts\workout_media\workout_release_bundle_registry_v1.json'
$recipeMediaRoot = Join-Path $RepositoryRoot 'assets\images\professional\recipes'
$hardAccountCeilingBytes = [long]10000000000
$safetyPlanCeilingBytes = [long]9500000000

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-SafeObjectPath([string]$ObjectPath) {
    if ([string]::IsNullOrWhiteSpace($ObjectPath) -or
        $ObjectPath.Contains('\') -or
        $ObjectPath.StartsWith('/') -or
        $ObjectPath.EndsWith('/') -or
        $ObjectPath -match '(^|/)\.\.?(/|$)') {
        throw "Unsafe R2 object path: $ObjectPath"
    }
}

function ConvertTo-MediaId([string]$Value) {
    $normalized = $Value.ToLowerInvariant().Replace('--', '-').Replace('.', '-')
    $normalized = [regex]::Replace($normalized, '[^a-z0-9-]+', '-')
    return [regex]::Replace($normalized, '-+', '-').Trim('-')
}

$workoutPathIndex = @{}
foreach ($source in @(
    [pscustomobject]@{ Group = 'bulk-legacy'; Directory = (Join-Path $WorkoutMediaRoot 'bulk_1000\processed'); Normalize = $true },
    [pscustomobject]@{ Group = 'female-10s'; Directory = (Join-Path $WorkoutMediaRoot 'bulk_1000_female_10s\processed'); Normalize = $true },
    [pscustomobject]@{ Group = 'paid-pilot-h264-delivery'; Directory = (Join-Path $WorkoutMediaRoot 'delivery_h264\home'); Normalize = $false },
    [pscustomobject]@{ Group = 'gym-six-month'; Directory = (Join-Path $WorkoutMediaRoot 'bulk_1000_gym_six_month\processed'); Normalize = $false }
)) {
    foreach ($file in Get-ChildItem -LiteralPath $source.Directory -Filter '*.mp4' -File | Sort-Object Name) {
        $assetId = if ($source.Normalize) { ConvertTo-MediaId $file.BaseName } else { $file.BaseName }
        $indexKey = "$($source.Group)|$assetId"
        if ($workoutPathIndex.ContainsKey($indexKey)) {
            throw "Duplicate normalized workout source identity: $indexKey"
        }
        $workoutPathIndex[$indexKey] = $file.FullName
    }
}

function Resolve-WorkoutLocalPath($Record) {
    $indexKey = "$($Record.sourceGroup)|$($Record.assetId)"
    if (!$workoutPathIndex.ContainsKey($indexKey)) {
        throw "Unknown workout source identity '$indexKey' for $($Record.releaseKey)"
    }
    return [string]$workoutPathIndex[$indexKey]
}

function New-ValidatedItem {
    param(
        [string]$Kind,
        [string]$Identity,
        [string]$Bucket,
        [string]$ObjectKey,
        [string]$LocalPath,
        [long]$ExpectedBytes,
        [string]$ExpectedSha256,
        [string]$ContentType
    )
    Assert-SafeObjectPath $ObjectKey
    if (!(Test-Path -LiteralPath $LocalPath -PathType Leaf)) {
        throw "Missing local media for $Identity`: $LocalPath"
    }
    $resolved = (Resolve-Path -LiteralPath $LocalPath).Path
    $actualBytes = (Get-Item -LiteralPath $resolved).Length
    if ($actualBytes -ne $ExpectedBytes) {
        throw "Byte mismatch for $Identity`: expected=$ExpectedBytes actual=$actualBytes path=$resolved"
    }
    if (!$SkipHashValidation) {
        $actualSha256 = Get-Sha256 $resolved
        if ($actualSha256 -ne $ExpectedSha256.ToLowerInvariant()) {
            throw "SHA-256 mismatch for $Identity`: expected=$ExpectedSha256 actual=$actualSha256 path=$resolved"
        }
    }
    return [pscustomobject][ordered]@{
        kind = $Kind
        identity = $Identity
        bucket = $Bucket
        objectKey = $ObjectKey
        localPath = $resolved
        sizeBytes = $actualBytes
        sha256 = $ExpectedSha256.ToLowerInvariant()
        contentType = $ContentType
        cacheControl = 'public, max-age=31536000, immutable'
        contentDisposition = 'inline'
    }
}

$recipeManifest = Get-Content -Raw -LiteralPath $recipeManifestPath | ConvertFrom-Json
if ([int]$recipeManifest.record_count -ne 1500 -or @($recipeManifest.entries).Count -ne 1500) {
    throw 'Recipe image manifest must contain exactly 1500 production entries.'
}
if (@($recipeManifest.excluded_source_files).Count -ne 6) {
    throw 'Recipe image manifest must retain exactly six excluded non-canonical source files.'
}

$items = [System.Collections.Generic.List[object]]::new()
foreach ($entry in @($recipeManifest.entries | Sort-Object object_path)) {
    $fileName = Split-Path -Leaf ([string]$entry.object_path)
    $localRecipePath = Join-Path $recipeMediaRoot $fileName
    if (!(Test-Path -LiteralPath $localRecipePath -PathType Leaf)) {
        # The fourteen original JPEGs predate canonical object-key naming and
        # intentionally retain underscore filenames on disk. Their manifest
        # SHA/size remains the authority and is validated below.
        $legacyFileName = $fileName.Replace('-', '_')
        $localRecipePath = Join-Path $recipeMediaRoot $legacyFileName
    }
    $items.Add((New-ValidatedItem `
        -Kind 'recipe-image' `
        -Identity ([string]$entry.canonical_id) `
        -Bucket 'bil-recipes-2026-v1' `
        -ObjectKey ([string]$entry.object_path) `
        -LocalPath $localRecipePath `
        -ExpectedBytes ([long]$entry.size_bytes) `
        -ExpectedSha256 ([string]$entry.sha256) `
        -ContentType ([string]$entry.mime_type)))
}

$bundleRegistry = Get-Content -Raw -LiteralPath $bundleRegistryPath | ConvertFrom-Json
if ([int]$bundleRegistry.bundleCount -ne 2 -or [int]$bundleRegistry.playableCount -ne 302) {
    throw 'Workout bundle registry must pin exactly two bundles and 302 playable records.'
}
foreach ($bundleRef in @($bundleRegistry.bundles | Sort-Object bundleId)) {
    $manifestPath = Join-Path $RepositoryRoot ([string]$bundleRef.manifestAsset).Replace('/', '\')
    if ((Get-Sha256 $manifestPath) -ne ([string]$bundleRef.manifestSha256).ToLowerInvariant()) {
        throw "Pinned workout bundle manifest SHA mismatch: $manifestPath"
    }
    $bundle = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if (@($bundle.records).Count -ne [int]$bundleRef.playableCount) {
        throw "Workout count mismatch for bundle $($bundleRef.bundleId)"
    }
    foreach ($record in @($bundle.records | Sort-Object objectPath)) {
        if (!$record.playable -or [string]$record.reviewStatus -ne 'human_approved') {
            throw "Workout is not approved/playable: $($record.releaseKey)"
        }
        $items.Add((New-ValidatedItem `
            -Kind 'workout-video' `
            -Identity ([string]$record.releaseKey) `
            -Bucket 'bil-premium-workouts-2026-v1' `
            -ObjectKey ([string]$record.objectPath) `
            -LocalPath (Resolve-WorkoutLocalPath $record) `
            -ExpectedBytes ([long]$record.byteLength) `
            -ExpectedSha256 ([string]$record.sha256) `
            -ContentType ([string]$record.mimeType)))
    }
}

$orderedItems = @($items | Sort-Object bucket, objectKey)
if ($orderedItems.Count -ne 1802) {
    throw "Cloudflare media plan must contain exactly 1802 items, got $($orderedItems.Count)."
}
$uniqueTargets = @($orderedItems | ForEach-Object { "$($_.bucket)/$($_.objectKey)" } | Sort-Object -Unique)
if ($uniqueTargets.Count -ne 1802) {
    throw 'Cloudflare media plan contains duplicate bucket/object targets.'
}
$recipeCount = @($orderedItems | Where-Object kind -eq 'recipe-image').Count
$workoutCount = @($orderedItems | Where-Object kind -eq 'workout-video').Count
$uniqueWorkoutPayloads = @($orderedItems | Where-Object kind -eq 'workout-video' | Select-Object -ExpandProperty sha256 -Unique).Count
if ($recipeCount -ne 1500 -or $workoutCount -ne 302 -or $uniqueWorkoutPayloads -ne 301) {
    throw "Inventory invariant failed: recipes=$recipeCount workouts=$workoutCount uniqueWorkoutPayloads=$uniqueWorkoutPayloads"
}

$plan = [ordered]@{
    schema = 'bil.cloudflare-media-upload-plan.v1'
    source = [ordered]@{
        recipeImageManifest = 'assets/catalogs/recipes/v1/recipe-images.json'
        recipeImageManifestSha256 = Get-Sha256 $recipeManifestPath
        workoutBundleRegistry = 'artifacts/workout_media/workout_release_bundle_registry_v1.json'
        workoutBundleRegistrySha256 = Get-Sha256 $bundleRegistryPath
    }
    buckets = @(
        [ordered]@{ name = 'bil-premium-workouts-2026-v1'; visibility = 'private'; locationHint = 'eeur' },
        [ordered]@{ name = 'bil-recipes-2026-v1'; visibility = 'private-until-custom-domain'; locationHint = 'eeur' }
    )
    counts = [ordered]@{
        total = 1802
        recipeImages = 1500
        workoutVideos = 302
        uniqueWorkoutPayloads = 301
    }
    totalBytes = [long](($orderedItems | Measure-Object -Property sizeBytes -Sum).Sum)
    limits = [ordered]@{
        hardAccountCeilingBytes = $hardAccountCeilingBytes
        safetyPlanCeilingBytes = $safetyPlanCeilingBytes
        policy = 'refuse-plan-at-or-above-safety-ceiling-and-never-exceed-hard-account-ceiling'
    }
    items = $orderedItems
}
if ($plan.totalBytes -gt $safetyPlanCeilingBytes -or $plan.totalBytes -ge $hardAccountCeilingBytes) {
    throw "R2 capacity guard rejected plan: planned=$($plan.totalBytes) safety=$safetyPlanCeilingBytes hard=$hardAccountCeilingBytes"
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$json = $plan | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutputPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
$planSha256 = Get-Sha256 $OutputPath
[System.IO.File]::WriteAllText("$OutputPath.sha256", "$planSha256  $(Split-Path -Leaf $OutputPath)`n", [System.Text.UTF8Encoding]::new($false))

Write-Host "CLOUDFLARE_MEDIA_PLAN_READY items=1802 recipes=1500 workouts=302 uniqueWorkoutPayloads=301 bytes=$($plan.totalBytes) sha256=$planSha256"
Write-Host "plan=$OutputPath"
