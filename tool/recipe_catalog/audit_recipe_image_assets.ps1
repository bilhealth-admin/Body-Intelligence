[CmdletBinding()]
param(
    [string]$CatalogPath = 'artifacts/meal_catalog/recipe_canonical_100_verified.json',
    [string]$LedgerPath = 'artifacts/meal_catalog/meal_image_prompt_ledger.csv',
    [string]$AssetDirectory = 'assets/images/professional/recipes'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$ledger = @(Import-Csv -LiteralPath $LedgerPath)
$errors = New-Object System.Collections.Generic.List[string]
$hashOwners = @{}
$linked = 0

foreach ($record in $catalog.records) {
    if (-not $record.image -or -not $record.image.assetPath) { continue }
    $path = Join-Path (Get-Location) ([string]$record.image.assetPath)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("missing catalog asset: $($record.canonicalId) -> $($record.image.assetPath)")
        continue
    }
    $image = [System.Drawing.Image]::FromFile($path)
    try { $width = $image.Width; $height = $image.Height } finally { $image.Dispose() }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne [string]$record.image.sha256) { $errors.Add("catalog hash mismatch: $($record.canonicalId)") }
    if ($width -ne [int]$record.image.width -or $height -ne [int]$record.image.height) { $errors.Add("catalog dimensions mismatch: $($record.canonicalId)") }
    if ($hashOwners.ContainsKey($hash)) { $errors.Add("duplicate bytes: $($record.canonicalId) and $($hashOwners[$hash])") } else { $hashOwners[$hash] = $record.canonicalId }
    $linked++
}

if ([int]$catalog.claims.marketedRecipeImageCount -ne $linked) { $errors.Add("marketedRecipeImageCount mismatch: claim=$($catalog.claims.marketedRecipeImageCount) actual=$linked") }
foreach ($row in $ledger) {
    if ($row.status -eq 'generated-unreviewed') {
        if (-not $row.asset_path -or -not (Test-Path -LiteralPath (Join-Path (Get-Location) $row.asset_path) -PathType Leaf)) { $errors.Add("generated ledger asset missing: $($row.canonical_id)"); continue }
        $hash = (Get-FileHash -LiteralPath (Join-Path (Get-Location) $row.asset_path) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $row.asset_sha256) { $errors.Add("ledger hash mismatch: $($row.canonical_id)") }
    }
    elseif ($row.asset_path -or $row.asset_sha256) { $errors.Add("non-generated ledger row carries asset data: $($row.canonical_id)") }
}

$canonicalIds = @($catalog.records.canonicalId)
foreach ($file in Get-ChildItem -LiteralPath $AssetDirectory -Filter '*.png' -File) {
    if ($canonicalIds -contains $file.BaseName) {
        $record = $catalog.records | Where-Object canonicalId -eq $file.BaseName | Select-Object -First 1
        if (-not $record.image -or -not $record.image.assetPath) { $errors.Add("orphan canonical PNG: $($file.Name)") }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "RECIPE_IMAGE_AUDIT=FAIL errors=$($errors.Count)"
}
Write-Output "RECIPE_IMAGE_AUDIT=PASS catalog_linked=$linked ledger_rows=$($ledger.Count) generated_ledger=$(@($ledger | Where-Object status -eq 'generated-unreviewed').Count) unique_hashes=$($hashOwners.Count)"
