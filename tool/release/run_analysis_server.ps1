param(
  [int]$TimeoutSeconds = 45,
  [string[]]$Paths = @()
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$included = if ($Paths.Count -eq 0) {
  @($workspace)
} else {
  @($Paths | ForEach-Object {
    (Resolve-Path (Join-Path $workspace $_)).Path
  })
}
$dartSdk = 'C:\develop\flutter\bin\cache\dart-sdk'
$runtime = Join-Path $dartSdk 'bin\dartaotruntime.exe'
$snapshot = Join-Path $dartSdk 'bin\snapshots\analysis_server_aot.dart.snapshot'

if (-not (Test-Path -LiteralPath $runtime) -or
    -not (Test-Path -LiteralPath $snapshot)) {
  throw 'Dart analysis server runtime is unavailable.'
}

$startInfo = New-Object Diagnostics.ProcessStartInfo
$startInfo.FileName = $runtime
$startInfo.Arguments = '"' + $snapshot +
    '" --client-id=bil-final-proof --sdk "' + $dartSdk + '"'
$startInfo.WorkingDirectory = $workspace
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.CreateNoWindow = $true

$process = New-Object Diagnostics.Process
$process.StartInfo = $startInfo
if (-not $process.Start()) {
  throw 'Analysis server failed to start.'
}

try {
  $subscribe = @{
    id = '1'
    method = 'server.setSubscriptions'
    params = @{ subscriptions = @('STATUS') }
  } | ConvertTo-Json -Compress -Depth 5
  $roots = @{
    id = '2'
    method = 'analysis.setAnalysisRoots'
    params = @{
      included = @($included)
      excluded = @(
        (Join-Path $workspace 'build'),
        (Join-Path $workspace 'artifacts'),
        (Join-Path $workspace 'tmp')
      )
    }
  } | ConvertTo-Json -Compress -Depth 5
  $process.StandardInput.WriteLine($subscribe)
  $process.StandardInput.WriteLine($roots)
  $process.StandardInput.Flush()

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  $seenStart = $false
  $completed = $false
  $errors = @()
  $protocolErrors = @()
  $rawLines = @()
  $read = $process.StandardOutput.ReadLineAsync()

  while ([DateTime]::UtcNow -lt $deadline -and -not $completed) {
    if (-not $read.Wait(500)) { continue }
    $line = $read.Result
    if ($null -eq $line) { break }
    if ($rawLines.Count -lt 20) { $rawLines += $line }
    try {
      $message = $line | ConvertFrom-Json
    } catch {
      $read = $process.StandardOutput.ReadLineAsync()
      continue
    }
    if ($null -ne $message.error) {
      $protocolErrors += $message.error
      break
    }
    if ($message.event -eq 'analysis.errors' -and
        $message.params.errors.Count -gt 0) {
      $errors += $message
    }
    if ($message.event -eq 'server.status' -and
        $null -ne $message.params.analysis) {
      if ($message.params.analysis.isAnalyzing) {
        $seenStart = $true
      } elseif ($seenStart) {
        $completed = $true
      }
    }
    $read = $process.StandardOutput.ReadLineAsync()
  }

  $allErrors = @()
  foreach ($event in $errors) {
    foreach ($error in $event.params.errors) {
      $allErrors += [pscustomobject]@{
        File = $event.params.file
        Line = $error.location.startLine
        Severity = $error.severity
        Type = $error.type
        Message = $error.message
      }
    }
  }

  Write-Output "ANALYSIS_COMPLETED=$completed"
  Write-Output "ANALYZER_ERROR_COUNT=$($allErrors.Count)"
  Write-Output "ANALYSIS_PROTOCOL_ERROR_COUNT=$($protocolErrors.Count)"
  $allErrors | Sort-Object File, Line | Format-Table -AutoSize
  if ($protocolErrors.Count -gt 0) {
    $protocolErrors | ConvertTo-Json -Depth 5
  }

  if (-not $completed -or
      $allErrors.Count -gt 0 -or
      $protocolErrors.Count -gt 0) {
    if (-not $completed) {
      Write-Output 'ANALYSIS_SERVER_PROTOCOL_SAMPLE'
      $rawLines
    }
    exit 1
  }
} finally {
  if (-not $process.HasExited) {
    $process.Kill()
    $process.WaitForExit()
  }
  $standardError = $process.StandardError.ReadToEnd()
  if ($standardError) {
    Write-Error $standardError
  }
  $process.Dispose()
}
