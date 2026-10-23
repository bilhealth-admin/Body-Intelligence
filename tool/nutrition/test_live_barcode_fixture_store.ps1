$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\release\supabase_query_result.ps1')
$source=Join-Path $PSScriptRoot 'run_live_barcode_resolved_fixture_e2e.ps1'
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count) { throw 'Live fixture source does not parse' }
# Compile the actual pure fixture functions, never the authenticated script body.
foreach($wanted in 'Db','Get-CacheRows','RemoveOwnedCacheEntry') {
  $functions=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $wanted},$true))
  if($functions.Count -ne 1) { throw 'Missing or ambiguous fixture function' }
  . ([scriptblock]::Create($functions[0].Extent.Text))
}
$fixtureName='BIL controlled barcode fixture';$fixtureBrand='BIL E2E'
$ProjectRef='offline-fixture-test';$key='1234567890123';$passed=0
function Assert($condition,[string]$message) { if(-not $condition) { throw $message } }
function Row([string]$brand=$fixtureBrand,[string]$name=$fixtureName) {
  return [pscustomobject]@{gtin=$key;payload=[pscustomobject]@{brand=$brand;name=$name}}
}
function Result([object[]]$rows=@()) { return [pscustomobject]@{rows=@($rows)} }
# Db's real JSON normalization is exercised with an in-process npx substitute.
function npx { $script:cliArguments=@($args);$global:LASTEXITCODE=0;' {"rows":[{"value":1}]}' }
$dbResult=Db 'select 1 as value'
Assert ($dbResult.rows.Count -eq 1 -and $dbResult.rows[0].value -eq 1) 'Actual CLI rows envelope was not normalized'
Assert ($script:cliArguments -contains 'offline-fixture-test') 'Explicit project ref was lost'
$passed++
Remove-Item Function:npx
function Reset([object[]]$results) {
  $script:results=[System.Collections.Generic.Queue[object]]::new()
  foreach($result in $results) { $script:results.Enqueue($result) }
  $script:queries=[System.Collections.Generic.List[string]]::new()
}
function Db([string]$sql) {
  $script:queries.Add($sql)
  if($script:results.Count -eq 0) { throw 'Unexpected fixture SQL request' }
  return $script:results.Dequeue()
}
Reset @((Result))
Assert (RemoveOwnedCacheEntry $key) 'An absent fixture was not clean'
Assert ($script:queries.Count -eq 1) 'Absent fixture triggered a write';$passed++
Reset @((Result @((Row 'Real brand' 'Real product'))))
Assert (RemoveOwnedCacheEntry $key) 'A legitimate product was not preserved'
Assert ($script:queries.Count -eq 1) 'Legitimate product triggered a delete';$passed++
Reset @((Result @((Row))),(Result @((Row))),(Result))
Assert (RemoveOwnedCacheEntry $key) 'Owned fixture cleanup did not read back absence'
$delete=$script:queries[1]
Assert ($delete.Contains("gtin='$key'") -and $delete.Contains("payload->>'brand'='BIL E2E'") -and $delete.Contains("payload->>'name'='BIL controlled barcode fixture'")) 'DELETE lost exact ownership predicates'
Assert ($script:queries.Count -eq 3) 'Cleanup omitted independent readback';$passed++
Reset @((Result @((Row))),(Result @((Row 'Other brand'))))
Assert (-not (RemoveOwnedCacheEntry $key)) 'Mismatched deleted payload was accepted';$passed++
Reset @((Result @((Row))),(Result @((Row))),(Result @((Row))))
Assert (-not (RemoveOwnedCacheEntry $key)) 'Remaining fixture was declared clean';$passed++
Reset @((Result @((Row))),(Result))
Assert (-not (RemoveOwnedCacheEntry $key)) 'Concurrent zero-row delete was accepted';$passed++
Reset @([pscustomobject]@{unexpected=@()})
$caught=$false;try { Get-CacheRows $key|Out-Null } catch { $caught=$true }
Assert $caught 'Missing rows evidence was accepted';$passed++
Reset @((Result @([pscustomobject]@{gtin=$key})))
$caught=$false;try { Get-CacheRows $key|Out-Null } catch { $caught=$true }
Assert $caught 'Malformed cache payload was accepted';$passed++
Reset @()
$caught=$false;try { Get-CacheRows "';delete from auth.users;--"|Out-Null } catch { $caught=$true }
Assert ($caught -and $script:queries.Count -eq 0) 'Untrusted GTIN reached management SQL';$passed++
Reset @((Result @((Row),(Row))))
Assert (-not (RemoveOwnedCacheEntry $key)) 'Ambiguous ownership rows were accepted';$passed++
$mainTry=@($ast.FindAll({param($node)
  $node -is [System.Management.Automation.Language.TryStatementAst] -and
  $null -ne $node.Finally -and $node.Finally.Extent.Text.Contains('RemoveOwnedCacheEntry')
},$true))
Assert ($mainTry.Count -eq 1) 'Main cleanup block is ambiguous'
$cleanupText=$mainTry[0].Finally.Extent.Text
$cleanupScript=[scriptblock]::Create($cleanupText.Substring(1,$cleanupText.Length-2))
function Invoke-RestMethod {
  param($Method,$Uri,$Headers)
  Assert ($Uri.StartsWith('https://offline.invalid/')) 'Offline test attempted an external URL'
  if($Method -eq 'Post') { throw 'Synthetic logout transport failure' }
  if($Method -eq 'Delete') {
    $script:deleteCalled=$true
    if($script:deleteFails) { throw 'Synthetic admin delete failure' }
    return
  }
  throw 'Unexpected offline fixture request'
}
function Exercise-Cleanup([bool]$deleteFails,[int]$remaining) {
  $script:deleteFails=$deleteFails;$script:deleteCalled=$false
  Reset @((Result @([pscustomobject]@{auth_users=$remaining;sessions=$remaining;entitlements=$remaining})))
  $base='https://offline.invalid';$uid='00000000-0000-4000-8000-000000000099'
  $fixtureAttempted=$false;$gtin=$null;$cleanFixture=$false;$cleanUser=$false
  $auth=[pscustomobject]@{access_token='offline-placeholder'};$pub='offline';$sh=@{}
  . $cleanupScript
  return [pscustomobject]@{clean=$cleanUser;deleted=$script:deleteCalled}
}
$cleanup=Exercise-Cleanup $false 0
Assert ($cleanup.deleted -and $cleanup.clean) 'Logout failure prevented deletion or independent cleanup verification';$passed++
$cleanup=Exercise-Cleanup $true 1
Assert ($cleanup.deleted -and -not $cleanup.clean) 'Remaining user/session evidence was declared clean';$passed++
Write-Output "BARCODE_FIXTURE_STORE_TESTS_PASS=$passed;LIVE_REQUESTS=0"
