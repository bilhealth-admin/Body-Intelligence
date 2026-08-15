$ErrorActionPreference = 'Stop'
$ledger = 'artifacts/meal_catalog/meal_image_prompt_ledger_1400.csv'
$rows = Import-Csv $ledger
Add-Type -AssemblyName System.Drawing
$updated = 0
foreach ($row in $rows) {
  if ($row.canonical_id -match '^bil-en-' -and
      [int]($row.canonical_id -replace '.*-', '') -ge 171 -and
      [int]($row.canonical_id -replace '.*-', '') -le 175) {
    $path = "assets/images/professional/recipes/$($row.canonical_id).png"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path" }
    $image = [System.Drawing.Image]::FromFile((Resolve-Path $path))
    $row.status = 'generated'
    $row.asset_path = $path
    $row.asset_sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $row.width = [string]$image.Width
    $row.height = [string]$image.Height
    $row.validation_status = if ($row.canonical_id -match '-172$') { 'generated-visual-reviewed-perceptual-identity-watch' } else { 'generated-visual-reviewed-perceptual' }
    $image.Dispose()
    $updated++
  }
}
$rows | Export-Csv -LiteralPath $ledger -NoTypeInformation -Encoding UTF8
"UPDATED=$updated"
