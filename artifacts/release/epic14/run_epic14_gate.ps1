$ErrorActionPreference = "Stop"
throw "EPIC14_GATE=HISTORICAL_NON_AUTHORITATIVE. This legacy local gate cannot build or certify a release candidate. Use .github/workflows/bil_android_release_candidate.yml for the signed Android candidate workflow. No artifact was produced."

$ErrorActionPreference = "Continue"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$summaryPath = Join-Path $PSScriptRoot "epic14_summary.txt"
$formatLog = Join-Path $PSScriptRoot "epic14_format.log"
$auditLog = Join-Path $PSScriptRoot "epic14_release_audit.log"
$securityLog = Join-Path $PSScriptRoot "epic14_security_audit.log"
$targetedLog = Join-Path $PSScriptRoot "epic14_targeted_tests.log"
$goldenLog = Join-Path $PSScriptRoot "epic14_goldens.log"
$analyzeLog = Join-Path $PSScriptRoot "epic14_analyze.log"
$testLog = Join-Path $PSScriptRoot "epic14_tests.log"
$signingLog = Join-Path $PSScriptRoot "epic14_signing.log"
$buildLog = Join-Path $PSScriptRoot "epic14_android_aab.log"
$nativeLog = Join-Path $PSScriptRoot "epic14_native_16kb.log"
$artifactJson = Join-Path $PSScriptRoot "epic14_android_artifact.json"

Set-Location -LiteralPath $project

function Invoke-Logged {
  param([scriptblock]$Action, [string]$Log)
  $stageName = [IO.Path]::GetFileNameWithoutExtension($Log).ToUpperInvariant()
  Write-Host ""
  Write-Host "=== START $stageName ===" -ForegroundColor Cyan
  Write-Host "Started: $([DateTimeOffset]::Now.ToString('HH:mm:ss'))"

  # Do not let assignment of Invoke-Logged capture and hide Tee-Object output.
  # Write-Host uses the information stream, so the user sees live progress while
  # the function returns only the native exit code to its caller.
  & $Action 2>&1 |
    Tee-Object -FilePath $Log |
    ForEach-Object { Write-Host (($_ | Out-String).TrimEnd()) }
  $nativeExitCode = $LASTEXITCODE

  Write-Host "Finished: $([DateTimeOffset]::Now.ToString('HH:mm:ss'))"
  Write-Host "=== END $stageName (EXIT=$nativeExitCode) ===" -ForegroundColor $(if ($nativeExitCode -eq 0) { 'Green' } else { 'Red' })
  $script:LastLoggedExitCode = $nativeExitCode
}

$formatTargets = @(
  "tool/epic14_release_audit.dart",
  "test/launch_readiness/epic14_release_execution_test.dart"
)
Invoke-Logged { & dart format @formatTargets } $formatLog
$formatExit = $script:LastLoggedExitCode
Invoke-Logged { & dart run tool/epic14_release_audit.dart } $auditLog
$auditExit = $script:LastLoggedExitCode
Invoke-Logged { & dart run tool/epic12_security_audit.dart } $securityLog
$securityExit = $script:LastLoggedExitCode

$targetedTests = @(
  "test/launch_readiness/epic14_release_execution_test.dart",
  "test/launch_readiness/android_release_boundary_contract_test.dart",
  "test/launch_readiness/apple_release_boundary_contract_test.dart",
  "test/launch_readiness/release_candidate_gate_contract_test.dart",
  "test/google_play_preparation/google_play_preparation_contract_test.dart",
  "test/features/commerce/commerce_boundary_regression_test.dart",
  "test/features/commerce/epic13_store_entitlement_truth_test.dart",
  "test/epic12_security_privacy_contract_test.dart"
)
Invoke-Logged {
  & flutter test @targetedTests --timeout 30s
} $targetedLog
$targetedExit = $script:LastLoggedExitCode

$goldenTests = @(
  "test/visual_closure/actual_production_pages_golden_test.dart",
  "test/visual_closure/actual_data_pages_golden_test.dart",
  "test/visual_closure/visual_system_widget_test.dart",
  "test/epic8_weekly_report_golden_test.dart"
)
Invoke-Logged {
  & flutter test @goldenTests --timeout 30s
} $goldenLog
$goldenExit = $script:LastLoggedExitCode

Invoke-Logged { & flutter analyze } $analyzeLog
$analyzeExit = $script:LastLoggedExitCode
Invoke-Logged { & flutter test --reporter expanded --timeout 30s } $testLog
$testExit = $script:LastLoggedExitCode

$keyPath = Join-Path $project "android\keystores\bil-upload-key.jks"
$propertiesPath = Join-Path $project "android\key.properties"
if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $propertiesPath)) {
  Invoke-Logged {
    & (Join-Path $PSScriptRoot "prepare_android_upload_key.ps1")
  } $signingLog
  $signingExit = $script:LastLoggedExitCode
} else {
  "ANDROID_UPLOAD_KEY=EXISTS_NOT_OVERWRITTEN" | Tee-Object -FilePath $signingLog
  $signingExit = 0
}

Invoke-Logged {
  & flutter build appbundle --release --no-pub `
    --target-platform android-arm64,android-x64
} $buildLog
$buildExit = $script:LastLoggedExitCode

$aabPath = Join-Path $project "build\app\outputs\bundle\release\app-release.aab"
$artifactClean = $false
$signatureClean = $false
$nativeClean = $false
$aabHash = ""
$aabSize = 0

if ($buildExit -eq 0 -and (Test-Path -LiteralPath $aabPath)) {
  $aabItem = Get-Item -LiteralPath $aabPath
  $aabSize = $aabItem.Length
  $aabHash = (Get-FileHash -LiteralPath $aabPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $artifactClean = $aabSize -gt 0 -and $aabSize -lt 200MB

  $jarsigner = Get-Command jarsigner -ErrorAction SilentlyContinue
  if ($null -eq $jarsigner) {
    $studioSigner = "C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe"
    if (Test-Path -LiteralPath $studioSigner) { $jarsignerPath = $studioSigner }
  } else {
    $jarsignerPath = $jarsigner.Source
  }
  if (-not [string]::IsNullOrWhiteSpace($jarsignerPath)) {
    $signatureLog = Join-Path $PSScriptRoot "epic14_aab_signature.log"
    & $jarsignerPath -verify -verbose -certs $aabPath 2>&1 |
      Tee-Object -FilePath $signatureLog
    $signatureClean = $LASTEXITCODE -eq 0 -and
      (Select-String -LiteralPath $signatureLog -Pattern 'jar verified' -Quiet)
  }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $nativeTemp = Join-Path ([IO.Path]::GetTempPath()) ("bil-epic14-native-" + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $nativeTemp | Out-Null
  try {
    $archive = [IO.Compression.ZipFile]::OpenRead($aabPath)
    $nativeEntries = @($archive.Entries | Where-Object { $_.FullName -match '\.so$' })
    foreach ($entry in $nativeEntries) {
      $safeName = $entry.FullName.Replace('/', '__').Replace('\\', '__')
      $target = Join-Path $nativeTemp $safeName
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    }
    $archive.Dispose()

    $sdkLine = Get-Content -LiteralPath (Join-Path $project "android\local.properties") |
      Where-Object { $_ -like 'sdk.dir=*' } | Select-Object -First 1
    $sdkRoot = if ($sdkLine) {
      $sdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':')
    } else { $null }
    $readElf = if ($sdkRoot) {
      Get-ChildItem -LiteralPath (Join-Path $sdkRoot "ndk") -Filter "llvm-readelf.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    } else { $null }

    $nativeFailures = @()
    if ($nativeEntries.Count -eq 0) {
      "NATIVE_LIBRARIES=NONE" | Set-Content -LiteralPath $nativeLog
      $nativeClean = $true
    } elseif ($null -eq $readElf) {
      "NATIVE_ALIGNMENT=UNVERIFIED_LLVM_READELF_MISSING" | Set-Content -LiteralPath $nativeLog
      $nativeClean = $false
    } else {
      foreach ($so in Get-ChildItem -LiteralPath $nativeTemp -Filter "*.so") {
        $headers = & $readElf.FullName -lW $so.FullName 2>&1
        $loadLines = @($headers | Where-Object { $_ -match '^\s*LOAD\s+' })
        foreach ($line in $loadLines) {
          $tokens = ($line.Trim() -split '\s+')
          $alignment = $tokens[-1]
          if ($alignment -match '^0x[0-9a-fA-F]+$') {
            $value = [Convert]::ToInt64($alignment.Substring(2), 16)
            if ($value -lt 0x4000) { $nativeFailures += "$($so.Name):$alignment" }
          }
        }
      }
      @(
        "NATIVE_LIBRARIES=$($nativeEntries.Count)"
        "NATIVE_ALIGNMENT_FAILURES=$($nativeFailures.Count)"
        $nativeFailures
      ) | Set-Content -LiteralPath $nativeLog
      $nativeClean = $nativeFailures.Count -eq 0
    }
  } finally {
    if (Test-Path -LiteralPath $nativeTemp) {
      Remove-Item -LiteralPath $nativeTemp -Recurse -Force
    }
  }

  [ordered]@{
    path = $aabPath
    size_bytes = $aabSize
    sha256 = $aabHash
    signature_verified = $signatureClean
    native_16kb_verified = $nativeClean
  } | ConvertTo-Json | Set-Content -LiteralPath $artifactJson -Encoding utf8
}

$formatClean = $formatExit -eq 0
$auditClean = $auditExit -eq 0 -and (Select-String -LiteralPath $auditLog -SimpleMatch 'EPIC14_RELEASE_AUDIT=PASS' -Quiet)
$securityClean = $securityExit -eq 0 -and
  (Select-String -LiteralPath $securityLog -SimpleMatch 'EPIC12_SECRET_TLS_LOG_AUDIT=PASS' -Quiet)
$targetedClean = $targetedExit -eq 0 -and (Select-String -LiteralPath $targetedLog -SimpleMatch 'All tests passed!' -Quiet)
$goldenClean = $goldenExit -eq 0 -and (Select-String -LiteralPath $goldenLog -SimpleMatch 'All tests passed!' -Quiet)
$analyzeClean = $analyzeExit -eq 0 -and (Select-String -LiteralPath $analyzeLog -SimpleMatch 'No issues found!' -Quiet)
$testClean = $testExit -eq 0 -and (Select-String -LiteralPath $testLog -SimpleMatch 'All tests passed!' -Quiet)
$buildClean = $buildExit -eq 0 -and $artifactClean -and $signatureClean -and $nativeClean
$iosGate = "MACOS_UNSIGNED_AND_SIGNED_WORKFLOWS_READY_EXTERNAL_CREDENTIALS_NOT_CLAIMED"
$epicPass = $formatClean -and $auditClean -and $securityClean -and $targetedClean -and $goldenClean -and $analyzeClean -and $testClean -and ($signingExit -eq 0) -and $buildClean

$passedCount = 0
$skippedCount = 0
$testText = Get-Content -LiteralPath $testLog -Raw -ErrorAction SilentlyContinue
$summaryMatch = [regex]::Matches($testText, '(?m)^\d+:\d+ \+(\d+)(?: ~(\d+))?: All tests passed!\s*$') | Select-Object -Last 1
if ($null -ne $summaryMatch) {
  $passedCount = [int]$summaryMatch.Groups[1].Value
  if ($summaryMatch.Groups[2].Success) { $skippedCount = [int]$summaryMatch.Groups[2].Value }
}

$lines = @(
  "BIL v1 - Epic 14 build and release final gate summary",
  "Generated: $([DateTimeOffset]::Now.ToString('o'))",
  "Project: $project",
  "FORMAT_CLEAN=$formatClean",
  "RELEASE_AUDIT_CLEAN=$auditClean",
  "SECURITY_AUDIT_CLEAN=$securityClean",
  "TARGETED_TEST_CLEAN=$targetedClean",
  "GOLDEN_VERIFY_CLEAN=$goldenClean",
  "ANALYZE_CLEAN=$analyzeClean",
  "TESTS_PASSED_COUNT=$passedCount",
  "TESTS_SKIPPED_COUNT=$skippedCount",
  "TEST_CLEAN=$testClean",
  "ANDROID_SIGNING_READY=$($signingExit -eq 0)",
  "ANDROID_AAB_BUILD_CLEAN=$buildClean",
  "ANDROID_AAB_PATH=$aabPath",
  "ANDROID_AAB_SIZE_BYTES=$aabSize",
  "ANDROID_AAB_SHA256=$aabHash",
  "ANDROID_AAB_SIGNATURE_CLEAN=$signatureClean",
  "ANDROID_NATIVE_16KB_CLEAN=$nativeClean",
  "IOS_RELEASE_GATE=$iosGate",
  "EPIC14_GATE=$(if ($epicPass) { 'PASS' } else { 'FAIL' })"
)
$lines | Set-Content -LiteralPath $summaryPath -Encoding utf8
$lines | ForEach-Object { Write-Output $_ }

if (-not $epicPass) { exit 1 }
