param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$ExpectedHead = 'de831336c244f573c40c02f1edeed511cae603f5'
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
  'test/dashboard_polish/dashboard_p9_r13_final_visual_contract_test.dart'
)

& dart format --output=none --set-exit-if-changed @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Dart format verification failed.' }

& flutter analyze @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }

& flutter test test/dashboard_polish/dashboard_p9_r9_surface_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'P9-R9 surface contracts failed.' }
& flutter test test/dashboard_polish/dashboard_runtime_layout_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Runtime layout contracts failed.' }
& flutter test test/dashboard_polish/dashboard_live_health_hub_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Live health hub contracts failed.' }
& flutter test test/dashboard_polish/dashboard_p9_r13_final_visual_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'P9-R13 final visual contracts failed.' }

$ReportDir = Join-Path $ProjectRoot 'artifacts\dashboard_polish'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P9-R13-report.txt'
@(
  'BIL-DASHBOARD-POLISH-001-P9-R13 VERIFY: PASSED',
  "HEAD: $Head",
  'Scope: consolidated approved Dashboard UI, localization, alignment, watch geometry, signal palette, and chart markers.',
  'Logic/data/providers/storage/calculations: unchanged.'
) | Set-Content -LiteralPath $Report -Encoding utf8
Write-Host 'BIL-DASHBOARD-POLISH-001-P9-R13 VERIFY: PASSED' -ForegroundColor Green
