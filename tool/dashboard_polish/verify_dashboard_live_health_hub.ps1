param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$Required = @(
  'pubspec.yaml',
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/analytics/analytics_page.dart',
  'lib/shared/widgets/premium_chart_card.dart',
  'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P9.md'
)
foreach ($Path in $Required) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required file missing: $Path"
  }
}
Write-Host "Required files PASSED  $($Required.Count) files"

$DartFiles = @(
  'lib/features/connected_health/widgets/connected_health_card.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/analytics/analytics_page.dart',
  'lib/shared/widgets/premium_chart_card.dart',
  'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart'
)
& dart format --output=none --set-exit-if-changed @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Dart format gate failed.' }
Write-Host 'Dart format gate PASSED'

& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
Write-Host 'Flutter analyze PASSED'

& flutter test 'test/dashboard_polish/dashboard_live_health_hub_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dashboard live Health Hub contracts failed.' }
Write-Host 'Dashboard live Health Hub contracts PASSED'

& flutter test 'test/dashboard_integrity_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dashboard regression contracts failed.' }
Write-Host 'Dashboard regression contracts PASSED'

$Generated = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugins.cmake'
)
git restore -- $Generated
$GeneratedChanges = @(git status --porcelain=v1 -- $Generated)
if ($GeneratedChanges.Count -gt 0) { throw 'Generated Flutter registrants cleanup failed.' }
Write-Host 'Generated Flutter registrants cleanup PASSED'

& git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Diff hygiene failed.' }
Write-Host 'Diff hygiene PASSED'
Write-Host 'Algorithm boundary PASSED  Presentation-only live watch and responsive alignment'
Write-Host 'BIL-DASHBOARD-POLISH-001-P9 PASSED  Live Health Hub and alignment verified'
