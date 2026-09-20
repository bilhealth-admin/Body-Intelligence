$ErrorActionPreference = "Continue"
$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location -LiteralPath $project

# Materialize the canonical Supabase Edge Function layout from the reviewed
# flat sources. This is deterministic packaging, not a deployment.
$edgeFunctions = @{
  "community-push-dispatch" = "supabase/functions/community_push_dispatch.ts"
  "account-data-deletion" = "supabase/functions/account_data_deletion.ts"
}
foreach ($entry in $edgeFunctions.GetEnumerator()) {
  $directory = Join-Path $project ("supabase/functions/" + $entry.Key)
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $project $entry.Value) `
    -Destination (Join-Path $directory "index.ts") -Force
}

$formatLog = Join-Path $PSScriptRoot "epic9_format.log"
$targetedLog = Join-Path $PSScriptRoot "epic9_targeted_tests.log"
$analyzeLog = Join-Path $PSScriptRoot "epic9_analyze.log"
$testLog = Join-Path $PSScriptRoot "epic9_tests.log"
$integrationLog = Join-Path $PSScriptRoot "epic9_cloud_integration.log"
$summaryFile = Join-Path $PSScriptRoot "epic9_summary.txt"

function Invoke-LoggedCommand {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Command,
    [Parameter(Mandatory = $true)][string]$LogPath
  )
  & $Command 2>&1 | Tee-Object -FilePath $LogPath | Out-Host
  return [int]$LASTEXITCODE
}

$formatTargets = @("lib", "test", "integration_test") |
  Where-Object { Test-Path -LiteralPath $_ }
$formatExitCode = Invoke-LoggedCommand -LogPath $formatLog -Command {
  & dart format @formatTargets
}

$targetedTests = @(
  "test/epic9_community_release_contract_test.dart",
  "test/epic9_cloud_completion_contract_test.dart",
  "test/features/community/community_deep_link_test.dart",
  "test/features/nutrition/epic5_product_review_trust_contract_test.dart"
) | Where-Object { Test-Path -LiteralPath $_ }
$targetedExitCode = Invoke-LoggedCommand -LogPath $targetedLog -Command {
  & flutter test @targetedTests --timeout 30s
}

$integrationVariables = @(
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "BIL_EPIC9_ACCOUNT_A_EMAIL",
  "BIL_EPIC9_ACCOUNT_A_PASSWORD",
  "BIL_EPIC9_ACCOUNT_B_EMAIL",
  "BIL_EPIC9_ACCOUNT_B_PASSWORD"
)
$integrationConfigured = $true
foreach ($name in $integrationVariables) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    $integrationConfigured = $false
  }
}
$integrationExitCode = 0
$integrationStatus = "BLOCKED_CREDENTIALS_FEATURE_HIDDEN"
if ($integrationConfigured) {
  $integrationExitCode = Invoke-LoggedCommand -LogPath $integrationLog -Command {
    & flutter test integration_test/epic9_two_account_cloud_test.dart --timeout 60s `
      --dart-define=BIL_RUN_EPIC9_CLOUD_INTEGRATION=true `
      --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
      --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
      --dart-define=BIL_EPIC9_ACCOUNT_A_EMAIL=$env:BIL_EPIC9_ACCOUNT_A_EMAIL `
      --dart-define=BIL_EPIC9_ACCOUNT_A_PASSWORD=$env:BIL_EPIC9_ACCOUNT_A_PASSWORD `
      --dart-define=BIL_EPIC9_ACCOUNT_B_EMAIL=$env:BIL_EPIC9_ACCOUNT_B_EMAIL `
      --dart-define=BIL_EPIC9_ACCOUNT_B_PASSWORD=$env:BIL_EPIC9_ACCOUNT_B_PASSWORD
  }
  $integrationStatus = if ($integrationExitCode -eq 0) { "PASS" } else { "FAIL" }
} else {
  "Epic 9 cloud integration blocked by absent dedicated QA credentials; community and push remain disabled." |
    Set-Content -LiteralPath $integrationLog -Encoding utf8
}

$analyzeExitCode = Invoke-LoggedCommand -LogPath $analyzeLog -Command {
  & flutter analyze
}
$testExitCode = Invoke-LoggedCommand -LogPath $testLog -Command {
  & flutter test --timeout 30s
}

$targetedText = if (Test-Path -LiteralPath $targetedLog) {
  Get-Content -LiteralPath $targetedLog -Raw
} else { "" }
$analyzeText = if (Test-Path -LiteralPath $analyzeLog) {
  Get-Content -LiteralPath $analyzeLog -Raw
} else { "" }
$testText = if (Test-Path -LiteralPath $testLog) {
  Get-Content -LiteralPath $testLog -Raw
} else { "" }

$targetedClean = ($targetedExitCode -eq 0) -and ($targetedText -match 'All tests passed!')
$analyzeClean = ($analyzeExitCode -eq 0) -and ($analyzeText -match 'No issues found!')
$testClean = ($testExitCode -eq 0) -and ($testText -match 'All tests passed!')
$passedCount = 0
$skippedCount = 0
$resultMatches = [regex]::Matches(
  $testText,
  '\+(\d+)(?:\s+~(\d+))?:\s+All tests passed!'
)
if ($resultMatches.Count -gt 0) {
  $lastResult = $resultMatches[$resultMatches.Count - 1]
  $passedCount = [int]$lastResult.Groups[1].Value
  if ($lastResult.Groups[2].Success) {
    $skippedCount = [int]$lastResult.Groups[2].Value
  }
}

$gatePassed = (
  ($formatExitCode -eq 0) -and
  $targetedClean -and
  ($integrationExitCode -eq 0) -and
  $analyzeClean -and
  $testClean
)
$gate = if ($gatePassed) { "PASS" } else { "FAIL" }
$summary = @"
BIL v1 - Epic 9 community, cloud, friends, and messages gate summary
Generated: $(Get-Date -Format o)
Project: $project
FORMAT_EXIT_CODE=$formatExitCode
TARGETED_TEST_EXIT_CODE=$targetedExitCode
TARGETED_TEST_CLEAN=$targetedClean
CLOUD_INTEGRATION_STATUS=$integrationStatus
CLOUD_INTEGRATION_EXIT_CODE=$integrationExitCode
ANALYZE_EXIT_CODE=$analyzeExitCode
ANALYZE_CLEAN=$analyzeClean
TEST_EXIT_CODE=$testExitCode
TESTS_PASSED_COUNT=$passedCount
TESTS_SKIPPED_COUNT=$skippedCount
TEST_CLEAN=$testClean
EPIC9_GATE=$gate

SUCCESS CRITERIA:
1. FORMAT_EXIT_CODE=0
2. TARGETED_TEST_EXIT_CODE=0 and TARGETED_TEST_CLEAN=True
3. CLOUD_INTEGRATION_STATUS=PASS, or BLOCKED_CREDENTIALS_FEATURE_HIDDEN with feature flags false
4. ANALYZE_EXIT_CODE=0 and ANALYZE_CLEAN=True
5. TEST_EXIT_CODE=0 and TEST_CLEAN=True
6. EPIC9_GATE=PASS
"@
$summary | Set-Content -LiteralPath $summaryFile -Encoding utf8
$summary
Get-Item -LiteralPath $formatLog, $targetedLog, $integrationLog, $analyzeLog, $testLog, $summaryFile |
  Select-Object FullName, Length, LastWriteTime
if (-not $gatePassed) { exit 1 }
exit 0
