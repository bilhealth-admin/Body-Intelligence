param([string]$ProjectRef='tgmanzhqulksykhslrzb')
$ErrorActionPreference='Stop'
$base="https://$ProjectRef.supabase.co";$uid=$null;$result=$null;$cleaned=$false
function Invoke-DbQuery([string]$Sql){
  $old=$ErrorActionPreference;$ErrorActionPreference='Continue'
  try{$raw=(& npx --yes supabase@latest db query --linked $Sql 2>$null)-join "`n";$exit=$LASTEXITCODE}finally{$ErrorActionPreference=$old}
  if($exit-ne 0){throw 'database query failed'}
  return $raw|ConvertFrom-Json
}
try{
  $keys=((& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null)-join "`n")|ConvertFrom-Json
  $service=($keys|?{$_.name -eq 'service_role'}|select -First 1).api_key
  if([string]::IsNullOrWhiteSpace($service)){throw 'service key unavailable'}
  $h=@{apikey=$service;Authorization="Bearer $service"}
  $suffix=[guid]::NewGuid().ToString('N');$email="voice-meter-$suffix@bilhealth.invalid";$pw="Bil!${suffix}A9"
  $u=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $h -ContentType application/json -Body (@{email=$email;password=$pw;email_confirm=$true}|ConvertTo-Json);$uid=$u.id
  $now=[DateTime]::UtcNow.ToString('o');$exp=[DateTime]::UtcNow.AddHours(1).ToString('o')
  $sql="insert into public.bil_ai_coach_subscriptions(owner_id,provider,product_id,lifecycle,original_transaction_id,latest_transaction_id,expires_at,verified_at) values ('$uid','google','bil_ai_coach_metering_only','trial','voice-$suffix','voice-$suffix','$exp','$now')"
  $old=$ErrorActionPreference;$ErrorActionPreference='Continue'
  try{& npx --yes supabase@latest db query --linked $sql 2>$null|Out-Null;$exit=$LASTEXITCODE}finally{$ErrorActionPreference=$old}
  if($exit-ne 0){throw 'temporary entitlement insert failed'}
  $rid="bilvoice$([guid]::NewGuid().ToString('N'))"
  $reserve=Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_reserve_ai_voice" -Headers $h -ContentType application/json -Body (@{p_owner_id=$uid;p_request_id=$rid;p_estimated_seconds=120}|ConvertTo-Json)
  $settle=Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_settle_ai_voice" -Headers $h -ContentType application/json -Body (@{p_owner_id=$uid;p_request_id=$rid;p_succeeded=$true;p_actual_seconds=37;p_provider='gemini';p_model='voice-meter-contract';p_input_tokens=10;p_output_tokens=5;p_latency_ms=1234;p_cost_usd=0.001}|ConvertTo-Json)
  $event=(Invoke-DbQuery "select state,reserved_seconds,actual_seconds,weekly_debit,paid_debit from public.bil_ai_usage_events where owner_id='$uid' and request_id='$rid'").rows[0]
  $usage=(Invoke-DbQuery "select used,reserved from public.bil_ai_weekly_usage where owner_id='$uid' and capability='voice' order by week_start desc limit 1").rows[0]
  $result=[pscustomobject]@{success=($settle.state-eq'succeeded');estimated_seconds=120;actual_seconds=[int]$event.actual_seconds;weekly_used_minutes=[double]$usage.used;weekly_reserved_minutes=[double]$usage.reserved;paid_debit_minutes=[double]$event.paid_debit}
}finally{
  if($uid){try{Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$uid" -Headers $h|Out-Null;$cleaned=$true}catch{}}
  Remove-Variable service,keys,pw -ErrorAction SilentlyContinue
}
$result|Add-Member -NotePropertyName cleanup -NotePropertyValue $cleaned
$result|ConvertTo-Json
