param([string]$ProjectRef = 'tgmanzhqulksykhslrzb')

$ErrorActionPreference = 'Stop'
$baseUrl = "https://$ProjectRef.supabase.co"
$userId = $null
$authToken = $null
$adminHeaders = $null
$publishableKey = $null
$result = $null
$sessionRevoked = $false
$userDeleted = $false
$cascadeClean = $false

function Invoke-DbQuery([string]$Sql) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $raw = (& npx --yes supabase@latest db query --project-ref $ProjectRef $Sql 2>$null) -join "`n"
    $code = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $old
  }
  if ($code -ne 0) { throw 'Supabase database query failed.' }
  $raw | ConvertFrom-Json
}

function Get-HttpFailureBody($Exception) {
  if ($null -eq $Exception.Response) { return $Exception.Message }
  $reader = [IO.StreamReader]::new($Exception.Response.GetResponseStream())
  try { return $reader.ReadToEnd() }
  finally { $reader.Dispose() }
}

try {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $keysRaw = (& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null) -join "`n"
    $keyExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $old
  }
  if ($keyExit -ne 0) { throw 'Unable to read project API keys.' }
  $keys = $keysRaw | ConvertFrom-Json
  $serverKey = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
  $publishableKey = ($keys | Where-Object { $_.type -eq 'publishable' } | Select-Object -First 1).api_key
  if (-not $publishableKey) {
    $publishableKey = ($keys | Where-Object { $_.name -eq 'anon' } | Select-Object -First 1).api_key
  }
  if (-not $serverKey -or -not $publishableKey) {
    throw 'Required project API keys are unavailable.'
  }

  $suffix = [guid]::NewGuid().ToString('N')
  $email = "coach-e2e-$suffix@bilhealth.invalid"
  $password = "Bil!$([guid]::NewGuid().ToString('N'))a9"
  $adminHeaders = @{ apikey = $serverKey; Authorization = "Bearer $serverKey" }
  $created = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" -Headers $adminHeaders -UserAgent 'BIL-Coach-E2E/1.1' -ContentType 'application/json' -Body (@{
      email = $email
      password = $password
      email_confirm = $true
    } | ConvertTo-Json)
  $userId = [string]$created.id
  $expiry = [DateTime]::UtcNow.AddHours(1).ToString('o')
  [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_set_ai_closed_test_access" -Headers $adminHeaders -ContentType 'application/json' -Body (@{
        p_owner_id = $userId
        p_cohort = 'automated-e2e'
        p_active = $true
        p_expires_at = $expiry
        p_reason = 'Ephemeral automated AI Coach end-to-end verification'
      } | ConvertTo-Json))

  $auth = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" -Headers @{ apikey = $publishableKey } -ContentType 'application/json' -Body (@{
      email = $email
      password = $password
    } | ConvertTo-Json)
  $authToken = [string]$auth.access_token
  $userHeaders = @{ apikey = $publishableKey; Authorization = "Bearer $authToken" }
  [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_record_consent" -Headers $userHeaders -ContentType 'application/json' -Body (@{
        p_purpose = 'remote_ai'
        p_policy_version = '1'
        p_granted = $true
      } | ConvertTo-Json))

  $requestId = "coachlive$([guid]::NewGuid().ToString('N'))"
  $body = @{
    request_id = $requestId
    locale = 'en'
    messages = @(@{
        role = 'user'
        content = 'I weigh 82 kg and my saved goal is 75 kg. How much remains?'
      })
    context = @{
      profile = @{ currentWeightKg = 82; targetWeightKg = 75 }
      computedHealth = @{ kilogramsToGoal = 7; goalDirection = 'lose' }
    }
  } | ConvertTo-Json -Depth 8
  $requestWatch = [Diagnostics.Stopwatch]::StartNew()
  try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/ai-coach" -Headers $userHeaders -ContentType 'application/json' -Body $body -TimeoutSec 45
  }
  catch {
    throw "AI Coach HTTP failure: $(Get-HttpFailureBody $_.Exception)"
  }
  finally {
    $requestWatch.Stop()
  }
  if ([string]$response.response_id -ne $requestId) {
    throw 'AI Coach response ID did not match the metered request ID.'
  }
  if ([int]$response.attempts -ne 1) {
    throw 'Live verification used more than one Gemini provider attempt.'
  }

  $feedbackId = Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_record_ai_coach_feedback" -Headers $userHeaders -ContentType 'application/json' -Body (@{
      p_response_id = $requestId
      p_helpful = $true
      p_reason = $null
      p_locale = 'en'
      p_runtime = 'cloud_personalized'
    } | ConvertTo-Json)

  $duplicateStatus = $null
  try {
    [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/ai-coach" -Headers $userHeaders -ContentType 'application/json' -Body $body -TimeoutSec 45)
  }
  catch {
    $duplicateStatus = [int]$_.Exception.Response.StatusCode
  }
  $event = (Invoke-DbQuery "select state,provider,model,input_tokens,output_tokens,latency_ms,cost_usd,credit_actual,credit_reserved from public.bil_ai_usage_events where owner_id='$userId' and request_id='$requestId'").rows | Select-Object -First 1
  $usage = (Invoke-DbQuery "select used,reserved from public.bil_ai_credit_weekly_usage where owner_id='$userId'").rows | Select-Object -First 1
  $feedback = (Invoke-DbQuery "select feedback_id,helpful,runtime from public.bil_ai_coach_feedback where owner_id='$userId' and response_id='$requestId'").rows | Select-Object -First 1
  if ($event.state -ne 'succeeded' -or [decimal]$event.credit_actual -le 0 -or [decimal]$usage.used -le 0 -or [decimal]$usage.reserved -ne 0) {
    throw 'AI token settlement did not reach the expected succeeded/used>0/reserved=0 state.'
  }
  if ($duplicateStatus -ne 409) { throw 'Duplicate request was not rejected with HTTP 409.' }
  if (-not $feedback -or -not $feedback.helpful -or $feedback.runtime -ne 'cloud_personalized') {
    throw 'Feedback was not correlated to the successful cloud response.'
  }

  $result = [ordered]@{
    success = $true
    request_id = $requestId
    response_id = $response.response_id
    reply = $response.reply
    spoken_reply = $response.spoken_reply
    reason = $response.reason
    confidence = $response.confidence
    provider = $event.provider
    model = $event.model
    input_tokens = $event.input_tokens
    output_tokens = $event.output_tokens
    latency_ms = $event.latency_ms
    http_roundtrip_ms = $requestWatch.ElapsedMilliseconds
    provider_attempts = [int]$response.attempts
    cost_usd = $event.cost_usd
    request_transport = 'text'
    audio_payload_sent = $false
    bil_ai_tokens_used = $event.credit_actual
    quota_used = $usage.used
    quota_reserved = $usage.reserved
    feedback_id = [string]$feedbackId
    duplicate_status = $duplicateStatus
  }
}
finally {
  if ($authToken -and $publishableKey) {
    try {
      [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/logout?scope=global" -Headers @{
          apikey = $publishableKey
          Authorization = "Bearer $authToken"
        })
      $sessionRevoked = $true
    }
    catch { $sessionRevoked = $false }
  }
  if ($userId -and $adminHeaders) {
    try {
      [void](Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders -UserAgent 'BIL-Coach-E2E/1.1')
      $userDeleted = $true
    }
    catch { $userDeleted = $false }
    if ($userDeleted) {
      try {
        $cleanup = (Invoke-DbQuery "select (select count(*) from auth.users where id='$userId') as auth_users,(select count(*) from public.bil_ai_closed_test_grants where owner_id='$userId') as grants,(select count(*) from public.bil_ai_coach_subscriptions where owner_id='$userId') as subscriptions,(select count(*) from public.bil_ai_usage_events where owner_id='$userId') as events,(select count(*) from public.bil_ai_weekly_usage where owner_id='$userId') as usage,(select count(*) from public.bil_ai_credit_weekly_usage where owner_id='$userId') as credit_weekly_usage,(select count(*) from public.bil_ai_credit_monthly_usage where owner_id='$userId') as credit_monthly_usage,(select count(*) from public.bil_ai_credit_balances where owner_id='$userId') as credit_balances,(select count(*) from public.bil_ai_coach_feedback where owner_id='$userId') as feedback,(select count(*) from public.bil_consent_receipts where user_id='$userId') as consents").rows | Select-Object -First 1
        $cascadeClean = ([decimal]$cleanup.auth_users -eq 0) -and
          ([decimal]$cleanup.grants -eq 0) -and
          ([decimal]$cleanup.subscriptions -eq 0) -and
          ([decimal]$cleanup.events -eq 0) -and
          ([decimal]$cleanup.usage -eq 0) -and
          ([decimal]$cleanup.credit_weekly_usage -eq 0) -and
          ([decimal]$cleanup.credit_monthly_usage -eq 0) -and
          ([decimal]$cleanup.credit_balances -eq 0) -and
          ([decimal]$cleanup.feedback -eq 0) -and
          ([decimal]$cleanup.consents -eq 0)
      }
      catch { $cascadeClean = $false }
    }
  }
  Remove-Variable serverKey, publishableKey, password, keysRaw, authToken -ErrorAction SilentlyContinue
}

if ($null -eq $result) { throw 'AI Coach E2E did not produce a result.' }
$result.session_revoked = $sessionRevoked
$result.user_deleted = $userDeleted
$result.cascade_clean = $cascadeClean
if (-not $sessionRevoked -or -not $userDeleted -or -not $cascadeClean) {
  throw 'AI Coach E2E succeeded, but ephemeral-user cleanup verification failed.'
}
$result | ConvertTo-Json -Depth 8
