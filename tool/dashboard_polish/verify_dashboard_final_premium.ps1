param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$Required = @(
  'assets/images/dashboard/bil_health_hub_watch.webp',
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'test/dashboard_polish/dashboard_final_premium_contract_test.dart'
)

foreach ($File in $Required) {
  if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    throw "Missing: $File"
  }
}
Write-Output 'Required files PASSED'

& dart format --output=none --set-exit-if-changed `
  'lib/features/connected_health/widgets/connected_health_card.dart' `
  'lib/features/dashboard/widgets/dashboard_grid.dart' `
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart' `
  'test/dashboard_polish/dashboard_final_premium_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dart format gate failed.' }
Write-Output 'Dart format gate PASSED'

& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
Write-Output 'Flutter analyze PASSED'

& flutter test 'test/dashboard_polish/dashboard_final_premium_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'P8 contracts failed.' }
Write-Output 'Dashboard final premium contracts PASSED'

& flutter test 'test/dashboard_integrity_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dashboard regression contracts failed.' }
Write-Output 'Dashboard regression contracts PASSED'

Write-Output 'Algorithm boundary PASSED  Presentation and contract correction only'
