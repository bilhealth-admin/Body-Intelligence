$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'run_transactional_cloud_roundtrip.ps1')
$script:passed = 0
function Case([scriptblock]$Action) { & $Action; $script:passed++ }
function Expect-Failure([scriptblock]$Action, [string]$Code) {
  try { & $Action | Out-Null } catch {
    if ($_.Exception.Message -ceq $Code) { return }
    throw "Unexpected sanitized failure; expected $Code"
  }
  throw "Expected failure absent: $Code"
}
function Good-Row {
  [ordered]@{
    live_cloud_roundtrip=$true; device_download_payload_bytes=$true
    edit_redownload=$true; stale_conflict=$true; duplicate_idempotency=$true
    account_isolation=$true; persistence='ROLLBACK_ENFORCED'
    rollback_records=0; rollback_operations=0
  }
}
function Row-Json($Row) { ConvertTo-Json -InputObject @($Row) -Depth 5 -Compress }

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempParent ('bil-cloud-rollback-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  foreach ($name in @('run_transactional_cloud_roundtrip.ps1','test_transactional_cloud_roundtrip.ps1')) {
    $tokens=$null; $parseErrors=$null
    [void][Management.Automation.Language.Parser]::ParseFile(
      (Join-Path $PSScriptRoot $name), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) { throw 'TRANSACTIONAL_POWERSHELL_SYNTAX_FAILED' }
  }
  Case { $null = Assert-BilTransactionalCloudResult (Row-Json (Good-Row)) }
  Case {
    $wrapped = @{warning='untrusted data';rows=@((Good-Row))} | ConvertTo-Json -Depth 5 -Compress
    $null = Assert-BilTransactionalCloudResult $wrapped
  }
  Case { Expect-Failure { Assert-BilTransactionalCloudResult '' } 'TRANSACTIONAL_QUERY_EMPTY_OUTPUT' }
  Case { Expect-Failure { Assert-BilTransactionalCloudResult '{}' } 'SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE' }
  Case { Expect-Failure { Assert-BilTransactionalCloudResult '[]' } 'SUPABASE_QUERY_EXPECTED_ONE_ROW' }
  Case {
    Expect-Failure { Assert-BilTransactionalCloudResult '{"error":"database assert failed"}' } `
      'TRANSACTIONAL_QUERY_ERROR_ENVELOPE'
  }
  Case {
    $raw = @{error='server-error';rows=@((Good-Row))} | ConvertTo-Json -Depth 5 -Compress
    Expect-Failure { Assert-BilTransactionalCloudResult $raw } 'TRANSACTIONAL_QUERY_ERROR_ENVELOPE'
  }
  Case {
    $row=Good-Row; $row.error='server-error'
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'TRANSACTIONAL_QUERY_UNEXPECTED_COLUMNS'
  }
  Case {
    $row=Good-Row; $row.account_isolation=$false
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'TRANSACTIONAL_QUERY_ASSERTION_FAILED'
  }
  Case {
    $row=Good-Row; $row.edit_redownload='true'
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'TRANSACTIONAL_QUERY_ASSERTION_FAILED'
  }
  Case {
    $row=Good-Row; $row.rollback_records=1
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'TRANSACTIONAL_ROLLBACK_READBACK_FAILED'
  }
  Case {
    $row=Good-Row; $row.rollback_operations=1
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'TRANSACTIONAL_ROLLBACK_READBACK_FAILED'
  }
  Case {
    $row=Good-Row; $row.rollback_records='0'
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'
  }
  Case {
    $row=Good-Row; $row.persistence='COMMITTED'
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'TRANSACTIONAL_ROLLBACK_READBACK_FAILED'
  }
  Case {
    $raw = ConvertTo-Json -InputObject @((Good-Row),(Good-Row)) -Depth 5 -Compress
    Expect-Failure { Assert-BilTransactionalCloudResult $raw } 'SUPABASE_QUERY_EXPECTED_ONE_ROW'
  }
  Case {
    $row=Good-Row; $row.Remove('stale_conflict')
    Expect-Failure { Assert-BilTransactionalCloudResult (Row-Json $row) } 'SUPABASE_QUERY_REQUIRED_VALUE_MISSING'
  }
  Case {
    $original = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'pre_final_cloud_transaction.sql'))
    $marker = 'a' * 32
    $sql = New-BilTransactionalCloudSql $original $marker
    if ([regex]::Matches($sql, "'$marker'::text").Count -ne 4) { throw 'Synthetic marker replacement changed scope' }
    if ($sql.IndexOf('rollback;') -gt $sql.IndexOf('as rollback_records')) { throw 'Readback preceded rollback' }
    if ([regex]::Matches($sql, 'as live_cloud_roundtrip').Count -ne 1 -or
        $sql.IndexOf('rollback;') -gt $sql.IndexOf('as live_cloud_roundtrip')) {
      throw 'Expected exactly one original success SELECT, after rollback'
    }
    if ($sql -notmatch 'record_id = ''qa-prefinal-cloud-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa''') { throw 'Record readback is not exact marker' }
    if ($sql -match '\bcommit\s*;') { throw 'Transaction must not commit' }
    $null = New-BilTransactionalCloudSql ($original.Replace("`r`n","`n").Replace("`n","`r`n")) $marker
    Expect-Failure { New-BilTransactionalCloudSql ($original + '--changed') $marker } 'TRANSACTIONAL_SQL_SOURCE_CHANGED'
    Expect-Failure { New-BilTransactionalCloudSql $original "'; select 1;--" } 'TRANSACTIONAL_MARKER_INVALID'
  }
  Case {
    $evidence=Join-Path $tempRoot 'valid-offline'
    $answer=[pscustomobject]@{ExitCode=0;Json=(Row-Json (Good-Row))}
    $invoke=({param($sql)
      if ($sql -notmatch 'rollback;[\s\S]*as rollback_operations;') { throw 'Fixture did not receive rollback/readback SQL' }
      return $answer
    }).GetNewClosure()
    $result=Invoke-BilTransactionalCloudRoundtrip -EvidenceDir $evidence -SourceSha ('a'*40) -Query $invoke
    if ($result.status -cne 'OFFLINE_VALIDATED' -or $result.actual_live_cloud_roundtrip -or
        -not $result.rollback_readback_verified) { throw 'Offline fixture masqueraded as actual live PASS' }
  }
  foreach ($bad in @(
    @{Name='nonzero';ExitCode=17;Json=(Row-Json (Good-Row));Code='TRANSACTIONAL_CLOUD_CLI_FAILED'},
    @{Name='exit-zero-error';ExitCode=0;Json='{"error":"server failure with fake token must-not-export"}';Code='TRANSACTIONAL_QUERY_ERROR_ENVELOPE'},
    @{Name='empty';ExitCode=0;Json='';Code='TRANSACTIONAL_QUERY_EMPTY_OUTPUT'},
    @{Name='wrong-shape';ExitCode=0;Json='{"data":[]}';Code='SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE'}
  )) {
    Case {
      $evidence=Join-Path $tempRoot $bad.Name
      $answer=[pscustomobject]@{ExitCode=$bad.ExitCode;Json=$bad.Json}
      $invoke=({param($sql) return $answer}).GetNewClosure()
      Expect-Failure {
        Invoke-BilTransactionalCloudRoundtrip -EvidenceDir $evidence -SourceSha ('b'*40) -Query $invoke
      } $bad.Code
      $saved=Get-Content -LiteralPath (Join-Path $evidence 'transactional-cloud-receipt.json') -Raw
      $receipt=$saved | ConvertFrom-Json
      if ($receipt.status -cne 'FAIL' -or $receipt.actual_live_cloud_roundtrip -or
          $saved.Contains('must-not-export')) { throw 'Failed CLI output became PASS or leaked raw output' }
    }
  }
  Write-Output "TRANSACTIONAL_CLOUD_OFFLINE_CASES_PASS=$script:passed;NO_CLOUD_REQUESTS;POWERSHELL_PARSE=2"
} finally {
  $resolved=[IO.Path]::GetFullPath($tempRoot)
  $prefix=$tempParent.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or
      [IO.Path]::GetFileName($resolved) -notmatch '^bil-cloud-rollback-test-[a-f0-9]{32}$') {
    throw 'Refusing unowned fixture cleanup'
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
