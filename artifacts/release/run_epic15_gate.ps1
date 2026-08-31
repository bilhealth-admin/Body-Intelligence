$ErrorActionPreference = 'Stop'
throw 'EPIC15_GATE=HISTORICAL_NON_AUTHORITATIVE. This legacy local gate cannot mutate store assets or certify a release candidate. Use the reviewed store-media workflow and .github/workflows/bil_android_release_candidate.yml. No asset or artifact was produced.'

$ErrorActionPreference = 'Continue'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$summaryPath = Join-Path $PSScriptRoot 'epic15_summary.txt'
$prepareLog = Join-Path $PSScriptRoot 'epic15_prepare.log'
$formatLog = Join-Path $PSScriptRoot 'epic15_format.log'
$goldenUpdateLog = Join-Path $PSScriptRoot 'epic15_golden_update.log'
$packageLog = Join-Path $PSScriptRoot 'epic15_package.log'
$auditLog = Join-Path $PSScriptRoot 'epic15_asset_audit.log'
$goldenVerifyLog = Join-Path $PSScriptRoot 'epic15_golden_verify.log'
$targetedLog = Join-Path $PSScriptRoot 'epic15_targeted_tests.log'
$analyzeLog = Join-Path $PSScriptRoot 'epic15_analyze.log'
$buildLog = Join-Path $PSScriptRoot 'epic15_android_build.log'
$summaryJsonPath = Join-Path $PSScriptRoot 'epic15_summary.json'
Set-Location -LiteralPath $project

function Invoke-Logged {
  param([scriptblock]$Action, [string]$Log)
  $stage = [IO.Path]::GetFileNameWithoutExtension($Log).ToUpperInvariant()
  Write-Host ""
  Write-Host "=== START $stage ===" -ForegroundColor Cyan
  Write-Host "Started: $([DateTimeOffset]::Now.ToString('HH:mm:ss'))"
  $global:LASTEXITCODE = 0
  & $Action 2>&1 | Tee-Object -FilePath $Log |
    ForEach-Object { Write-Host (($_ | Out-String).TrimEnd()) }
  $actionSucceeded = $?
  $script:LastLoggedExitCode = if ($actionSucceeded) { $LASTEXITCODE } else { 1 }
  Write-Host "Finished: $([DateTimeOffset]::Now.ToString('HH:mm:ss'))"
  Write-Host "=== END $stage (EXIT=$script:LastLoggedExitCode) ===" -ForegroundColor $(if ($script:LastLoggedExitCode -eq 0) { 'Green' } else { 'Red' })
}

Invoke-Logged { & '.\artifacts\release\prepare_epic15_store_assets.ps1' } $prepareLog
$prepareExit = $script:LastLoggedExitCode

$formatTargets = @(
  'lib/app/localization/runtime_copy_secondary.dart',
  'lib/features/nutrition/presentation/food_catalog_tile.dart',
  'lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart',
  'test/epic15_store_screenshot_golden_test.dart',
  'test/visual_closure/visual_evidence_font.dart',
  'test/launch_readiness/epic15_store_materials_contract_test.dart',
  'tool/epic15_store_asset_audit.dart'
)
Invoke-Logged { & dart format @formatTargets } $formatLog
$formatExit = $script:LastLoggedExitCode

Invoke-Logged {
  & flutter test test/epic15_store_screenshot_golden_test.dart --update-goldens --timeout 60s
} $goldenUpdateLog
$goldenUpdateExit = $script:LastLoggedExitCode

Invoke-Logged { & '.\artifacts\release\prepare_epic15_store_assets.ps1' -PackageScreenshots } $packageLog
$packageExit = $script:LastLoggedExitCode

Invoke-Logged { & dart run tool/epic15_store_asset_audit.dart } $auditLog
$auditExit = $script:LastLoggedExitCode

Invoke-Logged {
  & flutter test test/epic15_store_screenshot_golden_test.dart --timeout 60s
} $goldenVerifyLog
$goldenVerifyExit = $script:LastLoggedExitCode

$targetedTests = @(
  'test/launch_readiness/epic15_store_materials_contract_test.dart',
  'test/launch_readiness/epic14_release_execution_test.dart',
  'test/launch_readiness/store_privacy_evidence_contract_test.dart',
  'test/google_play_preparation/google_play_preparation_contract_test.dart',
  'test/epic11_localization_accessibility_test.dart',
  'test/epic12_security_privacy_contract_test.dart',
  'test/features/commerce/epic13_store_entitlement_truth_test.dart'
)
Invoke-Logged { & flutter test @targetedTests --timeout 30s } $targetedLog
$targetedExit = $script:LastLoggedExitCode

Invoke-Logged {
  & flutter analyze `
    lib/app/localization/runtime_copy_secondary.dart `
    lib/features/nutrition/food_page.dart `
    lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart `
    test/epic15_store_screenshot_golden_test.dart `
    test/visual_closure/visual_evidence_font.dart `
    test/launch_readiness/epic15_store_materials_contract_test.dart `
    tool/epic15_store_asset_audit.dart
} $analyzeLog
$analyzeExit = $script:LastLoggedExitCode
Invoke-Logged {
  & flutter build appbundle --release --no-pub --target-platform android-arm64,android-x64
} $buildLog
$buildExit = $script:LastLoggedExitCode

$prepareClean = $prepareExit -eq 0 -and (Select-String -LiteralPath $prepareLog -SimpleMatch 'EPIC15_ASSET_PREPARATION=PASS' -Quiet)
$formatClean = $formatExit -eq 0
$goldenUpdateClean = $goldenUpdateExit -eq 0 -and (Select-String -LiteralPath $goldenUpdateLog -SimpleMatch 'All tests passed!' -Quiet)
$packageClean = $packageExit -eq 0 -and (Select-String -LiteralPath $packageLog -SimpleMatch 'PACKAGE_SCREENSHOTS=True' -Quiet)
$auditClean = $auditExit -eq 0 -and (Select-String -LiteralPath $auditLog -SimpleMatch 'EPIC15_STORE_ASSET_AUDIT=PASS' -Quiet)
$goldenVerifyClean = $goldenVerifyExit -eq 0 -and (Select-String -LiteralPath $goldenVerifyLog -SimpleMatch 'All tests passed!' -Quiet)
$targetedClean = $targetedExit -eq 0 -and (Select-String -LiteralPath $targetedLog -SimpleMatch 'All tests passed!' -Quiet)
$analyzeClean = $analyzeExit -eq 0 -and (Select-String -LiteralPath $analyzeLog -SimpleMatch 'No issues found!' -Quiet)
$buildClean = $buildExit -eq 0 -and (Test-Path -LiteralPath (Join-Path $project 'build\app\outputs\bundle\release\app-release.aab'))

$appleCount = @(Get-ChildItem -LiteralPath (Join-Path $project 'store_assets\screenshots\apple') -Filter '*.png' -File -ErrorAction SilentlyContinue).Count
$googleCount = @(Get-ChildItem -LiteralPath (Join-Path $project 'store_assets\screenshots\google_play') -Filter '*.png' -File -ErrorAction SilentlyContinue).Count
$evidenceRows = 0
$evidencePath = Join-Path $project 'store_assets\evidence\asset_evidence_matrix.json'
if (Test-Path -LiteralPath $evidencePath) {
  $evidenceRows = @((Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json)).Count
}
$rights = Get-Content -LiteralPath (Join-Path $project 'docs\release\BIL_EPIC15_CONTENT_RIGHTS.json') -Raw | ConvertFrom-Json
$rightsEntries = @($rights.generated_for_bil_2026_08_05).Count + @($rights.existing_bil_assets).Count + @($rights.third_party_assets).Count
$official = Get-Content -LiteralPath (Join-Path $project 'docs\release\BIL_EPIC15_OFFICIAL_REQUIREMENTS.json') -Raw | ConvertFrom-Json
$officialLinks = @($official.sources).Count
$ownerRegister = Get-Content -LiteralPath (Join-Path $project 'docs\release\BIL_EPIC15_OWNER_INPUT_AND_BLOCKERS.json') -Raw | ConvertFrom-Json
$ownerInputCount = @($ownerRegister.owner_inputs).Count
$externalBlockerCount = @($ownerRegister.external_blockers).Count
$targetedPassedCount = 0
$targetedSkippedCount = 0
$testText = Get-Content -LiteralPath $targetedLog -Raw -ErrorAction SilentlyContinue
$summaryMatch = [regex]::Matches($testText, '(?m)^\d+:\d+ \+(\d+)(?: ~(\d+))?: All tests passed!\s*$') | Select-Object -Last 1
if ($null -ne $summaryMatch) {
  $targetedPassedCount = [int]$summaryMatch.Groups[1].Value
  if ($summaryMatch.Groups[2].Success) { $targetedSkippedCount = [int]$summaryMatch.Groups[2].Value }
}

$ownerGate = 'PUBLIC_URLS_STORE_IDS_PRICING_REVIEW_CREDENTIALS_HUMAN_ART_REVIEW_EXTERNAL_REQUIRED_NOT_CLAIMED'
$epicPass = $prepareClean -and $formatClean -and $goldenUpdateClean -and $packageClean -and $auditClean -and $goldenVerifyClean -and $targetedClean -and $analyzeClean -and $buildClean -and $appleCount -eq 23 -and $googleCount -eq 19
$lines = @(
  'BIL v1 - Epic 15 store assets and visual evidence final gate summary',
  "Generated: $([DateTimeOffset]::Now.ToString('o'))",
  "Project: $project",
  "ASSET_PREPARATION_CLEAN=$prepareClean",
  "FORMAT_CLEAN=$formatClean",
  "GOLDEN_UPDATE_CLEAN=$goldenUpdateClean",
  "SCREENSHOT_PACKAGE_CLEAN=$packageClean",
  "STORE_ASSET_AUDIT_CLEAN=$auditClean",
  "GOLDEN_VERIFY_CLEAN=$goldenVerifyClean",
  "TARGETED_TEST_CLEAN=$targetedClean",
  "ANALYZE_CLEAN=$analyzeClean",
  "TARGETED_TESTS_PASSED_COUNT=$targetedPassedCount",
  "TARGETED_TESTS_SKIPPED_COUNT=$targetedSkippedCount",
  "ANDROID_AAB_BUILD_CLEAN=$buildClean",
  "APPLE_SCREENSHOTS=$appleCount",
  "GOOGLE_SCREENSHOTS=$googleCount",
  "EVIDENCE_ROWS=$evidenceRows",
  "RIGHTS_ENTRIES=$rightsEntries",
  "OFFICIAL_REQUIREMENT_LINKS=$officialLinks",
  "OWNER_INPUTS=$ownerInputCount",
  "EXTERNAL_BLOCKERS=$externalBlockerCount",
  'STORE_LOCALES=5',
  "OWNER_PUBLICATION_GATE=$ownerGate",
  "EPIC15_GATE=$(if ($epicPass) { 'PASS' } else { 'FAIL' })"
)
$lines | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summaryJson = [ordered]@{
  generated = [DateTimeOffset]::Now.ToString('o')
  project = $project
  asset_preparation_clean = $prepareClean
  format_clean = $formatClean
  golden_update_clean = $goldenUpdateClean
  screenshot_package_clean = $packageClean
  store_asset_audit_clean = $auditClean
  golden_verify_clean = $goldenVerifyClean
  targeted_test_clean = $targetedClean
  targeted_tests_passed = $targetedPassedCount
  targeted_tests_skipped = $targetedSkippedCount
  analyze_clean = $analyzeClean
  android_aab_build_clean = $buildClean
  apple_screenshots = $appleCount
  google_screenshots = $googleCount
  evidence_rows = $evidenceRows
  rights_entries = $rightsEntries
  official_requirement_links = $officialLinks
  owner_inputs = $ownerInputCount
  external_blockers = $externalBlockerCount
  store_locales = 5
  owner_publication_gate = $ownerGate
  epic15_gate = if ($epicPass) { 'PASS' } else { 'FAIL' }
} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($summaryJsonPath, $summaryJson, [Text.UTF8Encoding]::new($false))
$lines | ForEach-Object { Write-Output $_ }
if (-not $epicPass) { exit 1 }
