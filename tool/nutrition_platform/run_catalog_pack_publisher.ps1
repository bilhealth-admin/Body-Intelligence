param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Output = "dist/catalogs/manifest.json"
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$ConfigPath = (Resolve-Path -LiteralPath $Config).Path
$OutputPath = if ([System.IO.Path]::IsPathRooted($Output)) {
    $Output
} else {
    Join-Path $ProjectRoot $Output
}
$Python = Get-Command python -ErrorAction SilentlyContinue
$Prefix = @()
if (-not $Python) {
    $Python = Get-Command py -ErrorAction Stop
    $Prefix = @('-3')
}

& $Python.Source @Prefix (Join-Path $PSScriptRoot 'catalog_pack_publisher.py') `
    --config $ConfigPath `
    --output $OutputPath
if ($LASTEXITCODE -ne 0) {
    throw "Catalog pack publisher failed with exit code $LASTEXITCODE"
}

Write-Host "Verified manifest written to $OutputPath"
