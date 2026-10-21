param(
    [switch]$PlanOnly,
    [string]$Label = ('bil-release-' + (Get-Date -Format 'yyyyMMdd-HHmmss')),
    [int]$Port = 8775
)
$ErrorActionPreference = 'Stop'
$bilRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$bilPython = 'C:\Users\HP 1040 G8\AppData\Local\Programs\Python\Python314\python.exe'
$bilFlutter = 'G:\BIL_Toolchains\Flutter\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $bilPython -PathType Leaf)) { throw 'Configured Python is unavailable' }
if (-not (Test-Path -LiteralPath $bilFlutter -PathType Leaf)) { throw 'Pinned Flutter toolchain is unavailable' }
Push-Location -LiteralPath $bilRoot
try {
    $bilHead = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot establish the source HEAD' }
    $bilArguments = @(
        'tools/qa/bil_release_revalidation.py', '--label', $Label,
        '--expect-head', $bilHead, '--flutter', $bilFlutter,
        '--ci-manifest', 'tools/qa/revalidation_ci_plan.json', '--port', $Port
    )
    if (-not $PlanOnly) { $bilArguments += @('--run', '--publish', '--launch-background') }
    & $bilPython @bilArguments
    if ($LASTEXITCODE -ne 0) { throw "Revalidation launcher exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
