[CmdletBinding()]
param(
    [int]$PollSeconds = 20,
    [string]$RepositoryRoot,
    [string]$WranglerPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if ([string]::IsNullOrWhiteSpace($WranglerPath)) {
    $WranglerPath = 'C:\Users\HP 1040 G8\AppData\Local\npm-cache\_npx\d77349f55c2be1c0\node_modules\.bin\wrangler.cmd'
}
if ($PollSeconds -lt 10) { throw 'PollSeconds must be at least 10.' }

$logDirectory = Join-Path $RepositoryRoot 'artifacts\cloudflare_media'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$waitLog = Join-Path $logDirectory 'r2_entitlement_wait.log'

function Write-WaitLog([string]$Message) {
    $line = "$(Get-Date -Format o) $Message"
    Add-Content -LiteralPath $waitLog -Value $line -Encoding UTF8
    Write-Host $line
}

$Host.UI.RawUI.WindowTitle = 'BIL Cloudflare R2 upload monitor'
Write-WaitLog 'WAITING_FOR_R2_SUBSCRIPTION Cloudflare dashboard path=Storage & databases > R2 > Overview'
while ($true) {
    $env:WRANGLER_LOG = 'none'
    & $WranglerPath r2 bucket list *> $null
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { break }
    Write-WaitLog "R2_NOT_READY retryInSeconds=$PollSeconds"
    Start-Sleep -Seconds $PollSeconds
}

Write-WaitLog 'R2_READY starting deterministic resumable upload'
$uploader = Join-Path $PSScriptRoot 'Start-CloudflareMediaUpload.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $uploader `
    -RepositoryRoot $RepositoryRoot `
    -WranglerPath $WranglerPath
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-WaitLog 'UPLOAD_FINISHED_OK'
} else {
    Write-WaitLog "UPLOAD_STOPPED exitCode=$exitCode rerun same command to resume"
}
exit $exitCode

