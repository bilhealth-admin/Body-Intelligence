param(
  [string]$ProjectRef = 'tgmanzhqulksykhslrzb',
  [string]$ManifestPath = 'tool/meal_vision_benchmark/benchmark_manifest.synthetic_owned.json'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifestFile = (Resolve-Path (Join-Path $root $ManifestPath)).Path
$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding utf8 | ConvertFrom-Json
$baseUrl = "https://$ProjectRef.supabase.co"
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$rawOutput = Join-Path $root "artifacts/meal_vision_live_synthetic_responses_$stamp.json"
$predictionsOutput = Join-Path $root "artifacts/meal_vision_live_synthetic_predictions_$stamp.json"
$auditOutput = Join-Path $root "artifacts/meal_vision_live_synthetic_audit_$stamp.json"
$userId = $null
$productId = "bil.vision.benchmark.$([guid]::NewGuid().ToString('N'))"
$cleanup = [ordered]@{ user_deleted=$false; product_deleted=$false }

function Invoke-DbQuery([string]$Sql) {
  for ($attempt=1; $attempt -le 3; $attempt++) {
    $old=$ErrorActionPreference; $ErrorActionPreference='Continue'
    try {
      $raw=(& npx --yes supabase@latest db query --linked $Sql 2>$null)-join "`n"
      $exit=$LASTEXITCODE
    } finally { $ErrorActionPreference=$old }
    if ($exit -eq 0) { return $raw | ConvertFrom-Json }
    if ($attempt -lt 3) { Start-Sleep -Seconds 2 }
  }
  throw 'Supabase database query failed after three attempts.'
}

function Convert-ToGramAmount($Candidate) {
  if ($null -eq $Candidate.amount -or $null -eq $Candidate.unit) { return $null }
  $amount=[double]$Candidate.amount
  switch ($Candidate.unit.ToString().Trim().ToLowerInvariant()) {
    'g' { return $amount }
    'gram' { return $amount }
    'grams' { return $amount }
    'kg' { return $amount*1000 }
    default { return $null }
  }
}

function Get-HttpFailureBody($Exception) {
  if($null -eq $Exception.Response){return $Exception.Message}
  $reader=[IO.StreamReader]::new($Exception.Response.GetResponseStream())
  try{return $reader.ReadToEnd()}finally{$reader.Dispose()}
}

$rawCases=@(); $runs=@(); $receipts=@(); $failure=$null
try {
  $old=$ErrorActionPreference; $ErrorActionPreference='Continue'
  try {
    $keysRaw=(& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null)-join "`n"
  } finally { $ErrorActionPreference=$old }
  if ($LASTEXITCODE -ne 0) { throw 'Unable to read project API keys.' }
  $keys=$keysRaw|ConvertFrom-Json
  $serverKey=($keys|Where-Object {$_.name -eq 'service_role'}|Select-Object -First 1).api_key
  $publishableKey=($keys|Where-Object {$_.type -eq 'publishable'}|Select-Object -First 1).api_key
  if ([string]::IsNullOrWhiteSpace($serverKey)-or[string]::IsNullOrWhiteSpace($publishableKey)) { throw 'Required API keys unavailable.' }

  $suffix=[guid]::NewGuid().ToString('N')
  $email="vision-benchmark-$suffix@bilhealth.invalid"
  $password="Bil!$([guid]::NewGuid().ToString('N'))a9"
  $adminHeaders=@{apikey=$serverKey;Authorization="Bearer $serverKey"}
  $created=Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" -Headers $adminHeaders `
    -UserAgent 'BIL-Vision-Benchmark/1.0' -ContentType 'application/json' `
    -Body (@{email=$email;password=$password;email_confirm=$true}|ConvertTo-Json)
  $userId=[string]$created.id
  if ([string]::IsNullOrWhiteSpace($userId)) { throw 'Test user creation returned no id.' }

  $now=[DateTime]::UtcNow.ToString('o'); $expiry=[DateTime]::UtcNow.AddHours(1).ToString('o')
  # Explicit temporary benchmark entitlement. It is independent from Pro and
  # is cascade-deleted with the temporary auth user in finally.
  [void](Invoke-DbQuery "insert into public.bil_ai_coach_subscriptions(owner_id,provider,product_id,lifecycle,original_transaction_id,latest_transaction_id,expires_at,verified_at) values ('$userId','google','bil_ai_coach_benchmark_only','trial','bench-$suffix','bench-$suffix','$expiry','$now')")
  $auth=Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" `
    -Headers @{apikey=$publishableKey} -ContentType 'application/json' `
    -Body (@{email=$email;password=$password}|ConvertTo-Json)
  $accessToken=[string]$auth.access_token
  if ([string]::IsNullOrWhiteSpace($accessToken)) { throw 'Test sign-in returned no access token.' }

  $endpoint="$baseUrl/functions/v1/analyze-meal"
  foreach ($case in $manifest.cases) {
    $imagePath=(Resolve-Path (Join-Path $root $case.image_path)).Path
    $bytes=[IO.File]::ReadAllBytes($imagePath)
    $mime=if($imagePath.ToLowerInvariant().EndsWith('.png')){'image/png'}else{'image/jpeg'}
    # Mirror the client preflight: large camera/PNG inputs are bounded before
    # base64 expansion reaches the Edge gateway. 1280px at JPEG q=85 preserves
    # meal recognition detail while avoiding platform request-body failures.
    if($bytes.Length -gt 1500000){
      $compressed=Join-Path ([IO.Path]::GetTempPath()) "bil-vision-$([guid]::NewGuid().ToString('N')).jpg"
      try{
        & ffmpeg -loglevel error -y -i $imagePath -vf "scale='min(1280,iw)':-2" -q:v 3 $compressed
        if($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $compressed)){throw 'Benchmark image compression failed.'}
        $bytes=[IO.File]::ReadAllBytes($compressed)
        $mime='image/jpeg'
      } finally { if(Test-Path -LiteralPath $compressed){Remove-Item -LiteralPath $compressed -Force} }
    }
    $payload=@{schema_version=1;image_base64=[Convert]::ToBase64String($bytes);mime_type=$mime;requested_locale='en'}|ConvertTo-Json -Compress
    $requestId="bilbench$([guid]::NewGuid().ToString('N'))"
    $headers=@{apikey=$publishableKey;Authorization="Bearer $accessToken";'x-idempotency-key'=$requestId}
    $response=$null; $clientAttempts=0; $requestIds=@($requestId)
    for($clientAttempt=1;$clientAttempt -le 3;$clientAttempt++){
      $clientAttempts=$clientAttempt
      try{
        $response=Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers `
          -ContentType 'application/json' -Body $payload -TimeoutSec 60
        break
      }catch{
        $status=if($_.Exception.Response){[int]$_.Exception.Response.StatusCode}else{0}
        $failureBody=Get-HttpFailureBody $_.Exception
        if($status -eq 422 -and $case.category -eq 'non_food' -and
            $failureBody -match '"error"\s*:\s*"non_food_or_unrecognized"'){
          $nonFoodBody=$failureBody | ConvertFrom-Json
          $response=[pscustomobject]@{
            candidates=@()
            warnings=@('non_food_or_unrecognized')
            requires_review=$true
            auto_logged=$false
            provider_metrics=$nonFoodBody.provider_metrics
          }
          break
        }
        $nonRetryableProviderValidation = $failureBody -match '"provider_validation_code"\s*:\s*"(?:malformed_response|not_configured)"'
        if($clientAttempt -ge 3 -or $status -notin @(500,502,503,504) -or $nonRetryableProviderValidation){throw "Benchmark case $($case.id) failed HTTP $status after $clientAttempt client attempts: $failureBody"}
        # A failed provider call is settled/refunded. Retrying that same
        # idempotency key correctly replays the refunded terminal state, so a
        # bounded benchmark retry must be a new logical request. The digest is
        # allowed again because refunded rows are not live duplicates.
        $requestId="bilbench$([guid]::NewGuid().ToString('N'))"
        $requestIds += $requestId
        $headers['x-idempotency-key']=$requestId
        Start-Sleep -Seconds 2
      }
    }
    if($null -eq $response){throw "No response for benchmark case $($case.id)."}
    $rawCases += [ordered]@{case_id=$case.id;request_id=$requestId;request_ids=$requestIds;image_path=$case.image_path;client_attempts=$clientAttempts;response=$response}
    $runs += [ordered]@{
      case_id=$case.id
      latency_ms=[int]$response.provider_metrics.latency_ms
      cost_usd=if($null -eq $response.provider_metrics.cost_usd){0.0}else{[double]$response.provider_metrics.cost_usd}
      components=@($response.candidates|ForEach-Object {
        [ordered]@{name=$_.name;aliases=@($_.alternatives|ForEach-Object {$_.name});amount_g=(Convert-ToGramAmount $_);confidence=[double]$_.confidence}
      })
      dish_identities=@($response.candidates|ForEach-Object {
        if($null -ne $_.dish_identity){
          [ordered]@{name=$_.dish_identity.name;aliases=@($_.dish_identity.alternatives|ForEach-Object {$_.name});confidence=[double]$_.dish_identity.confidence}
        }
      })
      visible_components=@($response.candidates|ForEach-Object {
        @($_.visible_components|ForEach-Object {[ordered]@{name=$_.name;aliases=@();amount_g=$null;confidence=[double]$_.confidence}})
      })
    }
    $receiptQuery=Invoke-DbQuery "select request_id,state,provider,model,latency_ms,input_tokens,output_tokens,cost_usd,provider_attempts,cost_source from public.bil_ai_usage_events where owner_id='$userId' and capability='vision' and request_id='$requestId'"
    $receipts += $receiptQuery.rows|Select-Object -First 1
    # Persist a sanitized checkpoint after every completed case. A later
    # provider failure or local timeout must not erase paid benchmark evidence.
    [IO.File]::WriteAllText($rawOutput,(@{schema_version=1;suite_id=$manifest.suite_id;synthetic=$true;provider=$response.provider_metrics.provider;model_revision=$response.provider_metrics.model_revision;partial=($rawCases.Count -lt @($manifest.cases).Count);cases=$rawCases}|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($predictionsOutput,(@{schema_version=1;provider=$response.provider_metrics.provider;model_revision=$response.provider_metrics.model_revision;partial=($runs.Count -lt @($manifest.cases).Count);runs=$runs}|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
  }

  $provider=($rawCases|Select-Object -First 1).response.provider_metrics.provider
  $model=($rawCases|Select-Object -First 1).response.provider_metrics.model_revision
  [IO.File]::WriteAllText($rawOutput,(@{schema_version=1;suite_id=$manifest.suite_id;synthetic=$true;provider=$provider;model_revision=$model;cases=$rawCases}|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($predictionsOutput,(@{schema_version=1;provider=$provider;model_revision=$model;runs=$runs}|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
  $usageQuery=Invoke-DbQuery "select used,reserved from public.bil_ai_weekly_usage where owner_id='$userId' and capability='vision' order by week_start desc limit 1"
  $usage=$usageQuery.rows|Select-Object -First 1
  $audit=[ordered]@{schema_version=1;suite_id=$manifest.suite_id;synthetic=$true;executed_at_utc=[DateTime]::UtcNow.ToString('o');case_count=@($manifest.cases).Count;provider=$provider;model_revision=$model;quota_used=[int]$usage.used;quota_reserved=[int]$usage.reserved;receipts=$receipts;cleanup=$cleanup}
} catch {
  $failure=$_.Exception.Message
  throw
} finally {
  if($userId){try{Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders -UserAgent 'BIL-Vision-Benchmark/1.0'|Out-Null;$cleanup.user_deleted=$true}catch{}}
  try{[void](Invoke-DbQuery "delete from public.bil_store_product_registry where product_id='$productId'");$cleanup.product_deleted=$true}catch{}
  if($null -ne $audit){$audit.cleanup=$cleanup;[IO.File]::WriteAllText($auditOutput,($audit|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))}
  Remove-Variable serverKey,publishableKey,accessToken,password,keysRaw -ErrorAction SilentlyContinue
}

[pscustomobject]@{success=($null -eq $failure);raw_responses=$rawOutput;predictions=$predictionsOutput;audit=$auditOutput;cleanup=$cleanup}|ConvertTo-Json -Depth 5
