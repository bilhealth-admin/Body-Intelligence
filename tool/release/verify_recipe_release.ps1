$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releasePath = Join-Path $workspace 'assets\catalogs\recipes\v1\release-manifest.json'
if (-not (Test-Path -LiteralPath $releasePath -PathType Leaf)) {
  throw 'RECIPE_RELEASE=FAIL missing release manifest'
}

$release = Get-Content -Raw -LiteralPath $releasePath | ConvertFrom-Json
if ([int]$release.record_count -ne 1500) {
  throw "RECIPE_RELEASE=FAIL record_count=$($release.record_count)"
}
if (@($release.shards).Count -ne 30) {
  throw "RECIPE_RELEASE=FAIL shard_count=$(@($release.shards).Count)"
}

$components = @(
  [pscustomobject]@{
    path = [string]$release.index_path
    sha256 = [string]$release.index_sha256
    size = [long]$release.index_size_bytes
  },
  [pscustomobject]@{
    path = [string]$release.image_manifest_path
    sha256 = [string]$release.image_manifest_sha256
    size = [long]$release.image_manifest_size_bytes
  },
  [pscustomobject]@{
    path = [string]$release.provenance_path
    sha256 = [string]$release.provenance_sha256
    size = [long]$release.provenance_size_bytes
  }
)
$components += @($release.shards | ForEach-Object {
  [pscustomobject]@{
    path = [string]$_.path
    sha256 = [string]$_.sha256
    size = [long]$_.size_bytes
  }
})

$failures = @()
foreach ($component in $components) {
  $path = Join-Path $workspace $component.path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    $failures += "missing:$($component.path)"
    continue
  }
  $file = Get-Item -LiteralPath $path
  if ($file.Length -ne $component.size) {
    $failures += "size:$($component.path)"
  }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
  if ($hash -ne $component.sha256.ToLowerInvariant()) {
    $failures += "sha256:$($component.path)"
  }
}
if ($failures.Count -gt 0) {
  throw "RECIPE_RELEASE=FAIL component_errors=$($failures -join ',')"
}

$shardRecords = (@($release.shards) | Measure-Object -Property count -Sum).Sum
if ([int]$shardRecords -ne [int]$release.record_count) {
  throw "RECIPE_RELEASE=FAIL shard_record_sum=$shardRecords"
}

$imagesPath = Join-Path $workspace ([string]$release.image_manifest_path)
$images = Get-Content -Raw -LiteralPath $imagesPath | ConvertFrom-Json
$entries = @($images.entries)
$external = @($entries | Where-Object status -eq 'external_candidate')
$placeholders = @($entries | Where-Object status -eq 'placeholder')
$reviewedStatuses = @(
  'human-reviewed',
  'licensed-reviewed',
  'generated-visual-reviewed'
)
$reviewed = @(
  $entries | Where-Object { $reviewedStatuses -contains $_.review_status }
)
$duplicateIds = @($entries | Group-Object canonical_id | Where-Object Count -gt 1)
$duplicateHashes = @(
  $external |
    Where-Object { $_.sha256 } |
    Group-Object sha256 |
    Where-Object Count -gt 1
)

if ($entries.Count -ne [int]$release.record_count -or
    $external.Count + $placeholders.Count -ne $entries.Count -or
    $duplicateIds.Count -gt 0) {
  throw 'RECIPE_RELEASE=FAIL image manifest counts or IDs are inconsistent'
}

Write-Output 'RECIPE_RELEASE=PASS'
Write-Output "RECIPES_TOTAL=$($release.record_count)"
Write-Output "RELEASE_COMPONENTS_HASHED=$($components.Count)"
Write-Output "RELEASE_COMPONENT_HASH_FAILURES=$($failures.Count)"
Write-Output "RECIPE_IMAGE_ENTRIES=$($entries.Count)"
Write-Output "RECIPE_IMAGE_EXTERNAL_CANDIDATES=$($external.Count)"
Write-Output "RECIPE_IMAGE_PLACEHOLDERS=$($placeholders.Count)"
Write-Output "RECIPE_IMAGES_QA_PASS=$($reviewed.Count)"
Write-Output "SHA_DUPLICATE_GROUPS=$($duplicateHashes.Count)"
Write-Output 'PERCEPTUAL_DUPLICATES=UNVERIFIED_EXTERNAL_PIXELS'
Write-Output 'BROKEN_MEDIA_REFERENCES=UNVERIFIED_EXTERNAL_OBJECT_STORAGE'
