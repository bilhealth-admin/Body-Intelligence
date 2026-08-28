[CmdletBinding()]
param(
    [string]$ManifestPath = 'assets/catalogs/recipes/v1/recipe-images.json',
    [string]$ShardDirectory = 'assets/catalogs/recipes/v1/shards',
    [string]$OutputPath = 'artifacts/release/recipe_duplicate_image_regeneration_brief.md'
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$records = @{}
Get-ChildItem -LiteralPath $ShardDirectory -Filter 'recipes-*.json' -File |
    ForEach-Object {
        $shard = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 |
            ConvertFrom-Json
        foreach ($record in @($shard.records)) {
            $records[[string]$record.canonicalId] = $record
        }
    }

$duplicateGroups = @($manifest.entries | Group-Object sha256 | Where-Object Count -gt 1)
$minimumRegenerations = @()
$allAffected = @()
foreach ($group in $duplicateGroups) {
    $members = @($group.Group | Sort-Object canonical_id)
    $allAffected += $members
    if ($members.Count -gt 1) {
        $minimumRegenerations += $members | Select-Object -Skip 1
    }
}

$lines = [Collections.Generic.List[string]]::new()
$lines.Add('# BIL duplicate recipe image regeneration brief')
$lines.Add('')
$lines.Add("Duplicate SHA groups: $($duplicateGroups.Count)")
$lines.Add("Recipes requiring visual review: $($allAffected.Count)")
$lines.Add("Minimum images to regenerate for unique bytes: $($minimumRegenerations.Count)")
$lines.Add('')
$lines.Add('Keep the canonical ID and exact output filename. Generate one square 1254×1254 premium photorealistic finished-dish image. Show the listed ingredients naturally in the plated meal, three-quarter overhead food photography, soft daylight, clean neutral table, realistic portions, no people, no hands, no packaging, no text, no letters, no logo, no watermark, and no collage.')
$lines.Add('')

$index = 0
foreach ($entry in $minimumRegenerations) {
    $index++
    $id = [string]$entry.canonical_id
    $record = $records[$id]
    $title = if ($null -ne $record) { [string]$record.localizations.en.title } else { $id }
    $ingredients = if ($null -ne $record) {
        @($record.ingredients | ForEach-Object { [string]$_.itemId }) -join ', '
    } else { '' }
    $recordAssetPath = if ($null -ne $record) {
        [string]$record.image.assetPath
    } else { '' }
    $candidatePath = if ([string]::IsNullOrWhiteSpace($recordAssetPath)) {
        [string]$entry.object_path
    } else { $recordAssetPath }
    $filename = [IO.Path]::GetFileName($candidatePath)
    $lines.Add("## $index. $id")
    $lines.Add('')
    $lines.Add('- Output filename: `' + $filename + '`')
    $lines.Add("- English recipe title: $title")
    $lines.Add("- Ingredients: $ingredients")
    $lines.Add("- Prompt: Premium photorealistic finished dish of **$title**, visibly using **$ingredients**. Square 1254×1254, three-quarter overhead food photography, soft daylight, clean neutral table, realistic portions, one plate only, no people, no hands, no packaging, no text, no letters, no logo, no watermark, no collage.")
    $lines.Add('')
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "RECIPE_DUPLICATE_BRIEF=PASS groups=$($duplicateGroups.Count) affected=$($allAffected.Count) regenerate=$($minimumRegenerations.Count) output=$OutputPath"
