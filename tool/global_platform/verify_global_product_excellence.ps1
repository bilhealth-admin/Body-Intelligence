param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$ReportRoot = ""
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  $ReportRoot = Join-Path $ProjectRoot "artifacts\global_product_verification"
}
New-Item -ItemType Directory -Path $ReportRoot -Force | Out-Null
$ReportPath = Join-Path $ReportRoot "BIL-GLOBAL-001-R1-report.txt"
$lines = [System.Collections.Generic.List[string]]::new()

function Add-Result([string]$Name, [string]$Status, [string]$Detail = "") {
  $line = if ($Detail) { "$Name`t$Status`t$Detail" } else { "$Name`t$Status" }
  $lines.Add($line)
  Write-Host $line
}

function Invoke-Gate([string]$Name, [scriptblock]$Command) {
  Write-Host "`n=== $Name ===" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    Add-Result $Name "FAILED" "exit=$LASTEXITCODE"
    $lines | Set-Content -LiteralPath $ReportPath -Encoding utf8
    throw "$Name failed"
  }
  Add-Result $Name "PASSED"
}

$branch = (git branch --show-current).Trim()
$head = (git rev-parse HEAD).Trim()
Add-Result "Branch" "INFO" $branch
Add-Result "HEAD" "INFO" $head

$requiredFiles = @(
  "lib/features/global_platform/runtime/global_product_composition_root.dart",
  "lib/features/global_platform/runtime/bil_global_product_expansion_runtime.dart",
  "test/features/global_platform/global_product_wiring_system_test.dart",
  "test/features/global_platform/global_closure_audit_test.dart",
  "test/features/global_platform/ble_session_state_machine_test.dart",
  "test/features/global_platform/reports_runtime_test.dart",
  "test/features/global_platform/commerce_runtime_test.dart",
  "test/features/global_platform/wearable_production_catalog_regression_test.dart"
)
foreach ($relative in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative) -PathType Leaf)) {
    Add-Result "Required file" "FAILED" $relative
    $lines | Set-Content -LiteralPath $ReportPath -Encoding utf8
    throw "Missing required file: $relative"
  }
}
Add-Result "Required files" "PASSED" "$($requiredFiles.Count) files"

Invoke-Gate "Dart format" {
  dart format --output=none --set-exit-if-changed `
    "lib/features/global_platform" `
    "test/features/global_platform"
}

Invoke-Gate "Flutter analyze" { flutter analyze --no-pub }
Invoke-Gate "Global platform tests" { flutter test --no-pub "test/features/global_platform" }

$focused = @(
  "test/features/global_platform/global_product_wiring_system_test.dart",
  "test/features/global_platform/global_closure_audit_test.dart",
  "test/features/global_platform/global_runtime_readiness_barrier_test.dart",
  "test/features/global_platform/ble_session_state_machine_test.dart",
  "test/features/global_platform/native_ble_bridge_contract_test.dart",
  "test/features/global_platform/reports_runtime_test.dart",
  "test/features/global_platform/world_class_reports_system_test.dart",
  "test/features/global_platform/commerce_runtime_test.dart",
  "test/features/global_platform/wearable_production_catalog_regression_test.dart",
  "test/features/global_platform/plugin_runtime_test.dart",
  "test/features/global_platform/globalization_runtime_test.dart"
)
Invoke-Gate "Focused closure tests" { flutter test --no-pub @focused }
Invoke-Gate "Android debug build" { flutter build apk --debug --no-pub }
Invoke-Gate "Diff hygiene" { git diff --check }

Add-Result "External certification" "DEFERRED" "iOS/macOS, Apple Health, Health Connect devices, BLE devices, provider credentials"
$lines | Set-Content -LiteralPath $ReportPath -Encoding utf8
Write-Host "`nBIL-GLOBAL-001-R1 VERIFICATION: PASSED" -ForegroundColor Green
Write-Host "Report: $ReportPath"
