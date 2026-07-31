param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot

$Generated = @(
    'linux/flutter/generated_plugin_registrant.cc',
    'linux/flutter/generated_plugins.cmake',
    'macos/Flutter/GeneratedPluginRegistrant.swift',
    'windows/flutter/generated_plugin_registrant.cc',
    'windows/flutter/generated_plugins.cmake'
)

$ReportDir = Join-Path $ProjectRoot 'artifacts\dashboard_polish'
$Report = Join-Path $ReportDir 'BIL-DASHBOARD-POLISH-001-P3-report.txt'
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$Rows = New-Object System.Collections.Generic.List[string]

$Required = @(
    'lib/features/dashboard/widgets/daily_return_card.dart',
    'lib/features/dashboard/widgets/dashboard_grid.dart',
    'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    'test/dashboard_polish/dashboard_copy_contract_test.dart',
    'test/dashboard_integrity_contract_test.dart',
    'tool/dashboard_polish/verify_dashboard_copy.ps1',
    'docs/dashboard_polish/BIL_DASHBOARD_POLISH_001_P3.md'
)
foreach ($File in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $File) -PathType Leaf)) {
        throw "Required file missing: $File"
    }
}
$Rows.Add('Required files PASSED  8 files')

$DartFiles = @(
    'lib/features/dashboard/widgets/daily_return_card.dart',
    'lib/features/dashboard/widgets/dashboard_grid.dart',
    'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    'test/dashboard_polish/dashboard_copy_contract_test.dart',
    'test/dashboard_integrity_contract_test.dart'
)
dart format --output=none --set-exit-if-changed @DartFiles
if ($LASTEXITCODE -ne 0) { throw 'Dart format gate failed.' }
$Rows.Add('Dart format gate PASSED')

flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
$Rows.Add('Flutter analyze PASSED')

flutter test test/dashboard_polish/dashboard_copy_contract_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard copy contracts failed.' }
$Rows.Add('Dashboard copy contracts PASSED')

flutter test test/dashboard_integrity_contract_test.dart test/dashboard_loading_skeleton_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Dashboard regression contracts failed.' }
$Rows.Add('Dashboard regression contracts PASSED')

$ProductionFiles = @(
    'lib/features/dashboard/widgets/daily_return_card.dart',
    'lib/features/dashboard/widgets/dashboard_grid.dart',
    'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart'
)
$Added = @(git diff --unified=0 -- $ProductionFiles | Where-Object { $_ -match '^\+(?!\+\+\+)' }) -join "`n"
if ($Added -match '(Repository|Provider|Controller|Notifier|calculate|algorithm|database|supabase)') {
    throw 'Algorithm boundary failed: prohibited production logic appeared in added diff lines.'
}
$Rows.Add('Algorithm boundary PASSED  Added diff lines only')

git restore -- $Generated
if ($LASTEXITCODE -ne 0) { throw 'Generated registrant cleanup failed.' }
$Rows.Add('Generated Flutter registrants cleanup PASSED')

$AllowedTracked = @(
    'lib/features/dashboard/widgets/daily_return_card.dart',
    'lib/features/dashboard/widgets/dashboard_grid.dart',
    'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
    'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    'test/dashboard_integrity_contract_test.dart'
)
$Tracked = @(git status --porcelain=v1 --untracked-files=no | ForEach-Object { $_.Substring(3).Replace('\','/') })
$UnexpectedTracked = @($Tracked | Where-Object { $_ -notin $AllowedTracked })
if ($UnexpectedTracked.Count -gt 0) {
    throw "Unexpected tracked changes after verification:`n$($UnexpectedTracked -join "`n")"
}

git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Diff hygiene failed.' }
$Rows.Add('Diff hygiene PASSED')
$Rows.Add('BIL-DASHBOARD-POLISH-001-P3-R2 PASSED  Dashboard copy and updated label regression contract verified')
$Rows | Set-Content -LiteralPath $Report -Encoding UTF8
$Rows | ForEach-Object { Write-Host $_ }
Write-Host 'BIL-DASHBOARD-POLISH-001-P3-R2 VERIFY: PASSED' -ForegroundColor Green
