param([string]$ProjectRef='tgmanzhqulksykhslrzb')
$ErrorActionPreference='Stop';$base="https://$ProjectRef.supabase.co";$uid=$null;$cleanUser=$false;$cleanFixture=$false;$gtin='4006381333931'
function Db([string]$sql){$old=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$raw=(& npx --yes supabase@latest db query --linked $sql 2>$null)-join "`n";$exit=$LASTEXITCODE}finally{$ErrorActionPreference=$old};if($exit-ne 0){throw 'db query failed'};$raw|ConvertFrom-Json}
try{
  $keys=((& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null)-join "`n")|ConvertFrom-Json
  $svc=($keys|?{$_.name-eq'service_role'}|select -First 1).api_key;$pub=($keys|?{$_.name-eq'anon'-and $_.type-eq'legacy'}|select -First 1).api_key
  $sh=@{apikey=$svc;Authorization="Bearer $svc"};$payload=@{gtin=$gtin;name='BIL controlled barcode fixture';brand='BIL E2E';ingredients='oats';serving_size=40;serving_unit='g';nutrients=@(@{name='Energy';unit='KCAL';amount=150})}
  Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_put_cached_barcode" -Headers $sh -ContentType application/json -Body (@{p_gtin=$gtin;p_source='bil';p_payload=$payload;p_ttl_days=1}|ConvertTo-Json -Depth 8)|Out-Null
  $s=[guid]::NewGuid().ToString('N');$email="barcode-resolved-$s@bilhealth.invalid";$pw="Bil!${s}A9"
  $u=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $sh -ContentType application/json -Body (@{email=$email;password=$pw;email_confirm=$true}|ConvertTo-Json);$uid=$u.id
  $auth=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/token?grant_type=password" -Headers @{apikey=$pub} -ContentType application/json -Body (@{email=$email;password=$pw}|ConvertTo-Json)
  [void](Db "insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id) values ('$uid','plan:premium','e2e-only','google',true,now(),now()+interval '1 hour','e2e-$s')")
  $response=Invoke-RestMethod -Method Post -Uri "$base/functions/v1/barcode-lookup" -Headers @{apikey=$pub;Authorization="Bearer $($auth.access_token)"} -ContentType application/json -Body (@{gtin=$gtin}|ConvertTo-Json)
  $result=[pscustomobject]@{success=($response.status-eq'found'-and $response.cache_hit-eq$true-and $response.source-eq'bil');status=$response.status;source=$response.source;cache_hit=$response.cache_hit;gtin_match=($response.gtin-eq$gtin);fixture_name_match=($response.payload.name-eq'BIL controlled barcode fixture')}
}finally{
  try{[void](Db "delete from public.bil_barcode_shared_cache where gtin='$gtin' and payload->>'brand'='BIL E2E'");$cleanFixture=$true}catch{}
  if($uid){try{Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$uid" -Headers $sh|Out-Null;$cleanUser=$true}catch{}}
  Remove-Variable svc,pub,pw,keys,auth -ErrorAction SilentlyContinue
}
$result|Add-Member cleanup_user $cleanUser;$result|Add-Member cleanup_fixture $cleanFixture;$result|ConvertTo-Json
