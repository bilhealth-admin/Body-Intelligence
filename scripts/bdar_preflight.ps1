$ErrorActionPreference = "Stop"

$ExpectedBranch = "phase-3-product-excellence"
$RequiredFiles = @(
  "pubspec.yaml",
  "docs\PHASE_3_CONSTITUTION.md",
  "docs\governance\BIL_REPOSITORY_BASELINE_V1.md",
  "docs\governance\BIL_QUALITY_BOARD.md",
  "lib\features\dashboard\dashboard_page.dart",
  "lib\features\dashboard\widgets\dashboard_grid.dart"
)

Write-Host "BDAR preflight" -ForegroundColor Cyan

$branch = (git branch --show-current).Trim()
if ($branch -ne $ExpectedBranch) {
  throw "Expected branch '$ExpectedBranch' but found '$branch'."
}

foreach ($file in $RequiredFiles) {
  if (-not (Test-Path $file)) {
    throw "Required baseline file is missing: $file"
  }
}

$status = git status --short
if ($status) {
  Write-Host "Working tree is not clean. Existing work will not be deleted." -ForegroundColor Yellow
  Write-Host $status
} else {
  Write-Host "Working tree is clean." -ForegroundColor Green
}

Write-Host "Branch and baseline checks passed." -ForegroundColor Green
