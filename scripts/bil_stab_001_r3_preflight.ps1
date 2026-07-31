$ErrorActionPreference = "Stop"
Write-Host "BIL-STAB-001-R3 preflight" -ForegroundColor Cyan
if ((git branch --show-current).Trim() -ne "phase-3-product-excellence") { throw "Unexpected branch." }
if ((git rev-parse --short HEAD).Trim() -ne "3ea0b64") { throw "Expected HEAD 3ea0b64." }
if (-not (Test-Path "test\startup_state_test.dart")) { throw "startup_state_test.dart is missing." }
Write-Host "Preflight passed." -ForegroundColor Green
