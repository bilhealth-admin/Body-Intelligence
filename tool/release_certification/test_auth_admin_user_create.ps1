$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'auth_admin_user_create.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
foreach ($relativePath in @(
  'tool/ai_coach/run_live_text_e2e.ps1',
  'tool/release_certification/native_cloud_fixture.ps1'
)) {
  $tokens = $null
  $parseErrors = $null
  $scriptPath = Join-Path $repoRoot $relativePath
  [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors.Count -gt 0) {
    throw "PowerShell parser errors in $relativePath`: $($parseErrors -join '; ')"
  }
}

function New-TestHttpFailure([int]$StatusCode) {
  $exception = [System.Exception]::new("HTTP $StatusCode test failure")
  $exception | Add-Member -MemberType NoteProperty -Name Response -Value ([pscustomobject]@{
      StatusCode = $StatusCode
    })
  return $exception
}

$targetEmail = 'bil-native-recovery-test@bilhealth.invalid'
$pageState = [pscustomobject]@{ pages = 0 }
$fetchPage = ({
  param($page, $perPage)
  $pageState.pages++
  if ($page -eq 1) {
    $items = @(
      for ($index = 0; $index -lt $perPage; $index++) {
        [pscustomobject]@{ id = ([guid]::NewGuid().ToString()); email = "other-$index@bilhealth.invalid" }
      }
    )
    return [pscustomobject]@{ users = $items }
  }
  return [pscustomobject]@{
    users = @([pscustomobject]@{
        id = '217f3e44-5130-43f9-bf35-3ed5e07aa178'
        email = $targetEmail
      })
  }
}).GetNewClosure()
$located = Find-BilAuthAdminUserByEmail -Email $targetEmail -FetchPage $fetchPage -PerPage 2 -MaxPages 3
if ($located.id -ne '217f3e44-5130-43f9-bf35-3ed5e07aa178' -or $pageState.pages -ne 2) {
  throw 'Exact-email Auth recovery did not paginate and match only the target identity.'
}

$recoverState = [pscustomobject]@{ creates = 0; lookups = 0; waits = 0 }
$createTimeout = ({
  $recoverState.creates++
  throw (New-TestHttpFailure 504)
}).GetNewClosure()
$findCreated = ({
  $recoverState.lookups++
  [pscustomobject]@{
    id = 'de5d0632-1958-4ee4-9599-9b4b21932f0a'
    email = $targetEmail
  }
}).GetNewClosure()
$noDelay = ({ param($seconds) $recoverState.waits++ }).GetNewClosure()
$recovered = Invoke-BilAuthAdminUserCreateWithRecovery `
  -CreateRequest $createTimeout `
  -FindUser $findCreated `
  -Delay $noDelay `
  -RetryDelaysSeconds @(0)
if ($recovered.id -ne 'de5d0632-1958-4ee4-9599-9b4b21932f0a' -or
    $recoverState.creates -ne 1 -or $recoverState.lookups -ne 1 -or $recoverState.waits -ne 0) {
  throw 'An ambiguous 504 did not recover the exact existing user without a duplicate create.'
}

$retryState = [pscustomobject]@{ creates = 0; lookups = 0; waits = 0 }
$retryCreate = ({
  $retryState.creates++
  if ($retryState.creates -eq 1) {
    throw (New-TestHttpFailure 504)
  }
  [pscustomobject]@{ id = 'f9ce15d4-9a12-4dbf-a365-59d794fc3bf0'; email = $targetEmail }
}).GetNewClosure()
$lookupAbsent = ({
  $retryState.lookups++
  return $null
}).GetNewClosure()
$retryDelay = ({ param($seconds) $retryState.waits++ }).GetNewClosure()
$createdAfterRetry = Invoke-BilAuthAdminUserCreateWithRecovery `
  -CreateRequest $retryCreate `
  -FindUser $lookupAbsent `
  -Delay $retryDelay `
  -RetryDelaysSeconds @(0)
if ($createdAfterRetry.id -ne 'f9ce15d4-9a12-4dbf-a365-59d794fc3bf0' -or
    $retryState.creates -ne 2 -or $retryState.lookups -ne 1 -or $retryState.waits -ne 1) {
  throw 'A confirmed absent user was not retried exactly once after an ambiguous timeout.'
}

$forbiddenState = [pscustomobject]@{ creates = 0; lookups = 0 }
$forbiddenCreate = ({
  $forbiddenState.creates++
  throw (New-TestHttpFailure 403)
}).GetNewClosure()
$forbiddenLookup = ({ $forbiddenState.lookups++ }).GetNewClosure()
$forbiddenStatus = 0
try {
  Invoke-BilAuthAdminUserCreateWithRecovery `
    -CreateRequest $forbiddenCreate `
    -FindUser $forbiddenLookup `
    -RetryDelaysSeconds @(0) | Out-Null
}
catch {
  $forbiddenStatus = Get-BilAuthHttpStatusCode -Failure $_
}
if ($forbiddenStatus -ne 403 -or $forbiddenState.creates -ne 1 -or $forbiddenState.lookups -ne 0) {
  throw 'A non-retryable Auth authorization error was retried or hidden.'
}

$reconciliationState = [pscustomobject]@{ creates = 0; lookups = 0 }
$ambiguousCreate = ({
  $reconciliationState.creates++
  throw (New-TestHttpFailure 504)
}).GetNewClosure()
$failedLookup = ({
  $reconciliationState.lookups++
  throw 'simulated recovery read failure'
}).GetNewClosure()
$reconciliationFailure = $null
try {
  Invoke-BilAuthAdminUserCreateWithRecovery `
    -CreateRequest $ambiguousCreate `
    -FindUser $failedLookup `
    -RetryDelaysSeconds @(0) | Out-Null
}
catch {
  $reconciliationFailure = $_.Exception.Message
}
if ($reconciliationState.creates -ne 1 -or $reconciliationState.lookups -ne 1 -or
    $reconciliationFailure -notmatch 'no retry was sent') {
  throw 'The helper retried creation when it could not first reconcile the ambiguous request.'
}

$fixture = Get-Content -LiteralPath (Join-Path $repoRoot 'tool/release_certification/native_cloud_fixture.ps1') -Raw
if ($fixture -notmatch 'Find-BilAuthAdminUserByEmail' -or
    $fixture -notmatch 'id\s*=\s*'''';\s*email\s*=\s*\$email') {
  throw 'Disposable native fixtures must persist a recoverable pending email before creating users.'
}

Write-Output 'AUTH_ADMIN_USER_CREATE_TESTS_PASS=5;FIXTURE_SCRIPTS_PARSE=2'
