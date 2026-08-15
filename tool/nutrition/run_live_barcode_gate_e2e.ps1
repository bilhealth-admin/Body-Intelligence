param([string]$ProjectRef='tgmanzhqulksykhslrzb')
$ErrorActionPreference='Stop';$base="https://$ProjectRef.supabase.co";$uid=$null;$clean=$false
function Db([string]$sql){$old=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$raw=(& npx --yes supabase@latest db query --linked $sql 2>$null)-join "`n";$exit=$LASTEXITCODE}finally{$ErrorActionPreference=$old};if($exit-ne 0){throw 'db query failed'};$raw|ConvertFrom-Json}
try{
  $keys=((& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null)-join "`n")|ConvertFrom-Json
  $svc=($keys|?{$_.name-eq'service_role'}|select -First 1).api_key;$pub=($keys|?{$_.name-eq'anon'-and $_.type-eq'legacy'}|select -First 1).api_key
  $h=@{apikey=$svc;Authorization="Bearer $svc"};$s=[guid]::NewGuid().ToString('N');$email="barcode-$s@bilhealth.invalid";$pw="Bil!${s}A9"
  $u=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $h -ContentType application/json -Body (@{email=$email;password=$pw;email_confirm=$true}|ConvertTo-Json);$uid=$u.id
  $auth=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/token?grant_type=password" -Headers @{apikey=$pub} -ContentType application/json -Body (@{email=$email;password=$pw}|ConvertTo-Json)
  $ch=@{apikey=$pub;Authorization="Bearer $($auth.access_token)"};$endpoint="$base/functions/v1/barcode-lookup";$body=@{gtin='4006381333931'}|ConvertTo-Json
  $freeStatus=0;$freeError=$null;try{Invoke-RestMethod -Method Post -Uri $endpoint -Headers $ch -ContentType application/json -Body $body|Out-Null}catch{$freeStatus=[int]$_.Exception.Response.StatusCode;$freeError=$_.ErrorDetails.Message}
  [void](Db "insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id) values ('$uid','plan:premium','e2e-only','google',true,now(),now()+interval '1 hour','e2e-$s')")
  $premiumStatus=200;$premiumError=$null;try{$premium=Invoke-RestMethod -Method Post -Uri $endpoint -Headers $ch -ContentType application/json -Body $body}catch{$premiumStatus=[int]$_.Exception.Response.StatusCode;$premiumError=$_.ErrorDetails.Message}
  function SafeErrorCode([string]$raw){if([string]::IsNullOrWhiteSpace($raw)){return $null};try{$j=$raw|ConvertFrom-Json;return @($j.code,$j.error,$j.message)|?{$_}|select -First 1}catch{return 'non_json_error'}}
  $result=[pscustomobject]@{success=($freeStatus-eq403-and $premiumStatus-ne403-and $premiumStatus-ne401);free_status=$freeStatus;free_error_code=(SafeErrorCode $freeError);premium_status=$premiumStatus;premium_error_code=(SafeErrorCode $premiumError);premium_gate_opened=($premiumStatus-ne403-and $premiumStatus-ne401)}
}finally{if($uid){try{Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$uid" -Headers $h|Out-Null;$clean=$true}catch{}};Remove-Variable svc,pub,pw,keys -ErrorAction SilentlyContinue}
$result|Add-Member cleanup $clean;$result|ConvertTo-Json
