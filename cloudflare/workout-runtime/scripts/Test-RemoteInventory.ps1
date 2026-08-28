param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,
    [Parameter(Mandatory = $true)]
    [string]$BearerToken,
    [string]$PlanPath = "../../../artifacts/workout_media/cloudflare_runtime_v2/runtime_object_plan_v2.json",
    [string]$RegistryPath = "../../../artifacts/workout_media/workout_release_bundle_registry_v1.json"
)

$ErrorActionPreference = "Stop"
$origin = [Uri]$BaseUrl
if (-not $origin.IsAbsoluteUri -or $origin.Scheme -ne "https" -or
    $origin.Query -or $origin.Fragment -or $origin.AbsolutePath -ne "/") {
    throw "BaseUrl must be an HTTPS origin ending at /."
}
$token = $BearerToken.Trim()
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "BearerToken is required."
}

function Resolve-InputPath([string]$Value) {
    $candidate = if ([System.IO.Path]::IsPathRooted($Value)) {
        $Value
    } else {
        Join-Path $PSScriptRoot $Value
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

$resolvedPlan = Resolve-InputPath $PlanPath
$resolvedRegistry = Resolve-InputPath $RegistryPath
$plan = Get-Content -LiteralPath $resolvedPlan -Raw | ConvertFrom-Json
$registry = Get-Content -LiteralPath $resolvedRegistry -Raw | ConvertFrom-Json
$allowlistPath = Join-Path (Split-Path -Parent $resolvedPlan) "protected_object_keys_v2.json"
$allowlist = Get-Content -LiteralPath $allowlistPath -Raw | ConvertFrom-Json
$expected = [System.Collections.Generic.Dictionary[string,long]]::new(
    [System.StringComparer]::Ordinal
)
$runtimeSha = [System.Collections.Generic.Dictionary[string,string]]::new(
    [System.StringComparer]::Ordinal
)
$publicManifest = $null

foreach ($item in $plan.items) {
    if ($item.kind -eq "public-manifest") {
        $publicManifest = $item
        continue
    }
    $expected.Add([string]$item.objectKey, [long]$item.sizeBytes)
    $runtimeSha.Add([string]$item.objectKey, ([string]$item.sha256).ToLowerInvariant())
}
foreach ($bundle in $registry.bundles) {
    $manifestPath = Join-Path (Split-Path -Parent $resolvedRegistry) (
        Split-Path -Leaf ([string]$bundle.manifestAsset)
    )
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($record in $manifest.records) {
        $expected.Add([string]$record.objectPath, [long]$record.byteLength)
    }
}

if ($null -eq $publicManifest -or $expected.Count -ne 606 -or
    $allowlist.keys.Count -ne 606) {
    throw "Expected one public manifest and exactly 606 protected objects."
}
$expectedKeys = @($expected.Keys | Sort-Object)
$allowlistKeys = @($allowlist.keys | Sort-Object)
if ((Compare-Object -ReferenceObject $expectedKeys -DifferenceObject $allowlistKeys)) {
    throw "Remote inventory inputs do not match the generated exact allowlist."
}

$failures = [System.Collections.Generic.List[string]]::new()
$index = 0
foreach ($key in $expectedKeys) {
    $index += 1
    $encodedKey = [Uri]::EscapeDataString($key)
    $url = "$($origin.AbsoluteUri.TrimEnd('/'))/v2/objects/$encodedKey"
    try {
        if ($runtimeSha.ContainsKey($key)) {
            $temporary = [System.IO.Path]::GetTempFileName()
            try {
                $response = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing `
                    -MaximumRedirection 0 -OutFile $temporary -PassThru -Headers @{
                        Authorization = "Bearer $token"
                    }
                $length = (Get-Item -LiteralPath $temporary).Length
                $actualSha = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($response.StatusCode -ne 200 -or $length -ne $expected[$key] -or
                    $actualSha -ne $runtimeSha[$key]) {
                    $failures.Add("$key status=$($response.StatusCode) bytes=$length expected=$($expected[$key]) sha=$actualSha")
                }
            } finally {
                if (Test-Path -LiteralPath $temporary) {
                    Remove-Item -LiteralPath $temporary -Force
                }
            }
        } else {
            $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing `
                -MaximumRedirection 0 -Headers @{
                    Authorization = "Bearer $token"
                }
            $length = [long]$response.Headers["Content-Length"]
            if ($response.StatusCode -ne 200 -or $length -ne $expected[$key]) {
                $failures.Add("$key status=$($response.StatusCode) bytes=$length expected=$($expected[$key])")
            }
        }
    } catch {
        $failures.Add("$key request_failed=$($_.Exception.GetType().Name)")
    }
    if ($index % 25 -eq 0) {
        Write-Progress -Activity "Verifying protected R2 inventory" -Status "$index / 606" -PercentComplete (($index / 606) * 100)
    }
}
Write-Progress -Activity "Verifying protected R2 inventory" -Completed

$manifestName = ([string]$publicManifest.objectKey).Split('/')[-1]
$manifestUrl = "$($origin.AbsoluteUri.TrimEnd('/'))/v2/manifest/$manifestName"
try {
    $temporary = [System.IO.Path]::GetTempFileName()
    try {
        $manifestResponse = Invoke-WebRequest -Uri $manifestUrl -Method Get `
            -UseBasicParsing -MaximumRedirection 0 -OutFile $temporary -PassThru
        $manifestLength = (Get-Item -LiteralPath $temporary).Length
        $manifestSha = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($manifestResponse.StatusCode -ne 200 -or
            $manifestLength -ne [long]$publicManifest.sizeBytes -or
            $manifestSha -ne ([string]$publicManifest.sha256).ToLowerInvariant()) {
            $failures.Add("public_manifest status=$($manifestResponse.StatusCode) bytes=$manifestLength sha=$manifestSha")
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
} catch {
    $failures.Add("public_manifest request_failed=$($_.Exception.GetType().Name)")
}

if ($failures.Count -gt 0) {
    $preview = ($failures | Select-Object -First 20) -join [Environment]::NewLine
    throw "Remote R2 inventory verification failed ($($failures.Count)):`n$preview"
}
Write-Output "WORKOUT_REMOTE_INVENTORY verified=607 protected=606 videos=302 runtimeShaVerified=305 publicManifests=1"
