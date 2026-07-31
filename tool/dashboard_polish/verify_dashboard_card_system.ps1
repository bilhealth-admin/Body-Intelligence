param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$Required = @(
  'lib/app/theme/premium_design_tokens.dart',
  'lib/shared/widgets/premium_surface.dart',
  'test/dashboard_polish/dashboard_card_system_contract_test.dart',
  'tool/dashboard_polish/verify_dashboard_card_system.ps1',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P5.md'
)
foreach ($File in $Required) {
  if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $File) -PathType Leaf)) {
    throw "Required file missing: $File"
  }
}

flutter test test/dashboard_polish/dashboard_card_system_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard card-system contracts failed.' }

Write-Host "Required files PASSED  $($Required.Count) files"
Write-Host 'Dashboard card-system contracts PASSED'
