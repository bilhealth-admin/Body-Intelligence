# Inserted inside the existing disposable-account lifecycle. No real-user IDs,
# service-role client reads, provider calls, schema changes, or diary writes.
$fixtureSet = Get-Content -LiteralPath $planFixturePath -Raw | ConvertFrom-Json -Depth 100
if ($fixtureSet.schema -ne 'bil.smart-plan.live-fixtures.v1' -or $fixtureSet.cases.Count -ne 12) { throw 'Invalid real-client fixture inventory.' }
[void][guid]::Parse($userId)
$assertions = [ordered]@{}
$roundtrips = @()
function Invoke-PlanRpc([string]$Name, $Payload) {
  if ($Name -notin @('bil_smart_plan_read_v1','bil_smart_plan_cas_v1','bil_smart_plan_consent_v1')) { throw 'Unsupported live RPC.' }
  Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/$Name" -Headers $userHeaders -ContentType 'application/json' -Body ($Payload | ConvertTo-Json -Depth 100 -Compress) -TimeoutSec 20
}
function Assert-PlanDenied([string]$Name, $Payload, [string]$Code) {
  $denied = $false
  try { [void](Invoke-PlanRpc $Name $Payload) }
  catch {
    $rpcFailure = $_
    try { $failure = (Get-HttpFailureBody $rpcFailure) | ConvertFrom-Json }
    catch {
      $status = $null
      try { $status = [int]$rpcFailure.Exception.Response.StatusCode } catch {}
      throw "Expected SQL denial was not JSON. Status=$status; Kind=$($rpcFailure.Exception.GetType().Name); ErrorId=$($rpcFailure.FullyQualifiedErrorId)"
    }
    if ($failure.code -ne $Code) { throw 'Live RPC failed for an unexpected reason.' }
    if ($Code -eq 'PT409' -and [int]$rpcFailure.Exception.Response.StatusCode -ne 409) { throw 'Stale revision did not return HTTP 409.' }
    $denied = $true
  }
  if (-not $denied) { throw 'Forbidden live RPC unexpectedly succeeded.' }
}
Assert-PlanDenied 'bil_smart_plan_read_v1' @{} '42501'
$assertions['consent_required'] = $true
[void](Invoke-PlanRpc 'bil_smart_plan_consent_v1' @{granted=$true})
$initial = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
if ($initial.revision -ne 0 -or $null -ne $initial.payload) { throw 'Disposable plan state was not empty.' }
$revision = 0
foreach ($case in $fixtureSet.cases) {
  $payload = $case.draft
  $payload.ownerId = $userId
  $saved = Invoke-PlanRpc 'bil_smart_plan_cas_v1' @{expected_revision=$revision; next_payload=$payload}
  $read = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
  if ($saved.revision -ne ($revision+1) -or $read.revision -ne $saved.revision -or $read.payload.ownerId -ne $userId) { throw 'Actual saved revision/owner readback mismatch.' }
  $revision = [int]$read.revision
  $roundtrips += @{horizon=$case.horizon; focus=$case.focus; sent=$payload; received=$read.payload; write_payload=$saved.payload; cloud_revision=$revision}
}
$assertions['all_twelve_actual_rpc_readbacks'] = $true
$foreign = $fixtureSet.cases[-1].draft | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
$foreign.ownerId = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff'
Assert-PlanDenied 'bil_smart_plan_cas_v1' @{expected_revision=$revision; next_payload=$foreign} '23514'
if ((Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}).revision -ne $revision) { throw 'Foreign owner attempt changed cloud state.' }
$assertions['foreign_owner_payload_denied'] = $true
# Independent writers read the same version, then one becomes stale.
$writerA = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
$writerB = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
$fixtureSet.active.ownerId = $userId
$fixtureSet.completed.ownerId = $userId
$active = Invoke-PlanRpc 'bil_smart_plan_cas_v1' @{expected_revision=$writerA.revision; next_payload=$fixtureSet.active}
Assert-PlanDenied 'bil_smart_plan_cas_v1' @{expected_revision=$writerB.revision; next_payload=$fixtureSet.completed} 'PT409'
$afterConflict = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
if ($afterConflict.revision -ne $active.revision -or $afterConflict.payload.status -ne 'active') { throw 'Stale writer overwrote the active plan.' }
$assertions['two_writer_conflict_preserved'] = $true
$complete = Invoke-PlanRpc 'bil_smart_plan_cas_v1' @{expected_revision=$active.revision; next_payload=$fixtureSet.completed}
$completeRead = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
Assert-PlanDenied 'bil_smart_plan_cas_v1' @{expected_revision=$active.revision; next_payload=$fixtureSet.completed} 'PT409'
$assertions['duplicate_revision_replay_denied'] = $true
$deleted = Invoke-PlanRpc 'bil_smart_plan_cas_v1' @{expected_revision=$complete.revision; next_payload=$null}
$deletedRead = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
if ($deletedRead.revision -ne $deleted.revision -or $null -ne $deletedRead.payload) { throw 'Cloud deletion tombstone was not durable.' }
Assert-PlanDenied 'bil_smart_plan_cas_v1' @{expected_revision=$complete.revision; next_payload=$fixtureSet.completed} 'PT409'
$assertions['tombstone_prevents_stale_resurrection'] = $true
[void](Invoke-PlanRpc 'bil_smart_plan_consent_v1' @{granted=$false})
Assert-PlanDenied 'bil_smart_plan_read_v1' @{} '42501'
[void](Invoke-PlanRpc 'bil_smart_plan_consent_v1' @{granted=$true})
$reconsent = Invoke-PlanRpc 'bil_smart_plan_read_v1' @{}
if ($null -ne $reconsent.payload -or $reconsent.revision -ne ($deletedRead.revision+1)) { throw 'Consent change resurrected deleted content.' }
$assertions['revocation_and_reconsent_preserve_deletion'] = $true
$result = @{success=$true; assertions=$assertions; roundtrips=$roundtrips;
  active_sent=$fixtureSet.active; active_received=$afterConflict.payload;
  completed_sent=$fixtureSet.completed; completed_received=$completeRead.payload;
  no_gemini_calls=$true; no_diary_actions=$true; final_revision=$reconsent.revision}
