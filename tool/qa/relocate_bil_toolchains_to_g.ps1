[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-TreeBytes {
  param([Parameter(Mandatory)][string]$LiteralPath)

  if (-not (Test-Path -LiteralPath $LiteralPath)) { return [int64]0 }
  $measurement = Get-ChildItem -LiteralPath $LiteralPath -File -Force -Recurse -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum
  if ($null -eq $measurement.Sum) { return [int64]0 }
  return [int64]$measurement.Sum
}

$activeNames = @('adb', 'emulator', 'qemu-system-x86_64', 'dart', 'java')
$active = @(Get-Process -Name $activeNames -ErrorAction SilentlyContinue)
if ($active.Count -gt 0) {
  throw "Refusing to relocate live Android/Flutter toolchains. Active processes: $($active.ProcessName -join ', ')"
}

$destinationRoot = 'G:\BIL_Toolchains'
if (-not (Test-Path -LiteralPath $destinationRoot)) {
  New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
}
$resolvedDestinationRoot = (Resolve-Path -LiteralPath $destinationRoot).Path.TrimEnd('\')
if ($resolvedDestinationRoot -ne $destinationRoot) {
  throw "Safety check failed. Unexpected destination root: $resolvedDestinationRoot"
}

$moves = @(
  [pscustomobject]@{
    Name = 'Android SDK'
    Source = 'C:\Android\SDK'
    Destination = 'G:\BIL_Toolchains\Android\SDK'
  },
  [pscustomobject]@{
    Name = 'Android virtual devices'
    Source = 'C:\Users\HP 1040 G8\.android\avd'
    Destination = 'G:\BIL_Toolchains\Android\avd'
  },
  [pscustomobject]@{
    Name = 'Flutter SDK'
    Source = 'C:\develop\flutter'
    Destination = 'G:\BIL_Toolchains\Flutter\flutter'
  },
  [pscustomobject]@{
    Name = 'JDK 21'
    Source = 'C:\develop\jdk-21'
    Destination = 'G:\BIL_Toolchains\Java\jdk-21'
  }
)

$results = @()
foreach ($move in $moves) {
  if (-not (Test-Path -LiteralPath $move.Source)) {
    throw "Required source is missing: $($move.Source)"
  }
  $sourceItem = Get-Item -LiteralPath $move.Source -Force
  if ($sourceItem.LinkType -eq 'Junction') {
    $results += [pscustomobject]@{
      Name = $move.Name
      Source = $move.Source
      Destination = $sourceItem.Target
      GB = [math]::Round((Get-TreeBytes -LiteralPath $move.Source) / 1GB, 2)
      Status = 'Already relocated'
    }
    continue
  }
  $source = (Resolve-Path -LiteralPath $move.Source).Path.TrimEnd('\')
  if ($source -ne $move.Source -or -not $source.StartsWith('C:\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Safety check failed. Unexpected source: $source"
  }
  if (-not $move.Destination.StartsWith("$destinationRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Safety check failed. Unexpected destination: $($move.Destination)"
  }
  if (Test-Path -LiteralPath $move.Destination) {
    throw "Destination already exists; refusing to merge or overwrite: $($move.Destination)"
  }

  $sourceBytes = Get-TreeBytes -LiteralPath $source
  $destinationParent = Split-Path -Parent $move.Destination
  New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
  $resolvedParent = (Resolve-Path -LiteralPath $destinationParent).Path.TrimEnd('\')
  if (-not $resolvedParent.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Safety check failed after creating destination parent: $resolvedParent"
  }

  Move-Item -LiteralPath $source -Destination $move.Destination -Force -ErrorAction Stop
  if (Test-Path -LiteralPath $source) {
    throw "Move did not remove source: $source"
  }
  $destinationBytes = Get-TreeBytes -LiteralPath $move.Destination
  if ($sourceBytes -ne $destinationBytes) {
    throw "Byte verification failed for $($move.Name): $sourceBytes != $destinationBytes"
  }

  New-Item -ItemType Junction -Path $source -Target $move.Destination -ErrorAction Stop | Out-Null
  $junction = Get-Item -LiteralPath $source -Force
  if ($junction.LinkType -ne 'Junction') {
    throw "Compatibility junction was not created: $source"
  }
  $results += [pscustomobject]@{
    Name = $move.Name
    Source = $source
    Destination = $move.Destination
    GB = [math]::Round($sourceBytes / 1GB, 2)
    Status = 'Moved, byte-verified, junction active'
  }
}

$results
[pscustomobject]@{
  Name = 'C drive'
  Source = 'C:'
  Destination = $destinationRoot
  GB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
  Status = 'Free space after relocation'
}
