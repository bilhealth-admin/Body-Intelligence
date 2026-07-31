$ErrorActionPreference = "Stop"

Write-Host "BIL Epic 003 Final R1 preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
$head = (git rev-parse --short HEAD).Trim()

if ($branch -ne "phase-3-product-excellence") {
  throw "Expected branch phase-3-product-excellence, found $branch"
}

if ($head -ne "3ea0b64") {
  throw "Expected HEAD 3ea0b64, found $head"
}

if (-not (Test-Path "lib\features\settings\location_settings_page.dart")) {
  throw "The final Epic 003 UX package is not present."
}

if (-not (Test-Path "test\startup_state_test.dart")) {
  throw "startup_state_test.dart is missing."
}

Write-Host "Preflight passed." -ForegroundColor Green
