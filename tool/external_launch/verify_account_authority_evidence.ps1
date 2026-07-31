param(
    [Parameter(Mandatory = $true)]
    [string]$EvidencePath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
    throw "Account authority evidence file not found: $EvidencePath"
}

$Evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
if ($Evidence.schema_version -ne 1) { throw "Unsupported evidence schema." }
if ($Evidence.gate -ne "legal_owner_and_developer_account_authority") { throw "Wrong evidence gate." }
if ($Evidence.secrets_included -ne $false) { throw "Evidence declares secrets. Remove them before verification." }

$EnrollmentType = [string]$Evidence.owner.enrollment_type
if ($EnrollmentType -notin @("individual", "organization")) { throw "Enrollment type must be individual or organization." }
foreach ($Value in @($Evidence.owner.legal_name, $Evidence.owner.country_or_region)) {
    if ([string]::IsNullOrWhiteSpace([string]$Value) -or ([string]$Value).Contains("REQUIRED")) {
        throw "Legal owner evidence is incomplete."
    }
}

if ($Evidence.google_play.account_status -ne "active") { throw "Google Play developer account is not evidenced as active." }
if ($Evidence.google_play.identity_verification -ne "verified") { throw "Google Play identity verification is incomplete." }
foreach ($Value in @(
    $Evidence.google_play.developer_account_id,
    $Evidence.google_play.payment_reference,
    $Evidence.google_play.evidence_captured_at_utc
)) {
    if ([string]::IsNullOrWhiteSpace([string]$Value) -or ([string]$Value).Contains("REQUIRED")) {
        throw "Google Play authority evidence is incomplete."
    }
}

if ($Evidence.apple_developer.membership_status -ne "active") { throw "Apple Developer membership is not evidenced as active." }
if ($Evidence.apple_developer.account_holder_authority -ne "verified") { throw "Apple Account Holder authority is incomplete." }
if ($Evidence.apple_developer.agreements_status -ne "accepted") { throw "Apple agreements are not evidenced as accepted." }
foreach ($Value in @(
    $Evidence.apple_developer.team_id,
    $Evidence.apple_developer.payment_reference,
    $Evidence.apple_developer.evidence_captured_at_utc
)) {
    if ([string]::IsNullOrWhiteSpace([string]$Value) -or ([string]$Value).Contains("REQUIRED")) {
        throw "Apple Developer authority evidence is incomplete."
    }
}

Write-Host "ACCOUNT_AUTHORITY=VERIFIED"
Write-Host "ENROLLMENT_TYPE=$EnrollmentType"
Write-Host "GOOGLE_PLAY_ACCOUNT=ACTIVE_VERIFIED"
Write-Host "APPLE_DEVELOPER_MEMBERSHIP=ACTIVE_VERIFIED"
Write-Host "SECRETS_INCLUDED=FALSE"
