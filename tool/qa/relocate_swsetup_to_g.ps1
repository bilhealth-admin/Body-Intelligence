[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$source = 'C:\SWSetup'
$destinationParent = 'G:\System_Archives'
$destination = 'G:\System_Archives\SWSetup'

if ([IO.Path]::GetFullPath($source) -ne 'C:\SWSetup') {
  throw 'Unexpected source path.'
}
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
  throw 'C:\SWSetup is missing.'
}

$sourceItem = Get-Item -LiteralPath $source -Force
if ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
  throw 'Source is already a reparse point.'
}

New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
$resolvedDestinationParent = (Resolve-Path -LiteralPath $destinationParent).Path
if (-not $resolvedDestinationParent.StartsWith('G:\System_Archives', [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe destination: $resolvedDestinationParent"
}
if (Test-Path -LiteralPath $destination) {
  throw "Destination already exists: $destination"
}

$sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Force -Recurse)
$sourceCount = $sourceFiles.Count
$sourceBytes = ($sourceFiles | Measure-Object Length -Sum).Sum

Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force

$destinationFiles = @(Get-ChildItem -LiteralPath $destination -File -Force -Recurse)
$destinationCount = $destinationFiles.Count
$destinationBytes = ($destinationFiles | Measure-Object Length -Sum).Sum
if ($sourceCount -ne $destinationCount -or $sourceBytes -ne $destinationBytes) {
  throw "Copy verification failed: source $sourceCount/$sourceBytes destination $destinationCount/$destinationBytes"
}

$sourceLengths = @{}
foreach ($file in $sourceFiles) {
  $relative = $file.FullName.Substring($source.Length).TrimStart('\')
  $sourceLengths[$relative] = $file.Length
}
foreach ($file in $destinationFiles) {
  $relative = $file.FullName.Substring($destination.Length).TrimStart('\')
  if (-not $sourceLengths.ContainsKey($relative) -or $sourceLengths[$relative] -ne $file.Length) {
    throw "Relative-file verification failed: $relative"
  }
}

$largestFiles = $sourceFiles | Sort-Object Length -Descending | Select-Object -First 12
foreach ($file in $largestFiles) {
  $relative = $file.FullName.Substring($source.Length).TrimStart('\')
  $destinationFile = Join-Path $destination $relative
  $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  $destinationHash = (Get-FileHash -LiteralPath $destinationFile -Algorithm SHA256).Hash
  if ($sourceHash -ne $destinationHash) {
    throw "SHA256 mismatch: $relative"
  }
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

[pscustomobject]@{
  MovedFiles = $destinationCount
  MovedGiB = [math]::Round($destinationBytes / 1GB, 3)
  RelativeLengthCheck = 'PASS'
  Largest12Sha256 = 'PASS'
  Junction = $junction.FullName
  Target = ($junction.Target -join ',')
  CFreeGiB = [math]::Round((Get-Volume C).SizeRemaining / 1GB, 2)
  GFreeGiB = [math]::Round((Get-Volume G).SizeRemaining / 1GB, 2)
}
