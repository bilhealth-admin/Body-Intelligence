$ErrorActionPreference = "Stop"
Write-Host "BIL-STAB-001 preflight" -ForegroundColor Cyan
$branch = (git branch --show-current).Trim()
$head = (git rev-parse --short HEAD).Trim()
if ($branch -ne "phase-3-product-excellence") { throw "Unexpected branch: $branch" }
if ($head -ne "3ea0b64") { throw "Expected HEAD 3ea0b64, found $head" }
if (-not (Test-Path "lib\features\settings\location_settings_page.dart")) {
  throw "Epic 003 working-tree implementation is missing."
}
Write-Host "Preflight passed over Epic 003 working tree." -ForegroundColor Green
