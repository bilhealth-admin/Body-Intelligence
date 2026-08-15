param(
    [string]$Destination = "C:\develop\bil_food_sources",
    [switch]$IncludeBranded
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sources = @(
    [ordered]@{
        dataset = 'foundation'
        release = '2026-04-30'
        file = 'FoodData_Central_foundation_food_csv_2026-04-30.zip'
        url = 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_csv_2026-04-30.zip'
    },
    [ordered]@{
        dataset = 'legacy'
        release = '2018-04'
        file = 'FoodData_Central_sr_legacy_food_csv_2018-04.zip'
        url = 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip'
    }
)

if ($IncludeBranded) {
    $sources += [ordered]@{
        dataset = 'branded'
        release = '2026-04-30'
        file = 'FoodData_Central_branded_food_csv_2026-04-30.zip'
        url = 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_branded_food_csv_2026-04-30.zip'
    }
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$records = @()

foreach ($source in $sources) {
    $target = Join-Path $Destination $source.file
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Host "Downloading $($source.dataset): $($source.url)"
        & curl.exe --fail --location --retry 5 --retry-delay 3 --continue-at - --output $target $source.url
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed for $($source.dataset) with exit code $LASTEXITCODE"
        }
    } else {
        Write-Host "Using existing file: $target"
    }

    $item = Get-Item -LiteralPath $target
    if ($item.Length -le 0) { throw "Downloaded file is empty: $target" }
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $records += [pscustomobject][ordered]@{
        dataset = $source.dataset
        release = $source.release
        file = $source.file
        url = $source.url
        sha256 = $hash
        size_bytes = $item.Length
        downloaded_at_utc = [DateTime]::UtcNow.ToString('o')
    }
}

$manifest = [ordered]@{
    schema_version = 1
    authority = 'USDA FoodData Central'
    authority_url = 'https://fdc.nal.usda.gov/download-datasets/'
    sources = $records
}
$manifestPath = Join-Path $Destination 'usda_source_manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Verified source manifest: $manifestPath"
$records | Format-Table dataset, release, file, size_bytes, sha256 -AutoSize
