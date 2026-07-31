$ErrorActionPreference = "Stop"

$ExpectedBranch = "phase-3-product-excellence"
$RequiredFiles = @(
  "pubspec.yaml",
  "lib\features\dashboard\widgets\dashboard_grid.dart",
  "test\mojibake_regression_test.dart",
  "test\dashboard_insights_surface_test.dart",
  "test\dashboard_integrity_contract_test.dart",
  "test\daily_return_card_visual_integrity_test.dart"
)

Write-Host "BDAR-002R4 preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) {
  throw "Expected branch '$ExpectedBranch' but found '$branch'."
}

foreach ($file in $RequiredFiles) {
  if (-not (Test-Path $file)) {
    throw "Required file is missing: $file"
  }
}

if (Test-Path "lib\features\dashboard\widgets\dashboard_shell.dart") {
  throw "BDAR-003A appears to be extracted already. Do not mix it with BDAR-002R4."
}

Write-Host "Preflight passed. BDAR-003A has not been extracted." -ForegroundColor Green
