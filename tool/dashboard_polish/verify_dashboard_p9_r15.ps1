param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ExpectedHead = 'ce42ca4a5a32e17dbb72033d5c475d5b641cb1e8'
$Head = (git rev-parse HEAD).Trim()
if ($Head -ne $ExpectedHead) { throw "Wrong HEAD. Expected $ExpectedHead, got $Head" }

$DartFiles = @(
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/analytics/analytics_page.dart',
  'lib/features/dashboard/widgets/dashboard_carousel.dart',
  'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
  'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'lib/features/dashboard/widgets/dashboard_header.dart',
  'lib/features/dashboard/widgets/dashboard_top_bar.dart',
  'test/dashboard_polish/dashboard_p9_r9_surface_contract_test.dart',
  'test/dashboard_polish/dashboard_runtime_layout_contract_test.dart',
  'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart',
  'test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart'
)

foreach ($File in $DartFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $File) -PathType Leaf)) {
    throw "Required verification file missing: $File"
  }
}

& dart format --output=none --set-exit-if-changed @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Dart format verification failed.' }

& flutter analyze @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }

$Tests = @(
  'test/dashboard_polish/dashboard_p9_r9_surface_contract_test.dart',
  'test/dashboard_polish/dashboard_runtime_layout_contract_test.dart',
  'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart',
  'test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart'
)

foreach ($Test in $Tests) {
  & flutter test $Test
  if ($LASTEXITCODE -ne 0) { throw "Dashboard contract failed: $Test" }
}

$ReportDir = Join-Path $ProjectRoot 'artifacts\dashboard_polish'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P9-R15-report.txt'
@(
  'BIL-DASHBOARD-POLISH-001-P9-R15 PACKAGE VERIFY: PASSED',
  "HEAD: $Head",
  'Correction: final visual contract now matches the approved blue/silver Today Signal implementation.',
  'Scope: verification artifacts only; runtime UI implementation remains unchanged.',
  'Logic/data/providers/storage/calculations: unchanged.'
) | Set-Content -LiteralPath $Report -Encoding utf8
Write-Host 'BIL-DASHBOARD-POLISH-001-P9-R15 PACKAGE VERIFY: PASSED' -ForegroundColor Green
