$ErrorActionPreference = "Stop"

Write-Host "BIL Epic 003 final preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
$head = (git rev-parse --short HEAD).Trim()

if ($branch -ne "phase-3-product-excellence") {
  throw "Expected branch phase-3-product-excellence, found $branch"
}

if ($head -ne "3ea0b64") {
  throw "Expected HEAD 3ea0b64, found $head"
}

$required = @(
  "lib\features\settings\location_settings_page.dart",
  "lib\features\startup\startup_page.dart",
  "test\startup_state_test.dart"
)

foreach ($file in $required) {
  if (-not (Test-Path $file)) {
    throw "Required current working-tree file is missing: $file"
  }
}

Write-Host "Preflight passed over the verified Epic 003 working tree." -ForegroundColor Green
