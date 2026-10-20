$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'supabase_query_result.ps1')
$script:passed=0
function Assert-Equal($Actual,$Expected) {
  if($Actual -cne $Expected){throw 'ASSERT_EQUAL_FAILED'}
}
function Assert-Throws([scriptblock]$Work,[string]$Expected) {
  try { & $Work | Out-Null } catch {
    if($_.Exception.Message -eq $Expected){return}
    throw 'ASSERT_UNEXPECTED_EXCEPTION'
  }
  throw 'ASSERT_EXPECTED_EXCEPTION'
}
function Case([scriptblock]$Work){ & $Work; $script:passed++ }

Case {
  $r=ConvertFrom-BilSupabaseQueryJson '[{"state":"succeeded","used":7,"reserved":0}]'
  $row=Get-BilSupabaseQueryRow $r @('state','used','reserved') @('used','reserved')
  Assert-Equal $row.state 'succeeded';Assert-Equal $row.used 7;Assert-Equal $row.reserved 0
}
Case {
  $r=ConvertFrom-BilSupabaseQueryJson '{"warning":"untrusted data","boundary":"fixture","rows":[{"count":0}]}'
  Assert-Equal (Get-BilSupabaseQueryRow $r @('count') @('count')).count 0
}
Case {Assert-Equal (ConvertFrom-BilSupabaseQueryJson '[]').rows.Count 0}
Case {Assert-Equal (ConvertFrom-BilSupabaseQueryJson '{"rows":[]}').rows.Count 0}
Case {Assert-Equal (ConvertFrom-BilSupabaseQueryJson '[{"count":0},{"count":1}]').rows.Count 2}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson 'null'} 'SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson '{}'} 'SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson '{"rows":null}'} 'SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson '{"rows":{"count":0}}'} 'SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson '[null]'} 'SUPABASE_QUERY_ROW_NOT_OBJECT'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson '[0]'} 'SUPABASE_QUERY_ROW_NOT_OBJECT'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson '[[]]'} 'SUPABASE_QUERY_ROW_NOT_OBJECT'}
Case {Assert-Throws {ConvertFrom-BilSupabaseQueryJson 'not json'} 'SUPABASE_QUERY_INVALID_JSON'}
Case {Assert-Throws {Get-BilSupabaseQueryRow (ConvertFrom-BilSupabaseQueryJson '[]') @('count') @('count')} 'SUPABASE_QUERY_EXPECTED_ONE_ROW'}
Case {Assert-Throws {Get-BilSupabaseQueryRow (ConvertFrom-BilSupabaseQueryJson '[{"count":0},{"count":0}]') @('count') @('count')} 'SUPABASE_QUERY_EXPECTED_ONE_ROW'}
Case {Assert-Throws {Get-BilSupabaseQueryRow (ConvertFrom-BilSupabaseQueryJson '[{}]') @('count') @('count')} 'SUPABASE_QUERY_REQUIRED_VALUE_MISSING'}
Case {Assert-Throws {Get-BilSupabaseQueryRow (ConvertFrom-BilSupabaseQueryJson '[{"count":null}]') @('count') @('count')} 'SUPABASE_QUERY_REQUIRED_VALUE_MISSING'}
Case {Assert-Throws {Get-BilSupabaseQueryRow (ConvertFrom-BilSupabaseQueryJson '[{"count":"0"}]') @('count') @('count')} 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'}
Case {Assert-Throws {Get-BilSupabaseQueryRow (ConvertFrom-BilSupabaseQueryJson '[{"count":false}]') @('count') @('count')} 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'}
Case {
  $r=[pscustomobject]@{rows=@([pscustomobject]@{count=[double]::PositiveInfinity})}
  Assert-Throws {Get-BilSupabaseQueryRow $r @('count') @('count')} 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'
}
Case {
  $r=[pscustomobject]@{rows=@([pscustomobject]@{count=[double]::NaN})}
  Assert-Throws {Get-BilSupabaseQueryRow $r @('count') @('count')} 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'
}
Case {
  $r=ConvertFrom-BilSupabaseQueryJson '[{"state":"refunded","used":0,"reserved":0}]'
  $row=Get-BilSupabaseQueryRow $r @('state','used','reserved') @('used','reserved')
  Assert-Equal ($row.state -eq 'succeeded' -and $row.used -gt 0) $false
}
Case {
  $r=ConvertFrom-BilSupabaseQueryJson '[{"count":2}]'
  Assert-Equal ((Get-BilSupabaseQueryRow $r @('count') @('count')).count -eq 0) $false
}
Case {
  $root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $paths=@(
    'tool/release/supabase_query_result.ps1',
    'tool/ai_coach/run_live_text_e2e.ps1',
    'tool/ai_coach/run_live_voice_metering_db.ps1',
    'tool/meal_vision_benchmark/run_live_supabase_e2e.ps1',
    'tool/nutrition/run_live_barcode_gate_e2e.ps1',
    'tool/account_deletion/run_live_disposable_e2e.ps1',
    'tool/community_translation/run_live_synthetic_e2e.ps1'
  )
  foreach($relative in $paths){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative),[ref]$tokens,[ref]$errors)
    if($errors.Count -ne 0){throw 'LIVE_FIXTURE_POWERSHELL_SYNTAX_FAILED'}
  }
}
Write-Output "SUPABASE_QUERY_RESULT_TESTS_PASS=$script:passed"
