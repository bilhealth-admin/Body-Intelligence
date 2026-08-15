$ErrorActionPreference = "Stop"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$summaryPath = Join-Path $PSScriptRoot "epic14_summary.txt"
$commitSummaryPath = Join-Path $PSScriptRoot "epic14_commit_summary.txt"
Set-Location -LiteralPath $project

if (-not (Test-Path -LiteralPath $summaryPath)) {
  throw "Epic 14 gate summary is missing."
}
if (-not (Select-String -LiteralPath $summaryPath -SimpleMatch "EPIC14_GATE=PASS" -Quiet)) {
  throw "Epic 14 gate has not passed."
}

$branch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) { throw "Unable to read the current Git branch." }
if ($branch -ne "release/bil-v1-final-closure") {
  throw "Refusing Epic 14 commit on unexpected branch: $branch"
}

$epic14Files = @(
  ".github/workflows/bil_ios_signed_release.yml",
  ".github/workflows/bil_ios_unsigned_release.yml",
  "android/app/build.gradle.kts",
  "android/app/proguard-rules.pro",
  "android/app/src/main/AndroidManifest.xml",
  "android/key.properties.example",
  "artifacts/release/epic14/commit_epic14.ps1",
  "artifacts/release/epic14/prepare_android_upload_key.ps1",
  "artifacts/release/epic14/run_epic14_gate.ps1",
  "docs/release/BIL_EPIC14_OFFICIAL_REQUIREMENTS.md",
  "docs/release/BIL_EPIC14_OWNER_INPUTS.json",
  "docs/release/BIL_EPIC14_RELEASE_COVERAGE.md",
  "ios/Runner/Runner.entitlements",
  "ios/Runner/RunnerDebug.entitlements",
  "ios/Runner.xcodeproj/project.pbxproj",
  "pubspec.yaml",
  "test/launch_readiness/epic14_release_execution_test.dart",
  "tool/epic14_release_audit.dart"
)

foreach ($file in $epic14Files) {
  if (-not (Test-Path -LiteralPath (Join-Path $project $file))) {
    throw "Required Epic 14 file is missing: $file"
  }
}

& git add -- $epic14Files
if ($LASTEXITCODE -ne 0) { throw "Staging Epic 14 files failed." }

& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
  throw "No Epic 14 changes are staged."
}

$stagedFiles = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect staged Epic 14 files." }
$unexpected = @($stagedFiles | Where-Object { $epic14Files -notcontains $_.Replace('\\', '/') })
if ($unexpected.Count -gt 0) {
  throw "Unexpected staged files detected: $($unexpected -join ', ')"
}

& git commit -m "build(epic14): close signed release artifacts"
if ($LASTEXITCODE -ne 0) { throw "Epic 14 commit failed." }

$head = (& git rev-parse HEAD).Trim()
$remaining = @(& git status --short)
$lines = @(
  "EPIC14_COMMIT=PASS",
  "BRANCH=$branch",
  "HEAD=$head",
  "COMMITTED_FILES=$($stagedFiles.Count)",
  "GATE=PASS",
  "ANDROID_AAB=SIGNED_16KB_PASS",
  "IOS_RELEASE_GATE=EXTERNAL_MACOS_AND_CREDENTIALS_NOT_CLAIMED",
  "REMAINING_WORKTREE_STATUS_BEGIN",
  $remaining,
  "REMAINING_WORKTREE_STATUS_END"
)
$lines | Set-Content -LiteralPath $commitSummaryPath -Encoding utf8
$lines | ForEach-Object { Write-Output $_ }
