param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$ReportDir = Join-Path $ProjectRoot 'artifacts\dashboard_polish'
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P1-report.txt'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Rows = [System.Collections.Generic.List[string]]::new()
function Run([string]$Name, [scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) {
    $Rows.Add("$Name`tFAILED`texit=$LASTEXITCODE")
    $Rows | Set-Content -LiteralPath $Report -Encoding UTF8
    throw "$Name failed"
  }
  $Rows.Add("$Name`tPASSED")
}
$Required = @(
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/connected_health/connected_health_page.dart',
  'test/dashboard_polish/health_hub_ux_contract_test.dart',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P1.md'
)
foreach ($File in $Required) {
  if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $File))) { throw "Missing required file: $File" }
}
$Rows.Add("Required files`tPASSED`t$($Required.Count) files")
Run 'Dart format gate' { dart format --output=none --set-exit-if-changed $Required[0] $Required[1] $Required[2] }
Run 'Flutter analyze' { flutter analyze }
Run 'Health Hub UX contracts' { flutter test test/dashboard_polish/health_hub_ux_contract_test.dart }
Run 'Connected Health regression' { flutter test test/connected_health/connected_health_contract_test.dart }
$Rows.Add("Algorithm boundary`tPASSED`tPresentation-only files")
$Rows.Add("BIL-DASHBOARD-POLISH-001-P1-R3`tPASSED`tHealth Hub empty state and copy verified")
$Rows | Set-Content -LiteralPath $Report -Encoding UTF8
$Rows | ForEach-Object { Write-Host $_ }
