param(
    [string]$Master = "C:\develop\bil_food_work\bil_food_master.sqlite",
    [string]$WorkDirectory = "C:\develop\bil_food_dist",
    [string]$Version = "2026.08",
    [ValidateSet('free','plus','pro','coach','clinic','enterprise')]
    [string]$Access = "plus",
    [Parameter(Mandatory=$true)][string]$BaseUrl,
    [double]$MinimumQuality = 75,
    [int]$MaxRows = 0
)

$ErrorActionPreference = 'Stop'
$MasterPath = (Resolve-Path -LiteralPath $Master).Path
$OutputDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$CatalogName = "usda-core-$Version.sqlite"
$CatalogPath = Join-Path $OutputDirectory $CatalogName
$ArchiveName = "$CatalogName.gz"
$ArchivePath = Join-Path $OutputDirectory $ArchiveName
$ManifestPath = Join-Path $OutputDirectory 'manifest.json'
$ConfigPath = Join-Path $OutputDirectory 'publish-config.json'

$builderArgs = @(
    (Join-Path $PSScriptRoot 'run_mobile_catalog_builder.py'),
    '--master', $MasterPath, '--output', $CatalogPath,
    '--profile-id', 'usda-core', '--language', 'en',
    '--minimum-quality', $MinimumQuality.ToString([Globalization.CultureInfo]::InvariantCulture)
)
if ($MaxRows -gt 0) { $builderArgs += @('--max-rows', $MaxRows) }
python @builderArgs
if ($LASTEXITCODE -ne 0) { throw "Mobile catalog build failed: $LASTEXITCODE" }
python (Join-Path $PSScriptRoot 'compress_catalog.py') --source $CatalogPath --output $ArchivePath
if ($LASTEXITCODE -ne 0) { throw "Catalog compression failed: $LASTEXITCODE" }

$config = [ordered]@{
    base_url = $BaseUrl.TrimEnd('/')
    packs = @([ordered]@{
        id = 'usda-core'; version = $Version; title = 'USDA Verified Core Foods'
        file = $ArchivePath; database_file = $CatalogPath
        remote_name = $ArchiveName; compression = 'gzip'; access = $Access
        locale_codes = @('en'); country_codes = @()
    })
}
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
python (Join-Path $PSScriptRoot 'catalog_pack_publisher.py') --config $ConfigPath --output $ManifestPath
if ($LASTEXITCODE -ne 0) { throw "Catalog publishing failed: $LASTEXITCODE" }

$catalog = Get-Item -LiteralPath $ArchivePath
Write-Host "Download pack ready: $ArchivePath"
Write-Host "Manifest ready: $ManifestPath"
Write-Host ("Pack size: {0:N2} MB" -f ($catalog.Length / 1MB))
Write-Host "Upload both files to the HTTPS BaseUrl, then set BIL_CATALOG_MANIFEST_URL=$BaseUrl/manifest.json"
