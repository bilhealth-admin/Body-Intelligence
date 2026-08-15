$ErrorActionPreference = 'Stop'

$source = 'C:\develop\projects\body_intelligence_log'
$rollback = 'C:\develop\projects\body_intelligence_log.rollback_20260812'
$target = 'G:\BIL_Project\body_intelligence_log'
$backup = 'G:\BIL_Project_Backups\body_intelligence_log_2026-08-12'
$log = 'G:\BIL_Migration_Logs\finalize_c_to_g.log'

function Write-Log([string]$message) {
  "$(Get-Date -Format o) $message" | Add-Content -LiteralPath $log -Encoding UTF8
}

Write-Log 'START'
if (-not (Test-Path -LiteralPath $target)) { throw 'Runtime target missing.' }
if (-not (Test-Path -LiteralPath $backup)) { throw 'Backup target missing.' }
if ((git -C $target rev-parse --is-inside-work-tree 2>$null) -ne 'true') {
  throw 'Runtime target is not a Git worktree.'
}
if ((git -C $backup rev-parse --is-inside-work-tree 2>$null) -ne 'true') {
  throw 'Backup target is not a Git worktree.'
}

for ($attempt = 1; $attempt -le 180; $attempt++) {
  try {
    if (-not (Test-Path -LiteralPath $source)) { throw 'Source path disappeared.' }
    if (Test-Path -LiteralPath $rollback) { throw 'Rollback path already exists.' }
    Move-Item -LiteralPath $source -Destination $rollback -ErrorAction Stop
    Write-Log "RENAMED attempt=$attempt"
    break
  } catch {
    if ($attempt -eq 180) { throw }
    Start-Sleep -Seconds 2
  }
}

$linkOutput = cmd.exe /c "mklink /J C:\develop\projects\body_intelligence_log G:\BIL_Project\body_intelligence_log"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $source)) {
  if (-not (Test-Path -LiteralPath $source) -and (Test-Path -LiteralPath $rollback)) {
    Move-Item -LiteralPath $rollback -Destination $source -ErrorAction Stop
  }
  throw "Junction creation failed: $linkOutput"
}

$item = Get-Item -LiteralPath $source
if ($item.LinkType -ne 'Junction') { throw 'C path is not a junction.' }
if ((git -C $source rev-parse --is-inside-work-tree 2>$null) -ne 'true') {
  throw 'Git validation through junction failed.'
}
$sourceLedger = Get-FileHash -LiteralPath "$source\artifacts\meal_catalog\meal_image_prompt_ledger_1400.csv" -Algorithm SHA256
$targetLedger = Get-FileHash -LiteralPath "$target\artifacts\meal_catalog\meal_image_prompt_ledger_1400.csv" -Algorithm SHA256
if ($sourceLedger.Hash -ne $targetLedger.Hash) { throw 'Ledger validation failed.' }

Write-Log 'JUNCTION_VALIDATED'
Remove-Item -LiteralPath $rollback -Recurse -Force
Write-Log "COMPLETE C_FREE=$((Get-PSDrive C).Free)"
