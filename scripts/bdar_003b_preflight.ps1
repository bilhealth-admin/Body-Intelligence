$ErrorActionPreference = "Stop"

$ExpectedBranch = "phase-3-product-excellence"
$ExpectedHead = "cf4aa3e"
$RequiredFiles = @(
  "pubspec.yaml",
  "lib\features\dashboard\widgets\dashboard_composition.dart",
  "lib\features\dashboard\widgets\dashboard_shell.dart",
  "lib\features\dashboard\widgets\dashboard_top_bar.dart",
  "lib\features\dashboard\widgets\first_value_handoff_card.dart",
  "test\dashboard_composition_test.dart",
  "test\dashboard_composition_contract_test.dart"
)

Write-Host "BDAR-003B preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) {
  throw "Expected branch '$ExpectedBranch' but found '$branch'."
}

$head = (git rev-parse --short HEAD).Trim()
if ($head -ne $ExpectedHead) {
  throw "Expected BDAR-003A baseline '$ExpectedHead' but found '$head'."
}

foreach ($file in $RequiredFiles) {
  if (-not (Test-Path $file)) {
    throw "Required baseline file is missing: $file"
  }
}

Write-Host "Preflight passed at baseline $ExpectedHead." -ForegroundColor Green
