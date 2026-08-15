[CmdletBinding()]
param(
    [string]$RepositoryRoot = '',
    [string]$CatalogPath = '',
    [int]$ClaimedRecipeCount = -1,
    [int]$ClaimedImageCount = -1,
    [int]$ClaimedNutritionVerifiedCount = -1
)

$ErrorActionPreference = 'Stop'
if (!$RepositoryRoot) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Stop-Audit([string]$Message) {
    Write-Error "RECIPE_CATALOG_AUDIT=FAIL $Message"
    exit 1
}

$sourcePath = Join-Path $RepositoryRoot 'lib\features\wellness\presentation\recipe_library_page.dart'
$targetPath = Join-Path $RepositoryRoot 'artifacts\meal_catalog\recipe_catalog_target_manifest.json'
$imageRoot = Join-Path $RepositoryRoot 'assets\images\professional\recipes'

if (!(Test-Path -LiteralPath $sourcePath)) { Stop-Audit "missing_source=$sourcePath" }
if (!(Test-Path -LiteralPath $targetPath)) { Stop-Audit "missing_target_manifest=$targetPath" }

$source = Get-Content -Raw -LiteralPath $sourcePath
$ids = [regex]::Matches($source, "(?m)^\s*id:\s*'([^']+)'\s*,") | ForEach-Object { $_.Groups[1].Value }
$imageRefs = [regex]::Matches($source, "assets/images/professional/recipes/[^']+") | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($ids.Count -ne 18) { Stop-Audit "legacy_source_recipe_count expected=18 actual=$($ids.Count)" }
if (($ids | Sort-Object -Unique).Count -ne $ids.Count) { Stop-Audit 'duplicate_legacy_recipe_ids' }
if ($imageRefs.Count -ne 18) { Stop-Audit "legacy_source_image_ref_count expected=18 actual=$($imageRefs.Count)" }

$missing = @($imageRefs | Where-Object { !(Test-Path -LiteralPath (Join-Path $RepositoryRoot $_)) })
if ($missing.Count -gt 0) { Stop-Audit "missing_legacy_images=$($missing -join ',')" }
$physicalImages = @(Get-ChildItem -LiteralPath $imageRoot -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' })
if ($physicalImages.Count -lt 18) { Stop-Audit "physical_image_count expected_at_least=18 actual=$($physicalImages.Count)" }

$target = Get-Content -Raw -LiteralPath $targetPath | ConvertFrom-Json
$localeTotal = 0
foreach ($property in $target.bilReleaseTarget.primaryLocaleAllocation.PSObject.Properties) {
    if ([int]$property.Value -ne 300) { Stop-Audit "locale_target locale=$($property.Name) expected=300 actual=$($property.Value)" }
    $localeTotal += [int]$property.Value
}
if ($localeTotal -ne 1500) { Stop-Audit "locale_target_total expected=1500 actual=$localeTotal" }
foreach ($locale in @('ar', 'en', 'fr', 'es', 'tr')) {
    $regionalTotal = 0
    foreach ($region in $target.bilReleaseTarget.regionalTargetAllocation.$locale.PSObject.Properties) {
        if ([int]$region.Value -le 0) { Stop-Audit "invalid_region_target locale=$locale region=$($region.Name)" }
        $regionalTotal += [int]$region.Value
    }
    if ($regionalTotal -ne 300) { Stop-Audit "regional_target_total locale=$locale expected=300 actual=$regionalTotal" }
}
if ([int]$target.currentTruth.canonicalRecords -ne $ids.Count) { Stop-Audit 'current_truth_recipe_count_drift' }
if ($physicalImages.Count -lt [int]$target.currentTruth.existingImageFiles) { Stop-Audit 'current_truth_image_count_regressed' }

$actualRecipes = $ids.Count
$actualExistingImages = $physicalImages.Count
$actualImages = 0
$actualNutritionVerified = 0

if ($CatalogPath) {
    $resolvedCatalog = if ([System.IO.Path]::IsPathRooted($CatalogPath)) { $CatalogPath } else { Join-Path $RepositoryRoot $CatalogPath }
    if (!(Test-Path -LiteralPath $resolvedCatalog)) { Stop-Audit "missing_catalog=$resolvedCatalog" }
    $catalog = Get-Content -Raw -LiteralPath $resolvedCatalog | ConvertFrom-Json
    $records = @($catalog.records)
    $requiredRecordFields = @('canonicalId', 'contentFingerprint', 'origin', 'primaryLocale', 'region', 'countryTags', 'mealTypes', 'allergens', 'dietTags', 'budgetTier', 'serving', 'timing', 'ingredients', 'method', 'localizations', 'nutrition', 'image')
    foreach ($record in $records) {
        foreach ($field in $requiredRecordFields) {
            if ($null -eq $record.$field) { Stop-Audit "incomplete_record id=$($record.canonicalId) missing=$field" }
        }
        if (@($record.countryTags).Count -eq 0) { Stop-Audit "incomplete_record id=$($record.canonicalId) missing=countryTags" }
        if (@($record.mealTypes).Count -eq 0) { Stop-Audit "incomplete_record id=$($record.canonicalId) missing=mealTypes" }
        if (@($record.dietTags).Count -eq 0) { Stop-Audit "incomplete_record id=$($record.canonicalId) missing=dietTags" }
        if (@($record.ingredients).Count -eq 0) { Stop-Audit "incomplete_record id=$($record.canonicalId) missing=ingredients" }
        foreach ($ingredient in @($record.ingredients)) {
            $pending = [string]$record.nutrition.status -eq 'pending'
            if (!$ingredient.itemId -or (!$pending -and ($null -eq $ingredient.quantity -or [double]$ingredient.quantity -le 0 -or !$ingredient.unit))) {
                Stop-Audit "incomplete_ingredient id=$($record.canonicalId)"
            }
        }
        if (@($record.method).Count -eq 0) { Stop-Audit "incomplete_record id=$($record.canonicalId) missing=method" }
        $expectedStep = 1
        foreach ($step in @($record.method | Sort-Object { [int]$_.order })) {
            if ([int]$step.order -ne $expectedStep -or !$step.instructionKey) { Stop-Audit "invalid_method_order id=$($record.canonicalId)" }
            $expectedStep++
        }
        if (!$pending -and ([double]$record.serving.count -le 0 -or [double]$record.serving.size -le 0 -or !$record.serving.unit)) { Stop-Audit "invalid_serving id=$($record.canonicalId)" }
        if ([int]$record.timing.totalMinutes -le 0) { Stop-Audit "invalid_timing id=$($record.canonicalId)" }
        if (!$pending -and ([int]$record.timing.prepMinutes -lt 0 -or [int]$record.timing.cookMinutes -lt 0 -or [int]$record.timing.totalMinutes -ne ([int]$record.timing.prepMinutes + [int]$record.timing.cookMinutes))) { Stop-Audit "invalid_timing id=$($record.canonicalId)" }
        if (!$pending -and (!$record.image.promptId -or ([string]$record.image.promptId -notmatch [regex]::Escape([string]$record.canonicalId)))) { Stop-Audit "image_not_linked_by_recipe_id id=$($record.canonicalId)" }
        if ([string]$record.contentFingerprint -notmatch '^[a-f0-9]{64}$') { Stop-Audit "invalid_content_fingerprint id=$($record.canonicalId)" }
        if ($pending -and (@($record.nutrition.sourceRefs).Count -ne 0 -or $null -ne $record.nutrition.reviewedAt)) { Stop-Audit "pending_nutrition_has_false_evidence id=$($record.canonicalId)" }
        if ($record.image.assetPath) {
            $asset = Join-Path $RepositoryRoot ([string]$record.image.assetPath)
            if (!(Test-Path -LiteralPath $asset)) { Stop-Audit "missing_image id=$($record.canonicalId)" }
            $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $asset).Hash.ToLowerInvariant()
            if ($actualHash -ne [string]$record.image.sha256) { Stop-Audit "image_sha_mismatch id=$($record.canonicalId)" }
        }
    }
    $canonicalIds = @($records | ForEach-Object { [string]$_.canonicalId })
    if (($canonicalIds | Sort-Object -Unique).Count -ne $canonicalIds.Count) { Stop-Audit 'duplicate_canonical_ids' }
    $contentFingerprints = @($records | ForEach-Object { [string]$_.contentFingerprint })
    if (($contentFingerprints | Sort-Object -Unique).Count -ne $contentFingerprints.Count) { Stop-Audit 'duplicate_recipe_content_fingerprints' }
    $allImageHashes = @($records | Where-Object { $_.image.sha256 } | ForEach-Object { [string]$_.image.sha256 })
    if (($allImageHashes | Sort-Object -Unique).Count -ne $allImageHashes.Count) { Stop-Audit 'duplicate_recipe_image_hashes' }
    $actualRecipes = $records.Count
    $reviewedImages = @($records | Where-Object { $_.image.status -in @('human-reviewed', 'licensed-reviewed', 'generated-visual-reviewed') })
    $imageHashes = @($reviewedImages | ForEach-Object { [string]$_.image.sha256 })
    if ($imageHashes -contains '') { Stop-Audit 'reviewed_image_missing_sha256' }
    if (($imageHashes | Sort-Object -Unique).Count -ne $imageHashes.Count) { Stop-Audit 'duplicate_reviewed_image_hashes' }
    foreach ($record in $reviewedImages) {
        if (!$record.image.assetPath) { Stop-Audit "reviewed_image_missing_path id=$($record.canonicalId)" }
        $asset = Join-Path $RepositoryRoot ([string]$record.image.assetPath)
        if (!(Test-Path -LiteralPath $asset)) { Stop-Audit "reviewed_image_file_missing id=$($record.canonicalId)" }
        $hash = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne ([string]$record.image.sha256).ToLowerInvariant()) { Stop-Audit "reviewed_image_hash_mismatch id=$($record.canonicalId)" }
    }
    $actualImages = $reviewedImages.Count
    $verifiedStatuses = @('calculated', 'dietitian-reviewed', 'laboratory-verified')
    $actualNutritionVerified = @($records | Where-Object {
        $_.nutrition.status -in $verifiedStatuses -and
        @($_.nutrition.sourceRefs).Count -gt 0 -and
        $_.nutrition.reviewedAt -and
        $null -ne $_.nutrition.perServing.kcal -and
        $null -ne $_.nutrition.perServing.proteinG -and
        $null -ne $_.nutrition.perServing.carbohydrateG -and
        $null -ne $_.nutrition.perServing.fatG -and
        $null -ne $_.nutrition.perServing.fiberG -and
        $null -ne $_.nutrition.perServing.sugarG -and
        $null -ne $_.nutrition.perServing.sodiumMg -and
        $null -ne $_.nutrition.perServing.potassiumMg
    }).Count
    if ($ClaimedRecipeCount -lt 0) { $ClaimedRecipeCount = [int]$catalog.claims.marketedRecipeCount }
    if ($ClaimedImageCount -lt 0) { $ClaimedImageCount = [int]$catalog.claims.marketedRecipeImageCount }
    if ($ClaimedNutritionVerifiedCount -lt 0) { $ClaimedNutritionVerifiedCount = [int]$catalog.claims.marketedNutritionVerifiedCount }
}

if ($ClaimedRecipeCount -lt 0) { $ClaimedRecipeCount = $actualRecipes }
if ($ClaimedImageCount -lt 0) { $ClaimedImageCount = 0 }
if ($ClaimedNutritionVerifiedCount -lt 0) { $ClaimedNutritionVerifiedCount = 0 }
if ($ClaimedRecipeCount -gt $actualRecipes) { Stop-Audit "recipe_claim_exceeds_truth claim=$ClaimedRecipeCount actual=$actualRecipes" }
if ($ClaimedImageCount -gt $actualImages) { Stop-Audit "image_claim_exceeds_truth claim=$ClaimedImageCount actual=$actualImages" }
if ($ClaimedNutritionVerifiedCount -gt $actualNutritionVerified) { Stop-Audit "nutrition_claim_exceeds_truth claim=$ClaimedNutritionVerifiedCount actual=$actualNutritionVerified" }

Write-Output "RECIPE_CATALOG_AUDIT=PASS"
Write-Output "ACTUAL_CANONICAL_RECIPES=$actualRecipes"
Write-Output "ACTUAL_EXISTING_IMAGE_FILES=$actualExistingImages"
Write-Output "ACTUAL_REVIEWED_IMAGES=$actualImages"
Write-Output "ACTUAL_NUTRITION_VERIFIED=$actualNutritionVerified"
Write-Output "TARGET_CANONICAL_RECIPES=1500"
Write-Output "TARGET_PRIMARY_LOCALE_SPLIT=ar:300,en:300,fr:300,es:300,tr:300"
