[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$script = 'G:\BIL_Project\body_intelligence_log\tool\qa\complete_swsetup_relocation_elevated.ps1'
$result = 'G:\BIL_Project\body_intelligence_log\artifacts\disk_cleanup\swsetup_relocation_result.json'

if (Test-Path -LiteralPath $result) {
  Remove-Item -LiteralPath $result -Force
}

$startParameters = @{
  FilePath = 'powershell.exe'
  ArgumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script + '"'))
  Verb = 'RunAs'
  WindowStyle = 'Hidden'
  PassThru = $true
}
$process = Start-Process @startParameters

[pscustomobject]@{
  ElevatedPid = $process.Id
  ResultPath = $result
}
