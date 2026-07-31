param([string]$ProjectRoot = (Get-Location).Path)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Draft = Join-Path $ProjectRoot "docs\apple_preparation\PRIVACY_POLICY_DRAFT.md"
if (-not (Test-Path -LiteralPath $Draft -PathType Leaf)) { throw "Privacy policy draft missing: $Draft" }
$Text = [System.IO.File]::ReadAllText($Draft)
$Required = @("health", "delete", "retention", "security", "contact")
$Missing = @()
foreach ($Term in $Required) { if (-not $Text.ToLowerInvariant().Contains($Term)) { $Missing += $Term } }

$Pattern = '(?i)\b(TODO|TBD|PLACEHOLDER)\b|example\.com|your email|insert (name|email|url)|\[(INSERT|YOUR|COMPANY|LEGAL|CONTACT|EMAIL|URL)[^\]]*\]'
$Hits = @()
$Lines = $Text -split "`r?`n"
for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
    foreach ($Match in [regex]::Matches($Lines[$Index], $Pattern)) {
        $Hits += [ordered]@{ line = $Index + 1; token = $Match.Value }
        Write-Host "PLACEHOLDER_MATCH Line=$($Index + 1) Token=$($Match.Value)"
    }
}

$DraftHash = (Get-FileHash -LiteralPath $Draft -Algorithm SHA256).Hash
$Status = if ($Missing.Count -eq 0 -and $Hits.Count -eq 0) { "CONTENT_READY_FOR_LEGAL_REVIEW" } else { "REVISION_REQUIRED_BEFORE_PUBLICATION" }
$EvidenceRoot = Join-Path $ProjectRoot ".bil-package-evidence\external_launch"
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$EvidencePath = Join-Path $EvidenceRoot "BIL-V1-EXTERNAL-LAUNCH-003-privacy-audit.json"
$Evidence = [ordered]@{ status=$Status; draft=$Draft; draft_sha256=$DraftHash; missing_terms=$Missing; placeholder_hits=$Hits; published_url=$null; legal_approval="NOT_CLAIMED"; verified_at_utc=(Get-Date).ToUniversalTime().ToString("o") }
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($EvidencePath, (($Evidence | ConvertTo-Json -Depth 6) + "`n"), $Utf8NoBom)
Write-Host "PRIVACY_CONTENT_STATUS=$Status"
Write-Host "DRAFT_SHA256=$DraftHash"
Write-Host "MISSING_TERMS=$($Missing -join ',')"
Write-Host "PLACEHOLDER_HITS=$($Hits.Count)"
Write-Host "PUBLISHED_URL=NOT_CLAIMED"
Write-Host "LEGAL_APPROVAL=NOT_CLAIMED"
Write-Host "EVIDENCE=$EvidencePath"
