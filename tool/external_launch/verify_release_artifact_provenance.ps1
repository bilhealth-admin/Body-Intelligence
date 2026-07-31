param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ExpectedHead = "113ef663f28c0e55f80d07a79cb6fbde52875036"
$ExpectedBranch = "phase-3-product-excellence"
$ExpectedVersion = "1.0.0+1"
$ExpectedSize = [int64]74229640
$ExpectedSha256 = "0276C0628C9502A9436ACD915D953B5270916B5D883F138A2627E0E4A5821661"
$ArtifactPath = Join-Path $ProjectRoot "build\app\outputs\bundle\release\app-release.aab"

Set-Location $ProjectRoot
$ActualHead = (git rev-parse HEAD).Trim()
$ActualBranch = (git branch --show-current).Trim()
if ($ActualHead -ne $ExpectedHead) { throw "HEAD mismatch. Expected=$ExpectedHead Actual=$ActualHead" }
if ($ActualBranch -ne $ExpectedBranch) { throw "Branch mismatch. Expected=$ExpectedBranch Actual=$ActualBranch" }

$PubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
if (-not (Test-Path -LiteralPath $PubspecPath -PathType Leaf)) { throw "pubspec.yaml is missing." }
$Pubspec = [System.IO.File]::ReadAllText($PubspecPath)
if (-not $Pubspec.Contains("version: $ExpectedVersion")) { throw "Release version mismatch. Expected=$ExpectedVersion" }

if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) {
    throw "Release AAB is missing. Re-run the accepted release build before provenance verification."
}

$Artifact = Get-Item -LiteralPath $ArtifactPath
$ActualSha256 = (Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash
if ($Artifact.Length -ne $ExpectedSize) { throw "AAB size mismatch. Expected=$ExpectedSize Actual=$($Artifact.Length)" }
if ($ActualSha256 -ne $ExpectedSha256) { throw "AAB SHA-256 mismatch. Expected=$ExpectedSha256 Actual=$ActualSha256" }

$EvidenceRoot = Join-Path $ProjectRoot ".bil-package-evidence\external_launch"
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$EvidencePath = Join-Path $EvidenceRoot "BIL-V1-EXTERNAL-LAUNCH-001-$Timestamp.json"
$Evidence = [ordered]@{
    package = "BIL-V1-EXTERNAL-LAUNCH-001"
    gate = "release_artifact_provenance"
    status = "VERIFIED"
    verified_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    repository_head = $ActualHead
    branch = $ActualBranch
    version = $ExpectedVersion
    artifact_path = $ArtifactPath
    artifact_size_bytes = $Artifact.Length
    artifact_sha256 = $ActualSha256
    production_signing = "NOT_CLAIMED"
    store_upload = "NOT_CLAIMED"
    store_approval = "NOT_CLAIMED"
}
$Json = $Evidence | ConvertTo-Json -Depth 4
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($EvidencePath, $Json + "`n", $Utf8NoBom)

Write-Host "ARTIFACT_PROVENANCE=VERIFIED"
Write-Host "EVIDENCE=$EvidencePath"
Write-Host "HEAD=$ActualHead"
Write-Host "VERSION=$ExpectedVersion"
Write-Host "AAB=$ArtifactPath"
Write-Host "AAB_SIZE_BYTES=$($Artifact.Length)"
Write-Host "AAB_SHA256=$ActualSha256"
Write-Host "PRODUCTION_SIGNING=NOT_CLAIMED"
Write-Host "STORE_UPLOAD=NOT_CLAIMED"
Write-Host "STORE_APPROVAL=NOT_CLAIMED"
