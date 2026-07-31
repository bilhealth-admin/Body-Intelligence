param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$ReportDir = Join-Path $ProjectRoot 'artifacts\connected_health'
$Report = Join-Path $ReportDir 'BIL-CONNECTED-HEALTH-UX-001-report.txt'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
Remove-Item $Report -Force -ErrorAction SilentlyContinue
function Record([string]$Name, [string]$Status, [string]$Detail = '') {
  $line = "$Name`t$Status"
  if ($Detail) { $line += "`t$Detail" }
  Add-Content -LiteralPath $Report -Value $line
  Write-Host $line
}
function Run([string]$Name, [scriptblock]$Action) {
  & $Action
  if ($LASTEXITCODE -ne 0) { Record $Name 'FAILED' "exit=$LASTEXITCODE"; throw "$Name failed" }
  Record $Name 'PASSED'
}
$Required = @(
  'lib/features/connected_health/connected_health_model.dart',
  'lib/features/connected_health/providers/connected_health_provider.dart',
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/connected_health/connected_health_page.dart',
  'test/connected_health/connected_health_contract_test.dart',
  'test/dashboard_integrity_contract_test.dart',
  'test/dashboard_loading_skeleton_test.dart',
  'docs/connected_health/BIL_CONNECTED_HEALTH_UX_001.md'
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_)) })
if ($Missing.Count -gt 0) { Record 'Required files' 'FAILED' ($Missing -join ', '); throw 'Required files missing' }
Record 'Required files' 'PASSED' "$($Required.Count) files"
$FormatPaths = @(
  'lib/features/connected_health',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/app/router/app_router.dart',
  'test/connected_health/connected_health_contract_test.dart',
  'test/dashboard_integrity_contract_test.dart',
  'test/dashboard_loading_skeleton_test.dart'
)
Run 'Dart format gate' { dart format --output=none --set-exit-if-changed $FormatPaths }
Run 'Flutter analyze' { flutter analyze --no-pub }
Run 'Connected Health contracts' { flutter test --no-pub test/connected_health/connected_health_contract_test.dart }
Run 'Dashboard integrity contracts' { flutter test --no-pub test/dashboard_integrity_contract_test.dart test/dashboard_loading_skeleton_test.dart }
$Allowed = @(
  'lib/app/router/app_router.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/connected_health/connected_health_model.dart',
  'lib/features/connected_health/providers/connected_health_provider.dart',
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/connected_health/connected_health_page.dart',
  'test/connected_health/connected_health_contract_test.dart',
  'test/dashboard_integrity_contract_test.dart',
  'test/dashboard_loading_skeleton_test.dart',
  'tool/connected_health/verify_connected_health.ps1',
  'docs/connected_health/BIL_CONNECTED_HEALTH_UX_001.md'
)
$Changed = @(
  git diff --name-only
  git ls-files --others --exclude-standard
) | Where-Object { $_ -and -not $_.StartsWith('artifacts/') } | Sort-Object -Unique
$Unexpected = @($Changed | Where-Object { $_ -notin $Allowed })
if ($Unexpected.Count -gt 0) { Record 'Diff hygiene' 'FAILED' ($Unexpected -join ', '); throw 'Unexpected diff scope' }
Record 'Diff hygiene' 'PASSED'
Record 'BIL-CONNECTED-HEALTH-UX-001' 'PASSED' 'Independent dashboard card and management flow verified'
