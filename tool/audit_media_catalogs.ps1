param(
  [string]$MediaRoot = 'G:\BIL_Workout_Media',
  [string]$CatalogCsv = 'tool\workout_media\exercises_1000.csv',
  [string]$ApprovalsCsv = 'artifacts\workout_media\workout_release_review_approvals.csv',
  [string]$OutputCsv = 'artifacts\workout_media\workout_exact200_manifest.csv'
)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
  throw 'ffprobe is required to validate processed workout videos.'
}

$rows = Import-Csv -LiteralPath $CatalogCsv
$targets = $rows | Group-Object category, exercise_name | ForEach-Object {
  $_.Group | Select-Object -First 1
}
if ($targets.Count -ne 200) { throw "Expected 200 slots; found $($targets.Count)." }

$targetIds = @{}
foreach ($target in $targets) {
  $id = $target.exercise_id -replace '--', '-'
  if ($targetIds.ContainsKey($id)) { throw "Duplicate canonical target id: $id" }
  $targetIds[$id] = $true
}

$processedRoots = @(
  Join-Path $MediaRoot 'bulk_1000\processed'
  Join-Path $MediaRoot 'bulk_1000_female_10s\processed'
)
$processed = @{}
$excluded = 0
foreach ($file in Get-ChildItem $processedRoots -File -Filter *.mp4) {
  # Only an exact canonical target filename can enter the release manifest.
  # Raw, alternate, rejected, and unrelated processed files remain evidence only.
  if (-not $targetIds.ContainsKey($file.BaseName)) { $excluded++; continue }
  if ($processed.ContainsKey($file.BaseName)) {
    throw "Duplicate canonical processed id: $($file.BaseName)"
  }
  $processed[$file.BaseName] = $file
}

$approvals = @{}
if (Test-Path -LiteralPath $ApprovalsCsv) {
  foreach ($approval in Import-Csv -LiteralPath $ApprovalsCsv) {
    if ($approval.review_status -ne 'approved') { continue }
    if (-not $targetIds.ContainsKey($approval.variation_id)) {
      throw "Approval references a noncanonical id: $($approval.variation_id)"
    }
    if ($approval.processed_sha256 -notmatch '^[a-fA-F0-9]{64}$') {
      throw "Approval has an invalid SHA-256: $($approval.variation_id)"
    }
    if ($approvals.ContainsKey($approval.variation_id)) {
      throw "Duplicate approval: $($approval.variation_id)"
    }
    $approvals[$approval.variation_id] = $approval.processed_sha256.ToLowerInvariant()
  }
}

$manifest = foreach ($target in $targets) {
  $id = $target.exercise_id -replace '--', '-'
  $file = $processed[$id]
  $digest = $null
  $bytes = $null
  $duration = $null
  $available = $null -ne $file
  if ($available) {
    $digest = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $bytes = $file.Length
    $probe = & ffprobe -v error -show_entries stream=codec_name,codec_type,width,height -show_entries format=duration -of json -- $file.FullName | ConvertFrom-Json
    $video = @($probe.streams | Where-Object codec_type -eq 'video')
    if ($LASTEXITCODE -ne 0 -or $video.Count -ne 1 -or $video[0].codec_name -ne 'h264') {
      throw "Canonical processed video failed ffprobe/H.264 validation: $id"
    }
    $duration = [math]::Round([double]$probe.format.duration, 3)
    if ($duration -le 0 -or $video[0].width -le 0 -or $video[0].height -le 0) {
      throw "Canonical processed video has invalid dimensions or duration: $id"
    }
  }
  $approved = $available -and $approvals.ContainsKey($id) -and $approvals[$id] -eq $digest
  if ($approvals.ContainsKey($id) -and -not $approved) {
    throw "Approved digest does not match the canonical processed file: $id"
  }
  [pscustomobject]@{
    slot = "$($target.category)|$($target.exercise_name)"
    variation_id = $id
    object_path = if ($available) { "workouts/v1/movements/$id.mp4" } else { $null }
    processed_sha256 = $digest
    processed_bytes = $bytes
    duration_seconds = $duration
    mime_type = if ($available) { 'video/mp4' } else { $null }
    candidate_available = $available
    playable = $approved
    review_status = if (-not $available) { 'missing_processed' } elseif ($approved) { 'approved' } else { 'requires_release_review' }
  }
}

$directory = Split-Path $OutputCsv -Parent
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$manifest | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding utf8
$availableCount = @($manifest | Where-Object candidate_available -eq $true).Count
$approvedCount = @($manifest | Where-Object playable -eq $true).Count
Write-Output "slots=$($manifest.Count) processed=$availableCount missing=$($manifest.Count - $availableCount) approved=$approvedCount excluded_noncanonical=$excluded"
