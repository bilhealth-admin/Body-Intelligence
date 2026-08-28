[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$destinationRoot = 'G:\BIL_Toolchains\Codex'
$targets = @(
  [pscustomobject]@{ Source = 'C:\Users\HP 1040 G8\.codex\generated_images'; Name = 'generated_images' },
  [pscustomobject]@{ Source = 'C:\Users\HP 1040 G8\.codex\.sandbox-bin'; Name = 'sandbox-bin' },
  [pscustomobject]@{ Source = 'C:\Users\HP 1040 G8\.codex\plugins'; Name = 'plugins' }
)

New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
$resolvedRoot = (Resolve-Path -LiteralPath $destinationRoot).Path
if (-not $resolvedRoot.StartsWith('G:\BIL_Toolchains\Codex', [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe destination root: $resolvedRoot"
}

$results = @()
foreach ($target in $targets) {
  $source = $target.Source
  $destination = Join-Path $destinationRoot $target.Name
  $staging = "$destination.staging"
  $oldSource = "$source.relocation-old"

  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    $results += [pscustomobject]@{ Source = $source; Status = 'SKIP_MISSING'; Files = 0; Bytes = 0 }
    continue
  }

  $sourceItem = Get-Item -LiteralPath $source -Force
  if ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    $results += [pscustomobject]@{ Source = $source; Status = 'ALREADY_RELOCATED'; Files = 0; Bytes = 0 }
    continue
  }
  if ((Test-Path -LiteralPath $destination) -or
      (Test-Path -LiteralPath $staging) -or
      (Test-Path -LiteralPath $oldSource)) {
    throw "Refusing ambiguous relocation for $source"
  }

  $activeProcesses = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith("$source\", [StringComparison]::OrdinalIgnoreCase)
  })
  if ($activeProcesses.Count -gt 0) {
    $results += [pscustomobject]@{ Source = $source; Status = 'SKIP_ACTIVE_PROCESS'; Files = 0; Bytes = 0 }
    continue
  }

  $sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Force -Recurse)
  $sourceBytes = ($sourceFiles | Measure-Object Length -Sum).Sum
  Copy-Item -LiteralPath $source -Destination $staging -Recurse -Force

  $destinationFiles = @(Get-ChildItem -LiteralPath $staging -File -Force -Recurse)
  $destinationBytes = ($destinationFiles | Measure-Object Length -Sum).Sum
  if ($sourceFiles.Count -ne $destinationFiles.Count -or $sourceBytes -ne $destinationBytes) {
    throw "Copy verification failed for $source"
  }

  $sourceLengths = @{}
  foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\')
    $sourceLengths[$relative] = $file.Length
  }
  foreach ($file in $destinationFiles) {
    $relative = $file.FullName.Substring($staging.Length).TrimStart('\')
    if (-not $sourceLengths.ContainsKey($relative) -or $sourceLengths[$relative] -ne $file.Length) {
      throw "Relative-file verification failed for $source at $relative"
    }
  }

  foreach ($file in ($sourceFiles | Sort-Object Length -Descending | Select-Object -First 8)) {
    $relative = $file.FullName.Substring($source.Length).TrimStart('\')
    $copyPath = Join-Path $staging $relative
    if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $copyPath -Algorithm SHA256).Hash) {
      throw "SHA256 mismatch for $source at $relative"
    }
  }

  Move-Item -LiteralPath $source -Destination $oldSource
  Move-Item -LiteralPath $staging -Destination $destination
  try {
    New-Item -ItemType Junction -Path $source -Target $destination | Out-Null
  }
  catch {
    if (-not (Test-Path -LiteralPath $source) -and (Test-Path -LiteralPath $oldSource)) {
      Move-Item -LiteralPath $oldSource -Destination $source
    }
    throw
  }

  $junction = Get-Item -LiteralPath $source -Force
  if (-not ($junction.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Junction verification failed for $source"
  }

  $resolvedOld = (Resolve-Path -LiteralPath $oldSource).Path
  $expectedOld = [IO.Path]::GetFullPath($oldSource)
  if ($resolvedOld -ne $expectedOld) {
    throw "Refusing deletion of unexpected old source: $resolvedOld"
  }
  Remove-Item -LiteralPath $oldSource -Recurse -Force

  $results += [pscustomobject]@{
    Source = $source
    Status = 'RELOCATED'
    Files = $destinationFiles.Count
    Bytes = $destinationBytes
  }
}

$results
[pscustomobject]@{
  Source = 'C:'
  Status = 'FREE_SPACE'
  Files = 0
  Bytes = (Get-Volume C).SizeRemaining
}
