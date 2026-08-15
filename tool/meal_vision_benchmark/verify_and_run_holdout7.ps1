param(
  [string]$ProjectRef = 'tgmanzhqulksykhslrzb'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

python -m unittest `
  tool.meal_vision_benchmark.test_score_benchmark `
  tool.meal_vision_benchmark.test_provider_integration_contract `
  tool.meal_vision_benchmark.test_deploy_readiness_static_contract
if ($LASTEXITCODE -ne 0) { throw 'Local Vision contracts failed; deployment stopped.' }

& npx --yes supabase@latest migration list --linked | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify linked migration state.' }
& npx --yes supabase@latest db push --linked | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Vision migration deployment failed.' }
& npx --yes supabase@latest functions deploy analyze-meal --project-ref $ProjectRef | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'analyze-meal deployment failed.' }

$before = Get-ChildItem artifacts -Filter 'meal_vision_live_synthetic_audit_*.json' -File |
  Select-Object -ExpandProperty FullName
& "$PSScriptRoot\run_live_synthetic_benchmark.ps1" `
  -ProjectRef $ProjectRef `
  -ManifestPath 'tool/meal_vision_benchmark/benchmark_manifest.holdout7_separated_owned.json'
if ($LASTEXITCODE -ne 0) { throw 'Holdout7 live runner failed.' }

$audit = Get-ChildItem artifacts -Filter 'meal_vision_live_synthetic_audit_*.json' -File |
  Where-Object { $_.FullName -notin $before } | Sort-Object LastWriteTimeUtc -Descending |
  Select-Object -First 1
if ($null -eq $audit) { throw 'Holdout7 audit artifact was not created.' }
$stamp = $audit.BaseName.Replace('meal_vision_live_synthetic_audit_', '')
$predictions = Join-Path $root "artifacts\meal_vision_live_synthetic_predictions_$stamp.json"
$score = Join-Path $root "artifacts\meal_vision_live_holdout7_score_$stamp.json"
python tool\meal_vision_benchmark\score_benchmark.py `
  --manifest tool\meal_vision_benchmark\benchmark_manifest.holdout7_separated_owned.json `
  --predictions $predictions --output $score
if ($LASTEXITCODE -ne 0) { throw 'Holdout7 scoring failed.' }

$auditJson = Get-Content -Raw -LiteralPath $audit.FullName | ConvertFrom-Json
$scoreJson = Get-Content -Raw -LiteralPath $score | ConvertFrom-Json
if ($auditJson.model_revision -ne 'gemini-2.5-flash') { throw "Unexpected live model: $($auditJson.model_revision)" }
if ([int]$auditJson.quota_reserved -ne 0) { throw 'Holdout7 left reserved quota.' }
if (-not $auditJson.cleanup.user_deleted -or -not $auditJson.cleanup.product_deleted) {
  throw 'Holdout7 temporary resources were not cleaned up.'
}

[ordered]@{
  status = 'complete'
  model = $auditJson.model_revision
  score = $scoreJson.summary
  quota_used = $auditJson.quota_used
  quota_reserved = $auditJson.quota_reserved
  audit = $audit.FullName
  predictions = $predictions
  score_artifact = $score
} | ConvertTo-Json -Depth 10
