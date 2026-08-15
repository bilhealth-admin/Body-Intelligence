$ErrorActionPreference = 'Stop'
$audit = Join-Path $PSScriptRoot 'audit_recipe_catalog.ps1'

$pass = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $audit 2>&1
if ($LASTEXITCODE -ne 0 -or (($pass -join "`n") -notmatch '(?m)^RECIPE_CATALOG_AUDIT=PASS$')) {
    throw "Expected truthful baseline to pass. Output: $($pass -join ' | ')"
}

$ErrorActionPreference = 'Continue'
$fail = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $audit -ClaimedRecipeCount 100 2>&1
if ($LASTEXITCODE -eq 0 -or (($fail -join ' ') -notmatch 'recipe_claim_exceeds_truth')) {
    throw "Expected unsupported 100-recipe claim to fail closed. Output: $($fail -join ' | ')"
}

$fail = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $audit -ClaimedImageCount 18 2>&1
if ($LASTEXITCODE -eq 0 -or (($fail -join ' ') -notmatch 'image_claim_exceeds_truth')) {
    throw "Expected unreviewed-image marketing claim to fail closed. Output: $($fail -join ' | ')"
}

$fail = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $audit -ClaimedNutritionVerifiedCount 1 2>&1
if ($LASTEXITCODE -eq 0 -or (($fail -join ' ') -notmatch 'nutrition_claim_exceeds_truth')) {
    throw "Expected unsupported nutrition claim to fail closed. Output: $($fail -join ' | ')"
}

$ErrorActionPreference = 'Stop'
Write-Output 'RECIPE_CATALOG_STATIC_TEST=PASS'
