[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
throw 'EPIC2_COMMIT=HISTORICAL_NON_AUTHORITATIVE. An ignored historical summary cannot authorize staging or committing current source. Use docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md and .github/workflows/bil_android_release_candidate.yml. No Git state was changed.'

$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$summaryFile = Join-Path $PSScriptRoot 'epic2_summary.txt'
$commitSummary = Join-Path $PSScriptRoot 'epic2_commit_summary.txt'

$paths = @(
  'TODO.md'
  'BIL_V1_RC_EXECUTION_LOG.md'
  'lib/app/router/responsive_app_shell.dart'
  'lib/features/analytics/analytics_page.dart'
  'lib/features/analytics/widgets/analytics_page_primitives.dart'
  'lib/features/dashboard/widgets/dashboard_daily_summary.dart'
  'lib/features/dashboard/widgets/dashboard_guide_orb.dart'
  'lib/features/dashboard/widgets/dashboard_header.dart'
  'lib/features/dashboard/widgets/dashboard_metric_grid.dart'
  'lib/features/dashboard/widgets/dashboard_signal_orb.dart'
  'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart'
  'lib/features/dashboard/widgets/premium_dashboard_command_center.dart'
  'lib/features/dashboard/widgets/premium_dashboard_evidence.dart'
  'lib/features/history/history_page.dart'
  'lib/features/history/widgets/history_page_components.dart'
  'lib/features/nutrition/food_page.dart'
  'lib/features/nutrition/presentation/custom_food_dialog.dart'
  'lib/features/nutrition/presentation/food_catalog_overview.dart'
  'lib/features/nutrition/presentation/food_catalog_tile.dart'
  'lib/features/wellness/presentation/fasting_timer_page.dart'
  'lib/features/wellness/presentation/sleep_tracker_page.dart'
  'lib/features/wellness/presentation/wellness_tool_components.dart'
  'lib/features/wellness/presentation/wellness_tools_pages.dart'
  'lib/features/wellness/presentation/workout_library_page.dart'
  'test/architecture_source_file_size_guard_test.dart'
  'test/dashboard_analytics_reuse_test.dart'
  'test/dashboard_epic3/epic_e3_source_contract_test.dart'
  'test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart'
  'test/features/dashboard/presentation/dashboard_decision_explanation_route_test.dart'
  'test/features/nutrition/usda_search_quality_r2_contract_test.dart'
  'test/home_intelligence/home_body_twin_color_injection_r25_contract_test.dart'
  'test/home_intelligence/home_static_body_twin_primary_pages_r26_contract_test.dart'
  'test/premium_ui/premium_surface_hierarchy_test.dart'
  'test/product_owner_review_closure_contract_test.dart'
  'test/product_owner_visual_review_r6_contract_test.dart'
  'test/support/dart_library_source.dart'
  'artifacts/release/epic2/run_epic2_targeted_architecture_gate.ps1'
  'artifacts/release/epic2/run_epic2_failure_recheck.ps1'
  'artifacts/release/epic2/run_epic2_decision_contract_recheck.ps1'
  'artifacts/release/epic2/run_epic2_gate.ps1'
  'artifacts/release/epic2/close_epic2.ps1'
  'artifacts/release/epic2/epic2_targeted_architecture_summary.txt'
  'artifacts/release/epic2/epic2_failure_recheck_summary.txt'
  'artifacts/release/epic2/epic2_decision_contract_summary.txt'
  'artifacts/release/epic2/epic2_summary.txt'
)

Push-Location $project
try {
  if (-not (Test-Path -LiteralPath $summaryFile)) {
    throw "Epic 2 gate summary is missing: $summaryFile"
  }
  $gateSummary = Get-Content -LiteralPath $summaryFile -Raw
  if ($gateSummary -notmatch '(?m)^EPIC2_GATE=PASS\s*$') {
    throw 'Epic 2 cannot be committed because its full gate is not PASS.'
  }

  $branch = (& git branch --show-current).Trim()
  if ($LASTEXITCODE -ne 0 -or $branch -ne 'release/bil-v1-final-closure') {
    throw "Unexpected branch: $branch"
  }

  & git add -- $paths
  if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }

  & git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) { throw 'No Epic 2 changes were staged.' }
  if ($LASTEXITCODE -ne 1) { throw 'Unable to inspect the staged Epic 2 diff.' }

  $stagedFiles = @(& git diff --cached --name-only)
  if ($LASTEXITCODE -ne 0) { throw 'Unable to list staged Epic 2 files.' }

  & git commit -m 'refactor: close Epic 2 architecture boundaries'
  if ($LASTEXITCODE -ne 0) { throw 'Epic 2 commit failed.' }

  $head = (& git rev-parse HEAD).Trim()
  $remaining = @(& git status --short)
  $result = @(
    'EPIC2_COMMIT=PASS'
    "BRANCH=$branch"
    "HEAD=$head"
    "COMMITTED_FILES=$($stagedFiles.Count)"
    'REMAINING_WORKTREE_STATUS_BEGIN'
    $remaining
    'REMAINING_WORKTREE_STATUS_END'
  )
  $result | Set-Content -LiteralPath $commitSummary -Encoding utf8
  $result | ForEach-Object { Write-Host $_ }
}
finally {
  Pop-Location
}
