$ErrorActionPreference = 'Stop'
$projectRef = 'tgmanzhqulksykhslrzb'
$baseUrl = "https://$projectRef.supabase.co"
$fixtureUser = $null
$adminHeaders = $null
$accessToken = $null
$publishable = $null
$report = [ordered]@{ translated = $false; user_deleted = $false; session_revoked = $false }
try {
  # Credentials remain in process memory; never print/persist raw CLI output.
  $keysRaw = (& npx --yes supabase@latest projects api-keys --project-ref $projectRef --reveal --output json 2>$null) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw 'project_credentials_unavailable' }
  $keys = $keysRaw | ConvertFrom-Json
  $server = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
  $publishable = ($keys | Where-Object { $_.type -eq 'publishable' } | Select-Object -First 1).api_key
  if (-not $publishable) { $publishable = ($keys | Where-Object { $_.name -eq 'anon' } | Select-Object -First 1).api_key }
  if (-not $server -or -not $publishable) { throw 'project_credentials_unavailable' }
  $adminHeaders = @{apikey=$server; Authorization="Bearer $server"}
  $suffix = [guid]::NewGuid().ToString('N')
  $email = "translation-e2e-$suffix@bilhealth.invalid"
  $password = "Bil!$([guid]::NewGuid().ToString('N'))a9"
  $created = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/admin/users" -Headers $adminHeaders -ContentType 'application/json' -Body (@{email=$email;password=$password;email_confirm=$true} | ConvertTo-Json)
  $fixtureUser = [string]$created.id
  $auth = Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/token?grant_type=password" -Headers @{apikey=$publishable} -ContentType 'application/json' -Body (@{email=$email;password=$password} | ConvertTo-Json)
  $accessToken = [string]$auth.access_token
  $started = [Diagnostics.Stopwatch]::StartNew()
  $body = @{texts=@{title='Public translation test';body='Small healthy habits build lasting progress.'};targetTag='ar'} | ConvertTo-Json -Depth 5
  try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/community-translate" -Headers @{apikey=$publishable;Authorization="Bearer $accessToken"} -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 25
    $report.translated = $response.engine -eq 'google' -and $response.texts.title -match '[\u0600-\u06ff]' -and $response.texts.body -match '[\u0600-\u06ff]'
    $report.milliseconds = $started.ElapsedMilliseconds
    $report.engine = [string]$response.engine
  } catch {
    $report.failure = 'translation_http_failure'
    if ($_.Exception.Response) { $report.http_status = [int]$_.Exception.Response.StatusCode }
    # Application error codes only, never upstream bodies or credentials.
    if ($_.ErrorDetails.Message) {
      try { $report.error_code = [string](($_.ErrorDetails.Message | ConvertFrom-Json).error) } catch {}
    }
  }
} catch { $report.failure = 'fixture_setup_unavailable' }
finally {
  if ($accessToken -and $publishable) {
    try { [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/auth/v1/logout?scope=global" -Headers @{apikey=$publishable;Authorization="Bearer $accessToken"}); $report.session_revoked=$true } catch {}
  }
  if ($fixtureUser -and $adminHeaders) {
    try { [void](Invoke-RestMethod -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$fixtureUser" -Headers $adminHeaders); $report.user_deleted=$true } catch {}
  }
}
$report | ConvertTo-Json -Depth 5
if (-not $report.translated -or -not $report.user_deleted -or -not $report.session_revoked) { exit 1 }

