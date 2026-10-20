param([string]$Scenario = '')

$ErrorActionPreference = 'Stop'
$probePath = Join-Path $PSScriptRoot 'run_live_text_e2e.ps1'
foreach ($path in @($probePath, (Join-Path $PSScriptRoot 'live_text_e2e_diagnostics.ps1'),
  (Join-Path $PSScriptRoot '..\release\supabase_query_result.ps1'), $PSCommandPath)) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) { throw "PowerShell parser errors: $path" }
}

if ($Scenario) {
  # Both external entry points are mocked before the real probe is loaded.
  # Unknown requests fail locally; no network/native CLI fallback is allowed.
  $global:BilCoachMockScenario = $Scenario
  $global:BilCoachMockCoachCalls = 0
  function global:npx {
    process {
      $global:LASTEXITCODE = 0
      if ($args -contains 'projects') {
        @(
          @{ name = 'service_role'; api_key = 'DO_NOT_LOG_SERVER_KEY' },
          @{ type = 'publishable'; api_key = 'DO_NOT_LOG_PUBLIC_KEY' }
        ) | ConvertTo-Json -Compress
        return
      }
      $query = [string]$_
      $rows = @()
      if ($query.StartsWith('select (select count(*)')) {
        if ($global:BilCoachMockScenario -eq 'cleanup-query-failure') { throw 'Mock cleanup query failure' }
        $counts = [ordered]@{}
        foreach ($name in @('auth_users', 'grants', 'subscriptions', 'events', 'usage',
          'credit_weekly_usage', 'credit_monthly_usage', 'credit_balances', 'feedback', 'consents')) {
          $counts[$name] = 0
        }
        if ($global:BilCoachMockScenario -in @('cleanup-residue', 'settlement-cleanup-failure')) { $counts.events = 1 }
        if ($global:BilCoachMockScenario -eq 'cleanup-missing-count') { $counts.Remove('events') }
        if ($global:BilCoachMockScenario -eq 'cleanup-string-count') { $counts.events = '0' }
        $rows = @($counts)
        if ($global:BilCoachMockScenario -eq 'cleanup-empty-rows') { $rows = @() }
      }
      elseif ($query.Contains('from public.bil_ai_usage_events')) {
        if ($global:BilCoachMockScenario -ne 'missing-event') {
          $state = switch ($global:BilCoachMockScenario) {
            'wrong-state' { 'refunded' }
            'unsafe-state' { 'DO_NOT_LOG_PRIVATE_STATE' }
            default { 'succeeded' }
          }
          $rows = @(@{
              state = $state; credit_actual = $(if ($global:BilCoachMockScenario -in @('zero-credit', 'settlement-cleanup-failure')) { 0 } else { 35 })
              credit_reserved = 100; input_tokens = 3010; output_tokens = 328
              latency_ms = 500; cost_usd = 0.00348750; provider = 'gemini'; model = 'test-model'
              owner_id = 'DO_NOT_LOG_OWNER'; request_id = 'DO_NOT_LOG_REQUEST'
              reply = 'DO_NOT_LOG_REPLY'; context = 'DO_NOT_LOG_CONTEXT'
            })
        }
      }
      elseif ($query.Contains('from public.bil_ai_credit_weekly_usage')) {
        $rows = @(@{
            used = $(if ($global:BilCoachMockScenario -eq 'zero-used') { 0 } else { 35 })
            reserved = $(if ($global:BilCoachMockScenario -eq 'unreleased-reserve') { 100 } else { 0 })
          })
      }
      elseif ($query.Contains('from public.bil_ai_coach_feedback')) {
        $rows = @(@{ feedback_id = 'DO_NOT_LOG_FEEDBACK'; helpful = $true; runtime = 'cloud_personalized' })
      }
      else { throw 'Unexpected mocked CLI query; refusing native fallback.' }
      if ($global:BilCoachMockScenario -eq 'success-array') {
        ConvertTo-Json -InputObject @($rows) -Depth 4 -Compress
      }
      else { @{ rows = $rows } | ConvertTo-Json -Depth 4 -Compress }
    }
  }
  function global:Invoke-RestMethod {
    param($Method, $Uri, $Headers, $UserAgent, $ContentType, $Body, $TimeoutSec)
    if ($Uri.EndsWith('/auth/v1/admin/users') -and $Method -eq 'Post') {
      return [pscustomobject]@{ id = 'DO_NOT_LOG_OWNER'; email = 'DO_NOT_LOG_EMAIL' }
    }
    if ($Uri.Contains('/auth/v1/token?')) { return [pscustomobject]@{ access_token = 'DO_NOT_LOG_JWT' } }
    if ($Uri.EndsWith('/rpc/bil_set_ai_closed_test_access') -or $Uri.EndsWith('/rpc/bil_record_consent')) { return $true }
    if ($Uri.EndsWith('/rpc/bil_record_ai_coach_feedback')) { return 'DO_NOT_LOG_FEEDBACK' }
    if ($Uri.EndsWith('/functions/v1/ai-coach')) {
      $global:BilCoachMockCoachCalls++
      if ($global:BilCoachMockCoachCalls -gt 1) {
        $exception = [System.Exception]::new('Duplicate request')
        $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{ StatusCode = 409 })
        throw $exception
      }
      return [pscustomobject]@{
        response_id = ($Body | ConvertFrom-Json).request_id; attempts = 1
        reply = 'DO_NOT_LOG_REPLY'; spoken_reply = 'DO_NOT_LOG_SPOKEN_REPLY'
        reason = 'DO_NOT_LOG_REASON'; confidence = 0.9
      }
    }
    if ($Uri.Contains('/auth/v1/logout?')) {
      if ($global:BilCoachMockScenario -eq 'cleanup-revoke-failure') { throw 'Mock revoke failure' }
      return $true
    }
    if ($Uri.EndsWith('/auth/v1/admin/users/DO_NOT_LOG_OWNER') -and $Method -eq 'Delete') { return $true }
    throw 'Unexpected mocked HTTP request; refusing network fallback.'
  }
  & $probePath
  exit 0
}

function Invoke-MockedProbe([string]$Case) {
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = (Get-Process -Id $PID).Path
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in @('-NoProfile', '-File', $PSCommandPath, '-Scenario', $Case)) {
    $start.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::Start($start)
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  if (-not $process.WaitForExit(30000)) {
    $process.Kill($true)
    throw "Offline mocked probe timed out: $Case"
  }
  $result = [pscustomobject]@{ code = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result }
  $process.Dispose()
  return $result
}

$passed = 0
foreach ($case in @('success', 'success-array')) {
  $success = Invoke-MockedProbe $case
  if ($success.code -ne 0 -or $success.stderr -ne '') { throw "Successful probe no longer produces clean JSON stdout: $case" }
  $json = $success.stdout | ConvertFrom-Json
  if (-not $json.success -or -not $json.session_revoked -or -not $json.user_deleted -or -not $json.cascade_clean -or
    $json.quota_used -ne 35 -or $json.quota_reserved -ne 0 -or $json.duplicate_status -ne 409) {
    throw "Successful probe result contract changed: $case"
  }
  Write-Output "AI_COACH_OFFLINE_CASE_PASS=$case"
  $passed++
}

$failedPredicates = @{
  'wrong-state' = 'state_succeeded'
  'unsafe-state' = 'state_succeeded'
  'zero-credit' = 'event_credit_positive'
  'zero-used' = 'weekly_used_positive'
  'unreleased-reserve' = 'weekly_reserved_zero'
  'settlement-cleanup-failure' = 'event_credit_positive'
}
foreach ($case in $failedPredicates.Keys) {
  $failure = Invoke-MockedProbe $case
  if ($failure.code -eq 0 -or $failure.stdout.Trim() -ne '' -or
    -not $failure.stderr.Contains('AI token settlement did not reach the expected succeeded/used>0/reserved=0 state.')) {
    throw "Original settlement failure/nonzero exit was lost: $case"
  }
  if (($failure.stdout + $failure.stderr).Contains('DO_NOT_LOG_') -or $failure.stderr.Contains('coachlive')) {
    throw "Sensitive source data appeared in diagnostics: $case"
  }
  $diagnostics = @($failure.stderr -split '\r?\n' | Where-Object { $_.StartsWith('BIL_AI_COACH_DIAGNOSTIC=') } |
    ForEach-Object { $_.Substring('BIL_AI_COACH_DIAGNOSTIC='.Length) | ConvertFrom-Json })
  if ($diagnostics.Count -ne 2) { throw "Expected settlement and cleanup evidence: $case" }
  $settlement = $diagnostics | Where-Object kind -EQ 'settlement'
  $cleanup = $diagnostics | Where-Object kind -EQ 'cleanup'
  $expectedClean = $case -ne 'settlement-cleanup-failure'
  $expectedEvents = $(if ($expectedClean) { 0 } else { 1 })
  if ($settlement.predicates.($failedPredicates[$case]) -ne $false -or
    -not $cleanup.session_revoked -or -not $cleanup.user_deleted -or $cleanup.cascade_clean -ne $expectedClean -or
    -not $cleanup.counts_available -or $cleanup.counts.events -ne $expectedEvents) {
    throw "Settlement predicates or cleanup evidence are inaccurate: $case"
  }
  if ($case -eq 'unsafe-state' -and $settlement.state -ne 'unexpected') { throw 'Unknown state was not bounded.' }
  Write-Output "AI_COACH_OFFLINE_CASE_PASS=$case"
  $passed++
}

# A missing SQL row is rejected by the strict query contract before the
# settlement predicates can run. Keep that real failure and cleanup evidence.
$failure = Invoke-MockedProbe 'missing-event'
if ($failure.code -eq 0 -or $failure.stdout.Trim() -ne '' -or
  -not $failure.stderr.Contains('SUPABASE_QUERY_EXPECTED_ONE_ROW')) {
  throw 'Strict missing-event failure/nonzero exit was lost.'
}
if (($failure.stdout + $failure.stderr).Contains('DO_NOT_LOG_') -or $failure.stderr.Contains('coachlive')) {
  throw 'Sensitive source data appeared in the missing-event failure.'
}
$lines = @($failure.stderr -split '\r?\n' | Where-Object { $_.StartsWith('BIL_AI_COACH_DIAGNOSTIC=') })
if ($lines.Count -ne 1) { throw 'Expected only cleanup evidence after a missing SQL event.' }
$cleanup = $lines[0].Substring('BIL_AI_COACH_DIAGNOSTIC='.Length) | ConvertFrom-Json
if ($cleanup.kind -ne 'cleanup' -or -not $cleanup.session_revoked -or -not $cleanup.user_deleted -or
  -not $cleanup.cascade_clean -or -not $cleanup.counts_available -or $cleanup.counts.events -ne 0) {
  throw 'Missing-event failure lost verified cleanup evidence.'
}
Write-Output 'AI_COACH_OFFLINE_CASE_PASS=missing-event'
$passed++

foreach ($case in @('cleanup-residue', 'cleanup-revoke-failure', 'cleanup-query-failure',
  'cleanup-empty-rows', 'cleanup-missing-count', 'cleanup-string-count')) {
  $failure = Invoke-MockedProbe $case
  if ($failure.code -eq 0 -or $failure.stdout.Trim() -ne '' -or
    -not $failure.stderr.Contains('AI Coach E2E succeeded, but ephemeral-user cleanup verification failed.')) {
    throw "Cleanup failure/nonzero exit was lost: $case"
  }
  $line = @($failure.stderr -split '\r?\n' | Where-Object { $_.StartsWith('BIL_AI_COACH_DIAGNOSTIC=') })
  if ($line.Count -ne 1) { throw "Missing cleanup-failure evidence: $case" }
  $cleanup = $line[0].Substring('BIL_AI_COACH_DIAGNOSTIC='.Length) | ConvertFrom-Json
  if (($case -eq 'cleanup-residue' -and ($cleanup.cascade_clean -or $cleanup.counts.events -ne 1)) -or
    ($case -eq 'cleanup-revoke-failure' -and $cleanup.session_revoked) -or
    ($case -in @('cleanup-query-failure', 'cleanup-empty-rows', 'cleanup-missing-count', 'cleanup-string-count') -and
      ($cleanup.cascade_clean -or $cleanup.counts_available -or $null -ne $cleanup.counts.events))) {
    throw "Cleanup failure evidence is inaccurate: $case"
  }
  Write-Output "AI_COACH_OFFLINE_CASE_PASS=$case"
  $passed++
}
Write-Output "AI_COACH_OFFLINE_DIAGNOSTIC_TESTS_PASS=$passed;LIVE_REQUESTS=0"
