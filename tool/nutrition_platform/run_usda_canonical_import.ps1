param(
    [string]$SourcesPath = "C:\develop\bil_food_sources",
    [string]$Database = "C:\develop\bil_food_work\bil_food_master.sqlite",
    [int]$BatchSize = 5000,
    [ValidateSet('foundation','legacy','branded')]
    [string[]]$Datasets = @('foundation','legacy','branded')
)
$ErrorActionPreference = 'Stop'
$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Manifest = Join-Path $SourcesPath 'usda_source_manifest.json'
if (-not (Test-Path -LiteralPath $Manifest)) { throw "Missing source manifest: $Manifest" }
New-Item -ItemType Directory -Path (Split-Path -Parent $Database) -Force | Out-Null
Push-Location $ProjectPath
try {
    $DatasetList = $Datasets -join ','
    python -m tool.nutrition_platform.usda_canonical_importer --manifest $Manifest --database $Database --batch-size $BatchSize --datasets $DatasetList
    if ($LASTEXITCODE -ne 0) { throw "Canonical import failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
