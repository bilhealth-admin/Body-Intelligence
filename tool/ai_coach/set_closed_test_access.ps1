[CmdletBinding()]
param(
  [string[]]$Email = @(),
  [string[]]$UserId = @(),
  [ValidatePattern('^[a-z0-9][a-z0-9._:-]{2,63}$')]
  [string]$Cohort = 'google-play-closed-test',
  [ValidateRange(1, 548)]
  [int]$Days = 90,
  [switch]$Revoke,
  [switch]$Apply,
  [string]$ProjectRef = 'tgmanzhqulksykhslrzb'
)

$ErrorActionPreference = 'Stop'
if ($Email.Count -eq 0 -and $UserId.Count -eq 0) {
  throw 'Provide at least one -Email or -UserId value.'
}

$baseUrl = "https://$ProjectRef.supabase.co"
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
if (-not $serverKey) { throw 'The service-role key is unavailable.' }
$adminHeaders = @{ apikey = $serverKey; Authorization = "Bearer $serverKey" }

try {
  $resolved = [ordered]@{}
  foreach ($rawId in $UserId) {
    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($rawId, [ref]$parsed)) {
      throw "Invalid Supabase user ID: $rawId"
    }
    $resolved[$parsed.ToString()] = $null
  }

  $wantedEmails = @($Email | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
  if ($wantedEmails.Count -gt 0) {
    $remaining = [Collections.Generic.HashSet[string]]::new()
    foreach ($value in $wantedEmails) {
      [void]$remaining.Add($value)
    }
    for ($page = 1; $remaining.Count -gt 0; $page += 1) {
      $batch = Invoke-RestMethod -Method Get -Uri "$baseUrl/auth/v1/admin/users?page=$page&per_page=1000" -Headers $adminHeaders -UserAgent 'BIL-Coach-Closed-Test-Admin/1.0'
      $users = @($batch.users)
      foreach ($user in $users) {
        $candidate = ([string]$user.email).Trim().ToLowerInvariant()
        if ($remaining.Contains($candidate)) {
          $resolved[[string]$user.id] = $candidate
          [void]$remaining.Remove($candidate)
        }
      }
      if ($users.Count -lt 1000) { break }
    }
    if ($remaining.Count -gt 0) {
      throw "No Supabase account found for: $([string]::Join(', ', $remaining))"
    }
  }

  $active = -not $Revoke
  $ttlDays = if ($active) { $Days } else { 1 }
  $expiry = [DateTime]::UtcNow.AddDays($ttlDays).ToString('o')
  $reason = if ($active) {
    'Approved closed-test AI Coach access'
  }
  else {
    'Closed-test AI Coach access revoked'
  }
  $results = foreach ($entry in $resolved.GetEnumerator()) {
    if ($Apply) {
      $rpc = Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_set_ai_closed_test_access" -Headers $adminHeaders -ContentType 'application/json' -Body (@{
          p_owner_id = $entry.Key
          p_cohort = $Cohort
          p_active = $active
          p_expires_at = $expiry
          p_reason = $reason
        } | ConvertTo-Json)
      [pscustomobject]@{
        user_id = $entry.Key
        email = $entry.Value
        active = $rpc.active
        cohort = $rpc.cohort
        expires_at = $rpc.expires_at
        applied = $true
        remote_ai_consent_required = $true
      }
    }
    else {
      [pscustomobject]@{
        user_id = $entry.Key
        email = $entry.Value
        active = $active
        cohort = $Cohort
        expires_at = $expiry
        applied = $false
        remote_ai_consent_required = $true
      }
    }
  }
  [pscustomobject]@{
    project_ref = $ProjectRef
    mode = $(if ($Apply) { 'applied' } else { 'preview' })
    users = @($results)
  } | ConvertTo-Json -Depth 6
}
finally {
  Remove-Variable serverKey, keysRaw -ErrorAction SilentlyContinue
}
