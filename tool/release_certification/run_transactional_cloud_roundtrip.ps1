param([string]$OutputDir)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\release\supabase_query_result.ps1')

function Get-BilCloudSqlHash([string]$Text) {
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
    [Text.Encoding]::UTF8.GetBytes($Text)
  )).ToLowerInvariant()
}

function New-BilTransactionalCloudSql([string]$Original, [string]$Marker) {
  $normalized = $Original.Replace("`r`n", "`n")
  if ((Get-BilCloudSqlHash $normalized) -cne 'ec29074e3cce54c4c20992c874040be79c78914be3b0a34b90476cb546f9aff8') {
    throw 'TRANSACTIONAL_SQL_SOURCE_CHANGED'
  }
  if ($Marker -cnotmatch '^[a-f0-9]{32}$') { throw 'TRANSACTIONAL_MARKER_INVALID' }
  if ($normalized -cnotmatch '\Abegin;\s' -or $normalized -cnotmatch '\srollback;\s*\z' -or
      [regex]::Matches($normalized, [regex]::Escape('txid_current()::text')).Count -ne 4) {
    throw 'TRANSACTIONAL_SQL_BOUNDARY_INVALID'
  }
  # Change only the four synthetic record/operation suffixes, so the exact
  # same DO assertions run and their rows can be read back after ROLLBACK.
  $query = $normalized.Replace('txid_current()::text', "'$Marker'::text")
  $summaryStart = $query.IndexOf("select`n  true as live_cloud_roundtrip,", [StringComparison]::Ordinal)
  if ($summaryStart -lt 0) { throw 'TRANSACTIONAL_SQL_BOUNDARY_INVALID' }
  $body = $query.Substring(0, $summaryStart)
  $summary = $query.Substring($summaryStart).Replace("rollback;`n", '').Trim()
  $summary = $summary.Replace("'ROLLBACK_ENFORCED'::text as persistence;", @"
'ROLLBACK_ENFORCED'::text as persistence,
  (select count(*) from public.bil_cloud_records
    where record_id = 'qa-prefinal-cloud-$Marker') as rollback_records,
  (select count(*) from public.bil_cloud_operations
    where operation_id in ('qa-prefinal-op1-$Marker', 'qa-prefinal-op2-$Marker',
                          'qa-prefinal-stale-$Marker')) as rollback_operations;
"@)
  return $body + @"
rollback;

-- Reaching this statement means the original transaction did not error.
-- Readback is deliberately after ROLLBACK, in the same CLI query/session.
$summary
"@
}

function Assert-BilTransactionalCloudResult([string]$Json) {
  # CLI exit zero is insufficient: reject error envelopes and error rows even
  # if an unrelated success-looking field accompanies them.
  if ([string]::IsNullOrWhiteSpace($Json)) { throw 'TRANSACTIONAL_QUERY_EMPTY_OUTPUT' }
  try { $document = ConvertFrom-Json -InputObject $Json -NoEnumerate -ErrorAction Stop }
  catch { throw 'SUPABASE_QUERY_INVALID_JSON' }
  if ($document -is [pscustomobject] -and
      @(@('error','errors','failure','failed') | Where-Object {
        $document.PSObject.Properties.Name -contains $_
      }).Count -ne 0) {
    throw 'TRANSACTIONAL_QUERY_ERROR_ENVELOPE'
  }
  $result = ConvertFrom-BilSupabaseQueryJson -Json $Json
  $flags = @('live_cloud_roundtrip','device_download_payload_bytes','edit_redownload',
             'stale_conflict','duplicate_idempotency','account_isolation')
  $columns = $flags + @('persistence','rollback_records','rollback_operations')
  $row = Get-BilSupabaseQueryRow -Result $result -RequiredColumns $columns `
    -NumericColumns @('rollback_records','rollback_operations')
  if (@($row.PSObject.Properties.Name | Where-Object { $_ -notin $columns }).Count -ne 0) {
    throw 'TRANSACTIONAL_QUERY_UNEXPECTED_COLUMNS'
  }
  foreach ($flag in $flags) {
    if ($row.$flag -isnot [bool] -or -not $row.$flag) { throw 'TRANSACTIONAL_QUERY_ASSERTION_FAILED' }
  }
  if ($row.persistence -isnot [string] -or $row.persistence -cne 'ROLLBACK_ENFORCED' -or
      $row.rollback_records -ne 0 -or $row.rollback_operations -ne 0) {
    throw 'TRANSACTIONAL_ROLLBACK_READBACK_FAILED'
  }
  return $row
}

function Invoke-BilTransactionalCloudRoundtrip {
  param(
    [Parameter(Mandatory=$true)][string]$EvidenceDir,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$SourceSha,
    [scriptblock]$Query
  )
  New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
  $receiptPath = Join-Path $EvidenceDir 'transactional-cloud-receipt.json'
  $receipt = [ordered]@{
    schema = 'bil.qa.transactional-cloud-roundtrip.v1'; source_sha = $SourceSha
    project_ref = 'tgmanzhqulksykhslrzb'; status = 'STARTED'; stage = 'source_validation'
    actual_live_cloud_roundtrip = $false; rollback_readback_verified = $false
    data_exported = $false; deployment_performed = $false
    scope = 'Existing fixed rollback-only SQL; synthetic records, no hosted publication'
  }
  function Save-BilCloudReceipt {
    $receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $receiptPath -Encoding utf8
  }
  Save-BilCloudReceipt
  try {
    $sqlPath = Join-Path $PSScriptRoot 'pre_final_cloud_transaction.sql'
    $original = [IO.File]::ReadAllText($sqlPath)
    $marker = [guid]::NewGuid().ToString('N')
    $sql = New-BilTransactionalCloudSql -Original $original -Marker $marker
    $receipt.sql_source_sha256 = Get-BilCloudSqlHash ($original.Replace("`r`n", "`n"))
    $receipt.executed_sql_sha256 = Get-BilCloudSqlHash $sql
    $receipt.marker = $marker
    $receipt.stage = 'actual_cli_query'
    Save-BilCloudReceipt
    $isLive = $null -eq $Query
    if ($isLive) {
      if ([string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) {
        throw 'TRANSACTIONAL_CLOUD_CREDENTIAL_MISSING'
      }
      $priorPreference = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
        $raw = ($sql | & npx --yes supabase@2.121.0 db query --linked `
          --project-ref tgmanzhqulksykhslrzb --agent no --output-format json 2>$null) -join "`n"
        $code = $LASTEXITCODE
      } finally { $ErrorActionPreference = $priorPreference }
      $response = [pscustomobject]@{ ExitCode=$code; Json=$raw }
    } else { $response = & $Query $sql }
    if ($null -eq $response -or $response.ExitCode -isnot [int] -or $response.ExitCode -ne 0) {
      throw 'TRANSACTIONAL_CLOUD_CLI_FAILED'
    }
    $receipt.stage = 'result_and_rollback_readback'
    Save-BilCloudReceipt
    $row = Assert-BilTransactionalCloudResult -Json $response.Json
    $receipt.result = $row
    $receipt.rollback_readback_verified = $true
    $receipt.actual_live_cloud_roundtrip = $isLive
    $receipt.status = if ($isLive) { 'PASS' } else { 'OFFLINE_VALIDATED' }
    $receipt.stage = 'completed'
    Save-BilCloudReceipt
    return [pscustomobject]$receipt
  } catch {
    $receipt.status = 'FAIL'
    $message = $_.Exception.Message
    $receipt.error = if ($message -cmatch '^(TRANSACTIONAL_[A-Z_]+|SUPABASE_QUERY_[A-Z_]+)$') {
      $message
    } else { 'TRANSACTIONAL_CLOUD_UNEXPECTED_FAILURE' }
    Save-BilCloudReceipt
    throw $receipt.error
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    if ([string]::IsNullOrWhiteSpace($OutputDir)) { throw 'TRANSACTIONAL_OUTPUT_REQUIRED' }
    $source = (& git rev-parse HEAD) -join ''
    if ($LASTEXITCODE -ne 0 -or $source -cne $env:GITHUB_SHA) { throw 'TRANSACTIONAL_SOURCE_MISMATCH' }
    $result = Invoke-BilTransactionalCloudRoundtrip -EvidenceDir $OutputDir -SourceSha $source
    if ($result.status -cne 'PASS' -or -not $result.actual_live_cloud_roundtrip -or
        -not $result.rollback_readback_verified) { throw 'TRANSACTIONAL_ACTUAL_PASS_ABSENT' }
    Write-Output 'TRANSACTIONAL_LIVE_CLOUD_ROUNDTRIP=PASS;ROLLBACK_READBACK=PASS'
  } catch {
    Write-Error 'TRANSACTIONAL_LIVE_CLOUD_ROUNDTRIP=FAIL; inspect sanitized receipt and stage' -ErrorAction Continue
    exit 1
  }
}
