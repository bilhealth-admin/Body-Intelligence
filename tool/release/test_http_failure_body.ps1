$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'http_failure_body.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
foreach ($relativePath in @(
  'tool/ai_coach/run_live_text_e2e.ps1',
  'tool/meal_vision_benchmark/run_live_synthetic_benchmark.ps1',
  'tool/meal_vision_benchmark/run_live_supabase_e2e.ps1'
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

$expectedBody = '{"error":"provider_unavailable","request_id":"test-request"}'
$bodyException = [System.Exception]::new('HTTP request failed')
$bodyRecord = [System.Management.Automation.ErrorRecord]::new(
  $bodyException,
  'TestHttpFailureBody',
  [System.Management.Automation.ErrorCategory]::InvalidOperation,
  $null
)
$bodyRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($expectedBody)
if ((Get-HttpFailureBody $bodyRecord) -cne $expectedBody) {
  throw 'The captured HTTP error body was not preserved.'
}

$stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes('unread response body'))
$content = [System.Net.Http.StreamContent]::new($stream)
$stream.Dispose()
$response = [System.Net.Http.HttpResponseMessage]::new()
$response.Content = $content
$disposedException = [System.Exception]::new('Original HTTP failure')
$disposedException | Add-Member -MemberType NoteProperty -Name Response -Value $response
$disposedRecord = [System.Management.Automation.ErrorRecord]::new(
  $disposedException,
  'TestDisposedHttpContent',
  [System.Management.Automation.ErrorCategory]::InvalidOperation,
  $null
)
if ((Get-HttpFailureBody $disposedRecord) -cne 'Original HTTP failure') {
  throw 'Disposed response content replaced the original HTTP failure.'
}

$response.Dispose()
Write-Output 'HTTP_FAILURE_BODY_TESTS_PASS=2;LIVE_SCRIPT_PARSE=3'
