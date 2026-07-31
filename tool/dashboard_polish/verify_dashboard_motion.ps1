param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
$ReportDir = Join-Path $ProjectRoot 'artifacts\dashboard_polish'
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P7-report.txt'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Lines = [System.Collections.Generic.List[string]]::new()
function Pass([string]$Text) { $Lines.Add($Text); Write-Host $Text }
$Required = @(
  'lib/app/theme/premium_motion_tokens.dart',
  'lib/features/dashboard/widgets/dashboard_motion_reveal.dart',
  'lib/features/dashboard/widgets/dashboard_grid.dart',
  'test/dashboard_polish/dashboard_motion_contract_test.dart',
  'tool/dashboard_polish/verify_dashboard_motion.ps1',
  'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P7.md'
)
foreach ($Path in $Required) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required file missing: $Path"
  }
}
Pass "Required files PASSED  $($Required.Count) files"
& dart format --output=none --set-exit-if-changed -- `
  'lib/app/theme/premium_motion_tokens.dart' `
  'lib/features/dashboard/widgets/dashboard_motion_reveal.dart' `
  'lib/features/dashboard/widgets/dashboard_grid.dart' `
  'test/dashboard_polish/dashboard_motion_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dart format gate failed.' }
Pass 'Dart format gate PASSED'
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
Pass 'Flutter analyze PASSED'
& flutter test 'test/dashboard_polish/dashboard_motion_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dashboard motion contracts failed.' }
Pass 'Dashboard motion contracts PASSED'
& flutter test 'test/dashboard_integrity_contract_test.dart'
if ($LASTEXITCODE -ne 0) { throw 'Dashboard regression contracts failed.' }
Pass 'Dashboard regression contracts PASSED'
$Generated = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugins.cmake'
)
& git restore -- $Generated
if ($LASTEXITCODE -ne 0) { throw 'Generated Flutter registrants cleanup failed.' }
Pass 'Generated Flutter registrants cleanup PASSED'
$Allowed = @($Required)
$Changed = @(
  & git status --porcelain=v1 |
    ForEach-Object { $_.Substring(3).Replace('\','/') } |
    Where-Object { $_ -and $_ -notlike 'artifacts/*' }
)
$Unexpected = @($Changed | Where-Object { $_ -notin $Allowed })
if ($Unexpected.Count -gt 0) {
  throw "Unexpected changed files:`n$($Unexpected -join "`n")"
}
Pass 'Diff hygiene PASSED'
Pass 'Algorithm boundary PASSED  Presentation-only motion files'
Pass 'BIL-DASHBOARD-POLISH-001-P7 PASSED  Motion and reduced-motion behavior verified'
$Lines | Set-Content -LiteralPath $Report -Encoding UTF8
