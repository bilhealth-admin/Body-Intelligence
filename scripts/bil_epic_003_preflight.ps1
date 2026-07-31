$ErrorActionPreference = "Stop"

$ExpectedBranch = "phase-3-product-excellence"
$ExpectedHead = "3ea0b64"

Write-Host "BIL Epic 003 completion preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) {
  throw "Expected branch '$ExpectedBranch' but found '$branch'."
}

$head = (git rev-parse --short HEAD).Trim()
if ($head -ne $ExpectedHead) {
  throw "Expected baseline '$ExpectedHead' but found '$head'."
}

$required = @(
  "lib\features\dashboard\widgets\dashboard_layout_metrics.dart",
  "lib\features\dashboard\widgets\dashboard_composition.dart",
  "lib\features\dashboard\widgets\dashboard_shell.dart",
  "lib\features\profile\profile_settings_page.dart",
  "lib\features\settings\settings_page.dart"
)

foreach ($file in $required) {
  if (-not (Test-Path $file)) {
    throw "Required baseline file is missing: $file"
  }
}

Write-Host "Preflight passed at $ExpectedHead." -ForegroundColor Green
