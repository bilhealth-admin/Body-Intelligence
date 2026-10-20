# These diagnostics deliberately accept only fixed state names, numbers and
# booleans. Never serialize the source response, request, account or error.
function ConvertTo-BilCoachDiagnosticNumber([object]$Value) {
  if ($null -eq $Value) { return $null }
  try { return [decimal]$Value } catch { return $null }
}

function Write-BilCoachSettlementDiagnostic([object]$Event, [object]$Usage) {
  try {
    $state = 'missing'
    if ($null -ne $Event) {
      $state = switch ([string]$Event.state) {
        'succeeded' { 'succeeded' }
        'reserved' { 'reserved' }
        'refunded' { 'refunded' }
        default { 'unexpected' }
      }
    }
    $actual = ConvertTo-BilCoachDiagnosticNumber $Event.credit_actual
    $used = ConvertTo-BilCoachDiagnosticNumber $Usage.used
    $reserved = ConvertTo-BilCoachDiagnosticNumber $Usage.reserved
    $diagnostic = [ordered]@{
      kind = 'settlement'
      event_present = $null -ne $Event
      weekly_usage_present = $null -ne $Usage
      state = $state
      input_tokens = ConvertTo-BilCoachDiagnosticNumber $Event.input_tokens
      output_tokens = ConvertTo-BilCoachDiagnosticNumber $Event.output_tokens
      latency_ms = ConvertTo-BilCoachDiagnosticNumber $Event.latency_ms
      cost_usd = ConvertTo-BilCoachDiagnosticNumber $Event.cost_usd
      credit_actual = $actual
      credit_reserved = ConvertTo-BilCoachDiagnosticNumber $Event.credit_reserved
      weekly_used = $used
      weekly_reserved = $reserved
      predicates = [ordered]@{
        state_succeeded = $state -ceq 'succeeded'
        event_credit_positive = $null -ne $actual -and $actual -gt 0
        weekly_used_positive = $null -ne $used -and $used -gt 0
        weekly_reserved_zero = $null -ne $reserved -and $reserved -eq 0
      }
    }
    [Console]::Error.WriteLine('BIL_AI_COACH_DIAGNOSTIC=' + ($diagnostic | ConvertTo-Json -Depth 4 -Compress))
  }
  catch { # Retaining evidence must never replace the original probe failure.
  }
}

function Write-BilCoachCleanupDiagnostic(
  [bool]$FixtureIdentified,
  [bool]$SessionRevoked,
  [bool]$UserDeleted,
  [bool]$CascadeClean,
  [object]$Cleanup
) {
  try {
    $counts = [ordered]@{}
    foreach ($name in @('auth_users', 'grants', 'subscriptions', 'events', 'usage',
      'credit_weekly_usage', 'credit_monthly_usage', 'credit_balances', 'feedback', 'consents')) {
      $counts[$name] = ConvertTo-BilCoachDiagnosticNumber $Cleanup.$name
    }
    $diagnostic = [ordered]@{
      kind = 'cleanup'
      fixture_identified = $FixtureIdentified
      session_revoked = $SessionRevoked
      user_deleted = $UserDeleted
      cascade_clean = $CascadeClean
      counts_available = $null -ne $Cleanup
      counts = $counts
    }
    [Console]::Error.WriteLine('BIL_AI_COACH_DIAGNOSTIC=' + ($diagnostic | ConvertTo-Json -Depth 4 -Compress))
  }
  catch { # Cleanup evidence must never mask the probe or cleanup error.
  }
}
