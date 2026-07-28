param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
flutter test test/dashboard_polish/dashboard_responsive_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard responsive contracts failed.' }
Write-Host 'Dashboard responsive contracts PASSED' -ForegroundColor Green
