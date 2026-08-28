param(
    [int]$BatchSize = 25,
    [int]$DeliveryLimit = 0,
    [string]$OutputDirectory = 'artifacts/recipe_image_handoff_2026-08-20'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$output = Join-Path $root $OutputDirectory
$catalogRoot = Join-Path $root 'assets\catalogs\recipes\v1'
$imageManifestPath = Join-Path $catalogRoot 'recipe-images.json'

if ($BatchSize -lt 1) {
    throw 'BatchSize must be positive.'
}
if ($DeliveryLimit -lt 0) {
    throw 'DeliveryLimit cannot be negative.'
}

$recordsById = @{}
Get-ChildItem (Join-Path $catalogRoot 'shards') -Filter 'recipes-*.json' |
    Sort-Object Name |
    ForEach-Object {
        $shard = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($record in $shard.records) {
            $recordsById[$record.canonicalId] = $record
        }
    }

$imageManifest = Get-Content -LiteralPath $imageManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$missingIds = @(
    $imageManifest.entries |
        Where-Object status -eq 'placeholder' |
        ForEach-Object canonical_id
)

$expectedMissing = [int]$imageManifest.placeholder_count
if ($imageManifest.record_count -ne 1500 -or $expectedMissing -lt 0) {
    throw 'Recipe image manifest counts are invalid.'
}
if ($missingIds.Count -ne $expectedMissing) {
    throw "Image manifest mismatch: expected $expectedMissing placeholders, found $($missingIds.Count)."
}

$rows = foreach ($canonicalId in $missingIds) {
    $record = $recordsById[$canonicalId]
    if ($null -eq $record) {
        throw "Missing catalog record for $canonicalId."
    }
    $locale = [string]$record.primaryLocale
    $localizedProperty = $record.localizations.PSObject.Properties[$locale]
    if ($null -eq $localizedProperty) {
        throw "Missing $locale localization for $canonicalId."
    }
    $localized = $localizedProperty.Value
    $ingredients = @(
        $record.ingredients | ForEach-Object {
            $amount = if ($null -ne $_.grams) { "$($_.grams) g" } else { "$($_.quantity) $($_.unit)" }
            "$amount $($_.itemId)"
        }
    ) -join ', '
    $method = @($localized.steps) -join ' '
    $servings = [double]$record.serving.count
    $title = [string]$localized.title
    $region = [string]$record.region
    $filename = "$canonicalId.png"
    $prompt = @(
        "Create one square premium editorial food photograph for the recipe titled `"$title`" ($locale locale), from the $region region."
        "The full recipe serves $servings and uses exactly these catalog ingredients: $ingredients."
        "Depict one plausible plated serving; preserve the relative ingredient identity and do not add visible ingredients that are not listed."
        "Preparation context: $method"
        'Use authentic regionally appropriate tableware and restrained cultural styling, appetizing natural texture, soft directional daylight, true-to-life color, and a refined contemporary composition.'
        'No text, letters, numbers, labels, logos, trademarks, watermarks, packaging, people, hands, faces, duplicated food, impossible garnish, or unrelated ingredients.'
        "Output a single 1:1 PNG at the highest available quality, at least 1024x1024, with the exact filename $filename."
    ) -join ' '
    $bytes = [Text.Encoding]::UTF8.GetBytes($prompt)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $promptHash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }

    [pscustomobject]@{
        canonical_id = $canonicalId
        filename = $filename
        display_name = $title
        locale = $locale
        region = $region
        servings = $servings
        ingredients_exact = $ingredients
        preparation_context = $method
        aspect_ratio = '1:1'
        minimum_dimensions = '1024x1024'
        format = 'PNG'
        prompt = $prompt
        prompt_sha256 = $promptHash
    }
}

$rows = @($rows | Sort-Object locale, region, canonical_id)
New-Item -ItemType Directory -Path $output -Force | Out-Null

$numberedRows = for ($index = 0; $index -lt $rows.Count; $index++) {
    $batch = [int]([math]::Floor($index / $BatchSize) + 1)
    $row = $rows[$index]
    [pscustomobject]@{
        sequence = $index + 1
        batch = ('{0:D2}' -f $batch)
        canonical_id = $row.canonical_id
        filename = $row.filename
        display_name = $row.display_name
        locale = $row.locale
        region = $row.region
        servings = $row.servings
        ingredients_exact = $row.ingredients_exact
        preparation_context = $row.preparation_context
        aspect_ratio = $row.aspect_ratio
        minimum_dimensions = $row.minimum_dimensions
        format = $row.format
        prompt = $row.prompt
        prompt_sha256 = $row.prompt_sha256
    }
}
$totalMissing = $numberedRows.Count
if ($DeliveryLimit -gt 0) {
    $numberedRows = @($numberedRows | Select-Object -First $DeliveryLimit)
}
$remainingAfterDelivery = $totalMissing - $numberedRows.Count

$masterCsv = Join-Path $output 'missing_recipe_images_master.csv'
$numberedRows | Export-Csv -LiteralPath $masterCsv -NoTypeInformation -Encoding UTF8

$jsonLines = foreach ($row in $numberedRows) {
    $row | ConvertTo-Json -Compress -Depth 6
}
Set-Content -LiteralPath (Join-Path $output 'missing_recipe_images_master.jsonl') -Value $jsonLines -Encoding UTF8

$batchCount = [math]::Ceiling($numberedRows.Count / $BatchSize)
$availableCount = [int]$imageManifest.record_count - $totalMissing
for ($batch = 1; $batch -le $batchCount; $batch++) {
    $batchRows = @($numberedRows | Where-Object batch -eq ('{0:D2}' -f $batch))
    $batchPath = Join-Path $output ('batch_{0:D2}_{1:D4}_to_{2:D4}.csv' -f $batch, $batchRows[0].sequence, $batchRows[-1].sequence)
    $batchRows | Export-Csv -LiteralPath $batchPath -NoTypeInformation -Encoding UTF8
}

$localeSummary = $numberedRows | Group-Object locale | Sort-Object Name | ForEach-Object { "- $($_.Name): $($_.Count) images" }
$readme = @"
# Missing recipe image handoff

Authoritative inventory: **$totalMissing genuinely missing images** out of 1,500 recipes. The **$availableCount** images already matched to the corrected catalog are excluded and must not be regenerated.

This delivery contains **$($numberedRows.Count)** prompts. After importing it, **$remainingAfterDelivery** missing images remain for the next delivery.

Upload one batch CSV at a time. Ask the external image generator to execute every row's prompt literally, return one square PNG per row using the exact filename, and package only the completed images in a flat ZIP with no internal folders.

Delivery contract:

- PNG, 1:1, highest available quality, at least 1024x1024.
- Preserve every filename exactly; it is the app's installation key.
- Generate a distinct image for each recipe; never duplicate one image under multiple names.
- No text, logos, watermarks, people, hands, packaging, or unlisted visible ingredients.
- Keep the CSV unchanged; prompt_sha256 identifies the exact request.

Locale distribution:

$($localeSummary -join "`n")

Batches: **$batchCount**, at most **$BatchSize** images per batch.
"@
Set-Content -LiteralPath (Join-Path $output 'README.md') -Value $readme -Encoding UTF8

Write-Output "PASS delivery=$($numberedRows.Count) total_missing=$totalMissing remaining=$remainingAfterDelivery batches=$batchCount output=$output"
