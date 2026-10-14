$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'BIL - Visible full analyze and format - e27a5898'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Set-Location -LiteralPath 'G:\BIL_Project\worktrees\bil-stage1-closure-20261011'
$env:PYTHONIOENCODING = 'utf-8'
$env:NO_COLOR = '1'
python -X utf8 'build/stage1-closure/visible-validation-20261013/visible_validation.py' 'build/stage1-closure/visible-validation-20261013/final-check-plan-03.json'
$bilValidationExit = $LASTEXITCODE
Write-Host "Visible focused validation exited: $bilValidationExit"
