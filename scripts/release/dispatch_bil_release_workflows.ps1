#!/usr/bin/env pwsh
param(
  [Parameter(Mandatory = $false)]
  [string]$GithubToken = $env:GITHUB_TOKEN,

  [Parameter(Mandatory = $false)]
  [string]$Owner = 'bilhealth-admin',

  [Parameter(Mandatory = $false)]
  [string]$Repo = 'Body-Intelligence',

  [Parameter(Mandatory = $false)]
  [string]$Ref = '',

  [Parameter(Mandatory = $false)]
  [string]$AndroidWorkflow = 'bil_android_release_candidate.yml',

  [Parameter(Mandatory = $false)]
  [string]$IosWorkflow = 'bil_ios_signed_release.yml',

  [Parameter(Mandatory = $false)]
  [string]$IosBuildNumber = '11',

  [Parameter(Mandatory = $false)]
  [string]$AndroidBuildNumber = '9',

  [Parameter(Mandatory = $false)]
  [bool]$UploadToTestflight = $true,

  [Parameter(Mandatory = $false)]
  [bool]$RunNativeCryptoChecksIos = $false,

  [Parameter(Mandatory = $false)]
  [bool]$RunNativeCryptoChecksAndroid = $false,

  [Parameter(Mandatory = $false)]
  [bool]$WaitForRuns = $false,

  [Parameter(Mandatory = $false)]
  [string]$OutputJson = '',

  [Parameter(Mandatory = $false)]
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ReleaseRef {
  param([string]$RequestedRef)

  if ([string]::IsNullOrWhiteSpace($RequestedRef)) {
    $head = (& git rev-parse HEAD).Trim()
    if (-not $head) {
      throw 'Unable to resolve current git HEAD. Run this command inside the project repository.'
    }
    return $head
  }
  return $RequestedRef.Trim()
}

function Resolve-AuthHeaders {
  param([string]$Token)

  if ([string]::IsNullOrWhiteSpace($Token)) {
    throw 'GITHUB_TOKEN is required. Set it in env:GITHUB_TOKEN or pass -GithubToken.'
  }

  return @{
    Authorization           = "token $Token"
    Accept                  = 'application/vnd.github+json'
    'User-Agent'           = 'bil-release-api-orchestrator'
    'X-GitHub-Api-Version' = '2022-11-28'
  }
}

function Invoke-GitHubDispatch {
  param(
    [string]$Owner,
    [string]$Repo,
    [string]$Workflow,
    [hashtable]$Inputs,
    [string]$Ref,
    [hashtable]$Headers,
    [string]$ApiRoot = 'https://api.github.com',
    [bool]$DryRun
  )

  $requestUri = "${ApiRoot}/repos/$Owner/$Repo/actions/workflows/$Workflow/dispatches"
  $payload = @{ ref = $Ref; inputs = $Inputs }

  if ($DryRun) {
    Write-Host "[DRY-RUN] POST $requestUri"
    Write-Host (ConvertTo-Json $payload -Depth 10)
    return
  }

  $json = ConvertTo-Json $payload -Depth 10
  $response = Invoke-WebRequest -Method POST -Uri $requestUri -Headers $Headers -Body $json
  if ($response.StatusCode -ne 204) {
    throw "GitHub workflow dispatch failed for $Workflow with status $($response.StatusCode)."
  }
}

function Get-LatestWorkflowRunBySha {
  param(
    [string]$Owner,
    [string]$Repo,
    [string]$Workflow,
    [string]$HeadSha,
    [hashtable]$Headers,
    [string]$ApiRoot = 'https://api.github.com',
    [int]$Retries = 10
  )

  $encodedSha = [uri]::EscapeDataString($HeadSha)
  $runsUri = "${ApiRoot}/repos/$Owner/$Repo/actions/workflows/$Workflow/runs?event=workflow_dispatch&head_sha=$encodedSha&per_page=20"

  for ($attempt = 1; $attempt -le $Retries; $attempt += 1) {
    $runsResponse = Invoke-RestMethod -Method GET -Uri $runsUri -Headers $Headers
    $runs = @($runsResponse.workflow_runs)

    if ($runs.Count -gt 0) {
      $sorted = $runs | Sort-Object -Property created_at -Descending
      return $sorted[0].id
    }

    Start-Sleep -Milliseconds 500
  }

  return $null
}

function Test-PositiveInt {
  param([string]$value)
  return [regex]::IsMatch($value, '^\d+$')
}

$ref = Resolve-ReleaseRef -RequestedRef $Ref
if (-not (Test-PositiveInt $IosBuildNumber) -or [int]$IosBuildNumber -lt 11) {
  throw 'iOS build number must be a positive integer of 11 or greater.'
}
if (-not (Test-PositiveInt $AndroidBuildNumber) -or [int]$AndroidBuildNumber -lt 9) {
  throw 'Android build number must be a positive integer of 9 or greater.'
}

$headers = Resolve-AuthHeaders -Token $GithubToken

$runInfo = [ordered]@{
  ref                           = $ref
  started_at                    = (Get-Date).ToString('o')
  repository                    = "$Owner/$Repo"
  ios_workflow                  = $IosWorkflow
  android_workflow              = $AndroidWorkflow
  ios_build_number              = $IosBuildNumber
  android_build_number          = $AndroidBuildNumber
  ios_upload_to_testflight      = $UploadToTestflight
  ios_run_native_crypto_checks  = $RunNativeCryptoChecksIos
  android_run_native_crypto_checks = $RunNativeCryptoChecksAndroid
  android_run_id                = $null
  ios_run_id                    = $null
}

$androidInputs = @{
  build_number = $AndroidBuildNumber
  run_native_crypto_checks = $RunNativeCryptoChecksAndroid
}
$iosInputs = @{
  build_number = $IosBuildNumber
  upload_to_testflight = $UploadToTestflight
  run_native_crypto_checks = $RunNativeCryptoChecksIos
}

Write-Host "Dispatching Android workflow -> $AndroidWorkflow (build_number=$AndroidBuildNumber)"
Invoke-GitHubDispatch -Owner $Owner -Repo $Repo -Workflow $AndroidWorkflow -Inputs $androidInputs -Ref $ref -Headers $headers -DryRun:$DryRun
Write-Host "Dispatching iOS workflow -> $IosWorkflow (build_number=$IosBuildNumber, upload_to_testflight=$UploadToTestflight)"
Invoke-GitHubDispatch -Owner $Owner -Repo $Repo -Workflow $IosWorkflow -Inputs $iosInputs -Ref $ref -Headers $headers -DryRun:$DryRun

if ($DryRun) {
  $runInfo.android_run_id = 'dry-run'
  $runInfo.ios_run_id = 'dry-run'
  $dryRunOutput = [pscustomobject]$runInfo
  Write-Output $dryRunOutput
  if (-not [string]::IsNullOrWhiteSpace($OutputJson)) {
    $dryRunOutput | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 -FilePath $OutputJson
    Write-Host "Saved dry-run evidence -> $OutputJson"
  }
  return
}

if ($WaitForRuns) {
  Write-Host 'Waiting up to 90 seconds for workflow run IDs...'
  $end = (Get-Date).AddSeconds(90)
  while ((Get-Date) -lt $end) {
    if (-not $runInfo.android_run_id) {
      $runInfo.android_run_id = Get-LatestWorkflowRunBySha -Owner $Owner -Repo $Repo -Workflow $AndroidWorkflow -HeadSha $ref -Headers $headers
    }
    if (-not $runInfo.ios_run_id) {
      $runInfo.ios_run_id = Get-LatestWorkflowRunBySha -Owner $Owner -Repo $Repo -Workflow $IosWorkflow -HeadSha $ref -Headers $headers
    }

    if ($runInfo.android_run_id -and $runInfo.ios_run_id) { break }
    Start-Sleep -Seconds 3
  }
}

$output = [pscustomobject]$runInfo
Write-Output $output
if (-not [string]::IsNullOrWhiteSpace($OutputJson)) {
  $output | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 -FilePath $OutputJson
  Write-Host "Saved evidence -> $OutputJson"
}
