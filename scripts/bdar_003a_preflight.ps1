$ErrorActionPreference = "Stop"

$ExpectedBranch = "phase-3-product-excellence"
$RequiredFiles = @(
  "pubspec.yaml",
  "docs\governance\BDAR_PROGRAM_CONSTITUTION.md",
  "lib\features\dashboard\dashboard_page.dart",
  "lib\features\dashboard\widgets\dashboard_grid.dart",
  "lib\features\dashboard\widgets\dashboard_insights_surface.dart"
)

Write-Host "BDAR-003A preflight" -ForegroundColor Cyan
$branch = (git branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) {
  throw "Expected branch '$ExpectedBranch' but found '$branch'."
}
foreach ($file in $RequiredFiles) {
  if (-not (Test-Path $file)) { throw "Required file is missing: $file" }
}
Write-Host "Preflight passed. Existing unrelated work will not be deleted." -ForegroundColor Green
