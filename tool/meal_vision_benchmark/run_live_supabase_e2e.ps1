param(
  [string]$ProjectRef = 'tgmanzhqulksykhslrzb',
  [string]$ImagePath = 'assets/images/professional/recipes/egyptian-koshari.png',
  [string]$Locale = 'en'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$resolvedImage = (Resolve-Path (Join-Path $root $ImagePath)).Path
$baseUrl = "https://$ProjectRef.supabase.co"
$userId = $null
$productId = "bil.vision.e2e.$([guid]::NewGuid().ToString('N'))"

function Invoke-DbQuery([string]$Sql) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      $raw = (& npx --yes supabase@latest db query --linked $Sql 2>$null) -join "`n"
      $exitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -eq 0) { return $raw | ConvertFrom-Json }
    if ($attempt -lt 3) { Start-Sleep -Seconds 2 }
  }
  throw 'Supabase database query failed after three attempts.'
}

function Get-HttpFailureBody($Exception) {
  if ($null -eq $Exception.Response) { return $Exception.Message }
  $reader = New-Object System.IO.StreamReader($Exception.Response.GetResponseStream())
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

try {
  # Fetch keys into process memory only. Never print or persist them.
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $keysRaw = (& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null) -join "`n"
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($LASTEXITCODE -ne 0) { throw 'Unable to read project API keys.' }
  $keys = $keysRaw | ConvertFrom-Json
    $serverKey = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
  $publishableKey = ($keys | Where-Object { $_.type -eq 'publishable' } | Select-Object -First 1).api_key
  if ([string]::IsNullOrWhiteSpace($serverKey) -or [string]::IsNullOrWhiteSpace($publishableKey)) {
    throw 'Required server or publishable key is unavailable.'
  }

  $suffix = [guid]::NewGuid().ToString('N')
  $email = "vision-e2e-$suffix@bilhealth.invalid"
  $password = "Bil!$([guid]::NewGuid().ToString('N'))a9"
  $adminHeaders = @{ apikey = $serverKey; Authorization = "Bearer $serverKey" }
  $created = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" `
    -Headers $adminHeaders -UserAgent 'BIL-Server-Validation/1.0' -ContentType 'application/json' `
    -Body (@{ email=$email; password=$password; email_confirm=$true } | ConvertTo-Json)
  $userId = [string]$created.id
  if ([string]::IsNullOrWhiteSpace($userId)) { throw 'Test user creation returned no id.' }

  $now = [DateTime]::UtcNow.ToString('o')
  $expiry = [DateTime]::UtcNow.AddHours(1).ToString('o')
  [void](Invoke-DbQuery "insert into public.bil_ai_coach_subscriptions(owner_id,provider,product_id,lifecycle,original_transaction_id,latest_transaction_id,expires_at,verified_at) values ('$userId','google','bil_ai_coach_benchmark_only','trial','e2e-$suffix','e2e-$suffix','$expiry','$now')")

  $auth = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" `
    -Headers @{ apikey = $publishableKey } -ContentType 'application/json' `
    -Body (@{ email=$email; password=$password } | ConvertTo-Json)
  $accessToken = [string]$auth.access_token
  if ([string]::IsNullOrWhiteSpace($accessToken)) { throw 'Test sign-in returned no access token.' }

  $imageBytes = [IO.File]::ReadAllBytes($resolvedImage)
  $mime = if ($resolvedImage.ToLowerInvariant().EndsWith('.png')) { 'image/png' } else { 'image/jpeg' }
  $payload = @{
    schema_version = 1
    image_base64 = [Convert]::ToBase64String($imageBytes)
    mime_type = $mime
    requested_locale = $Locale
  } | ConvertTo-Json -Compress
  $requestId = "bilvision$([guid]::NewGuid().ToString('N'))"
  $headers = @{
    apikey = $publishableKey
    Authorization = "Bearer $accessToken"
    'x-idempotency-key' = $requestId
  }
  $endpoint = "$baseUrl/functions/v1/analyze-meal"
  try {
    $first = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers `
      -ContentType 'application/json' -Body $payload -TimeoutSec 75
  } catch {
    $failureStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
    $failureBody = Get-HttpFailureBody $_.Exception
    $failureJson = try { $failureBody | ConvertFrom-Json } catch { $null }
    $failedReceiptQuery = Invoke-DbQuery "select state,provider,model,latency_ms,input_tokens,output_tokens,cost_usd,provider_attempts,cost_source from public.bil_ai_usage_events where owner_id='$userId' and capability='vision' and request_id='$requestId'"
    $failedReceipt = $failedReceiptQuery.rows | Select-Object -First 1
    $failedUsageQuery = Invoke-DbQuery "select used,reserved from public.bil_ai_weekly_usage where owner_id='$userId' and capability='vision' order by week_start desc limit 1"
    $failedUsage = $failedUsageQuery.rows | Select-Object -First 1
    [pscustomobject]@{
      success = $false
      http_status = $failureStatus
      error = $failureJson.error
      provider_status = $failureJson.provider_status
      provider_error_code = $failureJson.provider_error_code
      provider_validation_code = $failureJson.provider_validation_code
      provider_validation_reason = $failureJson.provider_validation_reason
      receipt_state = $failedReceipt.state
      provider_attempts = $failedReceipt.provider_attempts
      quota_used = $failedUsage.used
      quota_reserved = $failedUsage.reserved
      refunded = ($failedReceipt.state -eq 'refunded' -and [int]$failedUsage.used -eq 0 -and [int]$failedUsage.reserved -eq 0)
    } | ConvertTo-Json -Depth 5
    return
  }
  $replay = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers `
    -ContentType 'application/json' -Body $payload -TimeoutSec 75

  $duplicateRejected = $false
  $duplicateStatus = $null
  $duplicateCacheHit = $false
  $duplicateCharged = $null
  try {
    $duplicateHeaders = @{
      apikey = $publishableKey
      Authorization = "Bearer $accessToken"
      'x-idempotency-key' = "bilvision$([guid]::NewGuid().ToString('N'))"
    }
    $duplicateResponse = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $duplicateHeaders `
      -ContentType 'application/json' -Body $payload -TimeoutSec 75
    $duplicateStatus = 200
    $duplicateCacheHit = $duplicateResponse.cache.hit -eq $true
    $duplicateCharged = $duplicateResponse.cache.charged -eq $true
  } catch {
    $duplicateStatus = [int]$_.Exception.Response.StatusCode
    $duplicateRejected = $duplicateStatus -eq 409
  }

  $receiptQuery = Invoke-DbQuery "select state,provider,model,latency_ms,input_tokens,output_tokens,cost_usd,provider_attempts,cost_source from public.bil_ai_usage_events where owner_id='$userId' and capability='vision' and request_id='$requestId'"
  $receipt = $receiptQuery.rows | Select-Object -First 1
  $usageQuery = Invoke-DbQuery "select used,reserved from public.bil_ai_weekly_usage where owner_id='$userId' and capability='vision' order by week_start desc limit 1"
  $usage = $usageQuery.rows | Select-Object -First 1

  [pscustomobject]@{
    success = $true
    request_id = $requestId
    candidate_count = @($first.candidates).Count
    provider = $first.provider_metrics.provider
    model = $first.provider_metrics.model_revision
    latency_ms = $receipt.latency_ms
    input_tokens = $receipt.input_tokens
    output_tokens = $receipt.output_tokens
    cost_usd = $receipt.cost_usd
    cost_source = $receipt.cost_source
    provider_attempts = $receipt.provider_attempts
    receipt_state = $receipt.state
    quota_used = $usage.used
    quota_reserved = $usage.reserved
    replay_same_request = ($replay.request_id -eq $first.request_id)
    exact_duplicate_handled = ($duplicateRejected -or ($duplicateCacheHit -and -not $duplicateCharged))
    exact_duplicate_cache_hit = $duplicateCacheHit
    exact_duplicate_charged = $duplicateCharged
    duplicate_image_rejected = $duplicateRejected
    duplicate_status = $duplicateStatus
    requires_review = $true
    auto_logged = $false
  } | ConvertTo-Json -Depth 5
} finally {
  if ($userId) {
    try { Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders -UserAgent 'BIL-Server-Validation/1.0' | Out-Null } catch {}
  }
  try { [void](Invoke-DbQuery "delete from public.bil_store_product_registry where product_id='$productId'") } catch {}
  Remove-Variable serverKey,publishableKey,accessToken,password,keysRaw -ErrorAction SilentlyContinue
}
