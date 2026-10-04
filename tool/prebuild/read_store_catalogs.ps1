param([Parameter(Mandatory=$true)][string]$OutputDir)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$sha=(git rev-parse HEAD).Trim()
$state=[ordered]@{source=$sha;apple='NOT_RUN';google='NOT_RUN';appBuild=$false;storeUpload=$false;storeEditCreated=$false}
$root=Join-Path $env:RUNNER_TEMP 'bil-prebuild-store-readonly-drive'
New-Item -ItemType Directory -Force -Path $root | Out-Null
if(Test-Path 'G:\'){throw 'G: already exists; refusing to reuse a drive'}
subst G: $root
if($LASTEXITCODE -ne 0){throw 'Cannot create isolated evidence drive'}
try {
  New-Item -ItemType Directory -Force -Path 'G:\secret','G:\evidence' | Out-Null
  $appleNames=@('APP_STORE_CONNECT_KEY_ID','APP_STORE_CONNECT_ISSUER_ID','APP_STORE_CONNECT_PRIVATE_KEY_BASE64')
  $appleMissing=@($appleNames | Where-Object {[string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))})
  if($appleMissing.Count -eq 0){
    [IO.File]::WriteAllBytes('G:\secret\asc.p8',[Convert]::FromBase64String($env:APP_STORE_CONNECT_PRIVATE_KEY_BASE64))
    $env:ASC_KEY_ID=$env:APP_STORE_CONNECT_KEY_ID
    $env:ASC_ISSUER_ID=$env:APP_STORE_CONNECT_ISSUER_ID
    $env:ASC_PRIVATE_KEY_PATH='G:\secret\asc.p8'
    node tool/apple_store_connect/asc_v1_final_audit.mjs --output 'G:\evidence\apple.json'
    $state.apple=if($LASTEXITCODE -eq 0){'READ_COMPLETED_NOT_DEVICE_VERIFIED'}else{'READ_FAILED'}
  } else {
    $state.apple='NOT_RUN_MISSING_CREDENTIALS'
  }
  if(-not [string]::IsNullOrWhiteSpace($env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64)){
    [IO.File]::WriteAllBytes('G:\secret\google.json',[Convert]::FromBase64String($env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64))
    node tool/google_play/google_play_catalog_readonly_audit.mjs --credentials 'G:\secret\google.json' --output 'G:\evidence\google.json' --credential-label 'CI configured account'
    $state.google=if($LASTEXITCODE -eq 0){'READ_COMPLETED_NOT_DEVICE_VERIFIED'}else{'READ_FAILED'}
  } else {
    $state.google='NOT_RUN_MISSING_CREDENTIALS'
  }
  Get-ChildItem 'G:\evidence' -File | Copy-Item -Destination $OutputDir
} finally {
  Remove-Item 'G:\secret' -Recurse -Force -ErrorAction SilentlyContinue
  $state | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputDir 'read-status.json')
  @('NO_APP_BUILD','NO_STORE_UPLOAD','NO_TRANSIENT_EDIT','NO_REVIEWER_CREDENTIAL_VALUES_IN_REPORT','HTTP_READ_COMPLETION_IS_NOT_STORE_READINESS') | Set-Content (Join-Path $OutputDir 'boundary.txt')
  subst G: /D | Out-Null
}
if($state.apple -ne 'READ_COMPLETED_NOT_DEVICE_VERIFIED' -or $state.google -ne 'READ_COMPLETED_NOT_DEVICE_VERIFIED'){exit 1}
