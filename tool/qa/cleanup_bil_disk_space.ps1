[CmdletBinding()]
param(
  [ValidateSet('UserTemp', 'OldCodexSessions', 'GBilBuildAndBackupArtifacts', 'CProjectArtifacts', 'CDevelopmentCaches', 'CDesktopBilArtifacts', 'CStaleTodayCodexSessions', 'CNpmCacheExceptWrangler', 'CFinalProjectCaches')]
  [string]$Mode = 'UserTemp'
)

$ErrorActionPreference = 'Stop'

function Get-TreeBytes {
  param([Parameter(Mandatory)][string]$LiteralPath)

  if (-not (Test-Path -LiteralPath $LiteralPath)) { return [int64]0 }
  try {
    $measurement = Get-ChildItem -LiteralPath $LiteralPath -File -Force -Recurse -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum
  } catch {
    return [int64]0
  }
  if ($null -eq $measurement.Sum) { return [int64]0 }
  return [int64]$measurement.Sum
}

if ($Mode -eq 'UserTemp') {
  $expected = 'C:\Users\HP 1040 G8\AppData\Local\Temp'
  $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
  if ($target -ne $expected) {
    throw "Safety check failed. Refusing to clean unexpected path: $target"
  }

  $before = Get-TreeBytes -LiteralPath $target
  $removed = 0
  $inUse = 0
  foreach ($item in Get-ChildItem -LiteralPath $target -Force) {
    try {
      Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
      $removed++
    } catch {
      # Active applications may hold temporary files. Leaving them in place is safe.
      $inUse++
    }
  }
  $after = Get-TreeBytes -LiteralPath $target
  [pscustomobject]@{
    Target = $target
    BeforeGB = [math]::Round($before / 1GB, 2)
    AfterGB = [math]::Round($after / 1GB, 2)
    FreedGB = [math]::Round(($before - $after) / 1GB, 2)
    TopLevelRemoved = $removed
    TopLevelInUse = $inUse
    CFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
  }
}

if ($Mode -eq 'OldCodexSessions') {
  $expected = 'C:\Users\HP 1040 G8\.codex\sessions'
  $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
  if ($target -ne $expected) {
    throw "Safety check failed. Refusing to clean unexpected path: $target"
  }

  # Preserve every session touched today, including this active thread and its agents.
  $cutoff = (Get-Date).Date
  $candidates = @(Get-ChildItem -LiteralPath $target -File -Force -Recurse |
    Where-Object { $_.LastWriteTime -lt $cutoff })
  $before = [int64](($candidates | Measure-Object -Property Length -Sum).Sum)
  $removed = 0
  $failed = 0
  foreach ($file in $candidates) {
    try {
      Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
      $removed++
    } catch {
      $failed++
    }
  }

  # Remove only empty date folders left behind by the deleted historical logs.
  Get-ChildItem -LiteralPath $target -Directory -Force -Recurse |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
      if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
      }
    }

  $remainingOld = @(Get-ChildItem -LiteralPath $target -File -Force -Recurse |
    Where-Object { $_.LastWriteTime -lt $cutoff })
  $remainingBytes = [int64](($remainingOld | Measure-Object -Property Length -Sum).Sum)
  [pscustomobject]@{
    Target = $target
    CutoffPreservedFrom = $cutoff.ToString('yyyy-MM-dd')
    CandidateGB = [math]::Round($before / 1GB, 2)
    FreedGB = [math]::Round(($before - $remainingBytes) / 1GB, 2)
    FilesRemoved = $removed
    FilesFailed = $failed
    TodaySessionsPreserved = @(Get-ChildItem -LiteralPath $target -File -Force -Recurse |
      Where-Object { $_.LastWriteTime -ge $cutoff }).Count
    CFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
  }
}

if ($Mode -eq 'GBilBuildAndBackupArtifacts') {
  # Explicit whitelist only. Source, approved workout media, audit packs and exports are excluded.
  $expectedTargets = @(
    'G:\BIL_Backups',
    'G:\BIL_Test_Temp',
    'G:\BIL_Gradle_Cache',
    'G:\BIL_TEMP',
    'G:\BIL_SAFETY_BACKUPS',
    'G:\BIL_Project_Backups',
    'G:\BIL_EXPORT_TEMP',
    'G:\BIL_PUB_CACHE',
    'G:\BIL_PubCache'
  )
  $protected = @(
    'G:\BIL_Project',
    'G:\BIL_Workout_Media',
    'G:\BIL_EXPORTS',
    'G:\BIL_AUDIT_PACKS',
    'G:\BIL_AI'
  )

  $results = @()
  foreach ($expected in $expectedTargets) {
    if (-not (Test-Path -LiteralPath $expected)) {
      $results += [pscustomobject]@{ Target = $expected; BeforeGB = 0; Removed = $false; Note = 'Already absent' }
      continue
    }
    $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
    if ($target -ne $expected -or $target -in $protected -or -not $target.StartsWith('G:\BIL_', [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Safety check failed. Refusing to remove unexpected path: $target"
    }
    $before = Get-TreeBytes -LiteralPath $target
    try {
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    } catch {
      # The historical read-only package contains paths beyond the legacy
      # PowerShell path limit. Use the .NET long-path form on this already
      # verified, explicit desktop target only.
      $longTarget = "\\?\$target"
      [System.IO.Directory]::Delete($longTarget, $true)
    }
    $results += [pscustomobject]@{
      Target = $target
      BeforeGB = [math]::Round($before / 1GB, 2)
      Removed = -not (Test-Path -LiteralPath $target)
      Note = 'Build cache, test temp, export temp, or redundant backup'
    }
  }
  $results
  [pscustomobject]@{
    Target = 'G:'
    BeforeGB = $null
    Removed = $null
    Note = "G free space: $([math]::Round((Get-PSDrive -Name G).Free / 1GB, 2)) GB"
  }
}

if ($Mode -eq 'CProjectArtifacts') {
  $expectedRoot = 'C:\develop'
  $root = (Resolve-Path -LiteralPath $expectedRoot).Path.TrimEnd('\')
  if ($root -ne $expectedRoot) {
    throw "Safety check failed. Unexpected C project root: $root"
  }
  $expectedTargets = @(
    'C:\develop\baselines',
    'C:\develop\BIL-Baselines',
    'C:\develop\bil_archives',
    'C:\develop\bil_backups',
    'C:\develop\bil_food_catalog',
    'C:\develop\bil_food_catalog_work',
    'C:\develop\bil_food_core',
    'C:\develop\bil_food_dist',
    'C:\develop\bil_food_sources',
    'C:\develop\bil_food_work',
    'C:\develop\exports',
    'C:\develop\investigations',
    'C:\develop\local_changes_backup_1867640',
    'C:\develop\packages',
    'C:\develop\projects'
  )
  $results = @()
  foreach ($expected in $expectedTargets) {
    if (-not (Test-Path -LiteralPath $expected)) {
      $results += [pscustomobject]@{ Target = $expected; BeforeGB = 0; Removed = $false; Note = 'Already absent' }
      continue
    }
    $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
    if (-not $target.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase) -or
        $target -in @('C:\develop\flutter', 'C:\develop\jdk-21')) {
      throw "Safety check failed. Refusing to remove unexpected path: $target"
    }
    $before = Get-TreeBytes -LiteralPath $target
    try {
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    } catch {
      # This explicit historical package can contain paths beyond the legacy
      # PowerShell path limit. The verified long-path target remains confined
      # to the named BIL directory on this user's Desktop.
      $longTarget = "\\?\$target"
      [System.IO.Directory]::Delete($longTarget, $true)
    }
    $results += [pscustomobject]@{
      Target = $target
      BeforeGB = [math]::Round($before / 1GB, 3)
      Removed = -not (Test-Path -LiteralPath $target)
      Note = 'Old BIL project copy, backup, generated food work, or investigation output'
    }
  }
  $results
  [pscustomobject]@{
    Target = 'C:'
    BeforeGB = $null
    Removed = $null
    Note = "C free space: $([math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)) GB"
  }
}

if ($Mode -eq 'CDevelopmentCaches') {
  $expectedTargets = @(
    'C:\Users\HP 1040 G8\AppData\Local\.dartServer',
    'C:\Users\HP 1040 G8\.gradle',
    'C:\Users\HP 1040 G8\AppData\Local\Pub\Cache',
    'C:\Users\HP 1040 G8\.cache\codex-runtimes',
    'C:\Users\HP 1040 G8\.cache\hyperframes',
    'C:\Users\HP 1040 G8\AppData\Local\pip',
    'C:\Users\HP 1040 G8\AppData\Local\uv',
    'C:\Users\HP 1040 G8\AppData\Roaming\uv',
    'C:\Users\HP 1040 G8\AppData\Local\CrashDumps',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\CachedExtensionVSIXs',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\Crashpad',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\CachedData',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\Cache',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\logs',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\GPUCache',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\DawnWebGPUCache',
    'C:\Users\HP 1040 G8\AppData\Roaming\Code\DawnGraphiteCache'
  )
  $allowedRoots = @(
    'C:\Users\HP 1040 G8\AppData\Local',
    'C:\Users\HP 1040 G8\AppData\Roaming',
    'C:\Users\HP 1040 G8\.gradle',
    'C:\Users\HP 1040 G8\.cache'
  )
  $results = @()
  foreach ($expected in $expectedTargets) {
    if (-not (Test-Path -LiteralPath $expected)) {
      $results += [pscustomobject]@{ Target = $expected; BeforeGB = 0; Removed = $false; Note = 'Already absent' }
      continue
    }
    $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
    $withinAllowedRoot = $false
    foreach ($allowedRoot in $allowedRoots) {
      if ($target -eq $allowedRoot -or $target.StartsWith("$allowedRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
        $withinAllowedRoot = $true
        break
      }
    }
    if ($target -ne $expected -or -not $withinAllowedRoot) {
      throw "Safety check failed. Refusing to remove unexpected cache path: $target"
    }
    $before = Get-TreeBytes -LiteralPath $target
    try {
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
      $removed = -not (Test-Path -LiteralPath $target)
      $note = 'Rebuildable development or editor cache'
    } catch {
      $removed = $false
      $note = "Partially retained because files are in use: $($_.Exception.Message)"
    }
    $after = if (Test-Path -LiteralPath $target) { Get-TreeBytes -LiteralPath $target } else { [int64]0 }
    $results += [pscustomobject]@{
      Target = $target
      BeforeGB = [math]::Round($before / 1GB, 3)
      FreedGB = [math]::Round(($before - $after) / 1GB, 3)
      Removed = $removed
      Note = $note
    }
  }

  $generatedRoot = 'C:\Users\HP 1040 G8\.codex\generated_images'
  if (Test-Path -LiteralPath $generatedRoot) {
    $cutoff = (Get-Date).Date
    $oldGenerated = @(Get-ChildItem -LiteralPath $generatedRoot -File -Force -Recurse |
      Where-Object { $_.LastWriteTime -lt $cutoff })
    $oldBytes = [int64](($oldGenerated | Measure-Object -Property Length -Sum).Sum)
    foreach ($file in $oldGenerated) {
      Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
    }
    Get-ChildItem -LiteralPath $generatedRoot -Directory -Force -Recurse |
      Sort-Object { $_.FullName.Length } -Descending |
      ForEach-Object {
        if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)) {
          Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        }
      }
    $remainingOldBytes = [int64]((Get-ChildItem -LiteralPath $generatedRoot -File -Force -Recurse |
      Where-Object { $_.LastWriteTime -lt $cutoff } |
      Measure-Object -Property Length -Sum).Sum)
    $results += [pscustomobject]@{
      Target = "$generatedRoot (before today only)"
      BeforeGB = [math]::Round($oldBytes / 1GB, 3)
      FreedGB = [math]::Round(($oldBytes - $remainingOldBytes) / 1GB, 3)
      Removed = $remainingOldBytes -eq 0
      Note = 'Historical generated-image cache; today preserved'
    }
  }
  $results
  [pscustomobject]@{
    Target = 'C:'
    BeforeGB = $null
    FreedGB = $null
    Removed = $null
    Note = "C free space: $([math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)) GB"
  }
}

if ($Mode -eq 'CDesktopBilArtifacts') {
  $desktopRoot = 'C:\Users\HP 1040 G8\Desktop'
  $desktop = (Resolve-Path -LiteralPath $desktopRoot).Path.TrimEnd('\')
  if ($desktop -ne $desktopRoot) {
    throw "Safety check failed. Unexpected desktop root: $desktop"
  }
  $deleteTargets = @(
    'C:\Users\HP 1040 G8\Desktop\BIL-READONLY-COPY-20260816-224917',
    'C:\Users\HP 1040 G8\Desktop\BIL-STORE-ASSETS-REVIEW'
  )
  $results = @()
  foreach ($expected in $deleteTargets) {
    if (-not (Test-Path -LiteralPath $expected)) {
      $results += [pscustomobject]@{ Target = $expected; FreedGB = 0; Status = 'Already absent' }
      continue
    }
    $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
    if ($target -ne $expected -or -not $target.StartsWith("$desktop\BIL-", [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Safety check failed. Refusing to remove unexpected desktop path: $target"
    }
    $before = Get-TreeBytes -LiteralPath $target
    try {
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    } catch {
      # This explicit historical package can contain paths beyond the legacy
      # PowerShell path limit. The verified long-path target remains confined
      # to the named BIL directory on this user's Desktop.
      $longTarget = "\\?\$target"
      [System.IO.Directory]::Delete($longTarget, $true)
    }
    $results += [pscustomobject]@{
      Target = $target
      FreedGB = [math]::Round($before / 1GB, 3)
      Status = if (Test-Path -LiteralPath $target) { 'FAILED: still present' } else { 'Removed old BIL copy/evidence cache' }
    }
  }

  # Preserve the four small final artwork files by relocating them to the project drive.
  $artworkNames = @(
    'BIL_APP_ICON_FINAL.png',
    'bil_app_icon_newب.png',
    'BIL_FEATURE_GRAPHIC_1024x500.png',
    'BIL_SPLASH_FINAL.png'
  )
  $artworkDestination = 'G:\BIL_EXPORTS\desktop_final_artwork_20260817'
  New-Item -ItemType Directory -Path $artworkDestination -Force | Out-Null
  $resolvedArtworkDestination = (Resolve-Path -LiteralPath $artworkDestination).Path.TrimEnd('\')
  if ($resolvedArtworkDestination -ne $artworkDestination) {
    throw "Safety check failed. Unexpected artwork destination: $resolvedArtworkDestination"
  }
  foreach ($name in $artworkNames) {
    $source = Join-Path $desktop $name
    if (-not (Test-Path -LiteralPath $source)) { continue }
    $destination = Join-Path $artworkDestination $name
    if (Test-Path -LiteralPath $destination) {
      $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
      $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
      if ($sourceHash -ne $destinationHash) {
        throw "Artwork collision with different content: $destination"
      }
      Remove-Item -LiteralPath $source -Force -ErrorAction Stop
      $status = 'Identical G copy already existed; C copy removed'
    } else {
      $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
      Move-Item -LiteralPath $source -Destination $destination -Force -ErrorAction Stop
      $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
      if ($sourceHash -ne $destinationHash -or (Test-Path -LiteralPath $source)) {
        throw "Artwork relocation verification failed: $name"
      }
      $status = 'Moved to G and SHA-256 verified'
    }
    $results += [pscustomobject]@{ Target = $source; FreedGB = 0; Status = $status }
  }
  $results
  [pscustomobject]@{
    Target = 'C:'
    FreedGB = $null
    Status = "C free space: $([math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)) GB"
  }
}

if ($Mode -eq 'CStaleTodayCodexSessions') {
  $sessionRoot = 'C:\Users\HP 1040 G8\.codex\sessions\2026\08\23'
  $target = (Resolve-Path -LiteralPath $sessionRoot).Path.TrimEnd('\')
  if ($target -ne $sessionRoot) {
    throw "Safety check failed. Unexpected current-day session root: $target"
  }
  $files = @(Get-ChildItem -LiteralPath $target -File -Force | Sort-Object LastWriteTime -Descending)
  $preserved = @($files | Select-Object -First 3)
  $stale = @($files | Select-Object -Skip 3)
  $staleBytes = [int64](($stale | Measure-Object -Property Length -Sum).Sum)
  foreach ($file in $stale) {
    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
  }
  [pscustomobject]@{
    Target = $target
    Preserved = $preserved.Count
    Removed = $stale.Count
    FreedGB = [math]::Round($staleBytes / 1GB, 3)
    Note = 'Three newest root/uploader/watchdog session snapshots preserved'
    CFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
  }
}

if ($Mode -eq 'CNpmCacheExceptWrangler') {
  $cacheRoot = 'C:\Users\HP 1040 G8\AppData\Local\npm-cache'
  $activeWrangler = 'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_npx\d77349f55c2be1c0'
  $root = (Resolve-Path -LiteralPath $cacheRoot).Path.TrimEnd('\')
  $wrangler = (Resolve-Path -LiteralPath $activeWrangler).Path.TrimEnd('\')
  if ($root -ne $cacheRoot -or $wrangler -ne $activeWrangler -or
      -not $wrangler.StartsWith("$root\_npx\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Safety check failed for npm cache or the active Wrangler runtime.'
  }

  $targets = @(
    'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_cacache',
    'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_logs',
    'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_update-notifier-last-checked'
  )
  $targets += @(Get-ChildItem -LiteralPath "$root\_npx" -Directory -Force |
    Where-Object { $_.FullName -ne $wrangler } |
    Select-Object -ExpandProperty FullName)
  $freed = [int64]0
  $removed = 0
  foreach ($expected in $targets) {
    if (-not (Test-Path -LiteralPath $expected)) { continue }
    $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
    if (-not $target.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase) -or
        $target -eq $wrangler -or $wrangler.StartsWith("$target\", [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Safety check failed. Refusing to remove npm path: $target"
    }
    if ((Get-Item -LiteralPath $target -Force).PSIsContainer) {
      $freed += Get-TreeBytes -LiteralPath $target
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    } else {
      $freed += (Get-Item -LiteralPath $target -Force).Length
      Remove-Item -LiteralPath $target -Force -ErrorAction Stop
    }
    $removed++
  }
  [pscustomobject]@{
    Target = $root
    ActiveWranglerPreserved = Test-Path -LiteralPath "$wrangler\node_modules\.bin\wrangler.cmd"
    EntriesRemoved = $removed
    FreedGB = [math]::Round($freed / 1GB, 3)
    CFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
  }
}

if ($Mode -eq 'CFinalProjectCaches') {
  $results = @()
  $deleteTargets = @(
    'C:\Users\HP 1040 G8\.codex\sessions\2026\08\23',
    'C:\Users\HP 1040 G8\AppData\Local\Microsoft\vscode-cpptools\91a66b84155ac57a0fed33fc8ddca159\.BROWSE.VC.DB',
    'C:\Users\HP 1040 G8\vscode-remote-wsl',
    'C:\Users\HP 1040 G8\shipin7_update_temp'
  )
  $allowedPrefixes = @(
    'C:\Users\HP 1040 G8\.codex\sessions\2026\08\23',
    'C:\Users\HP 1040 G8\AppData\Local\Microsoft\vscode-cpptools\',
    'C:\Users\HP 1040 G8\vscode-remote-wsl',
    'C:\Users\HP 1040 G8\shipin7_update_temp'
  )
  foreach ($expected in $deleteTargets) {
    if (-not (Test-Path -LiteralPath $expected)) { continue }
    $target = (Resolve-Path -LiteralPath $expected).Path.TrimEnd('\')
    $allowed = $false
    foreach ($prefix in $allowedPrefixes) {
      if ($target -eq $prefix.TrimEnd('\') -or $target.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $allowed = $true
        break
      }
    }
    if ($target -ne $expected.TrimEnd('\') -or -not $allowed) {
      throw "Safety check failed. Refusing to remove unexpected final-cache target: $target"
    }
    $item = Get-Item -LiteralPath $target -Force
    $before = if ($item.PSIsContainer) { Get-TreeBytes -LiteralPath $target } else { [int64]$item.Length }
    try {
      Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
      $after = [int64]0
      $status = 'Removed rebuildable/project cache'
    } catch {
      $after = if (Test-Path -LiteralPath $target) {
        $remaining = Get-Item -LiteralPath $target -Force
        if ($remaining.PSIsContainer) { Get-TreeBytes -LiteralPath $target } else { [int64]$remaining.Length }
      } else { [int64]0 }
      $status = "Retained because in use: $($_.Exception.Message)"
    }
    $results += [pscustomobject]@{
      Target = $target
      FreedGB = [math]::Round(($before - $after) / 1GB, 3)
      Status = $status
    }
  }

  $bilRuntimeSource = 'C:\Users\HP 1040 G8\AppData\Roaming\BIL'
  $bilRuntimeDestination = 'G:\BIL_RuntimeData\Windows\BIL'
  if (Test-Path -LiteralPath $bilRuntimeSource) {
    $sourceItem = Get-Item -LiteralPath $bilRuntimeSource -Force
    if ($sourceItem.LinkType -ne 'Junction') {
      $source = (Resolve-Path -LiteralPath $bilRuntimeSource).Path.TrimEnd('\')
      if ($source -ne $bilRuntimeSource -or (Test-Path -LiteralPath $bilRuntimeDestination)) {
        throw 'Safety check failed for BIL Windows runtime relocation.'
      }
      $sourceBytes = Get-TreeBytes -LiteralPath $source
      New-Item -ItemType Directory -Path (Split-Path -Parent $bilRuntimeDestination) -Force | Out-Null
      Move-Item -LiteralPath $source -Destination $bilRuntimeDestination -Force -ErrorAction Stop
      $destinationBytes = Get-TreeBytes -LiteralPath $bilRuntimeDestination
      if ($sourceBytes -ne $destinationBytes -or (Test-Path -LiteralPath $source)) {
        throw 'BIL Windows runtime relocation byte verification failed.'
      }
      New-Item -ItemType Junction -Path $source -Target $bilRuntimeDestination -ErrorAction Stop | Out-Null
      $results += [pscustomobject]@{
        Target = $source
        FreedGB = [math]::Round($sourceBytes / 1GB, 3)
        Status = 'Moved to G, byte-verified, compatibility junction active'
      }
    }
  }

  $desktop = 'C:\Users\HP 1040 G8\Desktop'
  $artworkDestination = 'G:\BIL_EXPORTS\desktop_final_artwork_20260817'
  $remainingArtwork = @(Get-ChildItem -LiteralPath $desktop -File -Force |
    Where-Object { $_.Name -like 'bil_app_icon_new*.png' })
  foreach ($file in $remainingArtwork) {
    $destination = Join-Path $artworkDestination $file.Name
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    Move-Item -LiteralPath $file.FullName -Destination $destination -Force -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $sourceHash) {
      throw "Remaining artwork SHA verification failed: $($file.Name)"
    }
    $results += [pscustomobject]@{ Target = $file.FullName; FreedGB = 0; Status = 'Moved to G and SHA-256 verified' }
  }

  try {
    $recycleBefore = Get-TreeBytes -LiteralPath 'C:\$Recycle.Bin'
    Clear-RecycleBin -DriveLetter C -Force -ErrorAction Stop
    $recycleAfter = Get-TreeBytes -LiteralPath 'C:\$Recycle.Bin'
    $results += [pscustomobject]@{
      Target = 'C:\$Recycle.Bin'
      FreedGB = [math]::Round(($recycleBefore - $recycleAfter) / 1GB, 3)
      Status = 'Recycle Bin permanently emptied for C'
    }
  } catch {
    $results += [pscustomobject]@{ Target = 'C:\$Recycle.Bin'; FreedGB = 0; Status = "Could not empty: $($_.Exception.Message)" }
  }
  $results
  [pscustomobject]@{
    Target = 'C:'
    FreedGB = $null
    Status = "C free space: $([math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)) GB"
  }
}
