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
  if ($null -ne $Exception.Response.Content) {
    return $Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  }
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

  $expiry = [DateTime]::UtcNow.AddHours(1).ToString('o')
  [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_set_ai_closed_test_access" `
    -Headers $adminHeaders -ContentType 'application/json' -Body (@{
      p_owner_id = $userId
      p_cohort = 'automated-meal-vision-e2e'
      p_active = $true
      p_expires_at = $expiry
      p_reason = 'Ephemeral automated meal vision end-to-end verification'
    } | ConvertTo-Json))

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
  $endpoint = "$baseUrl/functions/v1/analyze-meal"
  $consentDeniedRequestId = "bilvisiondenied$([guid]::NewGuid().ToString('N'))"
  $consentDeniedStatus = $null
  $consentDeniedError = $null
  try {
    [void](Invoke-RestMethod -Method Post -Uri $endpoint -Headers @{
        apikey = $publishableKey
        Authorization = "Bearer $accessToken"
        'x-idempotency-key' = $consentDeniedRequestId
      } -ContentType 'application/json' -Body '{}' -TimeoutSec 30)
  } catch {
    $consentDeniedStatus = [int]$_.Exception.Response.StatusCode
    $consentDeniedBody = if ($_.ErrorDetails.Message) {
      $_.ErrorDetails.Message
    } else {
      Get-HttpFailureBody $_.Exception
    }
    $consentDeniedJson = try { $consentDeniedBody | ConvertFrom-Json } catch { $null }
    $consentDeniedError = $consentDeniedJson.error
  }
  if ($consentDeniedStatus -ne 403 -or $consentDeniedError -ne 'meal_vision_ai_consent_required') {
    throw "Meal vision did not fail closed before explicit current consent (status=$consentDeniedStatus error=$consentDeniedError)."
  }
  $deniedUsage = (Invoke-DbQuery "select count(*) as count from public.bil_ai_usage_events where owner_id='$userId' and request_id='$consentDeniedRequestId'").rows | Select-Object -First 1
  if ([int]$deniedUsage.count -ne 0) {
    throw 'Consent-denied meal vision request reached metering/provider work.'
  }

  [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_record_consent" `
    -Headers @{ apikey = $publishableKey; Authorization = "Bearer $accessToken" } `
    -ContentType 'application/json' -Body (@{
      p_purpose = 'meal_vision_ai'
      p_policy_version = '1'
      p_granted = $true
    } | ConvertTo-Json))

  $requestId = "bilvision$([guid]::NewGuid().ToString('N'))"
  $headers = @{
    apikey = $publishableKey
    Authorization = "Bearer $accessToken"
    'x-idempotency-key' = $requestId
  }
  try {
    $first = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers `
      -ContentType 'application/json' -Body $payload -TimeoutSec 75
  } catch {
    $failureStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
    $failureBody = if ($_.ErrorDetails.Message) {
      $_.ErrorDetails.Message
    } else {
      Get-HttpFailureBody $_.Exception
    }
    $failureJson = try { $failureBody | ConvertFrom-Json } catch { $null }
    $failedReceiptQuery = Invoke-DbQuery "select state,provider,model,latency_ms,input_tokens,output_tokens,cost_usd,provider_attempts,cost_source from public.bil_ai_usage_events where owner_id='$userId' and capability='vision' and request_id='$requestId'"
    $failedReceipt = $failedReceiptQuery.rows | Select-Object -First 1
    $failedUsageQuery = Invoke-DbQuery "select used,reserved from public.bil_ai_credit_weekly_usage where owner_id='$userId' order by week_start desc limit 1"
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
  $replaySameRequest = $replay.request_id -eq $first.request_id

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
  $usageQuery = Invoke-DbQuery "select used,reserved from public.bil_ai_credit_weekly_usage where owner_id='$userId' order by week_start desc limit 1"
  $usage = $usageQuery.rows | Select-Object -First 1

  $success = (
    $consentDeniedStatus -eq 403 -and
    $consentDeniedError -eq 'meal_vision_ai_consent_required' -and
    [int]$deniedUsage.count -eq 0 -and
    @($first.candidates).Count -gt 0 -and
    $receipt.state -eq 'succeeded' -and
    [int]$usage.used -gt 0 -and
    [int]$usage.reserved -eq 0 -and
    $replaySameRequest
  )

  [pscustomobject]@{
    success = $success
    consent_denied_status = $consentDeniedStatus
    consent_denied_error = $consentDeniedError
    consent_denied_provider_events = [int]$deniedUsage.count
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
    replay_same_request = $replaySameRequest
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
