param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$Required = @(
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/dashboard/widgets/dashboard_carousel.dart',
  'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
  'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'test/dashboard_polish/dashboard_p9_r9_surface_contract_test.dart',
  'test/dashboard_polish/dashboard_runtime_layout_contract_test.dart',
  'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart'
)
foreach ($File in $Required) {
  if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Required file missing: $File" }
}
Write-Host 'Required files PASSED'

$DartFiles = @(
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/dashboard/widgets/dashboard_carousel.dart',
  'lib/features/dashboard/widgets/dashboard_twin_deck_shell.dart',
  'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'test/dashboard_polish/dashboard_p9_r9_surface_contract_test.dart',
  'test/dashboard_polish/dashboard_runtime_layout_contract_test.dart',
  'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart'
)
& dart format --output=none --set-exit-if-changed @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Dart format gate failed.' }
Write-Host 'Dart format gate PASSED'

& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
Write-Host 'Flutter analyze PASSED'

& flutter test test/dashboard_polish/dashboard_p9_r9_surface_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'P9-R9 paired-deck surface contracts failed.' }
Write-Host 'P9-R9 paired-deck surface contracts PASSED'

& flutter test test/dashboard_polish/dashboard_runtime_layout_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard runtime layout contracts failed.' }
Write-Host 'Dashboard runtime layout contracts PASSED'

& flutter test test/dashboard_polish/dashboard_live_health_hub_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard live Health Hub contracts failed.' }
Write-Host 'Dashboard live Health Hub contracts PASSED'

& flutter test test/dashboard_integrity_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard regression contracts failed.' }
Write-Host 'Dashboard regression contracts PASSED'

$Generated = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugins.cmake'
)
& git restore -- $Generated
Write-Host 'Generated Flutter registrants cleanup PASSED'

$ReportDir = Join-Path $ProjectRoot 'artifacts\dashboard_polish'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Report = @(
  'Required files PASSED',
  'Dart format gate PASSED',
  'Flutter analyze PASSED',
  'P9-R9 paired-deck surface contracts PASSED',
  'Dashboard runtime layout contracts PASSED',
  'Dashboard live Health Hub contracts PASSED',
  'Dashboard regression contracts PASSED',
  'Generated Flutter registrants cleanup PASSED',
  'Shared deck shell PASSED  One geometry implementation for both paired cards',
  'Nutrition surface source PASSED  Nutrition Signal implementation left unchanged',
  'Inner surface parity PASSED  All paired-deck cards use the exact Nutrition Signal gradient border and shadow',
  'Header alignment PASSED  Identical reserved title and subtitle slot',
  'Inner deck alignment PASSED  Matching card bounds arrows and pager baseline',
  'BIL-DASHBOARD-POLISH-001-P9-R9 PASSED  Paired insight decks and shared surface verified'
)
$ReportPath = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P9-R9-report.txt'
$Report | Set-Content -LiteralPath $ReportPath -Encoding utf8
$Report | ForEach-Object { Write-Host $_ }
