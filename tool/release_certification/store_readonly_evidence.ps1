function Assert-StoreReadonlyChildPath {
  param([string]$ParentPath, [string]$ChildPath)
  $parent = [IO.Path]::GetFullPath($ParentPath).TrimEnd([char[]]'\/')
  $child = [IO.Path]::GetFullPath($ChildPath).TrimEnd([char[]]'\/')
  if (-not $child.StartsWith($parent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Store audit path escaped its allocated temporary directory'
  }
  $current = $child
  while ($true) {
    if (Test-Path -LiteralPath $current) {
      $item = Get-Item -LiteralPath $current -Force
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Store audit temporary path contains a reparse point'
      }
    }
    if ($current.Equals($parent, [StringComparison]::OrdinalIgnoreCase)) { break }
    $current = [IO.Path]::GetDirectoryName($current)
  }
  return $child
}

function Assert-StoreReadonlyDriveMapping {
  param([string]$DriveRoot, [scriptblock]$ReadMappings)
  $mappedTargets = @(& $ReadMappings | ForEach-Object {
    $match = [regex]::Match([string]$_, '^\s*G:\\:\s*=>\s*(.+?)\s*$')
    if ($match.Success) { $match.Groups[1].Value }
  })
  if ($mappedTargets.Count -ne 1 -or -not ([IO.Path]::GetFullPath($mappedTargets[0]).TrimEnd([char[]]'\/')).Equals(
    [IO.Path]::GetFullPath($DriveRoot).TrimEnd([char[]]'\/'), [StringComparison]::OrdinalIgnoreCase
  )) { throw 'Store audit G drive mapping does not match its allocated temporary directory' }
}

function Invoke-StoreReadonlyDrive {
  param(
    [Parameter(Mandatory=$true)][string]$RunnerTemp,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [Parameter(Mandatory=$true)][scriptblock]$Audit,
    [scriptblock]$DriveExists = {
      [bool](Get-PSDrive -Name G -ErrorAction SilentlyContinue) -or
        ([Environment]::GetLogicalDrives() -contains 'G:\')
    },
    [scriptblock]$MapDrive = { param($path) & subst.exe G: $path | Out-Null; return $LASTEXITCODE },
    [scriptblock]$ReadMappings = {
      $lines = @(& subst.exe)
      if ($LASTEXITCODE -ne 0) { throw 'Unable to verify store audit temporary drive mapping' }
      return $lines
    },
    [scriptblock]$UnmapDrive = { & subst.exe G: /D | Out-Null; return $LASTEXITCODE }
  )
  if (& $DriveExists) { throw 'Store audit refuses to run because G is already present' }
  $driveRoot = Assert-StoreReadonlyChildPath -ParentPath $RunnerTemp -ChildPath (
    Join-Path $RunnerTemp ('bil-store-drive-' + [guid]::NewGuid().ToString('N'))
  )
  New-Item -ItemType Directory -Path $driveRoot | Out-Null
  $mapped = $false
  $failure = $null
  $driveAudit = $Audit
  try {
    if ((& $MapDrive $driveRoot) -ne 0) { throw 'Store audit temporary drive creation failed' }
    $mapped = $true
    Assert-StoreReadonlyDriveMapping -DriveRoot $driveRoot -ReadMappings $ReadMappings
    Invoke-StoreReadonlyEvidence -OutputDir $OutputDir -EvidenceDir (Join-Path $driveRoot 'evidence') -Audit {
      Assert-StoreReadonlyDriveMapping -DriveRoot $driveRoot -ReadMappings $ReadMappings
      & $driveAudit $driveRoot
    } -Cleanup {
      Assert-StoreReadonlyDriveMapping -DriveRoot $driveRoot -ReadMappings $ReadMappings
      $null = Assert-StoreReadonlyChildPath -ParentPath $RunnerTemp -ChildPath $driveRoot
      $secretRoot = Assert-StoreReadonlyChildPath -ParentPath $driveRoot -ChildPath (Join-Path $driveRoot 'secret')
      foreach ($name in @('asc.p8', 'google.json')) {
        $secret = Assert-StoreReadonlyChildPath -ParentPath $secretRoot -ChildPath (Join-Path $secretRoot $name)
        if (Test-Path -LiteralPath $secret -PathType Leaf) { Remove-Item -LiteralPath $secret -Force }
      }
      if (Test-Path -LiteralPath $secretRoot) {
        if (@(Get-ChildItem -LiteralPath $secretRoot -Force).Count -ne 0) {
          throw 'Store audit secret directory contains unexpected entries; refusing recursive deletion'
        }
        Remove-Item -LiteralPath $secretRoot -Force
      }
    }
  } catch {
    $failure = $_
  } finally {
    if ($mapped) {
      try {
        Assert-StoreReadonlyDriveMapping -DriveRoot $driveRoot -ReadMappings $ReadMappings
        if ((& $UnmapDrive) -ne 0) { throw 'Store audit temporary drive removal failed' }
      } catch { if ($null -eq $failure) { $failure = $_ } }
    }
  }
  if ($null -ne $failure) {
    if (Test-Path -LiteralPath $OutputDir -PathType Container) {
      'STORE_READONLY=FAIL' | Set-Content (Join-Path $OutputDir 'status.txt')
    }
    throw $failure
  }
}

function Invoke-StoreReadonlyEvidence {
  param(
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [Parameter(Mandatory=$true)][string]$EvidenceDir,
    [Parameter(Mandatory=$true)][scriptblock]$Audit,
    [Parameter(Mandatory=$true)][scriptblock]$Cleanup
  )
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
  'STORE_READONLY=FAIL' | Set-Content (Join-Path $OutputDir 'status.txt')
  $failure = $null
  try {
    & $Audit
  } catch {
    $failure = $_
  } finally {
    try {
      foreach ($name in @('apple-v1.json', 'google-release.json')) {
        $source = Join-Path $EvidenceDir $name
        if (Test-Path -LiteralPath $source -PathType Leaf) {
          Copy-Item -LiteralPath $source -Destination (Join-Path $OutputDir $name) -Force
        }
      }
    } catch {
      if ($null -eq $failure) { $failure = $_ }
    } finally {
      try { & $Cleanup } catch { if ($null -eq $failure) { $failure = $_ } }
    }
  }
  if ($null -ne $failure) { throw $failure }
  'STORE_READONLY=PASS' | Set-Content (Join-Path $OutputDir 'status.txt')
}
