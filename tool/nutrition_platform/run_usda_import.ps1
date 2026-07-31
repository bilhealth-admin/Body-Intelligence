param(
    [Parameter(Mandatory=$true)][string]$ProjectPath,
    [string]$SourcesPath = "$env:USERPROFILE\Downloads",
    [string]$WorkPath = "C:\develop\bil_food_work",
    [int]$BatchSize = 2000,
    [switch]$InspectOnly
)
$ErrorActionPreference = 'Stop'
$Expected = @{
    foundation='d6d4f41dcd19a46abcdd67775379cb6f0292ff08daa7e0680fdd0982830bf57b';
    legacy='b80817294b8850530aaedf2e515c02593b1824f763a0ff356e5c2081643e6fd0';
    branded='26050a5d03197469813754743a21ee0fad4ccf22b6aac2a995846a987719fc49'
}
$Resolved = @{}
foreach ($Zip in Get-ChildItem -LiteralPath $SourcesPath -Filter '*.zip' -File) {
    $Hash = (Get-FileHash -LiteralPath $Zip.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach ($Dataset in $Expected.Keys) {
        if ($Hash -eq $Expected[$Dataset]) { $Resolved[$Dataset] = $Zip.FullName }
    }
}
foreach ($Dataset in $Expected.Keys) {
    if (-not $Resolved.ContainsKey($Dataset)) { throw "Missing $Dataset source ZIP by SHA-256 in $SourcesPath" }
}
New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null
$Python = Get-Command python -ErrorAction SilentlyContinue
$Prefix = @()
if (-not $Python) { $Python = Get-Command py -ErrorAction Stop; $Prefix = @('-3') }
$Importer = Join-Path $ProjectPath 'tool/nutrition_platform/usda_importer.py'
$Archives = @($Resolved.foundation,$Resolved.legacy,$Resolved.branded)
if ($InspectOnly) {
    & $Python.Source @Prefix $Importer inspect @Archives --report (Join-Path $WorkPath 'source_inspection.json')
} else {
    & $Python.Source @Prefix $Importer import @Archives --database (Join-Path $WorkPath 'bil_food_raw.sqlite') --report (Join-Path $WorkPath 'import_report.json') --batch-size $BatchSize
}
if ($LASTEXITCODE -ne 0) { throw "USDA importer failed with exit code $LASTEXITCODE" }
