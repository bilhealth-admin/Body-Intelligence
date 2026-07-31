param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$ReportRoot = Join-Path $ProjectRoot "artifacts\engineering_audit"
$Report = Join-Path $ReportRoot "BIL-ENGINEERING-AUDIT-001-report.txt"
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null

function Record([string]$Name, [string]$State, [string]$Details = "") {
  $line = "{0}`t{1}`t{2}" -f $Name, $State, $Details
  Write-Host $line
  Add-Content -LiteralPath $Report -Value $line
}

function Run-Gate([string]$Name, [scriptblock]$Action) {
  Write-Host "`n=== $Name ===" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) {
    Record $Name "FAILED" "exit=$LASTEXITCODE"
    throw "$Name failed"
  }
  Record $Name "PASSED"
}

"BIL-ENGINEERING-AUDIT-001" | Set-Content -LiteralPath $Report
Record "Branch" "INFO" ((git branch --show-current).Trim())
Record "HEAD" "INFO" ((git rev-parse HEAD).Trim())

$Required = @(
  "lib/main.dart",
  "lib/data/database/database_provider.dart",
  "lib/features/ai_platform/services/local_intelligence_composition_root.dart",
  "lib/features/cloud_platform/services/cloud_platform_composition_root.dart",
  "lib/features/global_platform/runtime/global_product_composition_root.dart",
  "test/repository_test.dart",
  "test/features/global_platform/global_product_bootstrap_test.dart",
  "test/features/global_platform/global_product_wiring_system_test.dart"
)
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) {
  Record "Required files" "FAILED" ($Missing -join ", ")
  throw "Required architecture files are missing"
}
Record "Required files" "PASSED" "$($Required.Count) files"

Run-Gate "Scoped Dart format" {
  dart format --output=none --set-exit-if-changed `
    lib/main.dart `
    lib/data/database/database_provider.dart `
    lib/features/ai_platform/services/local_intelligence_composition_root.dart `
    lib/features/cloud_platform/services/cloud_platform_composition_root.dart `
    lib/features/global_platform/runtime/global_product_composition_root.dart `
    test/repository_test.dart `
    test/features/global_platform/global_product_bootstrap_test.dart `
    test/features/global_platform/global_product_wiring_system_test.dart
}

Run-Gate "Flutter analyze" { flutter analyze --no-pub }
Run-Gate "Core repository test" { flutter test --no-pub test/repository_test.dart }
Run-Gate "Local intelligence composition tests" {
  flutter test --no-pub `
    test/features/ai_platform/local_intelligence_runtime_system_test.dart `
    test/features/ai_platform/local_intelligence_canonical_runtime_regression_test.dart
}
Run-Gate "Cloud composition tests" {
  flutter test --no-pub `
    test/features/cloud_platform/cloud_platform_closure_regression_test.dart `
    test/features/cloud_platform/durable_cloud_runtime_test.dart
}
Run-Gate "Global composition tests" {
  flutter test --no-pub `
    test/features/global_platform/global_product_bootstrap_test.dart `
    test/features/global_platform/global_product_wiring_system_test.dart
}
Run-Gate "Android debug build" { flutter build apk --debug --no-pub }
Run-Gate "Diff hygiene" { git diff --check }

Record "BIL-ENGINEERING-AUDIT-001" "PASSED" "Core architecture and composition roots verified"
