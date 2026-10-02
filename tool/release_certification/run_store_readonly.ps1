param([Parameter(Mandatory=$true)][string]$OutputDir)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$required=@('APP_STORE_CONNECT_KEY_ID','APP_STORE_CONNECT_ISSUER_ID','APP_STORE_CONNECT_PRIVATE_KEY_BASE64','GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64')
$missing=@($required | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_)) })
if($missing.Count -gt 0){
  'STORE_READONLY=NOT RUN' | Set-Content (Join-Path $OutputDir 'status.txt')
  "Missing: $($missing -join ', ')" | Set-Content (Join-Path $OutputDir 'not-run.txt')
  exit 0
}
$driveRoot=Join-Path $env:RUNNER_TEMP 'bil-store-drive'
New-Item -ItemType Directory -Force -Path $driveRoot | Out-Null
subst G: $driveRoot
try {
  New-Item -ItemType Directory -Force -Path 'G:\\secret','G:\\evidence' | Out-Null
  [IO.File]::WriteAllBytes('G:\\secret\\asc.p8',[Convert]::FromBase64String($env:APP_STORE_CONNECT_PRIVATE_KEY_BASE64))
  [IO.File]::WriteAllBytes('G:\\secret\\google.json',[Convert]::FromBase64String($env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64))
  $env:ASC_KEY_ID=$env:APP_STORE_CONNECT_KEY_ID
  $env:ASC_ISSUER_ID=$env:APP_STORE_CONNECT_ISSUER_ID
  $env:ASC_PRIVATE_KEY_PATH='G:\\secret\\asc.p8'
  node tool/apple_store_connect/asc_v1_final_audit.mjs --output 'G:\\evidence\\apple-v1.json'
  if($LASTEXITCODE -ne 0){ throw 'Apple read-only audit failed' }
  node tool/google_play/google_play_release_surface_readonly_audit.mjs --credentials 'G:\\secret\\google.json' --output 'G:\\evidence\\google-release.json'
  if($LASTEXITCODE -ne 0){ throw 'Google read-only audit failed' }
  Remove-Item -LiteralPath 'G:\\secret' -Recurse -Force
  Copy-Item -Path 'G:\\evidence\\*' -Destination $OutputDir -Force
  'STORE_READONLY=PASS' | Set-Content (Join-Path $OutputDir 'status.txt')
} finally {
  Remove-Item -LiteralPath 'G:\\secret' -Recurse -Force -ErrorAction SilentlyContinue
  subst G: /D | Out-Null
}
