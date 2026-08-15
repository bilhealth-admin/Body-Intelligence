$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$generatedNativeAssets = Join-Path $project 'build\native_assets\windows'
$captureScript = Join-Path $PSScriptRoot 'capture_visual_evidence.ps1'

# Stop only stale Dart/Flutter test hosts whose command line belongs to this
# project. VS Code, the terminal, unrelated Flutter projects, and user apps are
# deliberately outside this filter.
$testHostNames = @('dart.exe', 'dartaotruntime.exe', 'flutter_tester.exe')
$projectPattern = [regex]::Escape($project)
$staleHosts = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -in $testHostNames -and
  $_.CommandLine -and
  $_.CommandLine -match $projectPattern -and
  (
    $_.Name -eq 'flutter_tester.exe' -or
    $_.CommandLine -match '(flutter_tools\.snapshot\s+test|test\.dart\.dill|flutter_test)'
  )
}

foreach ($hostProcess in $staleHosts) {
  Write-Host "Stopping stale project test host PID=$($hostProcess.ProcessId) NAME=$($hostProcess.Name)"
  Stop-Process -Id $hostProcess.ProcessId -Force -ErrorAction Stop
}

if ($staleHosts) {
  Start-Sleep -Seconds 2
}

# This is generated build output only. Validate the resolved parent before
# removing it so the cleanup can never escape this project's build directory.
if (Test-Path -LiteralPath $generatedNativeAssets) {
  $resolvedAssets = (Resolve-Path -LiteralPath $generatedNativeAssets).Path
  $expectedPrefix = [System.IO.Path]::GetFullPath(
    (Join-Path $project 'build\native_assets')
  )
  if (-not $resolvedAssets.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove unexpected path: $resolvedAssets"
  }
  Remove-Item -LiteralPath $resolvedAssets -Recurse -Force
}

& $captureScript
exit $LASTEXITCODE
