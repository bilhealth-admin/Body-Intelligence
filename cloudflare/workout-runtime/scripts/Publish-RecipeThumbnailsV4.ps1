[CmdletBinding()]
param(
    [string]$ManifestPath = "../../../assets/catalogs/recipes/v1/recipe-thumbnails-v4.json",
    [string]$GeneratedDirectory = "../../../.tmp/recipe-thumbnails-v4",
    [switch]$Execute,
    [ValidateRange(1, 8)]
    [int]$Concurrency = 6,
    [ValidateRange(1, 5)]
    [int]$MaxUploadAttempts = 4
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$workerRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $workerRoot "../.."))
function Resolve-InputPath([string]$Value) {
    $candidate = if ([System.IO.Path]::IsPathRooted($Value)) {
        $Value
    } else {
        Join-Path $PSScriptRoot $Value
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

$manifestFile = Resolve-InputPath $ManifestPath
$generatedRoot = Resolve-InputPath $GeneratedDirectory
$expectedManifestSha256 = "24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029"
$manifestItem = Get-Item -LiteralPath $manifestFile
$manifestSha256 = (Get-FileHash -LiteralPath $manifestFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifestItem.Length -ne 899684 -or $manifestSha256 -ne $expectedManifestSha256) {
    throw "Recipe thumbnail v4 manifest bytes differ from the reviewed release."
}
$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
$expectedSourceManifestSha256 = "e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3"
$expectedTopKeys = @(
    "entries", "record_count", "schema_version",
    "source_image_manifest_sha256", "total_size_bytes", "transformation"
)
$actualTopKeys = @($manifest.PSObject.Properties.Name | Sort-Object)
if (($actualTopKeys -join ",") -ne (($expectedTopKeys | Sort-Object) -join ",") -or
    [int]$manifest.schema_version -ne 4 -or
    [int]$manifest.record_count -ne 1500 -or
    @($manifest.entries).Count -ne 1500 -or
    [string]$manifest.source_image_manifest_sha256 -ne $expectedSourceManifestSha256) {
    throw "Refusing an unknown or incomplete recipe thumbnail v4 manifest."
}
$transformation = $manifest.transformation
$expectedTransformation = [ordered]@{
    codec = "libwebp"
    fit = "contain-no-upscale"
    max_height = 512
    max_width = 512
    method = 6
    quality = 78
    resampling = "lanczos"
    version = 1
}
foreach ($name in $expectedTransformation.Keys) {
    if ($transformation.$name -ne $expectedTransformation[$name]) {
        throw "Recipe thumbnail transformation pin differs at '$name'."
    }
}
if ((@($transformation.PSObject.Properties.Name | Sort-Object) -join ",") -ne
    ((@($expectedTransformation.Keys) | Sort-Object) -join ",")) {
    throw "Recipe thumbnail transformation contains unknown fields."
}

$sourceManifest = Join-Path $repositoryRoot "assets/catalogs/recipes/v1/recipe-images.json"
$sourceManifestSha256 = (Get-FileHash -LiteralPath $sourceManifest -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceManifestSha256 -ne $expectedSourceManifestSha256) {
    throw "The authoritative recipe image manifest changed after thumbnail generation."
}
$source = Get-Content -LiteralPath $sourceManifest -Raw | ConvertFrom-Json
$sourceById = @{}
foreach ($entry in $source.entries) { $sourceById[[string]$entry.canonical_id] = $entry }

$expectedEntryKeys = @(
    "canonical_id", "delivery_path", "height", "mime_type", "object_path",
    "sha256", "size_bytes", "source_sha256", "width"
)
$validated = [System.Collections.Generic.List[object]]::new()
$ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$totalSize = [long]0
foreach ($entry in $manifest.entries) {
    $entryKeys = @($entry.PSObject.Properties.Name | Sort-Object)
    if (($entryKeys -join ",") -ne (($expectedEntryKeys | Sort-Object) -join ",")) {
        throw "Unknown fields in thumbnail entry '$($entry.canonical_id)'."
    }
    $id = [string]$entry.canonical_id
    $digest = ([string]$entry.sha256).ToLowerInvariant()
    $objectKey = [string]$entry.object_path
    $expectedKey = "recipes/v4/thumbnails/512/$id-$digest.webp"
    $expectedDelivery = "/v4/recipes/thumbnails/$id/$digest.webp"
    if ($id -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or
        $digest -notmatch '^[0-9a-f]{64}$' -or
        $objectKey -ne $expectedKey -or
        [string]$entry.delivery_path -ne $expectedDelivery -or
        [string]$entry.mime_type -ne "image/webp" -or
        [int]$entry.width -lt 1 -or [int]$entry.width -gt 512 -or
        [int]$entry.height -lt 1 -or [int]$entry.height -gt 512 -or
        -not $ids.Add($id) -or -not $keys.Add($objectKey)) {
        throw "Unsafe or non-canonical thumbnail entry '$id'."
    }
    if (-not $sourceById.ContainsKey($id) -or
        [string]$sourceById[$id].sha256 -ne [string]$entry.source_sha256) {
        throw "Thumbnail source pin differs for '$id'."
    }
    $fileName = "$id-$digest.webp"
    $localPath = Join-Path $generatedRoot $fileName
    if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        throw "Generated thumbnail is missing: $fileName"
    }
    $local = Get-Item -LiteralPath $localPath
    $actualSha256 = (Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($local.Length -ne [long]$entry.size_bytes -or $actualSha256 -ne $digest) {
        throw "Generated thumbnail integrity mismatch: $fileName"
    }
    $totalSize += $local.Length
    $validated.Add([pscustomobject]@{
        canonicalId = $id
        objectKey = $objectKey
        localPath = $local.FullName
        sha256 = $digest
        sizeBytes = [long]$local.Length
    })
}
if ($validated.Count -ne 1500 -or $ids.Count -ne 1500 -or $keys.Count -ne 1500 -or
    $totalSize -ne [long]$manifest.total_size_bytes) {
    throw "Recipe thumbnail count or byte total differs from the manifest."
}

# The exact baseline is release-pinned by the two already-published plans. The
# live object-count guard below ensures this calculation is not used for an
# unrelated bucket. The additive v4 inventory must stay under the project's
# conservative 9.5 GB safety ceiling.
$mediaPlan = Get-Content -LiteralPath (Join-Path $repositoryRoot "artifacts/cloudflare_media/media_upload_plan_v1.json") -Raw | ConvertFrom-Json
$runtimePlan = Get-Content -LiteralPath (Join-Path $repositoryRoot "artifacts/workout_media/cloudflare_runtime_v2/runtime_object_plan_v2.json") -Raw | ConvertFrom-Json
$baselineBytes = [long]$mediaPlan.totalBytes + [long](($runtimePlan.items | Measure-Object -Property sizeBytes -Sum).Sum)
$projectedBytes = $baselineBytes + $totalSize
if ($baselineBytes -ne 9261305529 -or $projectedBytes -gt 9500000000) {
    throw "R2 capacity guard rejected v4 thumbnails: baseline=$baselineBytes thumbnails=$totalSize projected=$projectedBytes"
}

$wrangler = Join-Path $workerRoot "node_modules/.bin/wrangler.cmd"
if (-not (Test-Path -LiteralPath $wrangler -PathType Leaf)) {
    throw "Pinned project Wrangler is unavailable."
}
Push-Location -LiteralPath $workerRoot
try {
    $whoamiOutput = @(& $wrangler whoami 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Cloudflare authentication is unavailable." }
    $recipeInfoRaw = @(& $wrangler r2 bucket info bil-recipes-2026-v1 --json 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect the recipe R2 bucket." }
    $recipeInfo = ($recipeInfoRaw -join "`n") | ConvertFrom-Json
    $liveRecipeCount = [int](([string]$recipeInfo.object_count).Replace(",", ""))
    if ($liveRecipeCount -lt 1500 -or $liveRecipeCount -gt 3000) {
        throw "Recipe R2 object count is outside the safe v1/v4 range: $liveRecipeCount"
    }
} finally {
    Pop-Location
}

if (-not $Execute) {
    Write-Output "RECIPE_THUMBNAILS_V4 validated=1500 bytes=$totalSize projectedR2Bytes=$projectedBytes liveRecipeObjects=$liveRecipeCount execute=false"
    exit 0
}

$resultRoot = Join-Path $repositoryRoot ".tmp/recipe-thumbnails-v4-upload-results"
New-Item -ItemType Directory -Force -Path $resultRoot | Out-Null
$pending = @($validated | Where-Object {
    $receipt = Join-Path $resultRoot "$($_.canonicalId)-$($_.sha256).ok"
    -not (Test-Path -LiteralPath $receipt -PathType Leaf)
})
$pending | ForEach-Object -Parallel {
    $item = $_
    $uploaded = $false
    for ($attempt = 1; $attempt -le $using:MaxUploadAttempts; $attempt += 1) {
        Push-Location -LiteralPath $using:workerRoot
        try {
            $destination = "bil-recipes-2026-v1/$($item.objectKey)"
            $output = @(& $using:wrangler r2 object put $destination `
                --remote --force --file $item.localPath `
                --content-type "image/webp" `
                --cache-control "public, max-age=31536000, immutable" `
                --content-disposition "inline" 2>&1)
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        if ($exitCode -eq 0) {
            $receipt = Join-Path $using:resultRoot "$($item.canonicalId)-$($item.sha256).ok"
            Set-Content -LiteralPath $receipt -Value "$($item.objectKey)|$($item.sizeBytes)" -Encoding utf8NoBOM
            $uploaded = $true
            break
        }
        if ($attempt -lt $using:MaxUploadAttempts) {
            Start-Sleep -Seconds ([Math]::Min(12, [Math]::Pow(2, $attempt)))
        }
    }
    if (-not $uploaded) {
        throw "Upload failed after retries: $($item.objectKey)"
    }
} -ThrottleLimit $Concurrency

$receipts = @(Get-ChildItem -LiteralPath $resultRoot -Filter "*.ok" -File)
if ($receipts.Count -ne 1500) {
    throw "Upload did not produce the complete receipt set: $($receipts.Count)/1500"
}
Push-Location -LiteralPath $workerRoot
try {
    $afterRaw = @(& $wrangler r2 bucket info bil-recipes-2026-v1 --json 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Unable to verify the recipe R2 bucket after upload." }
    $after = ($afterRaw -join "`n") | ConvertFrom-Json
    $afterCount = [int](([string]$after.object_count).Replace(",", ""))
} finally {
    Pop-Location
}
$readbackRoot = Join-Path $repositoryRoot ".tmp/recipe-thumbnails-v4-upload-readback"
New-Item -ItemType Directory -Force -Path $readbackRoot | Out-Null
$readbackEntries = @($validated[0], $validated[749], $validated[1499])
foreach ($item in $readbackEntries) {
    $download = Join-Path $readbackRoot "$($item.canonicalId)-$($item.sha256).webp"
    if (Test-Path -LiteralPath $download) {
        [System.IO.File]::Delete($download)
    }
    Push-Location -LiteralPath $workerRoot
    try {
        $downloadOutput = @(& $wrangler r2 object get "bil-recipes-2026-v1/$($item.objectKey)" `
            --remote --file $download 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "R2 readback failed for $($item.objectKey)."
        }
    } finally {
        Pop-Location
    }
    $readback = Get-Item -LiteralPath $download
    $readbackSha256 = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($readback.Length -ne [long]$item.sizeBytes -or $readbackSha256 -ne [string]$item.sha256) {
        throw "R2 readback integrity mismatch for $($item.objectKey)."
    }
}
if ($afterCount -ne 3000) {
    Write-Warning "R2 aggregate object_count is not refreshed yet (reported=$afterCount); exact first/middle/last readbacks passed."
}
Write-Output "RECIPE_THUMBNAILS_V4 uploaded=1500 bytes=$totalSize reportedRecipeObjects=$afterCount readback=3 execute=true"
