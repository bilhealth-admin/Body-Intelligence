$ErrorActionPreference = 'Stop'
$catalogPath = Join-Path $PSScriptRoot '..\..\lib\app\localization\runtime_copy_extended.dart'
$lines = Get-Content -LiteralPath $catalogPath -Encoding UTF8
$tags = [System.Collections.Generic.HashSet[string]]::new()
$keys = 0
$rows = 0
$blank = 0
$generatorTokens = 0
$replacementCharacters = 0
foreach ($line in $lines) {
  if ($line -match '^    ".*": \{$') { $keys += 1 }
  # dart format wraps long translation values onto the following line. Count
  # the locale property itself rather than assuming key and value share a line.
  if ($line -match '^      "([^"]+)":(?: ".*",)?$') {
    [void]$tags.Add($Matches[1])
    $rows += 1
    if ($line -match ': "",$') { $blank += 1 }
  }
  if ($line.Contains('ZXQP')) { $generatorTokens += 1 }
  if ($line.Contains([char]0xFFFD)) { $replacementCharacters += 1 }
}
$expectedRows = $keys * $tags.Count
$result = [ordered]@{
  catalogs = $tags.Count
  keys = $keys
  translation_rows = $rows
  expected_rows = $expectedRows
  blanks = $blank
  generator_tokens = $generatorTokens
  unicode_replacement_characters = $replacementCharacters
  passed = $tags.Count -eq 20 -and $keys -ge 270 -and $rows -eq $expectedRows -and $blank -eq 0 -and $generatorTokens -eq 0 -and $replacementCharacters -eq 0
}
$result | ConvertTo-Json
if (-not $result.passed) { exit 1 }
