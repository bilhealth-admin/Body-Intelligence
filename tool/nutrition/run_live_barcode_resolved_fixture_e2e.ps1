param([string]$ProjectRef='tgmanzhqulksykhslrzb')
. (Join-Path $PSScriptRoot '..\release\supabase_query_result.ps1')
$ErrorActionPreference='Stop'
$base="https://$ProjectRef.supabase.co"
$uid=$null
$gtin=$null
$fixtureAttempted=$false
$cleanUser=$false
$cleanFixture=$false
$cleanupLegacy=$false
$result=$null
$fixtureName='BIL controlled barcode fixture'
$fixtureBrand='BIL E2E'

function Db([string]$sql) {
  $old=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  try {
    $raw=($sql | & npx --yes supabase@latest db query --linked --project-ref $ProjectRef --output-format json 2>$null)-join [Environment]::NewLine
    $exit=$LASTEXITCODE
  } finally {
    $ErrorActionPreference=$old
  }
  if($exit -ne 0) { throw "db query failed (exit $exit; explicit project ref)" }
  return ConvertFrom-BilSupabaseQueryJson -Json $raw
}

function New-TestGtin13 {
  $rng=[System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $bytes=New-Object byte[] 12
    $rng.GetBytes($bytes)
  } finally {
    $rng.Dispose()
  }
  $digits=[System.Text.StringBuilder]::new()
  foreach($byte in $bytes) { [void]$digits.Append([int]$byte % 10) }
  $sum=0
  for($i=0;$i -lt 12;$i++) {
    $digit=[int]$digits[$i].ToString()
    $weight=if((11-$i)%2 -eq 0){3}else{1}
    $sum+=$digit*$weight
  }
  $check=(10-($sum%10))%10
  return $digits.ToString()+[string]$check
}

function Get-CacheRows([string]$key) {
  if($key -notmatch '^[0-9]{13}$') { throw 'BARCODE_FIXTURE_INVALID_GTIN' }
  # This server-private table deliberately has no service-role REST grant.
  # Fixture maintenance uses the already authenticated management SQL channel;
  # the product roundtrip below still uses the actual barcode Edge Function.
  $result=Db "select gtin,payload from public.bil_barcode_shared_cache where gtin='$key' limit 2"
  if($result -isnot [pscustomobject] -or $result.rows -isnot [System.Array]) {
    throw 'BARCODE_FIXTURE_INVALID_QUERY_RESULT'
  }
  foreach($row in $result.rows) {
    if($row -isnot [pscustomobject] -or $row.gtin -isnot [string] -or
       $row.gtin -cne $key -or $row.payload -isnot [pscustomobject]) {
      throw 'BARCODE_FIXTURE_INVALID_CACHE_ROW'
    }
  }
  return $result.rows
}

function RemoveOwnedCacheEntry([string]$key) {
  $rows=@(Get-CacheRows $key)
  if($rows.Count -eq 0) { return $true }
  if($rows.Count -ne 1) { return $false }
  $row=$rows[0]
  if($row.payload.brand -ne $fixtureBrand -or $row.payload.name -ne $fixtureName) {
    return $true
  }

  # Exact ownership predicates are repeated in DELETE to survive concurrent
  # changes between the read and cleanup. Never delete a real cached product.
  $brand=$fixtureBrand.Replace("'","''")
  $name=$fixtureName.Replace("'","''")
  $deleted=Db "delete from public.bil_barcode_shared_cache where gtin='$key' and payload->>'brand'='$brand' and payload->>'name'='$name' returning gtin,payload"
  if($deleted -isnot [pscustomobject] -or $deleted.rows -isnot [System.Array]) { return $false }
  $deletedRows=@($deleted.rows)
  if($deletedRows.Count -ne 1) { return $false }
  if($deletedRows[0].gtin -ne $key -or
     $deletedRows[0].payload.brand -ne $fixtureBrand -or
     $deletedRows[0].payload.name -ne $fixtureName) { return $false }
  $remaining=@(Get-CacheRows $key)
  return ($remaining.Count -eq 0)
}

function New-FixtureHeaders {
  return @{apikey=$svc;Authorization="Bearer $svc"}
}

try {
  $keys=((& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null)-join [Environment]::NewLine)|ConvertFrom-Json
  $svc=($keys|Where-Object name -eq 'service_role'|Select-Object -First 1).api_key
  $pub=($keys|Where-Object { $_.name -eq 'anon' -and $_.type -eq 'legacy' }|Select-Object -First 1).api_key
  if([string]::IsNullOrWhiteSpace($svc) -or [string]::IsNullOrWhiteSpace($pub)) {
    throw 'Required Supabase API keys were not resolved'
  }
  $sh=New-FixtureHeaders

  # A previous failed version could leave only this exact synthetic marker.
  # Preserve any legitimate cached product at the same real-world GTIN.
  $cleanupLegacy=RemoveOwnedCacheEntry '4006381333931'
  if(-not $cleanupLegacy) { throw 'A prior disposable barcode fixture could not be safely cleaned' }

  $gtin=New-TestGtin13
  $preflight=Get-BilSupabaseQueryRow -Result (Db "select count(*)::int as row_count from public.bil_barcode_shared_cache where gtin='$gtin'") -RequiredColumns @('row_count') -NumericColumns @('row_count')
  if($preflight.row_count -ne 0) {
    throw 'Synthetic GTIN collision; refusing to overwrite an existing barcode'
  }

  $s=[guid]::NewGuid().ToString('N')
  $email="barcode-resolved-$s@bilhealth.invalid"
  $pw="Bil!"+$s+"A9"
  $u=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $sh -ContentType application/json -Body (@{email=$email;password=$pw;email_confirm=$true}|ConvertTo-Json)
  $uid=$u.id
  $auth=Invoke-RestMethod -Method Post -Uri "$base/auth/v1/token?grant_type=password" -Headers @{apikey=$pub} -ContentType application/json -Body (@{email=$email;password=$pw}|ConvertTo-Json)

  [void](Db "insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id) values ('$uid','plan:premium','e2e-only','google',true,now(),now()+interval '1 hour','e2e-$s')")

  $payload=@{gtin=$gtin;name=$fixtureName;brand=$fixtureBrand;ingredients='oats';serving_size=40;serving_unit='g';nutrients=@(@{name='Energy';unit='KCAL';amount=150})}
  $fixtureAttempted=$true
  Invoke-RestMethod -Method Post -Uri "$base/rest/v1/rpc/bil_put_cached_barcode" -Headers $sh -ContentType application/json -Body (@{p_gtin=$gtin;p_source='bil';p_payload=$payload;p_ttl_days=1}|ConvertTo-Json -Depth 8)|Out-Null

  $response=Invoke-RestMethod -Method Post -Uri "$base/functions/v1/barcode-lookup" -Headers @{apikey=$pub;Authorization="Bearer $($auth.access_token)"} -ContentType application/json -Body (@{gtin=$gtin}|ConvertTo-Json)
  $result=[pscustomobject]@{
    success=($response.status -eq 'found' -and $response.cache_hit -eq $true -and $response.source -eq 'bil' -and $response.gtin -eq $gtin -and $response.payload.name -eq $fixtureName -and $response.payload.brand -eq $fixtureBrand)
    status=$response.status
    source=$response.source
    cache_hit=$response.cache_hit
    gtin_match=($response.gtin -eq $gtin)
    fixture_name_match=($response.payload.name -eq $fixtureName)
  }
} finally {
  if($fixtureAttempted -and $gtin) {
    try { $cleanFixture=RemoveOwnedCacheEntry $gtin } catch { $cleanFixture=$false }
  } elseif(-not $fixtureAttempted) {
    $cleanFixture=$true
  }
  if($uid) {
    # Always attempt deletion even if the independent logout request fails.
    # Read back actual user/session/fixture-entitlement absence afterwards.
    try {
      Invoke-RestMethod -Method Post -Uri "$base/auth/v1/logout?scope=global" -Headers @{apikey=$pub;Authorization="Bearer $($auth.access_token)"}|Out-Null
    } catch {}
    try {
      Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$uid" -Headers $sh|Out-Null
    } catch {}
    try {
      $cleanup=Get-BilSupabaseQueryRow -Result (Db "select (select count(*) from auth.users where id='$uid') as auth_users,(select count(*) from auth.sessions where user_id='$uid') as sessions,(select count(*) from public.bil_entitlements where owner_id='$uid') as entitlements") -RequiredColumns @('auth_users','sessions','entitlements') -NumericColumns @('auth_users','sessions','entitlements')
      $cleanUser=($cleanup.auth_users -eq 0 -and $cleanup.sessions -eq 0 -and $cleanup.entitlements -eq 0)
    } catch { $cleanUser=$false }
  }
  Remove-Variable svc,pub,pw,keys,auth -ErrorAction SilentlyContinue
}

$result|Add-Member -MemberType NoteProperty -Name cleanup_user -Value $cleanUser
$result|Add-Member -MemberType NoteProperty -Name cleanup_fixture -Value $cleanFixture
$result|Add-Member -MemberType NoteProperty -Name cleanup_legacy_fixture -Value $cleanupLegacy
$result|ConvertTo-Json -Depth 8
if(-not $result.success -or -not $cleanUser -or -not $cleanFixture -or -not $cleanupLegacy) {
  throw 'Live barcode identity or independently verified fixture cleanup failed.'
}
