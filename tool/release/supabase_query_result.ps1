# Normalize the documented Supabase CLI db-query JSON formats without relying
# on agent auto-detection. Never infer a successful zero count from missing data.
function ConvertFrom-BilSupabaseQueryJson {
  param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Json)
  try { $parsed = ConvertFrom-Json -InputObject $Json -NoEnumerate -ErrorAction Stop }
  catch { throw 'SUPABASE_QUERY_INVALID_JSON' }
  if ($parsed -is [System.Array]) {
    $rows = $parsed
  } elseif ($parsed -is [pscustomobject] -and $parsed.PSObject.Properties.Name -contains 'rows' -and $parsed.rows -is [System.Array]) {
    $rows = $parsed.rows
  } else {
    throw 'SUPABASE_QUERY_UNSUPPORTED_JSON_SHAPE'
  }
  foreach ($row in $rows) {
    if ($row -isnot [pscustomobject]) { throw 'SUPABASE_QUERY_ROW_NOT_OBJECT' }
  }
  # Wrap the array so PowerShell's pipeline cannot unwrap [] or a singleton.
  return [pscustomobject]@{ rows = @($rows) }
}

function Get-BilSupabaseQueryRow {
  param(
    [Parameter(Mandatory=$true)]$Result,
    [Parameter(Mandatory=$true)][string[]]$RequiredColumns,
    [string[]]$NumericColumns = @()
  )
  if ($Result -isnot [pscustomobject] -or $Result.rows -isnot [System.Array] -or $Result.rows.Count -ne 1) {
    throw 'SUPABASE_QUERY_EXPECTED_ONE_ROW'
  }
  $row = $Result.rows[0]
  foreach ($column in $RequiredColumns) {
    if ($row.PSObject.Properties.Name -notcontains $column -or $null -eq $row.$column) {
      throw 'SUPABASE_QUERY_REQUIRED_VALUE_MISSING'
    }
  }
  foreach ($column in $NumericColumns) {
    if ($RequiredColumns -notcontains $column) { throw 'SUPABASE_QUERY_NUMERIC_COLUMN_NOT_REQUIRED' }
    $value = $row.$column
    if ($value -is [bool] -or $value -is [string] -or $value -isnot [System.ValueType]) {
      throw 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'
    }
    try { $number = [double]$value }
    catch { throw 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID' }
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
      throw 'SUPABASE_QUERY_NUMERIC_VALUE_INVALID'
    }
  }
  return $row
}
