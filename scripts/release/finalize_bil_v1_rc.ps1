param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('PASS')]
  [string]$VisualOwnerApproval
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $project

if ($VisualOwnerApproval -ne 'PASS') { throw 'VISUAL_OWNER_APPROVAL=PASS is required.' }
if ((& git branch --show-current).Trim() -ne 'release/bil-v1-final-closure') {
  throw 'The RC tag may only be created from release/bil-v1-final-closure.'
}
if (@(& git status --porcelain).Count -ne 0) { throw 'The worktree must be clean.' }
$summary = Join-Path $project 'artifacts\release\epic16\epic16_summary.txt'
if (-not (Test-Path -LiteralPath $summary) -or
    -not (Select-String -LiteralPath $summary -SimpleMatch 'EPIC16_GATE=PASS' -Quiet)) {
  throw 'A passing Epic 16 gate is required.'
}
$subject = (& git log -1 --pretty=%s).Trim()
if ($subject -ne 'chore(release): close BIL v1 engineering candidate') {
  throw "Unexpected final commit subject: $subject"
}
if (& git tag --list 'bil-v1.0.0-rc1') { throw 'bil-v1.0.0-rc1 already exists.' }
& git tag -a 'bil-v1.0.0-rc1' -m 'BIL v1.0.0 release candidate 1'
if ($LASTEXITCODE -ne 0) { throw 'RC tag creation failed.' }
"VISUAL_OWNER_APPROVAL=$VisualOwnerApproval"
"RC_TAG=bil-v1.0.0-rc1"
"RC_HEAD=$((& git rev-parse HEAD).Trim())"

