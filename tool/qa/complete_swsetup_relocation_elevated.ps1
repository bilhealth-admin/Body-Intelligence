[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$source = 'C:\SWSetup'
$destination = 'G:\System_Archives\SWSetup'
$resultDirectory = 'G:\BIL_Project\body_intelligence_log\artifacts\disk_cleanup'
$resultPath = Join-Path $resultDirectory 'swsetup_relocation_result.json'

New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null

try {
  if ([IO.Path]::GetFullPath($source) -ne 'C:\SWSetup') {
    throw 'Unexpected source path.'
  }
  if ([IO.Path]::GetFullPath($destination) -ne 'G:\System_Archives\SWSetup') {
    throw 'Unexpected destination path.'
  }
  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw 'Source is missing.'
  }
  if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
    throw 'Verified destination is missing.'
  }

  $sourceItem = Get-Item -LiteralPath $source -Force
  if ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Source is already a reparse point.'
  }

  $sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Force -Recurse)
  $destinationFiles = @(Get-ChildItem -LiteralPath $destination -File -Force -Recurse)
  $sourceBytes = ($sourceFiles | Measure-Object Length -Sum).Sum
  $destinationBytes = ($destinationFiles | Measure-Object Length -Sum).Sum
  if ($sourceFiles.Count -ne $destinationFiles.Count -or $sourceBytes -ne $destinationBytes) {
    throw 'Source/destination verification failed before elevated deletion.'
  }

  $resolvedSource = (Resolve-Path -LiteralPath $source).Path
  if ($resolvedSource -ne 'C:\SWSetup') {
    throw "Refusing deletion of unexpected source: $resolvedSource"
  }

  Remove-Item -LiteralPath $source -Recurse -Force
  New-Item -ItemType Junction -Path $source -Target $destination | Out-Null

  $junction = Get-Item -LiteralPath $source -Force
  if (-not ($junction.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Junction creation failed.'
  }

  $result = [ordered]@{
    status = 'PASS'
    movedFiles = $destinationFiles.Count
    movedBytes = $destinationBytes
    junction = $junction.FullName
    target = ($junction.Target -join ',')
    cFreeBytes = (Get-Volume C).SizeRemaining
    completedAt = (Get-Date).ToString('o')
  }
  $result | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
  exit 0
}
catch {
  $result = [ordered]@{
    status = 'FAIL'
    error = $_.Exception.Message
    completedAt = (Get-Date).ToString('o')
  }
  $result | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
  exit 1
}
