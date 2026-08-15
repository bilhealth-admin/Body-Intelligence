param(
    [string]$Catalog = "C:\develop\bil_food_dist\bil-arabic-seed-2026.08.sqlite",
    [string]$WorkDirectory = "C:\develop\bil_food_dist",
    [string]$Version = "2026.08",
    [ValidateSet('free','plus','pro','coach','clinic','enterprise')]
    [string]$Access = "free",
    [Parameter(Mandatory=$true)][string]$BaseUrl
)

$ErrorActionPreference = 'Stop'
$CatalogPath = (Resolve-Path -LiteralPath $Catalog).Path
$OutputDirectory = [System.IO.Path]::GetFullPath($WorkDirectory)
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$ArchiveName = "bil-arabic-seed-$Version.sqlite.gz"
$ArchivePath = Join-Path $OutputDirectory $ArchiveName
$ConfigPath = Join-Path $OutputDirectory 'publish-config.json'
$ManifestPath = Join-Path $OutputDirectory 'manifest.json'

python (Join-Path $PSScriptRoot 'compress_catalog.py') `
    --source $CatalogPath `
    --output $ArchivePath
if ($LASTEXITCODE -ne 0) { throw "Arabic catalog compression failed: $LASTEXITCODE" }

$config = if (Test-Path -LiteralPath $ConfigPath) {
    Get-Content -LiteralPath $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
} else {
    [pscustomobject]@{ base_url = $BaseUrl.TrimEnd('/'); packs = @() }
}
$config.base_url = $BaseUrl.TrimEnd('/')
$existing = @($config.packs | Where-Object { $_.id -ne 'bil-arabic-seed' })
$arabicPack = [pscustomobject]@{
    id = 'bil-arabic-seed'
    version = $Version
    title = 'BIL Arabic Verified Seed Foods'
    file = $ArchivePath
    database_file = $CatalogPath
    remote_name = $ArchiveName
    compression = 'gzip'
    access = $Access
    locale_codes = @('ar')
    country_codes = @('EG','JO','SA','AE','KW','QA','BH','OM','IQ','LB')
}
$config.packs = @($existing) + @($arabicPack)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    $ConfigPath,
    ($config | ConvertTo-Json -Depth 8),
    $utf8NoBom
)

python (Join-Path $PSScriptRoot 'catalog_pack_publisher.py') `
    --config $ConfigPath `
    --output $ManifestPath
if ($LASTEXITCODE -ne 0) { throw "Catalog manifest publishing failed: $LASTEXITCODE" }

$archive = Get-Item -LiteralPath $ArchivePath
Write-Host "Arabic pack ready: $ArchivePath"
Write-Host "Combined manifest ready: $ManifestPath"
Write-Host ("Compressed size: {0:N2} KB" -f ($archive.Length / 1KB))
Write-Host "Upload the Arabic archive and the updated manifest.json to the catalogs bucket."
