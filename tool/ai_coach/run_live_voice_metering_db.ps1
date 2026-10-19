param([string]$ProjectRef = 'tgmanzhqulksykhslrzb')
$ErrorActionPreference = 'Stop'
$base = "https://$ProjectRef.supabase.co"
$uid = $null
$cleaned = $false
function Invoke-DbQuery([string]$Sql) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { $raw = ($Sql | & npx --yes supabase@latest db query --linked --project-ref $ProjectRef --output-format json 2>$null) -join "`n"; $code = $LASTEXITCODE }
  finally { $ErrorActionPreference = $old }
  if ($code -ne 0) { throw 'Voice metering database query failed' }
  $raw | ConvertFrom-Json
}
try {
  $keys = ((& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null) -join "`n") | ConvertFrom-Json
  $service = ($keys | Where-Object {$_.name -eq 'service_role'} | Select-Object -First 1).api_key
  if ([string]::IsNullOrWhiteSpace($service)) { throw 'Service credential unavailable' }
  $headers = @{apikey=$service; Authorization="Bearer $service"}
  $suffix = [guid]::NewGuid().ToString('N')
  $email = "voice-meter-$suffix@bilhealth.invalid"
  $password = "Bil!${suffix}A9"
  $user = Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $headers -ContentType application/json -Body (@{email=$email;password=$password;email_confirm=$true} | ConvertTo-Json)
  $uid = [string]$user.id
  # Only this disposable identity receives short-lived synthetic test access.
  [void](Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_set_ai_closed_test_access" -Headers $headers -ContentType application/json -Body (@{p_owner_id=$uid;p_cohort='automated-e2e';p_active=$true;p_expires_at=[DateTime]::UtcNow.AddHours(1).ToString('o');p_reason='Disposable voice metering database contract'} | ConvertTo-Json))
  $rid = "bilvoice$([guid]::NewGuid().ToString('N'))"
  [void](Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_reserve_ai_voice" -Headers $headers -ContentType application/json -Body (@{p_owner_id=$uid;p_request_id=$rid;p_estimated_seconds=120} | ConvertTo-Json))
  $body = @{p_owner_id=$uid;p_request_id=$rid;p_succeeded=$true;p_actual_seconds=37;p_provider='gemini';p_model='voice-meter-contract';p_input_tokens=10;p_output_tokens=5;p_latency_ms=1234;p_cost_usd=0.001} | ConvertTo-Json
  $settle = Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_settle_ai_voice" -Headers $headers -ContentType application/json -Body $body
  $duplicate = Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_settle_ai_voice" -Headers $headers -ContentType application/json -Body $body
  $event = (Invoke-DbQuery "select state,reserved_seconds,actual_seconds,credit_actual,credit_paid_debit from public.bil_ai_usage_events where owner_id='$uid' and request_id='$rid'").rows[0]
  $week = (Invoke-DbQuery "select used,reserved from public.bil_ai_credit_weekly_usage where owner_id='$uid' order by week_start desc limit 1").rows[0]
  $month = (Invoke-DbQuery "select used,reserved from public.bil_ai_credit_monthly_usage where owner_id='$uid' order by month_start desc limit 1").rows[0]
  $result = [pscustomobject]@{
    success=($settle.state -eq 'succeeded' -and $duplicate.duplicate -eq $true -and [int]$event.actual_seconds -eq 37 -and [int]$event.credit_actual -eq 10 -and [int]$week.used -eq 10 -and [int]$month.used -eq 10 -and [int]$week.reserved -eq 0 -and [int]$month.reserved -eq 0 -and [int]$event.credit_paid_debit -eq 0)
    scope='Live voice metering DB contract; synthetic provider telemetry, no microphone or provider audio request'
    estimated_seconds=120;actual_seconds=[int]$event.actual_seconds;actual_bil_tokens=[int]$event.credit_actual
    weekly_bil_tokens=[int]$week.used;monthly_bil_tokens=[int]$month.used;duplicate_no_second_debit=($duplicate.duplicate -eq $true)
  }
} finally {
  if ($uid) { try { [void](Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$uid" -Headers $headers); $cleaned=$true } catch {} }
  Remove-Variable service,keys,password -ErrorAction SilentlyContinue
}
$result | Add-Member -NotePropertyName cleanup -NotePropertyValue $cleaned
$result | ConvertTo-Json
if (-not $result.success -or -not $cleaned) { throw 'Voice metering or disposable-user cleanup failed.' }
