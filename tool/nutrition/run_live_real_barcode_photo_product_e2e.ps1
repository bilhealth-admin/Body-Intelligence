param(
  [string]$ProjectRef = 'tgmanzhqulksykhslrzb',
  [string]$DeviceId = 'emulator-5554',
  [string]$SupabaseCli = 'G:\BIL_Toolchains\npm-cache\_npx\ade306d1eb8b9835\node_modules\@supabase\cli-windows-x64\bin\supabase.exe',
  [string]$FlutterExe = 'G:\BIL_Toolchains\Flutter\flutter\bin\flutter.bat',
  [string]$TempRoot = 'G:\BIL_QA_TMP\barcode_real_photo_gate',
  [string]$DeviceFixturePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$baseUrl = "https://$ProjectRef.supabase.co"
$userId = $null
$adminHeaders = $null
$entitlementCreated = $false
$entitlementCleaned = $false
$userCleaned = $false
$tempCleaned = $false
$nativeTestPassed = $false
$result = $null

function Get-SafeHttpStatus($ErrorRecord) {
  if ($null -eq $ErrorRecord.Exception.Response) { return 0 }
  [int]$ErrorRecord.Exception.Response.StatusCode
}

function Invoke-WithRetry([scriptblock]$Operation, [int]$Attempts = 3) {
  for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    try { return & $Operation }
    catch {
      $status = Get-SafeHttpStatus $_
      $transient = $status -in @(408, 425, 429, 500, 502, 503, 504)
      if (-not $transient -or $attempt -eq $Attempts) { throw }
      Start-Sleep -Seconds $attempt
    }
  }
  throw 'Retry loop ended without a response.'
}

function Invoke-DbQuery([string]$Sql) {
  $oldErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $raw = (& $SupabaseCli db query --linked $Sql 2>$null) -join "`n"
    $queryExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $oldErrorPreference
  }
  if ($queryExit -ne 0) { throw 'Supabase database query failed.' }
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  $raw | ConvertFrom-Json
}

function Get-SanitizedDiagnosticTail(
  [string]$RawOutput,
  [string[]]$SensitiveValues,
  [int]$MaximumLines = 80
) {
  $sanitized = $RawOutput
  foreach ($sensitiveValue in $SensitiveValues) {
    if (-not [string]::IsNullOrWhiteSpace($sensitiveValue)) {
      $sanitized = $sanitized.Replace($sensitiveValue, '[redacted]')
    }
  }
  $lines = $sanitized -split "`r?`n"
  ($lines | Select-Object -Last $MaximumLines) -join "`n"
}

if (-not (Test-Path -LiteralPath $SupabaseCli -PathType Leaf)) {
  throw 'Pinned Supabase CLI is unavailable on G:.'
}
if (-not (Test-Path -LiteralPath $FlutterExe -PathType Leaf)) {
  throw 'Pinned Flutter executable is unavailable.'
}

$tempRootFull = [IO.Path]::GetFullPath($TempRoot).TrimEnd('\')
if (-not $tempRootFull.StartsWith('G:\BIL_QA_TMP\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Temporary release-gate root must stay under G:\BIL_QA_TMP.'
}
[void](New-Item -ItemType Directory -Path $tempRootFull -Force)
$tempDirectory = [IO.Path]::GetFullPath((Join-Path $tempRootFull ([guid]::NewGuid().ToString('N'))))
if (-not $tempDirectory.StartsWith("$tempRootFull\", [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Resolved temporary directory escaped the release-gate root.'
}
[void](New-Item -ItemType Directory -Path $tempDirectory)
$definePath = Join-Path $tempDirectory 'barcode_gate_defines.json'
$originalTemp = [Environment]::GetEnvironmentVariable('TEMP', 'Process')
$originalTmp = [Environment]::GetEnvironmentVariable('TMP', 'Process')
[Environment]::SetEnvironmentVariable('TEMP', $tempDirectory, 'Process')
[Environment]::SetEnvironmentVariable('TMP', $tempDirectory, 'Process')

try {
  $oldErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $keysRaw = (& $SupabaseCli projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null) -join "`n"
    $keysExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $oldErrorPreference
  }
  if ($keysExit -ne 0) { throw 'Unable to read the project API keys.' }
  $keys = $keysRaw | ConvertFrom-Json
  $serviceKey = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
  $publishableKey = ($keys | Where-Object { $_.type -eq 'publishable' } | Select-Object -First 1).api_key
  if (-not $publishableKey) {
    $publishableKey = ($keys | Where-Object { $_.name -eq 'anon' } | Select-Object -First 1).api_key
  }
  if (-not $serviceKey -or -not $publishableKey) {
    throw 'Required project API keys are unavailable.'
  }

  $suffix = [guid]::NewGuid().ToString('N')
  $email = "barcode-photo-$suffix@bilhealth.invalid"
  $password = "Bil!$([guid]::NewGuid().ToString('N'))a9"
  $adminHeaders = @{
    apikey = $serviceKey
    Authorization = "Bearer $serviceKey"
  }
  $createBody = @{
    email = $email
    password = $password
    email_confirm = $true
  } | ConvertTo-Json
  $created = Invoke-WithRetry -Operation {
    Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" -Headers $adminHeaders -UserAgent 'BIL-Barcode-Photo-E2E/2.0' -ContentType 'application/json' -Body $createBody
  }
  $userId = [string]$created.id

  [void](Invoke-DbQuery "insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id) values ('$userId','plan:premium','e2e-real-barcode-photo','google',true,now()-interval '1 minute',now()+interval '1 hour','e2e-real-barcode-$suffix')")
  $entitlementCreated = $true

  $defines = [ordered]@{
    SUPABASE_URL = $baseUrl
    SUPABASE_ANON_KEY = $publishableKey
    BIL_BARCODE_GATE_EMAIL = $email
    BIL_BARCODE_GATE_PASSWORD = $password
  }
  if (-not [string]::IsNullOrWhiteSpace($DeviceFixturePath)) {
    $defines.BIL_BARCODE_PHOTO_PATH = $DeviceFixturePath
  }
  $defineJson = $defines | ConvertTo-Json
  [IO.File]::WriteAllText(
    $definePath,
    $defineJson,
    [Text.UTF8Encoding]::new($false)
  )

  $oldErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $nativeOutput = (& $FlutterExe test integration_test/real_barcode_photo_integration_test.dart -d $DeviceId "--dart-define-from-file=$definePath" --reporter compact 2>&1) -join "`n"
    $nativeExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $oldErrorPreference
  }
  $nativeTestPassed = $nativeExit -eq 0
  $diagnosticTail = if ($nativeTestPassed) {
    $null
  }
  else {
    Get-SanitizedDiagnosticTail -RawOutput $nativeOutput -SensitiveValues @(
      $serviceKey,
      $publishableKey,
      $password,
      $email
    )
  }
  $result = [pscustomobject]@{
    success = $nativeTestPassed
    native_photo_to_live_gateway = $nativeTestPassed
    device = $DeviceId
    diagnostic = if ($nativeTestPassed) { 'pass' } else { 'native_integration_failed' }
    diagnostic_tail = $diagnosticTail
  }
}
finally {
  [Environment]::SetEnvironmentVariable('TEMP', $originalTemp, 'Process')
  [Environment]::SetEnvironmentVariable('TMP', $originalTmp, 'Process')
  if ($entitlementCreated -and $userId) {
    try {
      [void](Invoke-DbQuery "delete from public.bil_entitlements where owner_id='$userId' and entitlement_id='plan:premium'")
      $entitlementCleaned = $true
    }
    catch {}
  }
  if ($userId -and $adminHeaders) {
    try {
      Invoke-WithRetry -Operation {
        Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders -UserAgent 'BIL-Barcode-Photo-E2E/2.0'
      } | Out-Null
      $userCleaned = $true
    }
    catch {}
  }
  if (Test-Path -LiteralPath $tempDirectory) {
    $resolvedCleanup = [IO.Path]::GetFullPath($tempDirectory)
    if ($resolvedCleanup.StartsWith("$tempRootFull\", [StringComparison]::OrdinalIgnoreCase)) {
      try {
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
        $tempCleaned = $true
      }
      catch {}
    }
  }
  Remove-Variable serviceKey, publishableKey, password, keys, keysRaw, defineJson, nativeOutput -ErrorAction SilentlyContinue
}

if ($null -eq $result) { throw 'Native real-product barcode gate did not produce a result.' }
$result | Add-Member entitlement_cleanup $entitlementCleaned
$result | Add-Member user_cleanup $userCleaned
$result | Add-Member temp_cleanup $tempCleaned
$result | ConvertTo-Json
if (-not $result.success -or -not $entitlementCleaned -or -not $userCleaned -or -not $tempCleaned) { exit 1 }
