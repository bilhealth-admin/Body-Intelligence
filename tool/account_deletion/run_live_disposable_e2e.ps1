param(
  [string]$ProjectRef = 'tgmanzhqulksykhslrzb',
  [string]$OwnerEmail = 'dr.kadem.nana@gmail.com'
)

$ErrorActionPreference = 'Stop'
# This intentionally uses a plus-address alias owned by the supplied mailbox.
# It never reads or sends mailbox contents and prints no credential or API key.
$baseUrl = "https://$ProjectRef.supabase.co"
$userId = $null
$suffix = [guid]::NewGuid().ToString('N')
$local, $domain = $OwnerEmail.Split('@', 2)
$email = "$local+bil-delete-$suffix@$domain"
$password = "Bil!$([guid]::NewGuid().ToString('N'))a9"

function Invoke-DbQuery([string]$Sql) {
  $raw = (& npx --yes supabase@latest db query --linked $Sql 2>$null) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw 'Supabase database query failed.' }
  return $raw | ConvertFrom-Json
}

try {
  $keysRaw = (& npx --yes supabase@latest projects api-keys --project-ref $ProjectRef --reveal --output json 2>$null) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw 'Unable to read project API keys.' }
  $keys = $keysRaw | ConvertFrom-Json
  $serverKey = ($keys | Where-Object name -eq 'service_role' | Select-Object -First 1).api_key
  $publishableKey = ($keys | Where-Object type -eq 'publishable' | Select-Object -First 1).api_key
  if (!$serverKey -or !$publishableKey) { throw 'Required API keys unavailable.' }
  $adminHeaders = @{ apikey = $serverKey; Authorization = "Bearer $serverKey" }

  $created = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" `
    -Headers $adminHeaders -ContentType 'application/json' -Body (@{
      email = $email; password = $password; email_confirm = $true
      user_metadata = @{ purpose = 'account-deletion-e2e' }
    } | ConvertTo-Json -Depth 4)
  $userId = [string]$created.id
  if (!$userId) { throw 'Disposable user creation returned no id.' }

  $session = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" `
    -Headers @{ apikey = $publishableKey } -ContentType 'application/json' `
    -Body (@{ email = $email; password = $password } | ConvertTo-Json)
  $userHeaders = @{ apikey = $publishableKey; Authorization = "Bearer $($session.access_token)" }

  [void](Invoke-DbQuery "insert into public.bil_public_profiles(user_id,display_name,discoverable) values ('$userId','Disposable deletion E2E',false)")

  $objectPaths = @(
    @{ bucket = 'profile-avatars'; path = "$userId/e2e-avatar.png" },
    @{ bucket = 'community-post-images'; path = "$userId/e2e-post.png" }
  )
  $png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
  foreach ($item in $objectPaths) {
    [void](Invoke-WebRequest -Method Post `
      -Uri "$baseUrl/storage/v1/object/$($item.bucket)/$($item.path)" `
      -Headers ($adminHeaders + @{ 'x-upsert' = 'true' }) `
      -ContentType 'image/png' -Body $png)
  }

  $receipt = Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_request_account_deletion" `
    -Headers $userHeaders -ContentType 'application/json' -Body (@{ p_reason = 'automated disposable production E2E' } | ConvertTo-Json)
  $requestId = if ($receipt -is [array]) { [string]$receipt[0].request_id } else { [string]$receipt.request_id }
  if (!$requestId) { throw 'Deletion RPC returned no request id.' }

  $result = Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/account-data-deletion" `
    -Headers $userHeaders -ContentType 'application/json' -Body (@{ request_id = $requestId } | ConvertTo-Json)
  if ($result.status -ne 'completed' -or [int]$result.removed_storage_objects -ne 2) {
    throw 'Deletion worker did not complete the expected storage-first deletion.'
  }

  $authDeleted = $false
  try { [void](Invoke-RestMethod -Method Get -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders) }
  catch { $authDeleted = [int]$_.Exception.Response.StatusCode -eq 404 }
  $profileCount = ((Invoke-DbQuery "select count(*)::int as count from public.bil_public_profiles where user_id='$userId'").rows | Select-Object -First 1).count
  $requestCount = ((Invoke-DbQuery "select count(*)::int as count from public.bil_account_deletion_requests where id='$requestId'").rows | Select-Object -First 1).count

  [pscustomobject]@{
    success = ($authDeleted -and [int]$profileCount -eq 0 -and [int]$requestCount -eq 0)
    request_status = $result.status
    removed_storage_objects = [int]$result.removed_storage_objects
    auth_user_deleted = $authDeleted
    owned_profile_rows_remaining = [int]$profileCount
    deletion_request_rows_remaining = [int]$requestCount
  } | ConvertTo-Json
} finally {
  if ($userId) {
    foreach ($item in @(
      @{ bucket = 'profile-avatars'; path = "$userId/e2e-avatar.png" },
      @{ bucket = 'community-post-images'; path = "$userId/e2e-post.png" }
    )) {
      try { [void](Invoke-RestMethod -Method Delete -Uri "$baseUrl/storage/v1/object/$($item.bucket)/$($item.path)" -Headers $adminHeaders) } catch {}
    }
    try { [void](Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$userId" -Headers $adminHeaders) } catch {}
  }
  $password = $null
}
