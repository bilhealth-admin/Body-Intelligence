[CmdletBinding()]
param(
    [string]$ManifestPath = 'artifacts/release/source_hygiene/2026-08-31/release-source-manifest.json',
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$repositoryPrefix = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$previousLocation = Get-Location

function Normalize-StatusPath {
    param([Parameter(Mandatory)][string]$RawPath)

    return $RawPath.Trim('"').Replace('\', '/')
}

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
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
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

function Assert-RepositoryChildPath {
    param([Parameter(Mandatory)][string]$RelativePath)

    if ([IO.Path]::IsPathRooted($RelativePath)) {
        throw "FREEZE_PREP_BLOCKED: absolute status path: $RelativePath"
    }
    $resolved = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (!$resolved.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "FREEZE_PREP_BLOCKED: path escapes repository: $RelativePath"
    }
    return $resolved
}

try {
    Set-Location -LiteralPath $repositoryRoot

    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'FREEZE_PREP_BLOCKED: source index is not clean.'
    }

    $headCommit = (& git rev-parse HEAD | Select-Object -First 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $headCommit -notmatch '^[0-9a-f]{40}$') {
        throw 'FREEZE_PREP_BLOCKED: cannot resolve exact source HEAD.'
    }
    $headTree = (& git rev-parse 'HEAD^{tree}' | Select-Object -First 1).Trim()
    if ($LASTEXITCODE -ne 0 -or $headTree -notmatch '^[0-9a-f]{40}$') {
        throw 'FREEZE_PREP_BLOCKED: cannot resolve exact source HEAD tree.'
    }
    $branch = (& git branch --show-current | Select-Object -First 1).Trim()

    $resolvedManifest = Assert-RepositoryChildPath -RelativePath $ManifestPath.Replace('\', '/')
    if (!(Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
        throw "FREEZE_PREP_BLOCKED: classification manifest is missing: $ManifestPath"
    }
    $manifestSha256 = (Get-FileHash -LiteralPath $resolvedManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json
    if ([int]$manifest.schema_version -ne 1) {
        throw 'FREEZE_PREP_BLOCKED: unsupported classification-manifest schema.'
    }
    if ([IO.Path]::GetFullPath([string]$manifest.repository_root) -ne [IO.Path]::GetFullPath($repositoryRoot)) {
        throw 'FREEZE_PREP_BLOCKED: classification manifest belongs to another repository.'
    }

    $statusLines = @(& git -c core.quotePath=false status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw 'FREEZE_PREP_BLOCKED: git status failed.'
    }

    $currentStatusByPath = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }
        $status = $line.Substring(0, 2)
        if ($status -match '[URCT]' -or $status -in @('AA', 'DD')) {
            throw "FREEZE_PREP_BLOCKED: unsupported conflict, rename, or copy status: $status"
        }
        $path = Normalize-StatusPath -RawPath $line.Substring(3)
        [void](Assert-RepositoryChildPath -RelativePath $path)
        if (!$currentStatusByPath.TryAdd($path, $status)) {
            throw "FREEZE_PREP_BLOCKED: duplicate current status path: $path"
        }
    }

    $entries = @($manifest.entries)
    if ([int]$manifest.git_repository.status_entries -ne $entries.Count) {
        throw 'FREEZE_PREP_BLOCKED: manifest status count is internally inconsistent.'
    }
    if ($entries.Count -ne $currentStatusByPath.Count) {
        throw "FREEZE_PREP_BLOCKED: manifest/current status counts differ ($($entries.Count) vs $($currentStatusByPath.Count))."
    }

    $manifestByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $operationByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $includePaths = [Collections.Generic.List[string]]::new()
    $excludePaths = [Collections.Generic.List[string]]::new()
    $stateLines = [Collections.Generic.List[string]]::new()

    foreach ($entry in $entries) {
        $path = ([string]$entry.path).Replace('\', '/')
        $absolutePath = Assert-RepositoryChildPath -RelativePath $path
        if (!$manifestByPath.TryAdd($path, $entry)) {
            throw "FREEZE_PREP_BLOCKED: duplicate manifest path: $path"
        }
        if (!$currentStatusByPath.ContainsKey($path)) {
            throw "FREEZE_PREP_BLOCKED: manifest path is absent from current status: $path"
        }
        if ([string]$entry.git_status -ne $currentStatusByPath[$path]) {
            throw "FREEZE_PREP_BLOCKED: status changed after classification: $path"
        }

        $decision = [string]$entry.decision
        if ($decision -notin @('INCLUDE', 'EXCLUDE')) {
            throw "FREEZE_PREP_BLOCKED: unresolved decision for $path"
        }

        $exists = Test-Path -LiteralPath $absolutePath -PathType Leaf
        if ($exists -ne [bool]$entry.exists) {
            throw "FREEZE_PREP_BLOCKED: source existence changed after classification: $path"
        }
        $hashAlgorithm = [string]$entry.content_hash.algorithm
        $expectedHash = ([string]$entry.content_hash.value).ToLowerInvariant()
        if ($exists) {
            $item = Get-Item -LiteralPath $absolutePath
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "FREEZE_PREP_BLOCKED: symbolic/reparse source is unsupported: $path"
            }
            if ($hashAlgorithm -ne 'sha256') {
                throw "FREEZE_PREP_BLOCKED: present source lacks SHA-256: $path"
            }
            $actualHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualHash -ne $expectedHash) {
                throw "FREEZE_PREP_BLOCKED: source bytes changed after classification: $path"
            }
        } else {
            if ($currentStatusByPath[$path] -notmatch 'D') {
                throw "FREEZE_PREP_BLOCKED: missing source is not an explicit deletion: $path"
            }
            if ($hashAlgorithm -ne 'git-object-sha1') {
                throw "FREEZE_PREP_BLOCKED: deletion lacks its HEAD blob identity: $path"
            }
            $treeLine = (& git ls-tree HEAD -- $path | Select-Object -First 1)
            if (!$treeLine -or $treeLine -notmatch '^[0-9]+\s+blob\s+([0-9a-f]{40})\t') {
                throw "FREEZE_PREP_BLOCKED: deleted path is not a HEAD blob: $path"
            }
            if ($Matches[1] -ne $expectedHash) {
                throw "FREEZE_PREP_BLOCKED: deleted HEAD blob changed after classification: $path"
            }
        }

        [void]$stateLines.Add("$decision`t$exists`t$hashAlgorithm`:$expectedHash`t$path")
        if ($decision -eq 'INCLUDE') {
            [void]$includePaths.Add($path)
            $operation = [pscustomobject][ordered]@{
                    path = $path
                    operation = if ($exists) { 'copy' } else { 'delete' }
                    content_hash = [ordered]@{
                        algorithm = $hashAlgorithm
                        value = $expectedHash
                    }
                }
            if (!$operationByPath.TryAdd($path, $operation)) {
                throw "FREEZE_PREP_BLOCKED: duplicate INCLUDE operation: $path"
            }
        } else {
            [void]$excludePaths.Add($path)
        }
    }

    if ($manifestByPath.Count -ne $currentStatusByPath.Count) {
        $newPaths = @($currentStatusByPath.Keys | Where-Object { !$manifestByPath.ContainsKey($_) })
        throw "FREEZE_PREP_BLOCKED: current status has $($newPaths.Count) path(s) absent from manifest."
    }

    $headByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $headLines = @(& git -c core.quotePath=false ls-tree -r --full-tree HEAD)
    if ($LASTEXITCODE -ne 0) {
        throw 'FREEZE_PREP_BLOCKED: cannot enumerate the full HEAD tree.'
    }
    foreach ($line in $headLines) {
        if ($line -notmatch '^([0-9]{6})\s+blob\s+([0-9a-f]{40})\t(.+)$') {
            throw "FREEZE_PREP_BLOCKED: unsupported non-blob HEAD entry: $line"
        }
        $path = Normalize-StatusPath -RawPath $Matches[3]
        [void](Assert-RepositoryChildPath -RelativePath $path)
        $headEntry = [pscustomobject][ordered]@{
            mode = $Matches[1]
            oid = $Matches[2]
        }
        if (!$headByPath.TryAdd($path, $headEntry)) {
            throw "FREEZE_PREP_BLOCKED: duplicate HEAD path: $path"
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
                throw "FREEZE_PREP_BLOCKED: INCLUDE deletion is absent from HEAD: $path"
            }
            continue
        }
        $mode = if ($headByPath.ContainsKey($path)) {
            [string]$headByPath[$path].mode
        } else {
            '100644'
        }
        $fullExpectedByPath[$path] = [pscustomobject][ordered]@{
            mode = $mode
            algorithm = [string]$operation.content_hash.algorithm
            value = [string]$operation.content_hash.value
        }
    }

    $statusPaths = @($currentStatusByPath.Keys)
    $classifierPath = Join-Path $repositoryRoot 'tool\release_hygiene\release_source_staging_dry_run.ps1'
    $classifierSha256 = (Get-FileHash -LiteralPath $classifierPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $includePathsetSha256 = Get-LineSetSha256 -Lines @($includePaths)
    $excludePathsetSha256 = Get-LineSetSha256 -Lines @($excludePaths)
    $statusPathsetSha256 = Get-LineSetSha256 -Lines $statusPaths
    $sourceStateSha256 = Get-LineSetSha256 -Lines @($stateLines)
    $fullExpectedPaths = @($fullExpectedByPath.Keys)
    $fullExpectedStateLines = @(
        $fullExpectedPaths | ForEach-Object {
            $entry = $fullExpectedByPath[$_]
            "$($entry.mode)`t$($entry.algorithm):$($entry.value)`t$_"
        }
    )
    $fullExpectedPathsetSha256 = Get-LineSetSha256 -Lines $fullExpectedPaths
    $fullExpectedStateSha256 = Get-LineSetSha256 -Lines $fullExpectedStateLines
    $orderedExcludePaths = @(Get-OrdinalSortedStrings -Values @($excludePaths))
    $orderedOperations = @(
        Get-OrdinalSortedStrings -Values @($includePaths) |
            ForEach-Object { $operationByPath[$_] }
    )

    $plan = [ordered]@{
        schema_version = 1
        invariant = 'Read-only preparation. This plan creates no worktree and performs no copy, delete, stage, commit, build, upload, reset, clean, or stash operation.'
        source = [ordered]@{
            repository_root = $repositoryRoot
            branch = $branch
            head_commit = $headCommit
            head_tree = $headTree
            classification_manifest_path = $ManifestPath.Replace('\', '/')
            classification_manifest_sha256 = $manifestSha256
            classifier_sha256 = $classifierSha256
            status_entries = $statusPaths.Count
            status_pathset_sha256 = $statusPathsetSha256
            source_state_sha256 = $sourceStateSha256
        }
        candidate = [ordered]@{
            base_commit = $headCommit
            base_tree = $headTree
            head_paths = $headByPath.Count
            include_paths = $includePaths.Count
            include_pathset_sha256 = $includePathsetSha256
            full_expected_paths = $fullExpectedPaths.Count
            full_expected_pathset_sha256 = $fullExpectedPathsetSha256
            full_expected_state_sha256 = $fullExpectedStateSha256
            finalization_path = 'docs/release/BIL_PLUS8_FROZEN_SOURCE_MANIFEST_2026-09-06.md'
            operations = $orderedOperations
        }
        preserve_only = [ordered]@{
            exclude_paths = $excludePaths.Count
            exclude_pathset_sha256 = $excludePathsetSha256
            paths = $orderedExcludePaths
        }
    }

    if ($EmitJson) {
        $plan | ConvertTo-Json -Depth 10
    } else {
        Write-Host "CLEAN_FREEZE_HEAD=$headCommit"
        Write-Host "CLEAN_FREEZE_HEAD_TREE=$headTree"
        Write-Host "CLEAN_FREEZE_STATUS_PATHS=$($statusPaths.Count)"
        Write-Host "CLEAN_FREEZE_STATUS_PATHSET_SHA256=$statusPathsetSha256"
        Write-Host "CLEAN_FREEZE_SOURCE_STATE_SHA256=$sourceStateSha256"
        Write-Host "CLEAN_FREEZE_INCLUDE=$($includePaths.Count)"
        Write-Host "CLEAN_FREEZE_INCLUDE_PATHSET_SHA256=$includePathsetSha256"
        Write-Host "CLEAN_FREEZE_FULL_PATHS=$($fullExpectedPaths.Count)"
        Write-Host "CLEAN_FREEZE_FULL_PATHSET_SHA256=$fullExpectedPathsetSha256"
        Write-Host "CLEAN_FREEZE_FULL_STATE_SHA256=$fullExpectedStateSha256"
        Write-Host "CLEAN_FREEZE_EXCLUDE=$($excludePaths.Count)"
        Write-Host "CLEAN_FREEZE_EXCLUDE_PATHSET_SHA256=$excludePathsetSha256"
        Write-Host 'CLEAN_SOURCE_FREEZE_PREPARATION=PASS'
    }
} finally {
    Set-Location -LiteralPath $previousLocation
}
