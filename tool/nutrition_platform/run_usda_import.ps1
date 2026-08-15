param(
    [Parameter(Mandatory=$true)][string]$ProjectPath,
    [string]$SourcesPath = "C:\develop\bil_food_sources",
    [string]$WorkPath = "C:\develop\bil_food_work",
    [int]$BatchSize = 2000,
    [switch]$InspectOnly
)
$ErrorActionPreference = 'Stop'
$ManifestPath = Join-Path $SourcesPath 'usda_source_manifest.json'
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Missing verified source manifest: $ManifestPath. Run download_usda_sources.ps1 first."
}
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$Resolved = @{}
foreach ($Source in $Manifest.sources) {
    $ZipPath = Join-Path $SourcesPath $Source.file
    if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Missing source ZIP: $ZipPath" }
    $Hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Hash -ne $Source.sha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for $($Source.dataset): $ZipPath"
    }
    $Resolved[$Source.dataset] = $ZipPath
}
foreach ($Dataset in @('foundation','legacy')) {
    if (-not $Resolved.ContainsKey($Dataset)) { throw "Missing $Dataset source in $ManifestPath" }
}
New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null
$Python = Get-Command python -ErrorAction SilentlyContinue
$Prefix = @()
if (-not $Python) { $Python = Get-Command py -ErrorAction Stop; $Prefix = @('-3') }
$Importer = Join-Path $ProjectPath 'tool/nutrition_platform/usda_importer.py'
$Archives = @($Resolved.foundation,$Resolved.legacy)
if ($Resolved.ContainsKey('branded')) { $Archives += $Resolved.branded }
if ($InspectOnly) {
    & $Python.Source @Prefix $Importer inspect @Archives --report (Join-Path $WorkPath 'source_inspection.json')
} else {
    & $Python.Source @Prefix $Importer import @Archives --database (Join-Path $WorkPath 'bil_food_raw.sqlite') --report (Join-Path $WorkPath 'import_report.json') --batch-size $BatchSize
}
if ($LASTEXITCODE -ne 0) { throw "USDA importer failed with exit code $LASTEXITCODE" }
