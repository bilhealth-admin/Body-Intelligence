param(
    [string]$PlanPath = "../../../artifacts/workout_media/cloudflare_runtime_v2/runtime_object_plan_v2.json",
    [switch]$Execute,
    [string]$StartAtObjectKey = "",
    [ValidateRange(1, 8)]
    [int]$MaxUploadAttempts = 5
)

$ErrorActionPreference = "Stop"
$workerRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$resolvedPlanInput = if ([System.IO.Path]::IsPathRooted($PlanPath)) {
    $PlanPath
} else {
    Join-Path $PSScriptRoot $PlanPath
}
$resolvedPlan = (Resolve-Path -LiteralPath $resolvedPlanInput).Path
$plan = Get-Content -LiteralPath $resolvedPlan -Raw | ConvertFrom-Json

if ($plan.schema -ne "bil.cloudflare-workout-runtime-upload-plan.v2") {
    throw "Unsupported runtime upload plan schema."
}
if ($plan.counts.videos -ne 0 -or $plan.counts.total -ne 305) {
    throw "The runtime plan must contain exactly 305 objects and zero videos."
}
if ($plan.protectedDelivery.objectCount -ne 606 -or
    ([string]$plan.protectedDelivery.objectKeysSha256) -notmatch '^[0-9a-f]{64}$') {
    throw "The protected delivery allowlist pin is missing or incomplete."
}
if ($plan.existingVideoObjects.action -ne "reuse-uploaded-in-place-never-upload" -or
    $plan.existingVideoObjects.logicalCount -ne 302) {
    throw "The existing 302-video upload evidence is missing."
}
if ($plan.items.Count -ne $plan.counts.total) {
    throw "Runtime object count does not match the plan summary."
}

$validated = 0
$uploadStarted = [string]::IsNullOrWhiteSpace($StartAtObjectKey)
$startKeyFound = $uploadStarted
foreach ($item in $plan.items) {
    $key = [string]$item.objectKey
    if ($item.kind -eq "video" -or $key.EndsWith(".mp4", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "MP4 uploads are forbidden by this runtime plan: $key"
    }
    if ([string]::IsNullOrWhiteSpace($key) -or $key.Contains("\") -or $key.Contains("../")) {
        throw "Unsafe R2 object key: $key"
    }
    $source = (Resolve-Path -LiteralPath ([string]$item.localPath)).Path
    $file = Get-Item -LiteralPath $source
    if ($file.PSIsContainer -or $file.Length -ne [long]$item.sizeBytes) {
        throw "Runtime object size mismatch: $key"
    }
    $actualSha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha -ne ([string]$item.sha256).ToLowerInvariant()) {
        throw "Runtime object SHA-256 mismatch: $key"
    }
    $validated += 1

    if ($Execute) {
        if (-not $uploadStarted) {
            if ($key -ne $StartAtObjectKey) {
                continue
            }
            $uploadStarted = $true
            $startKeyFound = $true
        }
        $destination = "$($item.bucket)/$key"
        $uploaded = $false
        for ($attempt = 1; $attempt -le $MaxUploadAttempts; $attempt += 1) {
            Push-Location -LiteralPath $workerRoot
            try {
                & npx wrangler r2 object put $destination `
                    --remote `
                    --file $source `
                    --content-type ([string]$item.contentType) `
                    --cache-control ([string]$item.cacheControl) `
                    --content-disposition ([string]$item.contentDisposition)
                if ($LASTEXITCODE -eq 0) {
                    $uploaded = $true
                    break
                }
            } finally {
                Pop-Location
            }
            if ($attempt -lt $MaxUploadAttempts) {
                $retryDelaySeconds = [Math]::Min(16, [Math]::Pow(2, $attempt))
                Write-Warning "Upload attempt $attempt failed for $key; retrying in $retryDelaySeconds seconds."
                Start-Sleep -Seconds $retryDelaySeconds
            }
        }
        if (-not $uploaded) {
            throw "Wrangler failed after $MaxUploadAttempts attempts while publishing: $key"
        }
    }
}

if ($Execute -and -not $startKeyFound) {
    throw "StartAtObjectKey was not found in the verified upload plan: $StartAtObjectKey"
}

$mode = if ($Execute) { "uploaded" } else { "validated-only" }
Write-Output "WORKOUT_RUNTIME_OBJECTS $mode=$validated videos=0 plan=$resolvedPlan"
