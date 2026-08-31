$ErrorActionPreference = 'Stop'

$metadata = Get-Content 'G:\BIL_Secrets\Apple\BIL_Store_Manager.metadata.json' -Raw | ConvertFrom-Json
$env:ASC_KEY_ID = $metadata.keyId
$env:ASC_ISSUER_ID = $metadata.issuerId
$env:ASC_PRIVATE_KEY_PATH = $metadata.privateKeyPath

$outputDirectory = 'G:\BIL_Project\body_intelligence_log\artifacts\release\apple\2026-08-30-final-audit'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$errorPath = "$outputDirectory\error.txt"
Remove-Item -LiteralPath $errorPath -Force -ErrorAction SilentlyContinue

function Invoke-NodeAudit {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [Parameter(Mandatory = $true)]
    [string]$StdoutPath,
    [Parameter(Mandatory = $true)]
    [string]$StderrPath,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  # Windows PowerShell promotes any native stderr output to NativeCommandError
  # when ErrorActionPreference is Stop, even when the process exits 0. Keep the
  # streams separate and decide success solely from the native exit code.
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & node @Arguments 1> $StdoutPath 2> $StderrPath
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($exitCode -ne 0) {
    throw "$Label failed with exit code $exitCode. See $StderrPath"
  }
}

function Assert-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  try {
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
  } catch {
    throw "$Label did not produce valid JSON at $Path"
  }
}

try {
  Invoke-NodeAudit `
    -Arguments @('tool/apple_store_connect/asc_full_catalog_audit.mjs', '--output', "$outputDirectory\catalog.json") `
    -StdoutPath "$outputDirectory\catalog.log" `
    -StderrPath "$outputDirectory\catalog.stderr.log" `
    -Label 'catalog audit'
  Assert-JsonFile -Path "$outputDirectory\catalog.json" -Label 'catalog audit'

  Invoke-NodeAudit `
    -Arguments @('tool/apple_store_connect/asc_review_assets_inspect.mjs') `
    -StdoutPath "$outputDirectory\review.json" `
    -StderrPath "$outputDirectory\review.stderr.log" `
    -Label 'review audit'
  Assert-JsonFile -Path "$outputDirectory\review.json" -Label 'review audit'

  Invoke-NodeAudit `
    -Arguments @('tool/apple_store_connect/asc_selected_prices_inspect.mjs', "$outputDirectory\catalog.json") `
    -StdoutPath "$outputDirectory\selected-prices.json" `
    -StderrPath "$outputDirectory\selected-prices.stderr.log" `
    -Label 'selected-prices audit'
  Assert-JsonFile -Path "$outputDirectory\selected-prices.json" -Label 'selected-prices audit'

  Set-Content -Encoding utf8 "$outputDirectory\complete.txt" ((Get-Date).ToUniversalTime().ToString('o'))
} catch {
  Set-Content -Encoding utf8 $errorPath ($_ | Out-String)
  exit 1
}
