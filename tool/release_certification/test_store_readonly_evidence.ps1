$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'store_readonly_evidence.ps1')

foreach ($name in @('run_store_readonly.ps1', 'store_readonly_evidence.ps1')) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot $name), [ref]$tokens, [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors.Count -gt 0) { throw "PowerShell parser errors in $name" }
}

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$root = Assert-StoreReadonlyChildPath -ParentPath $tempParent -ChildPath (
  Join-Path $tempParent ('bil-store-evidence-test-' + [guid]::NewGuid().ToString('N'))
)
New-Item -ItemType Directory -Path $root | Out-Null
try {
  $evidence = Join-Path $root 'evidence'
  $output = Join-Path $root 'failure-output'
  New-Item -ItemType Directory -Path $evidence | Out-Null
  $state = [pscustomobject]@{ cleaned = $false }
  $failure = $null
  try {
    Invoke-StoreReadonlyEvidence -OutputDir $output -EvidenceDir $evidence -Audit {
      '{"mode":"read-only","mutationPerformed":false}' | Set-Content (Join-Path $evidence 'apple-v1.json')
      '{"failure":{"httpStatus":403}}' | Set-Content (Join-Path $evidence 'google-release.json')
      'must-not-be-published' | Set-Content (Join-Path $evidence 'secret.json')
      throw 'Google read-only audit failed'
    } -Cleanup { $state.cleaned = $true }
  } catch { $failure = $_ }
  if ($null -eq $failure -or $failure.Exception.Message -ne 'Google read-only audit failed') { throw 'Google failure was lost or turned into success' }
  if (-not $state.cleaned) { throw 'Cleanup was skipped after audit failure' }
  if ((Get-Content (Join-Path $output 'status.txt') -Raw).Trim() -ne 'STORE_READONLY=FAIL') { throw 'Failure status was not retained' }
  foreach ($name in @('apple-v1.json', 'google-release.json')) {
    if ((Get-Content (Join-Path $output $name) -Raw) -ne (Get-Content (Join-Path $evidence $name) -Raw)) { throw "Partial evidence was lost: $name" }
  }
  if (Test-Path (Join-Path $output 'secret.json')) { throw 'An unallowlisted file was published' }

  $output = Join-Path $root 'success-output'
  $state.cleaned = $false
  Invoke-StoreReadonlyEvidence -OutputDir $output -EvidenceDir $evidence -Audit {} -Cleanup { $state.cleaned = $true }
  if (-not $state.cleaned -or (Get-Content (Join-Path $output 'status.txt') -Raw).Trim() -ne 'STORE_READONLY=PASS') { throw 'Successful audit did not complete normally' }

  $output = Join-Path $root 'dual-failure-output'
  $failure = $null
  try {
    Invoke-StoreReadonlyEvidence -OutputDir $output -EvidenceDir $evidence -Audit { throw 'primary-audit-failure' } -Cleanup { throw 'secondary-cleanup-failure' }
  } catch { $failure = $_ }
  if ($null -eq $failure -or $failure.Exception.Message -ne 'primary-audit-failure') { throw 'Cleanup erased the primary failure' }
  if ((Get-Content (Join-Path $output 'status.txt') -Raw).Trim() -ne 'STORE_READONLY=FAIL') { throw 'Dual failure was marked PASS' }

  function New-MockedStoreDrive([string]$Name) {
    $state = [pscustomobject]@{
      occupied = $false; mapCode = 0; unmapCode = 0; mapping = $null
      overrideMapping = $null; allocated = $null; auditFailure = $false
      tamperMapping = $false; extraSecret = $false
      mapCalls = 0; auditCalls = 0; unmapCalls = 0
    }
    $arguments = @{
      RunnerTemp = $root
      OutputDir = Join-Path $root $Name
      DriveExists = ({ return $state.occupied }).GetNewClosure()
      MapDrive = ({
        param($path)
        $state.mapCalls += 1
        $state.allocated = $path
        $state.mapping = if ($state.overrideMapping) { $state.overrideMapping } else { $path }
        return $state.mapCode
      }).GetNewClosure()
      ReadMappings = ({ return "G:\: => $($state.mapping)" }).GetNewClosure()
      UnmapDrive = ({ $state.unmapCalls += 1; return $state.unmapCode }).GetNewClosure()
      Audit = ({
        param($path)
        $state.auditCalls += 1
        $secret = Join-Path $path 'secret'
        $reports = Join-Path $path 'evidence'
        New-Item -ItemType Directory -Path $secret, $reports | Out-Null
        'synthetic-apple-key' | Set-Content (Join-Path $secret 'asc.p8')
        'synthetic-google-key' | Set-Content (Join-Path $secret 'google.json')
        '{}' | Set-Content (Join-Path $reports 'apple-v1.json')
        '{}' | Set-Content (Join-Path $reports 'google-release.json')
        if ($state.extraSecret) { 'preserve-unknown-file' | Set-Content (Join-Path $secret 'unrelated.txt') }
        if ($state.tamperMapping) { $state.mapping = Join-Path $path 'wrong-target' }
        if ($state.auditFailure) { throw 'synthetic-audit-failure' }
      }).GetNewClosure()
    }
    return [pscustomobject]@{ State = $state; Arguments = $arguments }
  }

  function Assert-MockedStoreDriveFailure($Case, [string]$Message) {
    $captured = $null
    $invokeArguments = $Case.Arguments
    try { Invoke-StoreReadonlyDrive @invokeArguments } catch { $captured = $_ }
    if ($null -eq $captured -or $captured.Exception.Message -notlike "*$Message*") {
      throw "Expected store drive safety failure: $Message; received $captured"
    }
  }

  $case = New-MockedStoreDrive 'occupied-drive'
  $case.State.occupied = $true
  Assert-MockedStoreDriveFailure $case 'G is already present'
  if ($case.State.mapCalls -ne 0 -or $case.State.auditCalls -ne 0 -or $case.State.unmapCalls -ne 0) { throw 'An existing drive was modified' }

  $case = New-MockedStoreDrive 'subst-failure'
  $case.State.mapCode = 1
  Assert-MockedStoreDriveFailure $case 'drive creation failed'
  if ($case.State.auditCalls -ne 0 -or $case.State.unmapCalls -ne 0) { throw 'Failed mapping proceeded to audit or unmap' }

  $case = New-MockedStoreDrive 'wrong-mapping'
  $case.State.overrideMapping = Join-Path $root 'unowned-drive'
  Assert-MockedStoreDriveFailure $case 'does not match'
  if ($case.State.auditCalls -ne 0 -or $case.State.unmapCalls -ne 0) { throw 'An unowned mapping was used or removed' }

  $case = New-MockedStoreDrive 'audit-failure-cleanup'
  $case.State.auditFailure = $true
  Assert-MockedStoreDriveFailure $case 'synthetic-audit-failure'
  if ($case.State.unmapCalls -ne 1 -or (Test-Path (Join-Path $case.State.allocated 'secret'))) { throw 'Owned synthetic secret cleanup did not complete' }
  if (-not (Test-Path (Join-Path $case.Arguments.OutputDir 'apple-v1.json'))) { throw 'Drive wrapper lost partial audit evidence' }

  $case = New-MockedStoreDrive 'owned-drive-success'
  $invokeArguments = $case.Arguments
  Invoke-StoreReadonlyDrive @invokeArguments
  if ($case.State.mapCalls -ne 1 -or $case.State.auditCalls -ne 1 -or $case.State.unmapCalls -ne 1) { throw 'Owned drive audit did not complete its exact lifecycle' }
  if (Test-Path (Join-Path $case.State.allocated 'secret')) { throw 'Owned drive success retained synthetic credentials' }
  if ((Get-Content (Join-Path $case.Arguments.OutputDir 'status.txt') -Raw).Trim() -ne 'STORE_READONLY=PASS') { throw 'Owned drive success did not retain PASS' }

  $case = New-MockedStoreDrive 'mapping-tampered'
  $case.State.tamperMapping = $true
  Assert-MockedStoreDriveFailure $case 'does not match'
  if ($case.State.unmapCalls -ne 0 -or -not (Test-Path (Join-Path $case.State.allocated 'secret/asc.p8'))) { throw 'Changed mapping was cleaned or unmapped' }

  $case = New-MockedStoreDrive 'unexpected-secret-file'
  $case.State.extraSecret = $true
  Assert-MockedStoreDriveFailure $case 'unexpected entries'
  if (-not (Test-Path (Join-Path $case.State.allocated 'secret/unrelated.txt'))) { throw 'Cleanup recursively deleted an unallowlisted file' }

  $case = New-MockedStoreDrive 'unmap-failure'
  $case.State.unmapCode = 1
  Assert-MockedStoreDriveFailure $case 'drive removal failed'
  if ((Get-Content (Join-Path $case.Arguments.OutputDir 'status.txt') -Raw).Trim() -ne 'STORE_READONLY=FAIL') { throw 'Unmap failure retained a PASS status' }

  $escaped = $null
  try { $null = Assert-StoreReadonlyChildPath -ParentPath $root -ChildPath (Join-Path $root '../outside-allocation') } catch { $escaped = $_ }
  if ($null -eq $escaped) { throw 'Parent traversal escaped deletion containment' }
  Write-Output 'STORE_READONLY_EVIDENCE_TESTS_PASS=3;STORE_DRIVE_SAFETY_TESTS_PASS=9;POWERSHELL_PARSE=2'
} finally {
  $null = Assert-StoreReadonlyChildPath -ParentPath $tempParent -ChildPath $root
  if ([IO.Path]::GetFileName($root) -notmatch '^bil-store-evidence-test-[a-f0-9]{32}$') { throw 'Refusing unexpected test cleanup target' }
  Remove-Item -LiteralPath $root -Recurse -Force
}
