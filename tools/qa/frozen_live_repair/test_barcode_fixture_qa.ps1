param([Parameter(Mandatory=$true)][string]$FunctionsPath,
      [Parameter(Mandatory=$true)][string]$PatchedScript)
$ErrorActionPreference='Stop'
$tokens=$null;$parseErrors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($PatchedScript,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count -ne 0) { throw 'Patched live fixture does not parse' }
. $FunctionsPath
$fixtureBrand='BIL E2E'
$fixtureName='BIL controlled barcode fixture'
$key='4006381333931'
$owned=[pscustomobject]@{gtin=$key;payload=[pscustomobject]@{brand=$fixtureBrand;name=$fixtureName}}
$real=[pscustomobject]@{gtin=$key;payload=[pscustomobject]@{brand='Real brand';name='Real product'}}
function Reset-Mocks {
  $script:queue=[System.Collections.Queue]::new()
  $script:queries=[System.Collections.Generic.List[string]]::new()
}
function Db([string]$sql) {
  $script:queries.Add($sql)
  if($script:queue.Count -eq 0) { throw 'Unexpected management query' }
  foreach($row in $script:queue.Dequeue()) { $row }
}
function Require([bool]$value,[string]$case) {
  if(-not $value) { throw "QA fixture safety regression: $case" }
  Write-Output "BARCODE_QA_CASE=PASS:$case"
}
Reset-Mocks
$script:queue.Enqueue(@())
Require (RemoveOwnedCacheEntry $key) 'absent fixture is clean'
Require ($script:queries.Count -eq 1) 'absent fixture never deletes'
Reset-Mocks
$script:queue.Enqueue(@($real))
Require (RemoveOwnedCacheEntry $key) 'real product preserved'
Require ($script:queries.Count -eq 1) 'real product never deletes'
Reset-Mocks
$script:queue.Enqueue(@($owned,$owned))
Require (-not (RemoveOwnedCacheEntry $key)) 'duplicate rows rejected'
Reset-Mocks
$script:queue.Enqueue(@($owned));$script:queue.Enqueue(@($owned));$script:queue.Enqueue(@())
Require (RemoveOwnedCacheEntry $key) 'owned fixture removed and independently read back'
Require ($script:queries[1].Contains("where gtin='$key' and payload->>'brand'='BIL E2E' and payload->>'name'='BIL controlled barcode fixture' returning gtin,payload")) 'atomic exact synthetic identity guard'
Reset-Mocks
$script:queue.Enqueue(@($owned));$script:queue.Enqueue(@())
Require (-not (RemoveOwnedCacheEntry $key)) 'missing delete receipt rejected'
Reset-Mocks
$script:queue.Enqueue(@($owned));$script:queue.Enqueue(@($owned));$script:queue.Enqueue(@($owned))
Require (-not (RemoveOwnedCacheEntry $key)) 'residue is not success'
Reset-Mocks
$thrown=$false
try { [void](RemoveOwnedCacheEntry "4006381333931' or true--") } catch { $thrown=$true }
Require ($thrown -and $script:queries.Count -eq 0) 'unsafe GTIN rejected before SQL'
Reset-Mocks
$script:queue.Enqueue(@([pscustomobject]@{gtin='1234567890123';payload=$owned.payload}))
Require (-not (RemoveOwnedCacheEntry $key)) 'wrong returned identity rejected'
Write-Output 'BARCODE_QA_OFFLINE_SAFETY=PASS;NETWORK_CALLS=0'
