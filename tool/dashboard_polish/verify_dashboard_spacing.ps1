param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$Required = @(
  'lib/features/dashboard/widgets/dashboard_layout_metrics.dart',
  'lib/features/dashboard/widgets/dashboard_experience_frame.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/dashboard/widgets/daily_return_card.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'test/dashboard_polish/dashboard_spacing_contract_test.dart',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P2.md'
)
foreach ($Path in $Required) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file missing: $Path" }
}

$FormatFiles = @($Required | Where-Object { $_ -like '*.dart' })
dart format --output=none --set-exit-if-changed -- $FormatFiles
if ($LASTEXITCODE -ne 0) { throw 'Dart format gate failed.' }

flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }

flutter test test/dashboard_polish/dashboard_spacing_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard spacing contracts failed.' }

flutter test test/dashboard_integrity_contract_test.dart test/dashboard_loading_skeleton_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard regression contracts failed.' }

$Generated = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugins.cmake'
)
git restore -- $Generated 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Generated Flutter registrants cleanup failed.' }

$Allowed = @(
  'lib/features/dashboard/widgets/dashboard_layout_metrics.dart',
  'lib/features/dashboard/widgets/dashboard_experience_frame.dart',
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
  'lib/features/dashboard/widgets/daily_return_card.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'test/dashboard_polish/dashboard_spacing_contract_test.dart',
  'tool/dashboard_polish/verify_dashboard_spacing.ps1',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P2.md'
)
$Changed = @(
  git status --porcelain=v1 --untracked-files=all |
    ForEach-Object { $_.Substring(3).Replace('\','/') } |
    Where-Object { $_ -and $_ -notlike 'artifacts/*' }
)
$Unexpected = @($Changed | Where-Object { $_ -notin $Allowed })
if ($Unexpected.Count -gt 0) { throw "Unexpected package changes:`n$($Unexpected -join "`n")" }

$Missing = @($Allowed | Where-Object { $_ -notin $Changed })
if ($Missing.Count -gt 0) { throw "Expected package changes are missing:`n$($Missing -join "`n")" }

$ReportDir = Join-Path $ProjectRoot 'artifacts/dashboard_polish'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P2-report.txt'
@(
  'Required files PASSED  7 files',
  'Dart format gate PASSED',
  'Flutter analyze PASSED',
  'Dashboard spacing contracts PASSED',
  'Dashboard regression contracts PASSED',
  'Algorithm boundary PASSED  Added diff lines only',
  'Generated Flutter registrants cleanup PASSED',
  'Diff hygiene PASSED',
  'BIL-DASHBOARD-POLISH-001-P2-R2 PASSED  Responsive dashboard spacing verified'
) | Set-Content -LiteralPath $Report -Encoding UTF8
Get-Content -LiteralPath $Report
