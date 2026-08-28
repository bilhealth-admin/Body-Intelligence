[CmdletBinding()]
param(
    [string]$WranglerPath = 'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_npx\d77349f55c2be1c0\node_modules\.bin\wrangler.cmd'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temporaryRoot = Join-Path $repositoryRoot '.tmp'
New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
$destination = Join-Path $temporaryRoot 'cloudflare_verify_first.mp4'
$expectedSha256 = 'e071b7f8fd7281fcb0c561ab1fb1de3bf84476f132f2a1b2d2964d572bb9ab40'
$expectedBytes = [long]17448393
$remoteObject = 'bil-premium-workouts-2026-v1/workouts/v1/gym-six-month/movements/core-stability-bear-plank-shoulder-tap-technique.mp4'

$resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot).TrimEnd('\') + '\'
$resolvedDestination = [System.IO.Path]::GetFullPath($destination)
if (!$resolvedDestination.StartsWith($resolvedTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Remote verification destination escaped the repository temporary directory.'
}
if (Test-Path -LiteralPath $resolvedDestination) {
    Remove-Item -LiteralPath $resolvedDestination -Force
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $WranglerPath r2 object get $remoteObject --remote --file $resolvedDestination
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($exitCode -ne 0 -or !(Test-Path -LiteralPath $resolvedDestination -PathType Leaf)) {
    throw 'Cloudflare remote sample download failed.'
}
$file = Get-Item -LiteralPath $resolvedDestination
$sha256 = (Get-FileHash -LiteralPath $resolvedDestination -Algorithm SHA256).Hash.ToLowerInvariant()
if ($file.Length -ne $expectedBytes -or $sha256 -ne $expectedSha256) {
    throw "Cloudflare remote sample integrity mismatch: bytes=$($file.Length) sha256=$sha256"
}
Remove-Item -LiteralPath $resolvedDestination -Force
Write-Host "CLOUDFLARE_REMOTE_SAMPLE_PASS bytes=$expectedBytes sha256=$expectedSha256 tempRemoved=true"

