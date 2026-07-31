param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$Files = @(
    "lib/features/dashboard/widgets/dashboard_grid.dart",
    "lib/features/dashboard/widgets/dashboard_shell.dart",
    "lib/features/dashboard/widgets/personal_health_ai_panel.dart",
    "lib/features/connected_health/widgets/connected_health_card.dart",
    "lib/features/analytics/analytics_page.dart",
    "test/dashboard_polish/dashboard_p9_r16_responsive_visual_contract_test.dart"
)

dart format --output=none --set-exit-if-changed $Files
flutter analyze $Files
flutter test test/dashboard_polish/dashboard_p9_r16_responsive_visual_contract_test.dart

Write-Host "BIL-DASHBOARD-POLISH-001-P9-R16 PACKAGE VERIFY: PASSED" -ForegroundColor Green
