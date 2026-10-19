function Get-HttpFailureBody($Failure) {
  $exception = $null
  $errorBody = $null

  if ($Failure -is [System.Management.Automation.ErrorRecord]) {
    $exception = $Failure.Exception
    $errorBody = [string]$Failure.ErrorDetails.Message
  } elseif ($Failure -is [System.Exception]) {
    $exception = $Failure
  } else {
    try { $exception = $Failure.Exception } catch {}
    try { $errorBody = [string]$Failure.ErrorDetails.Message } catch {}
  }

  # PowerShell captures non-success response bodies here. Prefer that copy:
  # Invoke-RestMethod may dispose the underlying response content before the
  # catch block runs, especially when automatic decompression is enabled.
  if (-not [string]::IsNullOrWhiteSpace($errorBody)) { return $errorBody }
  if ($null -eq $exception) { return [string]$Failure }

  $response = $null
  try { $response = $exception.Response } catch {}
  if ($null -eq $response) { return [string]$exception.Message }

  try {
    $content = $response.Content
    if ($null -ne $content) {
      try {
        $readTask = $content.ReadAsStringAsync()
        if ($null -ne $readTask) {
          $body = [string]$readTask.GetAwaiter().GetResult()
          if (-not [string]::IsNullOrWhiteSpace($body)) { return $body }
        }
      } catch {
        # A consumed or disposed response must not replace the original error.
      }
    }
  } catch {
    # Some legacy response types do not expose HttpContent.
  }

  try {
    $stream = $response.GetResponseStream()
    if ($null -ne $stream) {
      $reader = [System.IO.StreamReader]::new($stream)
      try {
        $body = $reader.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($body)) { return $body }
      } finally {
        $reader.Dispose()
      }
    }
  } catch {
    # The response stream may also have been disposed by the HTTP handler.
  }

  return [string]$exception.Message
}
