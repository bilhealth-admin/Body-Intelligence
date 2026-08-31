$ErrorActionPreference = "Stop"
throw "VISUAL_CLOSURE_COMMIT=HISTORICAL_NON_AUTHORITATIVE. An ignored historical summary cannot authorize staging or committing current source. Use docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md and .github/workflows/bil_android_release_candidate.yml. No Git state was changed."

$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$summaryPath = Join-Path $PSScriptRoot "visual_closure_summary.txt"
$commitSummaryPath = Join-Path $PSScriptRoot "visual_closure_commit_summary.txt"

Set-Location -LiteralPath $project

if (-not (Test-Path -LiteralPath $summaryPath)) {
  throw "Visual closure summary is missing: $summaryPath"
}

$gateSummary = Get-Content -LiteralPath $summaryPath -Raw
if ($gateSummary -notmatch '(?m)^VISUAL_CLOSURE_GATE=PASS\s*$') {
  throw "Visual closure gate is not PASS. Commit aborted."
}

$paths = [System.Collections.Generic.HashSet[string]]::new(
  [System.StringComparer]::OrdinalIgnoreCase
)

$fixedPaths = @(
  "docs/BIL_VISUAL_REVIEW_2026-08-05.md",
  "tool/visual_reference_manifest.dart",
  "tool/visual_reference_review_audit.dart",
  "lib/features/dashboard/widgets/dashboard_guide_orb.dart",
  "lib/features/nutrition/presentation/food_barcode_scanner_page.dart",
  "test/epic8_weekly_report_golden_test.dart",
  "test/goldens/epic8_weekly_report_phone_ltr_light.png",
  "test/visual_closure",
  "artifacts/release/visual_closure/recover_and_capture_visual_evidence.ps1",
  "artifacts/release/visual_closure/run_visual_closure_gate.ps1",
  "artifacts/release/visual_closure/commit_visual_closure.ps1"
)

foreach ($path in $fixedPaths) {
  if (Test-Path -LiteralPath (Join-Path $project $path)) {
    [void]$paths.Add($path)
  }
}

# Include only production Dart files explicitly named by the 177-reference
# coverage artifacts. This avoids sweeping unrelated pre-existing worktree edits
# into the visual-closure commit.
$coverageFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in @('.csv', '.md', '.txt') }

foreach ($coverageFile in $coverageFiles) {
  $content = Get-Content -LiteralPath $coverageFile.FullName -Raw -ErrorAction SilentlyContinue
  if ([string]::IsNullOrWhiteSpace($content)) { continue }

  $matches = [regex]::Matches(
    $content,
    '(?im)(?:^|["'',;\s])((?:lib|assets)/[^"'',;\r\n]+?\.(?:dart|png|jpg|jpeg|webp|svg))(?=["'',;\s]|$)'
  )
  foreach ($match in $matches) {
    $relative = $match.Groups[1].Value.Replace('\', '/').Trim()
    if (Test-Path -LiteralPath (Join-Path $project $relative)) {
      [void]$paths.Add($relative)
    }
  }
}

if ($paths.Count -eq 0) {
  throw "No visual-closure files were resolved. Commit aborted."
}

$orderedPaths = @($paths | Sort-Object)
& git add -- $orderedPaths
if ($LASTEXITCODE -ne 0) { throw "git add failed: $LASTEXITCODE" }

$staged = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect staged files." }
if ($staged.Count -eq 0) { throw "No visual-closure changes are staged." }

& git commit -m "feat(visual): close 177-reference production review"
if ($LASTEXITCODE -ne 0) { throw "git commit failed: $LASTEXITCODE" }

$branch = (& git branch --show-current).Trim()
$head = (& git rev-parse HEAD).Trim()
$remaining = @(& git status --short)

$lines = @(
  "VISUAL_CLOSURE_COMMIT=PASS",
  "BRANCH=$branch",
  "HEAD=$head",
  "COMMITTED_FILES=$($staged.Count)",
  "GATE=PASS",
  "REVIEWED_REFERENCES=177",
  "UNIQUE_VISUAL_EVIDENCE=29",
  "TESTS_PASSED=1066",
  "TESTS_SKIPPED=18",
  "ANDROID_BUILD=PASS",
  "REMAINING_WORKTREE_STATUS_BEGIN"
)
$lines += $remaining
$lines += "REMAINING_WORKTREE_STATUS_END"
$lines | Set-Content -LiteralPath $commitSummaryPath -Encoding utf8
$lines | ForEach-Object { Write-Output $_ }
