[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 10)]
    [int]$Day,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'android-health-connect',
        'ios-healthkit',
        'apple-watch-via-healthkit',
        'wear-os-via-health-connect',
        'ble-fitness'
    )]
    [string]$Surface,

    [Parameter(Mandatory = $true)]
    [ValidateSet('pass', 'fail', 'blocked')]
    [string]$Outcome,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceLabel,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EvidenceFile,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ArtifactPath,

    [string]$Notes = '',

    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$soakRoot = Join-Path $projectRoot 'artifacts\qa\physical_10_day_soak'
$statePath = Join-Path $soakRoot 'soak_state.json'
$today = (Get-Date).Date
$requiredSurfaces = @(
    'android-health-connect',
    'ios-healthkit',
    'apple-watch-via-healthkit',
    'wear-os-via-health-connect',
    'ble-fitness'
)

if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) {
    throw 'ArtifactPath must be the real signed mobile artifact used by the physical test.'
}
$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath -ErrorAction Stop).Path
$artifactExtension = [System.IO.Path]::GetExtension($resolvedArtifact).ToLowerInvariant()
$expectedExtensions = switch ($Surface) {
    'ios-healthkit' { @('.ipa') }
    'apple-watch-via-healthkit' { @('.ipa') }
    'android-health-connect' { @('.apk', '.aab') }
    'wear-os-via-health-connect' { @('.apk', '.aab') }
    'ble-fitness' { @('.apk', '.aab', '.ipa') }
}
if ($artifactExtension -notin $expectedExtensions) {
    throw "ArtifactPath extension $artifactExtension is invalid for $Surface. Expected: $($expectedExtensions -join ', ')."
}

$resolvedEvidence = $null
if (-not $PreflightOnly) {
    $resolvedEvidence = (Resolve-Path -LiteralPath $EvidenceFile -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf)) {
        throw 'EvidenceFile must be a real file captured from the physical test.'
    }
}

$records = @()
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $document = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $records = @($document.records)
}

if ($records.Count -ne ($Day - 1)) {
    throw "Day $Day must follow exactly $($records.Count) recorded day(s)."
}
if (@($records | Where-Object { [int]$_.day -eq $Day }).Count -gt 0) {
    throw "Day $Day is already recorded; soak evidence is append-only."
}
if ($records.Count -gt 0) {
    $previousDate = [datetime]::ParseExact(
        [string]$records[-1].local_date,
        'yyyy-MM-dd',
        [Globalization.CultureInfo]::InvariantCulture
    )
    if ($today -le $previousDate.Date) {
        throw 'Each soak day must be recorded on a later real calendar date.'
    }
}

if ($Day -eq 10) {
    $firstDate = [datetime]::ParseExact(
        [string]$records[0].local_date,
        'yyyy-MM-dd',
        [Globalization.CultureInfo]::InvariantCulture
    )
    if (($today - $firstDate.Date).TotalDays -lt 9) {
        throw 'Day 10 cannot close before nine full date boundaries after day 1.'
    }
}

$artifactHash = (Get-FileHash -LiteralPath $resolvedArtifact -Algorithm SHA256).Hash
if ($PreflightOnly) {
    Write-Host 'PHYSICAL_SOAK_PREFLIGHT=PASS'
    Write-Host "NEXT_DAY=$Day"
    Write-Host "SURFACE=$Surface"
    Write-Host "ARTIFACT_SHA256=$artifactHash"
    Write-Host 'STATE_MUTATED=False'
    exit 0
}

$evidenceHash = (Get-FileHash -LiteralPath $resolvedEvidence -Algorithm SHA256).Hash
$record = [ordered]@{
    day = $Day
    local_date = $today.ToString('yyyy-MM-dd')
    recorded_at_utc = [datetime]::UtcNow.ToString('o')
    surface = $Surface
    outcome = $Outcome
    device_label = $DeviceLabel.Trim()
    evidence_file = $resolvedEvidence
    evidence_sha256 = $evidenceHash
    artifact_path = $resolvedArtifact
    artifact_sha256 = $artifactHash
    notes = $Notes.Trim()
}
$records += [pscustomobject]$record

$coveredSurfaces = @(
    $records |
        Where-Object outcome -eq 'pass' |
        ForEach-Object surface |
        Sort-Object -Unique
)
$missingSurfaces = @(
    $requiredSurfaces |
        Where-Object { $_ -notin $coveredSurfaces }
)
$isComplete = (
    $records.Count -eq 10 -and
    @($records | Where-Object outcome -ne 'pass').Count -eq 0 -and
    $missingSurfaces.Count -eq 0
)

New-Item -ItemType Directory -Path $soakRoot -Force | Out-Null
$payload = [ordered]@{
    schema_version = 2
    required_days = 10
    required_surfaces = $requiredSurfaces
    covered_surfaces = $coveredSurfaces
    missing_surfaces = $missingSurfaces
    records = $records
    complete = $isComplete
}
$temporaryPath = "$statePath.tmp"
$payload | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath $temporaryPath -Encoding UTF8
Move-Item -LiteralPath $temporaryPath -Destination $statePath -Force

Write-Host 'PHYSICAL_SOAK_DAY_RECORDED=True'
Write-Host "DAY=$Day"
Write-Host "OUTCOME=$Outcome"
Write-Host "COMPLETE=$($payload.complete)"
Write-Host "COVERED_SURFACES=$($coveredSurfaces -join ',')"
Write-Host "MISSING_SURFACES=$($missingSurfaces -join ',')"
Write-Host "STATE=$statePath"
