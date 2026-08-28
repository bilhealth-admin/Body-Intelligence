[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$beforeC = (Get-Volume C).SizeRemaining
$removed = @()
$preserved = @()

$exactFiles = @(
  'C:\ProgramData\tmp\360TS_Setup.exe',
  'C:\ProgramData\tmp\recommend_installer.exe'
)
foreach ($path in $exactFiles) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    continue
  }
  $item = Get-Item -LiteralPath $path -Force
  try {
    Remove-Item -LiteralPath $path -Force
    $removed += [pscustomobject]@{ Path = $path; Bytes = $item.Length; Reason = 'stale installer' }
  }
  catch {
    $preserved += [pscustomobject]@{ Path = $path; Reason = $_.Exception.Message }
  }
}

$projectCache = 'C:\Users\HP 1040 G8\AppData\Local\flutter_webview_windows\body_intelligence_log'
if (Test-Path -LiteralPath $projectCache -PathType Container) {
  $resolvedCache = (Resolve-Path -LiteralPath $projectCache).Path
  if ($resolvedCache -ne $projectCache) {
    throw "Refusing deletion of unexpected project cache: $resolvedCache"
  }
  $cacheFiles = @(Get-ChildItem -LiteralPath $projectCache -File -Force -Recurse -ErrorAction SilentlyContinue)
  $cacheBytes = ($cacheFiles | Measure-Object Length -Sum).Sum
  try {
    Remove-Item -LiteralPath $projectCache -Recurse -Force
    $removed += [pscustomobject]@{ Path = $projectCache; Bytes = $cacheBytes; Reason = 'rebuildable BIL webview cache' }
  }
  catch {
    $preserved += [pscustomobject]@{ Path = $projectCache; Reason = $_.Exception.Message }
  }
}

$tempRoot = 'C:\Users\HP 1040 G8\AppData\Local\Temp'
$cutoff = (Get-Date).AddHours(-24)
if (Test-Path -LiteralPath $tempRoot -PathType Container) {
  foreach ($item in @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)) {
    if ($item.LastWriteTime -gt $cutoff) {
      $preserved += [pscustomobject]@{ Path = $item.FullName; Reason = 'newer than 24 hours' }
      continue
    }
    $resolvedParent = [IO.Path]::GetFullPath($item.DirectoryName)
    if (-not $resolvedParent.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Unsafe temp target: $($item.FullName)"
    }
    $bytes = if ($item.PSIsContainer) {
      (Get-ChildItem -LiteralPath $item.FullName -File -Force -Recurse -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum
    } else {
      $item.Length
    }
    try {
      Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
      $removed += [pscustomobject]@{ Path = $item.FullName; Bytes = $bytes; Reason = 'stale user temp' }
    }
    catch {
      $preserved += [pscustomobject]@{ Path = $item.FullName; Reason = 'locked or protected' }
    }
  }
}

$afterC = (Get-Volume C).SizeRemaining
[pscustomobject]@{
  CFreeBeforeGiB = [math]::Round($beforeC / 1GB, 3)
  CFreeAfterGiB = [math]::Round($afterC / 1GB, 3)
  FreedMiB = [math]::Round(($afterC - $beforeC) / 1MB, 1)
  RemovedItems = $removed.Count
  PreservedItems = $preserved.Count
}
$removed | Sort-Object Bytes -Descending | Select-Object -First 12
