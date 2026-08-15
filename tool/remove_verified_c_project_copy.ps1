$ErrorActionPreference = 'Stop'
$root = 'C:\develop\projects\body_intelligence_log'
$expectedRuntime = 'G:\BIL_Project\body_intelligence_log'
$expectedBackup = 'G:\BIL_Project_Backups\body_intelligence_log_2026-08-12'
$expectedHashResult = 'HASHED=13015 MISSING=0 MISMATCH=0 BYTES=6790719599'

if ((Resolve-Path -LiteralPath $root).Path -ne $root) { throw 'Unexpected C target.' }
if (-not (Test-Path -LiteralPath $expectedRuntime)) { throw 'G runtime missing.' }
if (-not (Test-Path -LiteralPath $expectedBackup)) { throw 'G backup missing.' }
if ((Get-Content 'G:\BIL_Migration_Logs\sha256_result.txt' -Raw).Trim() -ne $expectedHashResult) {
  throw 'Full SHA verification evidence does not match.'
}
if ((git -C $expectedRuntime rev-parse --is-inside-work-tree 2>$null) -ne 'true') { throw 'Runtime Git check failed.' }
if ((git -C $expectedBackup rev-parse --is-inside-work-tree 2>$null) -ne 'true') { throw 'Backup Git check failed.' }

$items = @(Get-ChildItem -LiteralPath $root -Force)
$failed = @()
foreach ($item in $items) {
  try {
    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
  } catch {
    $failed += "$($item.FullName): $($_.Exception.Message)"
  }
}
$remaining = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue)
"REMOVED=$($items.Count - $failed.Count) FAILED=$($failed.Count) REMAINING=$($remaining.Count)"
$failed
"C_FREE_GB=$([math]::Round((Get-PSDrive C).Free / 1GB, 2))"
"G_FREE_GB=$([math]::Round((Get-PSDrive G).Free / 1GB, 2))"
