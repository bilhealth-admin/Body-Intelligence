$ErrorActionPreference = 'Stop'

$metadata = Get-Content 'G:\BIL_Secrets\Apple\BIL_Store_Manager.metadata.json' -Raw | ConvertFrom-Json
$env:ASC_KEY_ID = $metadata.keyId
$env:ASC_ISSUER_ID = $metadata.issuerId
$env:ASC_PRIVATE_KEY_PATH = $metadata.privateKeyPath

$outputDirectory = 'G:\BIL_Project\body_intelligence_log\artifacts\release\apple\2026-08-30-final-audit'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
try {
  node tool/apple_store_connect/asc_v1_final_audit.mjs --output "$outputDirectory\v1-metadata.json" 2>&1 |
    Set-Content -Encoding utf8 "$outputDirectory\v1.log"
  if ($LASTEXITCODE -ne 0) { throw "v1 audit failed with exit code $LASTEXITCODE" }
  Set-Content -Encoding utf8 "$outputDirectory\v1-complete.txt" ((Get-Date).ToUniversalTime().ToString('o'))
} catch {
  Set-Content -Encoding utf8 "$outputDirectory\v1-error.txt" ($_ | Out-String)
  exit 1
}
