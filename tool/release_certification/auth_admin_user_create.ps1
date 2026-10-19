function Get-BilAuthHttpStatusCode {
  param([Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$Failure)

  try {
    if ($null -ne $Failure.Exception.Response.StatusCode) {
      return [int]$Failure.Exception.Response.StatusCode
    }
  }
  catch {}
  return 0
}

function Find-BilAuthAdminUserByEmail {
  param(
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][scriptblock]$FetchPage,
    [ValidateRange(1, 1000)][int]$PerPage = 1000,
    [ValidateRange(1, 1000)][int]$MaxPages = 100
  )

  for ($page = 1; $page -le $MaxPages; $page++) {
    $response = & $FetchPage $page $PerPage
    $usersProperty = $response.PSObject.Properties['users']
    if ($null -eq $usersProperty) {
      throw 'Supabase Auth user listing did not return a users collection.'
    }

    $users = @($usersProperty.Value)
    foreach ($user in $users) {
      if ([string]$user.email -ieq $Email) {
        if ([string]$user.id -notmatch '^[a-f0-9-]{36}$') {
          throw 'Exact-email Auth lookup returned an invalid user ID.'
        }
        return $user
      }
    }

    if ($users.Count -lt $PerPage) {
      return $null
    }
  }

  throw "Could not confirm whether the exact fixture identity exists within $MaxPages Auth pages; refusing another create request."
}

function Invoke-BilAuthAdminUserCreateWithRecovery {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$CreateRequest,
    [Parameter(Mandatory = $true)][scriptblock]$FindUser,
    [scriptblock]$Delay,
    [ValidateCount(0, 5)][int[]]$RetryDelaysSeconds = @(5, 15)
  )

  if ($null -eq $Delay) {
    $Delay = { param($seconds) Start-Sleep -Seconds $seconds }
  }

  $ambiguousCreate = $false
  $lastFailure = $null
  $maxAttempts = 1 + $RetryDelaysSeconds.Count
  for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
      return & $CreateRequest
    }
    catch {
      $failure = $_
      $lastFailure = $failure
      $status = Get-BilAuthHttpStatusCode -Failure $failure
      $transportFailure =
        ($failure.Exception -is [System.Net.Http.HttpRequestException]) -or
        ($failure.Exception -is [System.TimeoutException]) -or
        ($failure.Exception -is [System.Threading.Tasks.TaskCanceledException])
      $retryableStatus = $status -in @(408, 429, 502, 503, 504)

      if (-not $retryableStatus -and -not ($transportFailure -and $status -eq 0)) {
        if (-not $ambiguousCreate) {
          throw
        }

        # A retry after an ambiguous timeout may return a duplicate response
        # even though the first request created the user. Confirm only this
        # exact random fixture email before surfacing that response.
        try {
          $recovered = & $FindUser
        }
        catch {
          $lookupMessage = $_.Exception.Message
          throw [System.InvalidOperationException]::new(
            "Auth create retry returned HTTP $status and exact-email recovery failed; no more create requests were sent. $lookupMessage",
            $failure.Exception
          )
        }
        if ($null -ne $recovered) {
          return $recovered
        }
        throw
      }

      $ambiguousCreate = $true
      try {
        $recovered = & $FindUser
      }
      catch {
        $lookupMessage = $_.Exception.Message
        throw [System.InvalidOperationException]::new(
          "Auth create request failed ambiguously (HTTP $status); exact-email recovery failed, so no retry was sent. $lookupMessage",
          $failure.Exception
        )
      }
      if ($null -ne $recovered) {
        return $recovered
      }

      if ($attempt -lt $maxAttempts) {
        & $Delay $RetryDelaysSeconds[$attempt - 1]
      }
    }
  }

  if ($null -ne $lastFailure) {
    throw $lastFailure
  }
  throw 'Auth Admin user creation did not return a user.'
}
