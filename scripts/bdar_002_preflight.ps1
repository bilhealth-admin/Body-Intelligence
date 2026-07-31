$ErrorActionPreference = "Stop"

$ExpectedBranch = "phase-3-product-excellence"
$RequiredFiles = @(
  "pubspec.yaml",
  "docs\PHASE_3_CONSTITUTION.md",
  "docs\governance\BDAR_PROGRAM_CONSTITUTION.md",
  "lib\features\dashboard\widgets\dashboard_grid.dart",
  "lib\shared\widgets\premium_surface.dart"
)

Write-Host "BDAR-002 preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) {
  throw "Expected branch '$ExpectedBranch' but found '$branch'."
}

foreach ($file in $RequiredFiles) {
  if (-not (Test-Path $file)) {
    throw "Required file is missing: $file"
  }
}

$staged = git diff --cached --name-only
if ($staged) {
  Write-Host "Review files already staged before applying BDAR-002:" -ForegroundColor Yellow
  Write-Host $staged
}

Write-Host "Preflight passed. Existing unstaged work will not be deleted." -ForegroundColor Green
