# Parse repository scripts only. Never dot-source or execute the audited scripts.
$ErrorActionPreference = 'Stop'
$auditRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
Push-Location -LiteralPath $auditRoot
try {
    $paths = @(git -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Git source enumeration failed.' }
    $diagnostics = @()
    $count = 0
    foreach ($relative in ($paths | Sort-Object -Unique)) {
        $source = Join-Path $auditRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $source, [ref]$tokens, [ref]$parseErrors)
        $count++
        foreach ($diagnostic in $parseErrors) {
            $diagnostics += [pscustomobject]@{
                File = $relative
                Line = $diagnostic.Extent.StartLineNumber
                ErrorId = $diagnostic.ErrorId
            }
        }
    }
    [pscustomobject]@{ ParsedFiles = $count; Errors = $diagnostics } | ConvertTo-Json -Depth 4
    if ($count -eq 0 -or $diagnostics.Count -ne 0) { exit 1 }
} finally {
    Pop-Location
}
