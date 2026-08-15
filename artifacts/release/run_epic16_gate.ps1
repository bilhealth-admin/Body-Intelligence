$ErrorActionPreference = 'Continue'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$epicDir = Join-Path $PSScriptRoot 'epic16'
New-Item -ItemType Directory -Force -Path $epicDir | Out-Null
Set-Location -LiteralPath $project

function Invoke-Logged {
  param([scriptblock]$Action, [string]$Log)
  $stage = [IO.Path]::GetFileNameWithoutExtension($Log).ToUpperInvariant()
  Write-Host "`n=== START $stage ===" -ForegroundColor Cyan
  Write-Host "Started: $([DateTimeOffset]::Now.ToString('HH:mm:ss'))"
  $global:LASTEXITCODE = 0
  & $Action 2>&1 | Tee-Object -FilePath $Log |
    ForEach-Object { Write-Host (($_ | Out-String).TrimEnd()) }
  $ok = $?
  $script:LastLoggedExitCode = if ($ok) { $LASTEXITCODE } else { 1 }
  Write-Host "Finished: $([DateTimeOffset]::Now.ToString('HH:mm:ss'))"
  Write-Host "=== END $stage (EXIT=$script:LastLoggedExitCode) ===" -ForegroundColor $(if ($script:LastLoggedExitCode -eq 0) { 'Green' } else { 'Red' })
}

$initialStatus = Join-Path $epicDir 'epic16_initial_status.log'
$initialBranch = (& git branch --show-current).Trim()
$initialHead = (& git rev-parse HEAD).Trim()
$baselineClean = $initialBranch -eq 'release/bil-v1-final-closure' -and
  $initialHead -eq '9d7b2128970647aa847eb8650a6297c7c568d2a0'
@(
  "BRANCH=$initialBranch"
  "HEAD=$initialHead"
  "EPIC15_BASELINE_CLEAN=$baselineClean"
  'STATUS_BEGIN'
  (& git status --short)
  'STATUS_END'
) | Set-Content -LiteralPath $initialStatus -Encoding utf8

$auditLog = Join-Path $epicDir 'epic16_release_audit.log'
Invoke-Logged { & dart run tool/epic16_release_audit.dart } $auditLog
$auditExit = $script:LastLoggedExitCode

$gapAuditLog = Join-Path $epicDir 'epic16_final_gap_audit.log'
Invoke-Logged { & dart run tool/epic16_final_gap_audit.dart } $gapAuditLog
$gapAuditExit = $script:LastLoggedExitCode

$localizationLog = Join-Path $epicDir 'epic16_localization_audit.log'
Invoke-Logged { & dart run tool/epic11_localization_audit.dart } $localizationLog
$localizationExit = $script:LastLoggedExitCode

$securityLog = Join-Path $epicDir 'epic16_security_audit.log'
Invoke-Logged { & dart run tool/epic12_security_audit.dart } $securityLog
$securityExit = $script:LastLoggedExitCode

$assetsLog = Join-Path $epicDir 'epic16_store_asset_audit.log'
Invoke-Logged { & dart run tool/epic15_store_asset_audit.dart } $assetsLog
$assetsExit = $script:LastLoggedExitCode

$licenseLog = Join-Path $epicDir 'epic16_license_rights.log'
$licenseClean = (Test-Path -LiteralPath 'assets/fonts/OFL.txt') -and
  (Test-Path -LiteralPath 'docs/release/BIL_THIRD_PARTY_NOTICES.md') -and
  (Test-Path -LiteralPath 'docs/release/BIL_EPIC15_CONTENT_RIGHTS.json') -and
  (Test-Path -LiteralPath 'pubspec.lock')
@(
  "FONT_OFL_PRESENT=$(Test-Path -LiteralPath 'assets/fonts/OFL.txt')"
  "THIRD_PARTY_NOTICE_PRESENT=$(Test-Path -LiteralPath 'docs/release/BIL_THIRD_PARTY_NOTICES.md')"
  "CONTENT_RIGHTS_PRESENT=$(Test-Path -LiteralPath 'docs/release/BIL_EPIC15_CONTENT_RIGHTS.json')"
  "RESOLVED_DEPENDENCIES_PRESENT=$(Test-Path -LiteralPath 'pubspec.lock')"
  "LICENSE_RIGHTS_CLEAN=$licenseClean"
) | Set-Content -LiteralPath $licenseLog -Encoding utf8

$placeholderLog = Join-Path $epicDir 'epic16_placeholder_scan.log'
$productionRoots = @('lib', 'android', 'ios', 'supabase')
$productionFiles = Get-ChildItem -LiteralPath $productionRoots -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object {
    $_.FullName -notmatch '[\\/](?:build|\.dart_tool|\.gradle|ephemeral|Pods|Generated)[\\/]' -and
    $_.Extension -notin @('.lock', '.bin', '.jar', '.class', '.so', '.dll', '.dylib', '.png', '.jpg', '.jpeg', '.webp')
  }
$placeholderHits = @($productionFiles |
  Select-String -Pattern '\b(TODO|FIXME|HACK|CHANGEME)\b|example\.com|ca-app-pub-|testAdUnit|demoAdUnit' -CaseSensitive:$false |
  Where-Object { $_.Line -notmatch "'Everything in Plus': 'Todo lo incluido en Plus'" })
$placeholderHits | ForEach-Object { "$($_.Path):$($_.LineNumber):$($_.Line.Trim())" } |
  Set-Content -LiteralPath $placeholderLog -Encoding utf8
$placeholderClean = $placeholderHits.Count -eq 0

$formatLog = Join-Path $epicDir 'epic16_format.log'
Invoke-Logged { & dart format --output=none --set-exit-if-changed . } $formatLog
$formatExit = $script:LastLoggedExitCode

$targetedLog = Join-Path $epicDir 'epic16_targeted_tests.log'
$targetedTests = @(
  'test/launch_readiness/epic16_ad_privacy_contract_test.dart',
  'test/launch_readiness/epic16_release_candidate_contract_test.dart',
  'test/launch_readiness/epic15_store_materials_contract_test.dart',
  'test/launch_readiness/epic14_release_execution_test.dart',
  'test/launch_readiness/android_release_boundary_contract_test.dart',
  'test/launch_readiness/apple_release_boundary_contract_test.dart',
  'test/launch_readiness/release_candidate_gate_contract_test.dart',
  'test/launch_readiness/store_privacy_evidence_contract_test.dart',
  'test/epic11_localization_accessibility_test.dart',
  'test/epic12_security_privacy_contract_test.dart',
  'test/features/commerce/epic13_store_entitlement_truth_test.dart',
  'test/google_play_preparation/google_play_preparation_contract_test.dart'
)
Invoke-Logged { & flutter test @targetedTests --timeout 30s } $targetedLog
$targetedExit = $script:LastLoggedExitCode

$goldenLog = Join-Path $epicDir 'epic16_golden_verify.log'
$goldenTests = @(
  'test/visual_closure/actual_production_pages_golden_test.dart',
  'test/visual_closure/actual_data_pages_golden_test.dart',
  'test/visual_closure/visual_system_widget_test.dart',
  'test/epic8_weekly_report_golden_test.dart',
  'test/epic11_localization_accessibility_golden_test.dart',
  'test/epic15_store_screenshot_golden_test.dart'
)
$goldenTests = @($goldenTests | Where-Object { Test-Path -LiteralPath $_ })
Invoke-Logged { & flutter test @goldenTests --timeout 60s } $goldenLog
$goldenExit = $script:LastLoggedExitCode

$analyzeLog = Join-Path $epicDir 'epic16_analyze.log'
Invoke-Logged { & flutter analyze } $analyzeLog
$analyzeExit = $script:LastLoggedExitCode

$testLog = Join-Path $epicDir 'epic16_tests.log'
Invoke-Logged { & flutter test --reporter expanded --timeout 30s } $testLog
$testExit = $script:LastLoggedExitCode

$integrationLog = Join-Path $epicDir 'epic16_integration.log'
if (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_URL) -and
    -not [string]::IsNullOrWhiteSpace($env:SUPABASE_ANON_KEY) -and
    -not [string]::IsNullOrWhiteSpace($env:BIL_TEST_USER_A_EMAIL) -and
    -not [string]::IsNullOrWhiteSpace($env:BIL_TEST_USER_B_EMAIL)) {
  Invoke-Logged { & flutter test integration_test --timeout 90s } $integrationLog
  $integrationExit = $script:LastLoggedExitCode
  $integrationStatus = if ($integrationExit -eq 0) { 'PASS' } else { 'FAIL' }
} else {
  $integrationExit = 0
  $integrationStatus = 'CREDENTIALLED_CLOUD_SMOKE_EXTERNAL_REQUIRED_NOT_CLAIMED'
  $integrationStatus | Set-Content -LiteralPath $integrationLog -Encoding utf8
}

$urlLog = Join-Path $epicDir 'epic16_public_url_status.json'
$urlResults = @()
foreach ($path in @('privacy', 'terms', 'support', 'contact', 'account-deletion', 'data-deletion', 'subscription-terms', 'health-disclaimer')) {
  $url = "https://bilhealth.com/$path"
  try {
    $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 20
    $urlResults += [ordered]@{ url = $url; status = [int]$response.StatusCode; published = $response.StatusCode -eq 200 }
  } catch {
    $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    $urlResults += [ordered]@{ url = $url; status = $status; published = $false }
  }
}
$urlResults | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $urlLog -Encoding utf8
$publishedUrlCount = @($urlResults | Where-Object published).Count
$urlGate = if ($publishedUrlCount -eq $urlResults.Count) { 'PASS' } else { 'OWNER_EXTERNAL_ACTION_UNPUBLISHED_OR_UNVERIFIED' }

$buildLog = Join-Path $epicDir 'epic16_android_aab.log'
$keyPath = Join-Path $project 'android\keystores\bil-upload-key.jks'
$propertiesPath = Join-Path $project 'android\key.properties'
$signingReady = (Test-Path -LiteralPath $keyPath) -and (Test-Path -LiteralPath $propertiesPath)
if ($signingReady) {
  Invoke-Logged { & flutter build appbundle --release --no-pub --target-platform android-arm64,android-x64 } $buildLog
  $buildExit = $script:LastLoggedExitCode
} else {
  'ANDROID_SIGNING_MATERIAL_MISSING_GATE_FAIL_CLOSED' | Set-Content -LiteralPath $buildLog
  $buildExit = 1
}

$aabPath = Join-Path $project 'build\app\outputs\bundle\release\app-release.aab'
$aabSize = 0
$aabHash = ''
$signatureClean = $false
$nativeClean = $false
if ($buildExit -eq 0 -and (Test-Path -LiteralPath $aabPath)) {
  $aabSize = (Get-Item -LiteralPath $aabPath).Length
  $aabHash = (Get-FileHash -LiteralPath $aabPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $jarsigner = Get-Command jarsigner -ErrorAction SilentlyContinue
  $jarsignerPath = if ($jarsigner) { $jarsigner.Source } else { 'C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe' }
  $signatureLog = Join-Path $epicDir 'epic16_aab_signature.log'
  if (Test-Path -LiteralPath $jarsignerPath) {
    & $jarsignerPath -verify -verbose -certs $aabPath 2>&1 | Tee-Object -FilePath $signatureLog
    $signatureClean = $LASTEXITCODE -eq 0 -and (Select-String -LiteralPath $signatureLog -SimpleMatch 'jar verified' -Quiet)
  }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $nativeTemp = Join-Path ([IO.Path]::GetTempPath()) ('bil-epic16-native-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $nativeTemp | Out-Null
  try {
    $archive = [IO.Compression.ZipFile]::OpenRead($aabPath)
    $nativeEntries = @($archive.Entries | Where-Object { $_.FullName -match '\.so$' })
    foreach ($entry in $nativeEntries) {
      $target = Join-Path $nativeTemp $entry.FullName.Replace('/', '__')
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    }
    $archive.Dispose()
    $sdkLine = Get-Content -LiteralPath (Join-Path $project 'android\local.properties') | Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
    $sdkRoot = if ($sdkLine) { $sdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':') } else { $null }
    $readElf = if ($sdkRoot) { Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'ndk') -Filter 'llvm-readelf.exe' -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 } else { $null }
    $nativeFailures = @()
    if ($nativeEntries.Count -eq 0) { $nativeClean = $true }
    elseif ($readElf) {
      foreach ($so in Get-ChildItem -LiteralPath $nativeTemp -Filter '*.so') {
        foreach ($line in @(& $readElf.FullName -lW $so.FullName 2>&1 | Where-Object { $_ -match '^\s*LOAD\s+' })) {
          $alignment = (($line.Trim() -split '\s+')[-1])
          if ($alignment -match '^0x[0-9a-fA-F]+$' -and [Convert]::ToInt64($alignment.Substring(2), 16) -lt 0x4000) { $nativeFailures += "$($so.Name):$alignment" }
        }
      }
      $nativeClean = $nativeFailures.Count -eq 0
    }
    @("NATIVE_LIBRARIES=$($nativeEntries.Count)", "NATIVE_ALIGNMENT_FAILURES=$($nativeFailures.Count)") + $nativeFailures |
      Set-Content -LiteralPath (Join-Path $epicDir 'epic16_native_16kb.log') -Encoding utf8
  } finally {
    if (Test-Path -LiteralPath $nativeTemp) { Remove-Item -LiteralPath $nativeTemp -Recurse -Force }
  }
}

$auditClean = $auditExit -eq 0 -and (Select-String -LiteralPath $auditLog -SimpleMatch 'EPIC16_RELEASE_AUDIT=PASS' -Quiet)
$gapAuditClean = $gapAuditExit -eq 0 -and (Select-String -LiteralPath $gapAuditLog -SimpleMatch 'EPIC16_FINAL_GAP_AUDIT=PASS' -Quiet)
$localizationClean = $localizationExit -eq 0 -and (Select-String -LiteralPath $localizationLog -SimpleMatch 'EPIC11_LOCALIZATION_AUDIT=PASS' -Quiet)
$securityClean = $securityExit -eq 0 -and (Select-String -LiteralPath $securityLog -SimpleMatch 'EPIC12_SECRET_TLS_LOG_AUDIT=PASS' -Quiet)
$assetsClean = $assetsExit -eq 0 -and (Select-String -LiteralPath $assetsLog -SimpleMatch 'EPIC15_STORE_ASSET_AUDIT=PASS' -Quiet)
$formatClean = $formatExit -eq 0
$targetedClean = $targetedExit -eq 0 -and (Select-String -LiteralPath $targetedLog -SimpleMatch 'All tests passed!' -Quiet)
$goldenClean = $goldenExit -eq 0 -and (Select-String -LiteralPath $goldenLog -SimpleMatch 'All tests passed!' -Quiet)
$analyzeClean = $analyzeExit -eq 0 -and (Select-String -LiteralPath $analyzeLog -SimpleMatch 'No issues found!' -Quiet)
$testClean = $testExit -eq 0 -and (Select-String -LiteralPath $testLog -SimpleMatch 'All tests passed!' -Quiet)
$androidClean = $buildExit -eq 0 -and $aabSize -gt 0 -and $aabSize -lt 200MB -and $signatureClean -and $nativeClean
$iosGate = 'WINDOWS_STATIC_AND_CLOUD_WORKFLOWS_READY_APPLE_MEMBERSHIP_SIGNED_ARCHIVE_TESTFLIGHT_EXTERNAL_REQUIRED_NOT_CLAIMED'
$storeGate = 'GOOGLE_LISTING_PRODUCTS_CLOSED_TRACK_APPLE_MEMBERSHIP_SANDBOX_AND_PUBLICATION_EXTERNAL_REQUIRED_NOT_CLAIMED'
$linguisticGate = 'LEGACY_AR_EN_RUNTIME_COPY_FR_ES_TR_PROFESSIONAL_COMPLETION_AND_DEVICE_REVIEW_EXTERNAL_REQUIRED_NOT_CLAIMED'
$epicPass = $baselineClean -and $auditClean -and $gapAuditClean -and $localizationClean -and $securityClean -and $assetsClean -and $licenseClean -and $placeholderClean -and $formatClean -and $targetedClean -and $goldenClean -and $analyzeClean -and $testClean -and ($integrationExit -eq 0) -and $androidClean

$passedCount = 0
$skippedCount = 0
$testText = Get-Content -LiteralPath $testLog -Raw -ErrorAction SilentlyContinue
$match = [regex]::Matches($testText, '(?m)^\d+:\d+ \+(\d+)(?: ~(\d+))?: All tests passed!\s*$') | Select-Object -Last 1
if ($match) {
  $passedCount = [int]$match.Groups[1].Value
  if ($match.Groups[2].Success) { $skippedCount = [int]$match.Groups[2].Value }
}

$finalStatus = @(& git status --short)
$summary = [ordered]@{
  generated = [DateTimeOffset]::Now.ToString('o')
  project = $project
  branch = (& git branch --show-current)
  head = (& git rev-parse HEAD)
  epic15_baseline_clean = $baselineClean
  release_audit_clean = $auditClean
  final_gap_audit_clean = $gapAuditClean
  localization_audit_clean = $localizationClean
  security_audit_clean = $securityClean
  store_asset_rights_audit_clean = $assetsClean
  license_rights_clean = $licenseClean
  placeholder_scan_clean = $placeholderClean
  placeholder_hits = $placeholderHits.Count
  format_clean = $formatClean
  targeted_test_clean = $targetedClean
  golden_verify_clean = $goldenClean
  analyze_clean = $analyzeClean
  test_clean = $testClean
  tests_passed = $passedCount
  tests_skipped = $skippedCount
  integration_gate = $integrationStatus
  android_aab_clean = $androidClean
  android_aab_path = $aabPath
  android_aab_size_bytes = $aabSize
  android_aab_sha256 = $aabHash
  android_signature_clean = $signatureClean
  android_native_16kb_clean = $nativeClean
  ios_gate = $iosGate
  linguistic_content_gate = $linguisticGate
  public_url_gate = $urlGate
  published_public_urls = $publishedUrlCount
  store_publication_gate = $storeGate
  final_worktree_entries = $finalStatus.Count
  epic16_gate = if ($epicPass) { 'PASS' } else { 'FAIL' }
}
$jsonPath = Join-Path $epicDir 'epic16_summary.json'
$txtPath = Join-Path $epicDir 'epic16_summary.txt'
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding utf8
$lines = @(
  'BIL v1 - Epic 16 final release candidate gate summary',
  "Generated: $($summary.generated)",
  "Project: $project",
  "BRANCH=$($summary.branch)",
  "HEAD=$($summary.head)",
  "EPIC15_BASELINE_CLEAN=$baselineClean",
  "RELEASE_AUDIT_CLEAN=$auditClean",
  "FINAL_GAP_AUDIT_CLEAN=$gapAuditClean",
  "LOCALIZATION_AUDIT_CLEAN=$localizationClean",
  "SECURITY_AUDIT_CLEAN=$securityClean",
  "STORE_ASSET_RIGHTS_AUDIT_CLEAN=$assetsClean",
  "LICENSE_RIGHTS_CLEAN=$licenseClean",
  "PLACEHOLDER_SCAN_CLEAN=$placeholderClean",
  "PLACEHOLDER_HITS=$($placeholderHits.Count)",
  "FORMAT_CLEAN=$formatClean",
  "TARGETED_TEST_CLEAN=$targetedClean",
  "GOLDEN_VERIFY_CLEAN=$goldenClean",
  "ANALYZE_CLEAN=$analyzeClean",
  "TESTS_PASSED_COUNT=$passedCount",
  "TESTS_SKIPPED_COUNT=$skippedCount",
  "TEST_CLEAN=$testClean",
  "INTEGRATION_GATE=$integrationStatus",
  "ANDROID_AAB_BUILD_CLEAN=$androidClean",
  "ANDROID_AAB_PATH=$aabPath",
  "ANDROID_AAB_SIZE_BYTES=$aabSize",
  "ANDROID_AAB_SHA256=$aabHash",
  "ANDROID_AAB_SIGNATURE_CLEAN=$signatureClean",
  "ANDROID_NATIVE_16KB_CLEAN=$nativeClean",
  "IOS_GATE=$iosGate",
  "LINGUISTIC_CONTENT_GATE=$linguisticGate",
  "PUBLIC_URL_GATE=$urlGate",
  "PUBLISHED_PUBLIC_URLS=$publishedUrlCount/$($urlResults.Count)",
  "STORE_PUBLICATION_GATE=$storeGate",
  "FINAL_WORKTREE_ENTRIES=$($finalStatus.Count)",
  "EPIC16_GATE=$(if ($epicPass) { 'PASS' } else { 'FAIL' })"
)
$lines | Set-Content -LiteralPath $txtPath -Encoding utf8
$lines | ForEach-Object { Write-Output $_ }
if (-not $epicPass) { exit 1 }
