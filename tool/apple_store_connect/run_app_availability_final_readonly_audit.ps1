$ErrorActionPreference = 'Stop'
$metadata = Get-Content 'G:\BIL_Secrets\Apple\BIL_Store_Manager.metadata.json' -Raw | ConvertFrom-Json
$env:ASC_KEY_ID = $metadata.keyId
$env:ASC_ISSUER_ID = $metadata.issuerId
$env:ASC_PRIVATE_KEY_PATH = $metadata.privateKeyPath
$outputDirectory = 'G:\BIL_Project\body_intelligence_log\artifacts\release\apple\2026-08-30-final-audit'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
try {
  node tool/apple_store_connect/asc_app_availability_final_audit.mjs --output "$outputDirectory\app-availability.json" 2>&1 |
    Set-Content -Encoding utf8 "$outputDirectory\app-availability.log"
  if ($LASTEXITCODE -ne 0) { throw "app availability audit failed with exit code $LASTEXITCODE" }
  Set-Content -Encoding utf8 "$outputDirectory\app-availability-complete.txt" ((Get-Date).ToUniversalTime().ToString('o'))
} catch {
  Set-Content -Encoding utf8 "$outputDirectory\app-availability-error.txt" ($_ | Out-String)
  exit 1
}
