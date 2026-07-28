param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$Required = @(
  'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/dashboard/widgets/daily_return_card.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'test/dashboard_polish/dashboard_typography_contract_test.dart',
  'tool/dashboard_polish/verify_dashboard_typography.ps1',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P4.md'
)
foreach ($File in $Required) { if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Missing required file: $File" } }
$ReportDir = Join-Path $ProjectRoot 'artifacts/dashboard_polish'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P4-report.txt'
@('Required files PASSED  7 files') | Set-Content -LiteralPath $Report -Encoding UTF8
