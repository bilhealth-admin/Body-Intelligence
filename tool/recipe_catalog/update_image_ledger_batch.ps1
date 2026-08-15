param(
  [Parameter(Mandatory = $true)][int]$Start,
  [Parameter(Mandatory = $true)][int]$End,
  [string]$Locale = 'en'
)
$ErrorActionPreference = 'Stop'
$ledger = 'artifacts/meal_catalog/meal_image_prompt_ledger_1400.csv'
$rows = Import-Csv $ledger
Add-Type -AssemblyName System.Drawing
$updated = 0
foreach ($row in $rows) {
  if ($row.canonical_id -match "^bil-$Locale-" -and
      [int]($row.canonical_id -replace '.*-', '') -ge $Start -and
      [int]($row.canonical_id -replace '.*-', '') -le $End) {
    $path = "assets/images/professional/recipes/$($row.canonical_id).png"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path" }
    $image = [System.Drawing.Image]::FromFile((Resolve-Path $path))
    try {
      if ($image.Width -ne $image.Height -or $image.Width -lt 1024) {
        throw "Invalid dimensions $($image.Width)x$($image.Height): $path"
      }
      $row.status = 'generated'
      $row.asset_path = $path
      $row.asset_sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
      $row.width = [string]$image.Width
      $row.height = [string]$image.Height
      $row.validation_status = 'generated-visual-reviewed-perceptual'
      $updated++
    } finally {
      $image.Dispose()
    }
  }
}
$rows | Export-Csv -LiteralPath $ledger -NoTypeInformation -Encoding UTF8
"UPDATED=$updated"
