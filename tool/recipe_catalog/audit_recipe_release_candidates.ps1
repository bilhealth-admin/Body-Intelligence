[CmdletBinding()]
param(
    [string]$ManifestPath = 'assets/catalogs/recipes/v1/recipe-images.json',
    [string]$AssetDirectory = 'assets/images/professional/recipes',
    [string]$ShardDirectory = 'assets/catalogs/recipes/v1/shards'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$entries = @($manifest.entries)
if ([int]$manifest.record_count -ne 1500 -or $entries.Count -ne 1500) {
    throw "RECIPE_CANDIDATE_AUDIT=FAIL expected=1500 actual=$($entries.Count)"
}

$errors = [System.Collections.Generic.List[string]]::new()
$ids = [System.Collections.Generic.HashSet[string]]::new()
$hashes = [System.Collections.Generic.HashSet[string]]::new()
$referenced = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$verifiedBytes = [int64]0
$localAssetById = @{}
Get-ChildItem -LiteralPath $ShardDirectory -Filter 'recipes-*.json' -File |
    ForEach-Object {
        $shard = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
        foreach ($record in @($shard.records)) {
            $assetPath = [string]$record.image.assetPath
            if (![string]::IsNullOrWhiteSpace($assetPath)) {
                $localAssetById[[string]$record.canonicalId] = Split-Path -Leaf $assetPath
            }
        }
    }

foreach ($entry in $entries) {
    $id = [string]$entry.canonical_id
    if (!$ids.Add($id)) { $errors.Add("duplicate canonical id: $id"); continue }
    if ($entry.status -ne 'external_candidate' -or $entry.review_status -ne 'review_evidence_unbound') {
        $errors.Add("candidate/review gate mismatch: $id")
    }
    $filename = Split-Path -Leaf ([string]$entry.object_path)
    $path = Join-Path $AssetDirectory $filename
    if (!(Test-Path -LiteralPath $path -PathType Leaf) -and $localAssetById.ContainsKey($id)) {
        $filename = [string]$localAssetById[$id]
        $path = Join-Path $AssetDirectory $filename
    }
    [void]$referenced.Add($filename)
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("missing candidate: $id -> $filename")
        continue
    }
    $file = Get-Item -LiteralPath $path
    if ($file.Length -ne [int64]$entry.size_bytes) { $errors.Add("size mismatch: $id") }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne ([string]$entry.sha256).ToLowerInvariant()) { $errors.Add("hash mismatch: $id") }
    if (!$hashes.Add($hash)) { $errors.Add("duplicate candidate bytes: $id") }
    $image = [System.Drawing.Image]::FromFile($file.FullName)
    try {
        if ($image.Width -ne [int]$entry.width -or $image.Height -ne [int]$entry.height) {
            $errors.Add("dimension mismatch: $id")
        }
    } finally { $image.Dispose() }
    $verifiedBytes += $file.Length
}

$orphans = @(Get-ChildItem -LiteralPath $AssetDirectory -File | Where-Object { !$referenced.Contains($_.Name) })
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Output "ERROR=$_" }
    throw "RECIPE_CANDIDATE_AUDIT=FAIL errors=$($errors.Count)"
}

Write-Output 'RECIPE_CANDIDATE_AUDIT=PASS'
Write-Output "CANDIDATES_TECHNICALLY_VERIFIED=$($entries.Count)"
Write-Output "UNIQUE_HASHES=$($hashes.Count)"
Write-Output "VERIFIED_BYTES=$verifiedBytes"
Write-Output "HUMAN_REVIEWED=0"
Write-Output "PLAYABLE_OR_PUBLISHED=0"
Write-Output "UNREFERENCED_LOCAL_FILES=$($orphans.Count)"
foreach ($orphan in $orphans) { Write-Output "UNREFERENCED=$($orphan.Name)" }
