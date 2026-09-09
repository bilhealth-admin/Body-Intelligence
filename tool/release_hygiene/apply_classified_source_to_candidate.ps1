[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$CandidateRoot,
    [Parameter(Mandatory)][string]$CandidateBaseCommit,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$candidateResolved = (Resolve-Path -LiteralPath $CandidateRoot).Path
$manifestResolved = [IO.Path]::GetFullPath((Join-Path $sourceRoot $ManifestPath))
$temporaryIndex = [IO.Path]::GetTempFileName()
$pathspecFile = [IO.Path]::GetTempFileName()
$previousIndex = $env:GIT_INDEX_FILE

function Normalize-Path {
    param([Parameter(Mandatory)][string]$RawPath)
    $path = $RawPath.Trim('"').Replace('\', '/')
    if ([IO.Path]::IsPathRooted($path) -or $path -match '(^|/)\.\.(/|$)') {
        throw "CANDIDATE_TRANSFER_BLOCKED: unsafe path: $RawPath"
    }
    return $path
}

try {
    if (!(Test-Path -LiteralPath $manifestResolved -PathType Leaf)) {
        throw "CANDIDATE_TRANSFER_BLOCKED: manifest missing: $ManifestPath"
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestResolved | ConvertFrom-Json
    if ([int]$manifest.schema_version -ne 1) {
        throw 'CANDIDATE_TRANSFER_BLOCKED: unsupported manifest schema.'
    }
    if ([IO.Path]::GetFullPath([string]$manifest.repository_root) -ne [IO.Path]::GetFullPath($sourceRoot)) {
        throw 'CANDIDATE_TRANSFER_BLOCKED: manifest belongs to another source worktree.'
    }

    $candidateGitRoot = (& git -C $candidateResolved rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($candidateGitRoot) -ne [IO.Path]::GetFullPath($candidateResolved)) {
        throw 'CANDIDATE_TRANSFER_BLOCKED: candidate is not the requested Git worktree root.'
    }
    $candidateHead = (& git -C $candidateResolved rev-parse HEAD).Trim()
    $expectedBase = (& git -C $candidateResolved rev-parse $CandidateBaseCommit).Trim()
    if ($LASTEXITCODE -ne 0 -or $candidateHead -ne $expectedBase) {
        throw "CANDIDATE_TRANSFER_BLOCKED: candidate HEAD is $candidateHead, expected $expectedBase."
    }
    if (@(& git -C $candidateResolved -c core.quotepath=false status --porcelain=v1 -uall).Count -ne 0) {
        throw 'CANDIDATE_TRANSFER_BLOCKED: candidate worktree is not clean before transfer.'
    }

    # Verify every manifest status, hash and deletion before creating a patch.
    & (Join-Path $PSScriptRoot 'prepare_clean_source_freeze.ps1') -ManifestPath $ManifestPath | Out-Null

    $includePaths = @(
        $manifest.entries |
            Where-Object { $_.decision -eq 'INCLUDE' } |
            ForEach-Object { Normalize-Path -RawPath ([string]$_.path) } |
            Sort-Object -Unique
    )
    $declaredIncludeCount = @($manifest.entries | Where-Object { $_.decision -eq 'INCLUDE' }).Count
    if ($includePaths.Count -ne $declaredIncludeCount) {
        throw 'CANDIDATE_TRANSFER_BLOCKED: duplicate INCLUDE path.'
    }

    # Use a private temporary index. The user's real source index is untouched.
    Remove-Item -LiteralPath $temporaryIndex -Force
    $env:GIT_INDEX_FILE = $temporaryIndex
    & git -C $sourceRoot read-tree HEAD
    if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_TRANSFER_BLOCKED: temporary index initialization failed.' }
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllBytes($pathspecFile, $utf8.GetBytes(($includePaths -join "`0") + "`0"))
    # -f is bounded by the exact manifest pathspec and is required for the two
    # already-tracked release-evidence files beneath the ignored artifacts root.
    & git -C $sourceRoot --literal-pathspecs add -f -A "--pathspec-from-file=$pathspecFile" --pathspec-file-nul
    if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_TRANSFER_BLOCKED: exact path staging in temporary index failed.' }
    $sourceHead = (& git -C $sourceRoot rev-parse HEAD).Trim()
    $classifiedTree = (& git -C $sourceRoot write-tree).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_TRANSFER_BLOCKED: classified tree creation failed.' }
    $classifiedCommit = (& git -C $sourceRoot -c user.name='BIL Source Freeze' -c user.email='source-freeze@bil.invalid' commit-tree $classifiedTree -p $sourceHead -m 'BIL classified source transfer').Trim()
    if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_TRANSFER_BLOCKED: virtual commit creation failed.' }

    Write-Host "CANDIDATE_TRANSFER_INCLUDE=$($includePaths.Count)"
    Write-Host "CANDIDATE_TRANSFER_CLASSIFIED_TREE=$classifiedTree"

    # merge-tree computes the real three-way result without touching either
    # worktree. It has sourceHead as the virtual commit parent, so the merge
    # base is explicit and both the TestFlight lineage and new delta survive.
    $mergeOutput = @(& git -C $candidateResolved merge-tree --write-tree --name-only --no-messages $candidateHead $classifiedCommit)
    $mergeExit = $LASTEXITCODE
    if ($mergeExit -ne 0 -or $mergeOutput.Count -eq 0) {
        $conflictPaths = @($mergeOutput | Select-Object -Skip 1 | Where-Object { $_ } | Sort-Object -Unique)
        $detail = @($conflictPaths | Select-Object -First 60) -join ', '
        throw "CANDIDATE_TRANSFER_BLOCKED: merge-tree conflicts=$($conflictPaths.Count): $detail"
    }
    $mergedTree = $mergeOutput[0].Trim()
    if ($mergedTree -notmatch '^[0-9a-f]{40,64}$') {
        throw 'CANDIDATE_TRANSFER_BLOCKED: merge-tree did not return a tree object.'
    }

    $includeSet = [Collections.Generic.HashSet[string]]::new($includePaths, [StringComparer]::Ordinal)
    $unexpected = [Collections.Generic.List[string]]::new()
    foreach ($changedPath in @(& git -C $candidateResolved -c core.quotepath=false diff-tree --no-commit-id --name-only -r $candidateHead $mergedTree)) {
        $path = Normalize-Path -RawPath $changedPath
        if (!$includeSet.Contains($path)) { $unexpected.Add($path) }
    }
    if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_TRANSFER_BLOCKED: merged tree comparison failed.' }
    if ($unexpected.Count -gt 0) {
        throw "CANDIDATE_TRANSFER_BLOCKED: merged tree changed outside INCLUDE: $($unexpected -join ', ')"
    }
    Write-Host "CANDIDATE_TRANSFER_MERGED_TREE=$mergedTree"
    if (!$Apply) {
        Write-Host 'CANDIDATE_TRANSFER_DRY_RUN=PASS'
        return
    }

    & git -C $candidateResolved read-tree --reset -u $mergedTree
    if ($LASTEXITCODE -ne 0) {
        throw 'CANDIDATE_TRANSFER_BLOCKED: merged tree application failed.'
    }

    $unexpected.Clear()
    foreach ($line in @(& git -C $candidateResolved -c core.quotepath=false status --porcelain=v1 -uall)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
        $path = Normalize-Path -RawPath $line.Substring(3)
        if (!$includeSet.Contains($path)) { $unexpected.Add($path) }
    }
    if ($unexpected.Count -gt 0) {
        throw "CANDIDATE_TRANSFER_BLOCKED: candidate changed outside INCLUDE: $($unexpected -join ', ')"
    }
    $unmerged = @(& git -C $candidateResolved diff --name-only --diff-filter=U)
    if ($unmerged.Count -gt 0) {
        throw "CANDIDATE_TRANSFER_BLOCKED: unmerged paths remain: $($unmerged -join ', ')"
    }
    Write-Host 'CANDIDATE_TRANSFER_APPLY=PASS'
} finally {
    if ($null -eq $previousIndex) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue }
    else { $env:GIT_INDEX_FILE = $previousIndex }
    foreach ($temporaryPath in @($temporaryIndex, $pathspecFile)) {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}
