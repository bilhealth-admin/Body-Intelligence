[CmdletBinding()]
param([string]$RepositoryRoot = '')

$ErrorActionPreference = 'Stop'
if (!$RepositoryRoot) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Fail([string]$message) { throw "CONTENT_MEDIA_AUDIT=FAIL $message" }
function FullPath([string]$relative) { Join-Path $RepositoryRoot ($relative -replace '/', '\') }

$releasePath = FullPath 'assets/catalogs/recipes/v1/release-manifest.json'
if (!(Test-Path -LiteralPath $releasePath -PathType Leaf)) { Fail 'missing recipe release manifest' }
$release = Get-Content -Raw -LiteralPath $releasePath | ConvertFrom-Json
if ([int]$release.record_count -ne 1500) { Fail "recipe count expected=1500 actual=$($release.record_count)" }

$releaseFiles = @($release.index_path, $release.provenance_path, $release.image_manifest_path) + @($release.shards.path)
$broken = New-Object System.Collections.Generic.List[string]
foreach ($relative in $releaseFiles) {
    $path = FullPath ([string]$relative)
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { $broken.Add([string]$relative); continue }
    $entry = if ($relative -eq $release.index_path) { $release } elseif ($relative -eq $release.provenance_path) { $release } elseif ($relative -eq $release.image_manifest_path) { $release } else { @($release.shards | Where-Object path -eq $relative)[0] }
    $expected = if ($relative -eq $release.index_path) { $release.index_sha256 } elseif ($relative -eq $release.provenance_path) { $release.provenance_sha256 } elseif ($relative -eq $release.image_manifest_path) { $release.image_manifest_sha256 } else { $entry.sha256 }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -ne ([string]$expected).ToLowerInvariant()) { Fail "recipe release hash mismatch path=$relative" }
}

$imagesManifest = Get-Content -Raw -LiteralPath (FullPath ([string]$release.image_manifest_path)) | ConvertFrom-Json
$imageEntries = @($imagesManifest.entries)
if ([int]$imagesManifest.record_count -ne [int]$release.record_count -or $imageEntries.Count -ne [int]$release.record_count) {
    Fail "recipe image manifest count mismatch entries=$($imageEntries.Count)"
}

$reviewedImages = @($imageEntries | Where-Object { $_.review_status -in @('human-reviewed','licensed-reviewed','generated-visual-reviewed') })
$linkedImages = @($reviewedImages | Where-Object { $_.asset_path })
foreach ($entry in $linkedImages) {
    $path = FullPath ([string]$entry.asset_path)
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { $broken.Add([string]$entry.asset_path); continue }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -ne ([string]$entry.sha256).ToLowerInvariant()) { Fail "recipe image hash mismatch id=$($entry.canonical_id)" }
}

$physicalImages = @(Get-ChildItem -LiteralPath (FullPath 'assets/images/professional/recipes') -File | Where-Object Extension -Match '^\.(png|jpe?g|webp)$')
$hashGroups = @($physicalImages | ForEach-Object { [pscustomobject]@{ Path=$_.FullName; Hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash } } | Group-Object Hash | Where-Object Count -gt 1)
$shaDuplicateFiles = ($hashGroups | ForEach-Object Count | Measure-Object -Sum).Sum
if ($null -eq $shaDuplicateFiles) { $shaDuplicateFiles = 0 }

Add-Type -AssemblyName System.Drawing
function Get-DHash([string]$path) {
    $source = [System.Drawing.Image]::FromFile($path)
    try {
        $small = New-Object System.Drawing.Bitmap 9,8
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($small)
            try { $graphics.DrawImage($source, 0, 0, 9, 8) } finally { $graphics.Dispose() }
            [UInt64]$hash = 0
            for ($y = 0; $y -lt 8; $y++) {
                for ($x = 0; $x -lt 8; $x++) {
                    $left = $small.GetPixel($x, $y); $right = $small.GetPixel($x + 1, $y)
                    $leftLum = 299 * $left.R + 587 * $left.G + 114 * $left.B
                    $rightLum = 299 * $right.R + 587 * $right.G + 114 * $right.B
                    if ($leftLum -gt $rightLum) { $hash = $hash -bor ([UInt64]1 -shl ($y * 8 + $x)) }
                }
            }
            return $hash
        } finally { $small.Dispose() }
    } finally { $source.Dispose() }
}
function BitCount([UInt64]$value) {
    $count = 0
    while ($value -ne 0) { $value = $value -band ($value - 1); $count++ }
    return $count
}
$perceptual = @($physicalImages | ForEach-Object { [pscustomobject]@{ Name=$_.Name; Hash=(Get-DHash $_.FullName) } })
$perceptualPairs = 0
for ($leftIndex = 0; $leftIndex -lt $perceptual.Count; $leftIndex++) {
    for ($rightIndex = $leftIndex + 1; $rightIndex -lt $perceptual.Count; $rightIndex++) {
        if ((BitCount ([UInt64]($perceptual[$leftIndex].Hash -bxor $perceptual[$rightIndex].Hash))) -le 5) { $perceptualPairs++ }
    }
}

$registryPath = FullPath 'artifacts/workout_media/workout_release_bundle_registry_v1.json'
if (!(Test-Path -LiteralPath $registryPath -PathType Leaf)) { Fail 'missing workout bundle registry' }
$registry = Get-Content -Raw -LiteralPath $registryPath | ConvertFrom-Json
if (
    [string]$registry.schema -ne 'bil.workout-media.bundle-registry.v1' -or
    [int]$registry.bundleCount -ne 2 -or
    [int]$registry.totalRecordCount -ne 302 -or
    [int]$registry.playableCount -ne 302 -or
    [int]$registry.uniquePayloadCount -ne 301
) { Fail 'workout bundle registry summary is invalid' }

$workoutRecords = New-Object System.Collections.Generic.List[object]
$releaseKeys = New-Object System.Collections.Generic.HashSet[string]
$workoutDigests = New-Object System.Collections.Generic.HashSet[string]
$bundleCounts = @{}
$lineageCount = 0
foreach ($descriptor in @($registry.bundles)) {
    $manifestPath = FullPath ([string]$descriptor.manifestAsset)
    $approvalPath = FullPath ([string]$descriptor.ownerApprovalAsset)
    if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf) -or !(Test-Path -LiteralPath $approvalPath -PathType Leaf)) {
        Fail "missing workout bundle metadata bundle=$($descriptor.bundleId)"
    }
    $manifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()
    $approvalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $approvalPath).Hash.ToLowerInvariant()
    if ($manifestHash -ne [string]$descriptor.manifestSha256 -or $approvalHash -ne [string]$descriptor.ownerApprovalSha256) {
        Fail "workout bundle metadata hash mismatch bundle=$($descriptor.bundleId)"
    }
    $bundle = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $approval = Get-Content -Raw -LiteralPath $approvalPath | ConvertFrom-Json
    $records = @($bundle.records)
    if (
        [string]$bundle.schema -ne 'bil.workout-media.bundle-release-manifest.v1' -or
        [string]$bundle.bundleId -ne [string]$descriptor.bundleId -or
        $records.Count -ne [int]$descriptor.playableCount -or
        [int]$bundle.summary.playable -ne $records.Count -or
        [int]$bundle.summary.blocked -ne 0 -or
        [string]$approval.decision -ne 'accept_all_without_exception' -or
        [int]$approval.ownerApprovedCount -ne $records.Count
    ) { Fail "invalid workout bundle contract bundle=$($descriptor.bundleId)" }
    $bundleCounts[[string]$bundle.bundleId] = $records.Count
    foreach ($entry in $records) {
        $durationFramesValid = (
            ([int]$entry.durationMilliseconds -eq 7000 -and [int]$entry.frameCount -eq 210) -or
            ([int]$entry.durationMilliseconds -eq 10000 -and [int]$entry.frameCount -eq 300)
        )
        if (
            [string]$entry.releaseKey -ne "$($bundle.bundleId):$($entry.assetId)" -or
            [string]$entry.reviewStatus -ne 'human_approved' -or
            $entry.playable -ne $true -or
            [string]$entry.mimeType -ne 'video/mp4' -or
            [string]$entry.codecName -ne 'h264' -or
            !$durationFramesValid -or
            [int]$entry.fpsNumerator -ne 30 -or [int]$entry.fpsDenominator -ne 1 -or
            [int]$entry.width -ne 720 -or [int]$entry.height -ne 1280 -or
            [long]$entry.byteLength -le 0 -or
            [string]$entry.sha256 -notmatch '^[0-9a-f]{64}$' -or
            !$releaseKeys.Add([string]$entry.releaseKey)
        ) { Fail "invalid approved workout evidence key=$($entry.releaseKey)" }
        [void]$workoutDigests.Add([string]$entry.sha256)
        if ($null -ne $entry.lineage) {
            if (
                [string]$entry.lineage.operation -ne 'non_destructive_h264_delivery_transcode' -or
                [string]$entry.lineage.sourceCodecName -ne 'mpeg4' -or
                $entry.lineage.sourcePreserved -ne $true -or
                [string]$entry.lineage.sourceSha256 -notmatch '^[0-9a-f]{64}$'
            ) { Fail "invalid workout transcode lineage key=$($entry.releaseKey)" }
            $lineageCount++
        }
        $workoutRecords.Add($entry)
    }
}
if (
    $workoutRecords.Count -ne 302 -or $releaseKeys.Count -ne 302 -or
    $workoutDigests.Count -ne 301 -or $bundleCounts['home-training'] -ne 200 -or
    $bundleCounts['gym-six-month'] -ne 102 -or $lineageCount -ne 2
) { Fail 'combined workout bundle inventory is invalid' }

Write-Output 'CONTENT_MEDIA_AUDIT=PASS'
Write-Output "RECIPES_TOTAL=$($release.record_count)"
Write-Output "RECIPE_IMAGES_TOTAL=$($physicalImages.Count)"
Write-Output "RECIPE_IMAGES_QA_PASS=$($reviewedImages.Count)"
Write-Output "RECIPE_IMAGES_LINKED=$($linkedImages.Count)"
Write-Output "SHA_DUPLICATE_FILES=$shaDuplicateFiles"
Write-Output "PERCEPTUAL_DUPLICATE_PAIRS_DHASH_LE5=$perceptualPairs"
Write-Output "WORKOUT_VIDEOS_TOTAL=$($workoutRecords.Count)"
Write-Output "WORKOUT_VIDEOS_LINKED=$($workoutRecords.Count)"
Write-Output "WORKOUT_UNIQUE_PAYLOADS=$($workoutDigests.Count)"
Write-Output "WORKOUT_HOME_LOGICAL_RECORDS=$($bundleCounts['home-training'])"
Write-Output "WORKOUT_GYM_LOGICAL_RECORDS=$($bundleCounts['gym-six-month'])"
Write-Output "WORKOUT_H264_LINEAGE_DERIVATIVES=$lineageCount"
Write-Output 'WORKOUT_REMOTE_PUBLICATION=BLOCKED_DESTINATION_NOT_SELECTED'
Write-Output "BROKEN_ACTIVE_MEDIA_REFERENCES=$($broken.Count)"
Write-Output "UNVERIFIED_EXTERNAL_RECIPE_IMAGES=$(@($imageEntries | Where-Object status -eq 'external_candidate').Count)"
Write-Output 'WORKOUT_OWNER_APPROVAL=302_OF_302'
