param(
    [Parameter(Mandatory = $true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$target = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $target) { throw 'Snapshot destination must be new.' }
if (-not $target.StartsWith('G:\BIL_Project\audit_backups\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Snapshot destination must be inside the explicit BIL audit backup directory.'
}
$null = New-Item -ItemType Directory -Path $target
Push-Location -LiteralPath $repo
try {
    $head = git rev-parse HEAD
    $branch = git branch --show-current
    $status = @(git -c core.quotePath=false status --porcelain=v1 --untracked-files=all)
    $tracked = @(git -c core.quotePath=false diff HEAD --name-only)
    $untracked = @(git -c core.quotePath=false ls-files --others --exclude-standard)
    $paths = @($tracked + $untracked | Sort-Object -Unique)
    $manifest = foreach ($path in $paths) {
        $source = [IO.Path]::GetFullPath((Join-Path $repo $path))
        if (-not $source.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Snapshot path escaped the repository.'
        }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            [pscustomobject]@{ Path = $path; State = 'deleted'; Bytes = 0; SHA256 = '' }
            continue
        }
        $copy = Join-Path (Join-Path $target 'files') $path
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $copy)
        Copy-Item -LiteralPath $source -Destination $copy
        $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -ne $hash) {
            throw "Snapshot verification failed: $path"
        }
        [pscustomobject]@{ Path = $path; State = 'present'; Bytes = (Get-Item -LiteralPath $source).Length; SHA256 = $hash }
    }
    $manifest | Export-Csv -LiteralPath (Join-Path $target 'manifest.csv') -NoTypeInformation -Encoding utf8
    $unstagedPatch = Join-Path $target 'unstaged.patch'
    git diff --binary "--output=$unstagedPatch"
    if ($LASTEXITCODE -ne 0) { throw 'Unstaged patch capture failed.' }
    $stagedPatch = Join-Path $target 'staged.patch'
    git diff --cached --binary "--output=$stagedPatch"
    if ($LASTEXITCODE -ne 0) { throw 'Staged patch capture failed.' }
    $gitIndex = git rev-parse --path-format=absolute --git-path index
    if (Test-Path -LiteralPath $gitIndex) { Copy-Item -LiteralPath $gitIndex -Destination (Join-Path $target 'index.before') }
    [pscustomobject]@{
        Root = $repo; Destination = $target; HEAD = $head; Branch = $branch
        Status = $status; VerifiedFiles = $manifest.Count
        VerifiedBytes = ($manifest | Measure-Object -Property Bytes -Sum).Sum
        ManifestSHA256 = (Get-FileHash -LiteralPath (Join-Path $target 'manifest.csv') -Algorithm SHA256).Hash
    } | ConvertTo-Json -Depth 3 -Compress
} finally {
    Pop-Location
}
