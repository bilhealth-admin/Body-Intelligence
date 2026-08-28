[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BundlePath,
    [string]$RequestManifest = 'artifacts/BIL_missing_recipe_image_requests_883.zip',
    [string]$CurrentRequestManifest = 'artifacts/recipe_image_handoff_2026-08-22_corrected/missing_recipe_images_master.csv',
    [string]$ImageManifest = 'assets/catalogs/recipes/v1/recipe-images.json',
    [string]$AssetDirectory = 'assets/images/professional/recipes',
    [int]$ExpectedImageCount = 883,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Resolve-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

$bundle = Resolve-ProjectPath $BundlePath
$requestPath = Resolve-ProjectPath $RequestManifest
$currentRequestPath = Resolve-ProjectPath $CurrentRequestManifest
$imageManifestPath = Resolve-ProjectPath $ImageManifest
$assetRoot = Resolve-ProjectPath $AssetDirectory
if (-not (Test-Path -LiteralPath $bundle -PathType Leaf)) { throw "Bundle not found: $bundle" }
if (-not (Test-Path -LiteralPath $requestPath -PathType Leaf)) { throw "Request manifest not found: $requestPath" }
if (-not (Test-Path -LiteralPath $currentRequestPath -PathType Leaf)) { throw "Current request manifest not found: $currentRequestPath" }
if (-not (Test-Path -LiteralPath $imageManifestPath -PathType Leaf)) { throw "Image manifest not found: $imageManifestPath" }

function Read-ZipText([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try {
        $reader = [IO.StreamReader]::new($stream, [Text.UTF8Encoding]::new($false, $true), $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-ZipBytes([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try {
        $memory = [IO.MemoryStream]::new()
        try {
            $stream.CopyTo($memory)
            Write-Output -NoEnumerate $memory.ToArray()
        }
        finally { $memory.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-Sha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Read-PngDimensions([byte[]]$Bytes, [string]$Name) {
    $signature = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    if ($Bytes.Length -lt 24) { throw "PNG is truncated: $Name" }
    for ($i = 0; $i -lt $signature.Length; $i++) {
        if ($Bytes[$i] -ne $signature[$i]) { throw "Invalid PNG signature: $Name" }
    }
    $width = [uint32](
        ([uint32]$Bytes[16] -shl 24) -bor ([uint32]$Bytes[17] -shl 16) -bor
        ([uint32]$Bytes[18] -shl 8) -bor [uint32]$Bytes[19]
    )
    $height = [uint32](
        ([uint32]$Bytes[20] -shl 24) -bor ([uint32]$Bytes[21] -shl 16) -bor
        ([uint32]$Bytes[22] -shl 8) -bor [uint32]$Bytes[23]
    )
    return [pscustomobject]@{ Width = [int]$width; Height = [int]$height }
}

$requests = if ([IO.Path]::GetExtension($requestPath) -ieq '.zip') {
    $requestArchive = [IO.Compression.ZipFile]::OpenRead($requestPath)
    try {
        $requestEntry = $requestArchive.GetEntry('missing_recipe_images_master.csv')
        if ($null -eq $requestEntry) { throw 'Request ZIP is missing missing_recipe_images_master.csv.' }
        @((Read-ZipText $requestEntry) | ConvertFrom-Csv)
    }
    finally { $requestArchive.Dispose() }
}
else {
    @(Import-Csv -LiteralPath $requestPath -Encoding UTF8)
}
$requestById = @{}
foreach ($row in $requests) {
    $id = [string]$row.canonical_id
    if ($requestById.ContainsKey($id)) { throw "Duplicate request ID: $id" }
    $requestById[$id] = $row
}
$currentRequests = @(Import-Csv -LiteralPath $currentRequestPath -Encoding UTF8)
$currentRequestById = @{}
$currentRequestBySignature = @{}
function Get-RecipeSignature($Row) {
    # Corrected catalog rows may change the preparation method while retaining
    # the same localized recipe identity and exact ingredient set.
    return '{0}|{1}|{2}|{3}' -f $Row.locale, $Row.region, $Row.servings,
        $Row.ingredients_exact
}
foreach ($row in $currentRequests) {
    $id = [string]$row.canonical_id
    if ($currentRequestById.ContainsKey($id)) { throw "Duplicate current request ID: $id" }
    $currentRequestById[$id] = $row
    $signature = Get-RecipeSignature $row
    if ($currentRequestBySignature.ContainsKey($signature)) {
        throw "Duplicate current request signature: $signature"
    }
    $currentRequestBySignature[$signature] = $row
}

$releaseImages = Get-Content -LiteralPath $imageManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$placeholderIds = @{}
$currentIds = @{}
foreach ($entry in $releaseImages.entries) {
    $currentIds[[string]$entry.canonical_id] = $true
    if ($entry.status -eq 'placeholder') { $placeholderIds[[string]$entry.canonical_id] = $true }
}

$sourceRowsById = @{}
$rowsById = @{}
$rowsByFilename = @{}
$batchNumbers = New-Object System.Collections.Generic.List[int]
$validated = New-Object System.Collections.Generic.List[object]
$outer = [IO.Compression.ZipFile]::OpenRead($bundle)
try {
    $batchEntries = @($outer.Entries | Where-Object { $_.FullName -match '(?i)(?:^|/)BIL_recipe_images_batch_(\d{3})(?:_CORRECTED)?\.zip$' })
    if ($batchEntries.Count -eq 0) { throw 'No nested BIL recipe-image batches were found.' }
    foreach ($batchEntry in ($batchEntries | Sort-Object FullName)) {
        if ($batchEntry.FullName.Contains('..') -or $batchEntry.FullName.Contains('\')) {
            throw "Unsafe outer entry path: $($batchEntry.FullName)"
        }
        if ($batchEntry.FullName -notmatch '(?i)batch_(\d{3})(?:_CORRECTED)?\.zip$') {
            throw "Invalid batch filename: $($batchEntry.FullName)"
        }
        $batchNumber = [int]$Matches[1]
        $batchNumbers.Add($batchNumber)
        $nestedBytes = Read-ZipBytes $batchEntry
        $nestedMemory = [IO.MemoryStream]::new($nestedBytes, $false)
        try {
            $inner = [IO.Compression.ZipArchive]::new($nestedMemory, [IO.Compression.ZipArchiveMode]::Read, $false)
            try {
                foreach ($entry in $inner.Entries) {
                    if ($entry.FullName.Contains('..') -or $entry.FullName.Contains('\') -or $entry.FullName.StartsWith('/')) {
                        throw "Unsafe nested entry path in batch $batchNumber`: $($entry.FullName)"
                    }
                }
                $manifestEntry = $inner.GetEntry('manifest.csv')
                if ($null -eq $manifestEntry) { throw "Missing manifest.csv in batch $batchNumber" }
                $rows = @((Read-ZipText $manifestEntry) | ConvertFrom-Csv)
                $imageEntries = @($inner.Entries | Where-Object { $_.FullName -match '^images/[^/]+\.png$' })
                if ($rows.Count -ne $imageEntries.Count) {
                    throw "Manifest/image count mismatch in batch $batchNumber`: rows=$($rows.Count) images=$($imageEntries.Count)"
                }
                foreach ($row in $rows) {
                    foreach ($requiredProperty in @(
                        'canonical_id', 'filename',
                        'actual_format', 'image_sha256',
                        'image_width', 'image_height'
                    )) {
                        if ($null -eq $row.PSObject.Properties[$requiredProperty]) {
                            throw "Batch $batchNumber manifest row is missing '$requiredProperty': $($row | ConvertTo-Json -Compress)"
                        }
                    }
                    $id = [string]$row.canonical_id
                    $filename = [string]$row.filename
                    if ($id -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw "Invalid canonical ID: $id" }
                    if ($filename -ne "$id.png" -or [IO.Path]::GetFileName($filename) -ne $filename) {
                        throw "Unsafe or mismatched filename for $id`: $filename"
                    }
                    if ($sourceRowsById.ContainsKey($id)) { throw "Duplicate generated ID: $id" }
                    if ($rowsByFilename.ContainsKey($filename)) { throw "Duplicate generated filename: $filename" }
                    if (-not $requestById.ContainsKey($id)) { throw "Generated ID was not requested: $id" }
                    $request = $requestById[$id]
                    foreach ($requiredProperty in @('canonical_id', 'filename', 'prompt_sha256')) {
                        if ($null -eq $request.PSObject.Properties[$requiredProperty]) {
                            throw "Request row for $id is missing '$requiredProperty': $($request | ConvertTo-Json -Compress)"
                        }
                    }
                    if ([string]$request.filename -ne $filename) {
                        throw "Request identity mismatch: $id"
                    }
                    $rowPromptHash = $row.PSObject.Properties['prompt_sha256']
                    if ($null -ne $rowPromptHash) {
                        if ([string]$request.prompt_sha256 -ne [string]$rowPromptHash.Value) {
                            throw "Request prompt mismatch: $id"
                        }
                    }
                    else {
                        $sourceVisual = $row.PSObject.Properties['source_visual']
                        if ($null -eq $sourceVisual -or [string]::IsNullOrWhiteSpace([string]$sourceVisual.Value)) {
                            throw "Generated row has neither prompt hash nor audited source visual: $id"
                        }
                    }
                    if ($currentRequestById.ContainsKey($id)) {
                        $targetRequest = $currentRequestById[$id]
                    }
                    else {
                        $requestSignature = Get-RecipeSignature $request
                        if (-not $currentRequestBySignature.ContainsKey($requestSignature)) {
                            throw "Cannot map obsolete generated ID: $id"
                        }
                        $targetRequest = $currentRequestBySignature[$requestSignature]
                    }
                    $targetId = [string]$targetRequest.canonical_id
                    if (-not $currentIds.ContainsKey($targetId)) { throw "Mapped ID is absent from the current catalog: $targetId" }
                    if ($rowsById.ContainsKey($targetId)) { throw "Duplicate mapped generated ID: $targetId" }
                    $statusProperty = $row.PSObject.Properties['generated_status']
                    if (($null -ne $statusProperty -and [string]$statusProperty.Value -ne 'ready') -or
                        [string]$row.actual_format -ne 'PNG') {
                        throw "Generated row is not ready PNG: $id"
                    }
                    $imageEntry = $inner.GetEntry("images/$filename")
                    if ($null -eq $imageEntry) { throw "Missing generated image: $id" }
                    $bytes = Read-ZipBytes $imageEntry
                    $sha = Get-Sha256 $bytes
                    $dimensions = Read-PngDimensions $bytes $filename
                    if ($sha -ne ([string]$row.image_sha256).ToLowerInvariant()) { throw "SHA-256 mismatch: $id" }
                    $declaredSize = $row.PSObject.Properties['file_size_bytes']
                    if ($null -ne $declaredSize -and $bytes.Length -ne [int64]$declaredSize.Value) {
                        throw "File-size mismatch: $id"
                    }
                    if ($dimensions.Width -ne [int]$row.image_width -or $dimensions.Height -ne [int]$row.image_height) {
                        throw "Dimension metadata mismatch: $id"
                    }
                    if ($dimensions.Width -lt 1024 -or $dimensions.Height -lt 1024 -or $dimensions.Width -ne $dimensions.Height) {
                        throw "Image is not square 1024px minimum: $id"
                    }
                    $sourceRowsById[$id] = $true
                    $rowsById[$targetId] = $true
                    $rowsByFilename[$filename] = $true
                    $validated.Add([pscustomobject]@{
                        BatchEntry = $batchEntry.FullName
                        Batch = $batchNumber
                        SourceCanonicalId = $id
                        CanonicalId = $targetId
                        SourceFilename = $filename
                        Filename = "$targetId.png"
                        Sha256 = $sha
                        Width = $dimensions.Width
                        Height = $dimensions.Height
                        Size = $bytes.Length
                    })
                }
            }
            finally { $inner.Dispose() }
        }
        finally { $nestedMemory.Dispose() }
    }
}
finally { $outer.Dispose() }

$duplicates = @($batchNumbers | Group-Object | Where-Object Count -ne 1)
if ($duplicates.Count -gt 0) { throw "Duplicate batch numbers: $($duplicates.Name -join ', ')" }
$expectedBatches = 1..([math]::Ceiling($ExpectedImageCount / 10))
$actualBatches = @($batchNumbers | Sort-Object)
if (($expectedBatches -join ',') -ne ($actualBatches -join ',')) {
    throw "Batch sequence is incomplete: expected 1..$($expectedBatches[-1]), got $($actualBatches -join ',')"
}
if ($validated.Count -ne $ExpectedImageCount) {
    throw "Generated image count mismatch: expected $ExpectedImageCount, got $($validated.Count)"
}

$missingRequestIds = @($requestById.Keys | Where-Object { -not $sourceRowsById.ContainsKey($_) } | Sort-Object)
$currentPlaceholdersNotInBundle = @(
    $placeholderIds.Keys | Where-Object { -not $rowsById.ContainsKey($_) } | Sort-Object
)
$conflicts = New-Object System.Collections.Generic.List[string]
$alreadyInstalled = 0
foreach ($item in $validated) {
    $destination = Join-Path $assetRoot $item.Filename
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $existingHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($existingHash -ne $item.Sha256) { $conflicts.Add($item.CanonicalId) }
        else { $alreadyInstalled++ }
    }
}
if ($conflicts.Count -gt 0) { throw "Refusing to overwrite conflicting assets: $($conflicts -join ', ')" }

if (-not $ValidateOnly) {
    New-Item -ItemType Directory -Path $assetRoot -Force | Out-Null
    $outer = [IO.Compression.ZipFile]::OpenRead($bundle)
    try {
        foreach ($batchEntry in ($outer.Entries | Where-Object { $_.FullName -match '(?i)(?:^|/)BIL_recipe_images_batch_(\d{3})(?:_CORRECTED)?\.zip$' } | Sort-Object FullName)) {
            $nestedBytes = Read-ZipBytes $batchEntry
            $nestedMemory = [IO.MemoryStream]::new($nestedBytes, $false)
            try {
                $inner = [IO.Compression.ZipArchive]::new($nestedMemory, [IO.Compression.ZipArchiveMode]::Read, $false)
                try {
                    foreach ($entry in $inner.Entries | Where-Object { $_.FullName -match '^images/[^/]+\.png$' }) {
                        $sourceFilename = [IO.Path]::GetFileName($entry.FullName)
                        $item = $validated | Where-Object SourceFilename -eq $sourceFilename | Select-Object -First 1
                        $destination = Join-Path $assetRoot $item.Filename
                        if (Test-Path -LiteralPath $destination -PathType Leaf) { continue }
                        $temporary = "$destination.importing"
                        $source = $entry.Open()
                        try {
                            $target = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                            try { $source.CopyTo($target) } finally { $target.Dispose() }
                        }
                        finally { $source.Dispose() }
                        $writtenHash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
                        if ($writtenHash -ne $item.Sha256) { throw "Written SHA-256 mismatch: $sourceFilename" }
                        Move-Item -LiteralPath $temporary -Destination $destination
                    }
                }
                finally { $inner.Dispose() }
            }
            finally { $nestedMemory.Dispose() }
        }
    }
    finally { $outer.Dispose() }
}

$mode = if ($ValidateOnly) { 'VALIDATED' } else { 'IMPORTED' }
Write-Output "RECIPE_IMAGE_BUNDLE=$mode images=$($validated.Count) batches=$($actualBatches.Count) already_installed=$alreadyInstalled request_rows=$($requests.Count) request_rows_not_in_bundle=$($missingRequestIds.Count) current_placeholders_not_in_bundle=$($currentPlaceholdersNotInBundle.Count)"
if ($missingRequestIds.Count -gt 0) { Write-Output "NOT_IN_BUNDLE=$($missingRequestIds -join ',')" }
if ($currentPlaceholdersNotInBundle.Count -gt 0) { Write-Output "CURRENT_PLACEHOLDERS_NOT_IN_BUNDLE=$($currentPlaceholdersNotInBundle -join ',')" }
