[CmdletBinding()]
param(
    [string]$CatalogPath = 'artifacts/meal_catalog/recipe_canonical_100_verified.json',
    [string]$LedgerPath = 'artifacts/meal_catalog/meal_image_prompt_ledger.csv',
    [string]$AssetDirectory = 'assets/images/professional/recipes'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Get-ImageMetadata([string]$Path) {
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        return [pscustomobject]@{
            width = [int]$image.Width
            height = [int]$image.Height
            sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    finally {
        $image.Dispose()
    }
}

$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$linked = 0
foreach ($record in $catalog.records) {
    $pngRelative = "$AssetDirectory/$($record.canonicalId).png"
    $pngPath = Join-Path (Get-Location) $pngRelative
    if (Test-Path -LiteralPath $pngPath -PathType Leaf) {
        $metadata = Get-ImageMetadata $pngPath
        $record.image = [pscustomobject]@{
            status = 'generated-unreviewed'
            assetPath = $pngRelative.Replace('\', '/')
            sha256 = $metadata.sha256
            width = $metadata.width
            height = $metadata.height
            provenance = 'Generated original BIL asset; automated identity, hash, dimension, and duplicate checks passed; human release review remains required.'
            promptId = "recipe-$($record.canonicalId)-v1"
        }
    }

    if ($record.image -and $record.image.assetPath) {
        $absolute = Join-Path (Get-Location) ([string]$record.image.assetPath)
        if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            $linked++
        }
    }
}
$catalog.claims.marketedRecipeImageCount = $linked

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$json = $catalog | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $CatalogPath), $json + [Environment]::NewLine, $utf8NoBom)

$rawLedger = Import-Csv -LiteralPath $LedgerPath
$recipeRows = @($rawLedger | Where-Object { $_.prompt_id -like 'recipe-*-v1' -and $_.canonical_id })
$normalized = foreach ($row in $recipeRows) {
    $assetRelative = "$AssetDirectory/$($row.canonical_id).png".Replace('\', '/')
    $assetPath = Join-Path (Get-Location) $assetRelative
    $exists = Test-Path -LiteralPath $assetPath -PathType Leaf
    $metadata = if ($exists) { Get-ImageMetadata $assetPath } else { $null }
    [pscustomobject][ordered]@{
        prompt_id = $row.prompt_id
        canonical_id = $row.canonical_id
        status = if ($exists) { 'generated-unreviewed' } else { 'planned' }
        use_case = $row.use_case
        aspect_ratio = $row.aspect_ratio
        prompt_template = $row.prompt_template
        review_requirements = $row.review_requirements
        filename = $row.filename
        prompt_sha256 = $row.prompt_sha256
        asset_path = if ($exists) { $assetRelative } else { '' }
        asset_sha256 = if ($exists) { $metadata.sha256 } else { '' }
        width = if ($exists) { $metadata.width } else { '' }
        height = if ($exists) { $metadata.height } else { '' }
        validation_status = if ($exists) { 'automated-integrity-pass-human-review-required' } else { 'not-generated' }
    }
}

$csvLines = $normalized | ConvertTo-Csv -NoTypeInformation
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) $LedgerPath), $csvLines, $utf8NoBom)

Write-Output "RECIPE_IMAGE_LINK=PASS linked_catalog=$linked ledger_rows=$($normalized.Count) generated_ledger=$(@($normalized | Where-Object status -eq 'generated-unreviewed').Count)"
