[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanPath,
    [Parameter(Mandatory)][string]$CandidateRoot,
    [ValidateSet('PreFinalization', 'PostFinalization')]
    [string]$Phase = 'PreFinalization'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# PowerShell does not materialize this automatic variable until a native
# process has completed. Initialize it so strict-mode checks remain defined
# even on hosts that wrap `git` before forwarding to the native executable.
$global:LASTEXITCODE = 0

function Get-OrdinalSortedStrings {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Values)

    [string[]]$sorted = @($Values)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return $sorted
}

function Get-Utf8TextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString(
                $algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
            )).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-LineSetSha256 {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Lines)

    $sorted = @(Get-OrdinalSortedStrings -Values $Lines)
    $payload = if ($sorted.Count -eq 0) { '' } else { ($sorted -join "`n") + "`n" }
    return Get-Utf8TextSha256 -Text $payload
}

function Get-GitBlobOid {
    param([Parameter(Mandatory)][string]$AbsolutePath)

    $file = Get-Item -LiteralPath $AbsolutePath
    $algorithm = [Security.Cryptography.IncrementalHash]::CreateHash(
        [Security.Cryptography.HashAlgorithmName]::SHA1
    )
    $stream = [IO.File]::OpenRead($AbsolutePath)
    try {
        $header = [Text.Encoding]::UTF8.GetBytes("blob $($file.Length)`0")
        $algorithm.AppendData($header)
        $buffer = [byte[]]::new(1MB)
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $algorithm.AppendData($buffer, 0, $read)
        }
        return ([BitConverter]::ToString($algorithm.GetHashAndReset())).Replace('-', '').ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $algorithm.Dispose()
    }
}

function Get-RelativeCandidatePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$AbsolutePath
    )

    return [IO.Path]::GetRelativePath($Root, $AbsolutePath).Replace('\', '/')
}

function Get-ManifestMarker {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Name
    )

    $pattern = '(?m)^`?' + [regex]::Escape($Name) + ':\s*([^`\r\n]+)`?\s*$'
    $matches = @([regex]::Matches($Source, $pattern))
    if ($matches.Count -ne 1) {
        return $null
    }
    return $matches[0].Groups[1].Value.Trim()
}

$resolvedPlan = (Resolve-Path -LiteralPath $PlanPath).Path
$plan = Get-Content -Raw -LiteralPath $resolvedPlan | ConvertFrom-Json
if ([int]$plan.schema_version -ne 1) {
    throw 'CLEAN_TRANSFER_BLOCKED: unsupported plan schema.'
}

$sourceRoot = [IO.Path]::GetFullPath([string]$plan.source.repository_root).TrimEnd('\', '/')
$candidate = [IO.Path]::GetFullPath($CandidateRoot).TrimEnd('\', '/')
if ($candidate.Equals($sourceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate cannot be the dirty source worktree.'
}
if (!(Test-Path -LiteralPath $candidate -PathType Container)) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate directory is missing.'
}
if (!(Test-Path -LiteralPath (Join-Path $candidate '.git') -PathType Leaf)) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate is not a side-worktree checkout.'
}

$candidateTop = (& git -C $candidate rev-parse --show-toplevel | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or
    !([IO.Path]::GetFullPath($candidateTop).TrimEnd('\', '/')).Equals(
        $candidate,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate root identity mismatch.'
}
$registeredWorktrees = @(
    & git -C $sourceRoot worktree list --porcelain |
        Where-Object { $_ -like 'worktree *' } |
        ForEach-Object { [IO.Path]::GetFullPath($_.Substring(9)).TrimEnd('\', '/') }
)
if (!($registeredWorktrees | Where-Object { $_.Equals($candidate, [StringComparison]::OrdinalIgnoreCase) })) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate is not a registered side worktree.'
}

& git -C $candidate diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate index is not clean.'
}
$candidateHead = (& git -C $candidate rev-parse HEAD | Select-Object -First 1).Trim()
$candidateTree = (& git -C $candidate rev-parse 'HEAD^{tree}' | Select-Object -First 1).Trim()
if ($candidateHead -ne [string]$plan.candidate.base_commit -or
    $candidateTree -ne [string]$plan.candidate.base_tree) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate is not at the planned HEAD/tree.'
}
$autoCrlf = (& git -C $candidate config --bool core.autocrlf | Select-Object -First 1)
if ($autoCrlf -and $autoCrlf.Trim().ToLowerInvariant() -ne 'false') {
    throw 'CLEAN_TRANSFER_BLOCKED: core.autocrlf must be false for byte-exact verification.'
}

$headByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
$headLines = @(& git -C $candidate -c core.quotePath=false ls-tree -r --full-tree HEAD)
if ($LASTEXITCODE -ne 0) {
    throw 'CLEAN_TRANSFER_BLOCKED: cannot enumerate candidate HEAD.'
}
foreach ($line in $headLines) {
    if ($line -notmatch '^([0-9]{6})\s+blob\s+([0-9a-f]{40})\t(.+)$') {
        throw "CLEAN_TRANSFER_BLOCKED: unsupported non-blob HEAD entry: $line"
    }
    $path = $Matches[3].Replace('\', '/')
    if (!$headByPath.TryAdd($path, [pscustomobject][ordered]@{
                mode = $Matches[1]
                oid = $Matches[2]
            })) {
        throw "CLEAN_TRANSFER_BLOCKED: duplicate HEAD path: $path"
    }
}

$operationByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
foreach ($operation in @($plan.candidate.operations)) {
    $path = ([string]$operation.path).Replace('\', '/')
    if ([IO.Path]::IsPathRooted($path) -or $path -match '(^|/)\.\.(/|$)') {
        throw "CLEAN_TRANSFER_BLOCKED: operation path escapes candidate: $path"
    }
    if ([string]$operation.operation -notin @('copy', 'delete')) {
        throw "CLEAN_TRANSFER_BLOCKED: unsupported operation for $path"
    }
    if (!$operationByPath.TryAdd($path, $operation)) {
        throw "CLEAN_TRANSFER_BLOCKED: duplicate operation: $path"
    }
}
if ($operationByPath.Count -ne [int]$plan.candidate.include_paths) {
    throw 'CLEAN_TRANSFER_BLOCKED: INCLUDE operation count mismatch.'
}
if ((Get-LineSetSha256 -Lines @($operationByPath.Keys)) -ne
    [string]$plan.candidate.include_pathset_sha256) {
    throw 'CLEAN_TRANSFER_BLOCKED: INCLUDE operation path-set mismatch.'
}

$excludePaths = @($plan.preserve_only.paths | ForEach-Object { ([string]$_).Replace('\', '/') })
if ($excludePaths.Count -ne [int]$plan.preserve_only.exclude_paths -or
    (Get-LineSetSha256 -Lines $excludePaths) -ne [string]$plan.preserve_only.exclude_pathset_sha256) {
    throw 'CLEAN_TRANSFER_BLOCKED: EXCLUDE path-set mismatch.'
}
foreach ($path in $excludePaths) {
    if ($operationByPath.ContainsKey($path)) {
        throw "CLEAN_TRANSFER_BLOCKED: EXCLUDE path also has an INCLUDE operation: $path"
    }
}

$fullExpectedByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
foreach ($path in $headByPath.Keys) {
    $headEntry = $headByPath[$path]
    [void]$fullExpectedByPath.Add($path, [pscustomobject][ordered]@{
            mode = [string]$headEntry.mode
            algorithm = 'git-object-sha1'
            value = [string]$headEntry.oid
        })
}
foreach ($path in $operationByPath.Keys) {
    $operation = $operationByPath[$path]
    if ([string]$operation.operation -eq 'delete') {
        if (!$fullExpectedByPath.Remove($path)) {
            throw "CLEAN_TRANSFER_BLOCKED: planned deletion is absent from HEAD: $path"
        }
        continue
    }
    $mode = if ($headByPath.ContainsKey($path)) { [string]$headByPath[$path].mode } else { '100644' }
    $fullExpectedByPath[$path] = [pscustomobject][ordered]@{
        mode = $mode
        algorithm = [string]$operation.content_hash.algorithm
        value = ([string]$operation.content_hash.value).ToLowerInvariant()
    }
}
$expectedPaths = @($fullExpectedByPath.Keys)
$expectedStateLines = @(
    $expectedPaths | ForEach-Object {
        $entry = $fullExpectedByPath[$_]
        "$($entry.mode)`t$($entry.algorithm):$($entry.value)`t$_"
    }
)
if ($expectedPaths.Count -ne [int]$plan.candidate.full_expected_paths -or
    (Get-LineSetSha256 -Lines $expectedPaths) -ne [string]$plan.candidate.full_expected_pathset_sha256 -or
    (Get-LineSetSha256 -Lines $expectedStateLines) -ne [string]$plan.candidate.full_expected_state_sha256) {
    throw 'CLEAN_TRANSFER_BLOCKED: plan full HEAD plus INCLUDE overlay is inconsistent.'
}

$actualFileByPath = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
foreach ($file in Get-ChildItem -LiteralPath $candidate -Recurse -Force -File) {
    $path = Get-RelativeCandidatePath -Root $candidate -AbsolutePath $file.FullName
    if ($path -eq '.git') {
        continue
    }
    if (!$actualFileByPath.TryAdd($path, $file.FullName)) {
        throw "CLEAN_TRANSFER_BLOCKED: duplicate candidate file path: $path"
    }
}
$missing = @($expectedPaths | Where-Object { !$actualFileByPath.ContainsKey($_) })
$unexpected = @($actualFileByPath.Keys | Where-Object { !$fullExpectedByPath.ContainsKey($_) })
if ($missing.Count -ne 0 -or $unexpected.Count -ne 0) {
    throw "CLEAN_TRANSFER_BLOCKED: full candidate path mismatch: missing=$($missing.Count), unexpected=$($unexpected.Count)"
}

$finalizationPath = [string]$plan.candidate.finalization_path
if (!$operationByPath.ContainsKey($finalizationPath) -or
    [string]$operationByPath[$finalizationPath].operation -ne 'copy') {
    throw 'CLEAN_TRANSFER_BLOCKED: final manifest is not an exact INCLUDE copy operation.'
}
$actualStateLines = [Collections.Generic.List[string]]::new()
$hashMismatch = 0
foreach ($path in $expectedPaths) {
    $expected = $fullExpectedByPath[$path]
    $absolutePath = $actualFileByPath[$path]
    $actualAlgorithm = [string]$expected.algorithm
    $actualValue = if ($actualAlgorithm -eq 'git-object-sha1') {
        Get-GitBlobOid -AbsolutePath $absolutePath
    } elseif ($actualAlgorithm -eq 'sha256') {
        (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
    } else {
        throw "CLEAN_TRANSFER_BLOCKED: unsupported expected hash algorithm: $actualAlgorithm"
    }
    $isFinalizationException = $Phase -eq 'PostFinalization' -and $path -eq $finalizationPath
    if (!$isFinalizationException -and $actualValue -ne [string]$expected.value) {
        $hashMismatch += 1
    }
    [void]$actualStateLines.Add("$($expected.mode)`t$actualAlgorithm`:$actualValue`t$path")
}
if ($hashMismatch -ne 0) {
    throw "CLEAN_TRANSFER_BLOCKED: full candidate hash mismatches=$hashMismatch"
}
$actualFullStateSha256 = Get-LineSetSha256 -Lines @($actualStateLines)
if ($Phase -eq 'PreFinalization' -and
    $actualFullStateSha256 -ne [string]$plan.candidate.full_expected_state_sha256) {
    throw 'CLEAN_TRANSFER_BLOCKED: full candidate state digest mismatch.'
}

$statusByPath = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
$statusLines = @(& git -C $candidate -c core.quotePath=false status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate status failed.'
}
foreach ($line in $statusLines) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
    $status = $line.Substring(0, 2)
    if ($status -match '[URCT]' -or $status -in @('AA', 'DD')) {
        throw "CLEAN_TRANSFER_BLOCKED: unsupported candidate status: $status"
    }
    $path = $line.Substring(3).Trim('"').Replace('\', '/')
    if (!$statusByPath.TryAdd($path, $status)) {
        throw "CLEAN_TRANSFER_BLOCKED: duplicate candidate status path: $path"
    }
}
if ($statusByPath.Count -ne $operationByPath.Count) {
    throw 'CLEAN_TRANSFER_BLOCKED: candidate status count differs from INCLUDE operations.'
}
foreach ($path in $operationByPath.Keys) {
    if (!$statusByPath.ContainsKey($path)) {
        throw "CLEAN_TRANSFER_BLOCKED: INCLUDE path absent from candidate status: $path"
    }
    $expectedStatus = if ([string]$operationByPath[$path].operation -eq 'delete') {
        ' D'
    } elseif ($headByPath.ContainsKey($path)) {
        ' M'
    } else {
        '??'
    }
    if ($statusByPath[$path] -ne $expectedStatus) {
        throw "CLEAN_TRANSFER_BLOCKED: candidate status differs for $path"
    }
}

$excludeTracked = 0
$excludeUntracked = 0
foreach ($path in $excludePaths) {
    if ($headByPath.ContainsKey($path)) {
        $excludeTracked += 1
        if (!$actualFileByPath.ContainsKey($path)) {
            throw "CLEAN_TRANSFER_BLOCKED: tracked EXCLUDE baseline is missing: $path"
        }
    } else {
        $excludeUntracked += 1
        if ($actualFileByPath.ContainsKey($path)) {
            throw "CLEAN_TRANSFER_BLOCKED: untracked EXCLUDE crossed into candidate: $path"
        }
    }
}

if ($Phase -eq 'PostFinalization') {
    $manifestSource = Get-Content -Raw -LiteralPath $actualFileByPath[$finalizationPath]
    $requiredMarkers = [ordered]@{
        STAGING_MANIFEST_COMPLETE = 'YES'
        CANDIDATE_FROZEN_OR_ACCEPTED = 'YES'
        UNRESOLVED_REVIEW_COUNT = '0'
        RELEASE_VERSION = '1.0.0'
        RELEASE_BUILD_NUMBER = '8'
    }
    foreach ($marker in $requiredMarkers.GetEnumerator()) {
        if ((Get-ManifestMarker -Source $manifestSource -Name $marker.Key) -ne $marker.Value) {
            throw "CLEAN_TRANSFER_BLOCKED: final manifest marker is invalid: $($marker.Key)"
        }
    }
}

Write-Host "CLEAN_TRANSFER_PHASE=$Phase"
Write-Host "CLEAN_TRANSFER_HEAD=$candidateHead"
Write-Host "CLEAN_TRANSFER_FULL_PATHS=$($actualFileByPath.Count)"
Write-Host "CLEAN_TRANSFER_FULL_STATE_SHA256=$actualFullStateSha256"
Write-Host "CLEAN_TRANSFER_INCLUDE=$($operationByPath.Count)"
Write-Host "CLEAN_TRANSFER_EXCLUDE_TRACKED_PROTECTED=$excludeTracked"
Write-Host "CLEAN_TRANSFER_EXCLUDE_UNTRACKED_ABSENT=$excludeUntracked"
Write-Host 'CLEAN_TRANSFER_UNEXPECTED=0'
Write-Host 'CLEAN_TRANSFER_MISSING=0'
Write-Host 'CLEAN_TRANSFER_HASH_MISMATCH=0'
Write-Host 'CLEAN_TRANSFER_EXCLUDE_VIOLATION=0'
Write-Host 'CLEAN_SOURCE_TRANSFER_VERIFICATION=PASS'
