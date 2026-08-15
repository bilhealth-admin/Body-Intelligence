param([string]$ProjectRef='tgmanzhqulksykhslrzb')
$ErrorActionPreference='Stop'
$baseUrl="https://$ProjectRef.supabase.co"; $userId=$null
function Invoke-DbQuery([string]$Sql){
  $old=$ErrorActionPreference;$ErrorActionPreference='Continue'
  try{$raw=(& npx --yes supabase@latest db query --linked $Sql 2>$null)-join "`n";$code=$LASTEXITCODE}
  finally{$ErrorActionPreference=$old}
  if($code-ne 0){throw 'Supabase database query failed.'};$raw|ConvertFrom-Json
}
function Get-HttpFailureBody($Exception){
  if($null-eq$Exception.Response){return $Exception.Message}
  $reader=[IO.StreamReader]::new($Exception.Response.GetResponseStream())
  try{return $reader.ReadToEnd()}finally{$reader.Dispose()}
}
try{
  $old=$ErrorActionPreference;$ErrorActionPreference='Continue'
  try{$keysRaw=(& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null)-join "`n"}
  finally{$ErrorActionPreference=$old}
  if($LASTEXITCODE-ne 0){throw 'Unable to read project API keys.'}
  $keys=$keysRaw|ConvertFrom-Json
  $serverKey=($keys|Where-Object {$_.name-eq'service_role'}|Select-Object -First 1).api_key
  $publishableKey=($keys|Where-Object {$_.type-eq'publishable'}|Select-Object -First 1).api_key
  $suffix=[guid]::NewGuid().ToString('N');$email="coach-e2e-$suffix@bilhealth.invalid"
  $password="Bil!$([guid]::NewGuid().ToString('N'))a9"
  $adminHeaders=@{apikey=$serverKey;Authorization="Bearer $serverKey"}
  $created=Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" -Headers $adminHeaders -UserAgent 'BIL-Coach-E2E/1.0' -ContentType 'application/json' -Body (@{email=$email;password=$password;email_confirm=$true}|ConvertTo-Json)
  $userId=[string]$created.id;$now=[DateTime]::UtcNow.ToString('o');$expiry=[DateTime]::UtcNow.AddHours(1).ToString('o')
  [void](Invoke-DbQuery "insert into public.bil_ai_coach_subscriptions(owner_id,provider,product_id,lifecycle,original_transaction_id,latest_transaction_id,expires_at,verified_at) values ('$userId','google','bil_ai_coach_benchmark_only','trial','coach-$suffix','coach-$suffix','$expiry','$now')")
  $auth=Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" -Headers @{apikey=$publishableKey} -ContentType 'application/json' -Body (@{email=$email;password=$password}|ConvertTo-Json)
  $requestId="coachlive$([guid]::NewGuid().ToString('N'))"
  $headers=@{apikey=$publishableKey;Authorization="Bearer $($auth.access_token)"}
  $body=@{request_id=$requestId;locale='en';messages=@(@{role='user';content='I weigh 82 kg and my saved goal is 75 kg. How much remains?'});context=@{profile=@{currentWeightKg=82;targetWeightKg=75};computedHealth=@{kilogramsToGoal=7;goalDirection='lose'}}}|ConvertTo-Json -Depth 8
  try{$response=Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/ai-coach" -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 45}
  catch{throw "AI Coach HTTP failure: $(Get-HttpFailureBody $_.Exception)"}
  $duplicateStatus=$null
  try{[void](Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/ai-coach" -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 45)}catch{$duplicateStatus=[int]$_.Exception.Response.StatusCode}
  $event=(Invoke-DbQuery "select state,provider,model,input_tokens,output_tokens,latency_ms,cost_usd from public.bil_ai_usage_events where owner_id='$userId' and request_id='$requestId'").rows|Select-Object -First 1
  $usage=(Invoke-DbQuery "select used,reserved from public.bil_ai_weekly_usage where owner_id='$userId' and capability='text'").rows|Select-Object -First 1
  [pscustomobject]@{success=$true;request_id=$requestId;reply=$response.reply;proposed_actions=$response.proposed_actions;provider=$event.provider;model=$event.model;input_tokens=$event.input_tokens;output_tokens=$event.output_tokens;latency_ms=$event.latency_ms;cost_usd=$event.cost_usd;quota_used=$usage.used;quota_reserved=$usage.reserved;duplicate_status=$duplicateStatus}|ConvertTo-Json -Depth 8
}finally{
  if($userId){try{Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders -UserAgent 'BIL-Coach-E2E/1.0'|Out-Null}catch{}}
  Remove-Variable serverKey,publishableKey,password,keysRaw -ErrorAction SilentlyContinue
}
