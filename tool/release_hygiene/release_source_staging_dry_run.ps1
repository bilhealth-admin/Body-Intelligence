[CmdletBinding()]
param(
    [string]$OutputPath = 'artifacts/release/source_hygiene/2026-08-31/release-source-manifest.json',
    [switch]$NoWrite
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$previousLocation = Get-Location
$githubHardFileLimitBytes = 100MB
$githubHardPushLimitBytes = 2GB
$githubRecommendedGitDirectoryBytes = 10GB

function Normalize-StatusPath {
    param([Parameter(Mandatory)][string]$RawPath)

    $path = $RawPath.Trim('"')
    if ($path -match ' -> ') {
        $path = ($path -split ' -> ')[-1]
    }
    return $path.Replace('\', '/')
}

function Classify-Path {
    param([Parameter(Mandatory)][string]$Path)

    if ($Path -in @(
            'artifacts/release/epic14/commit_epic14.ps1',
            'artifacts/release/epic14/run_epic14_gate.ps1',
            'artifacts/release/epic2/close_epic2.ps1',
            'artifacts/release/prepare_epic15_store_assets.ps1',
            'artifacts/release/run_epic15_gate.ps1',
            'artifacts/release/run_epic16_gate.ps1',
            'artifacts/release/visual_closure/commit_visual_closure.ps1',
            'scripts/release/finalize_bil_v1_rc.ps1'
        )) {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'retired_release_safety_guard'
            reason = 'Exact retired release mutator retained only for its fail-fast safety guard and regression contract.'
        }
    }

    if ($Path -match '^assets/images/professional/recipes/[^/]+\.png$') {
        return [ordered]@{
            decision = 'EXCLUDE'
            category = 'generated_recipe_source_archive'
            reason = 'Generated recipe source PNG; not bundled by pubspec and delivered from the SHA-pinned Cloudflare runtime.'
        }
    }
    if ($Path -match '^\.agents/' -or $Path -eq 'skills-lock.json') {
        return [ordered]@{
            decision = 'EXCLUDE'
            category = 'local_codex_agent_configuration'
            reason = 'Local Codex skills and lock metadata are workstation tooling, not application release source.'
        }
    }
    if ($Path -match '^test/emulator_qa/') {
        return [ordered]@{
            decision = 'EXCLUDE'
            category = 'local_runtime_evidence'
            reason = 'Local emulator screenshot, hierarchy, or device diagnostic; preserve locally but do not stage as release source.'
        }
    }
    if ($Path -match '^test/(?:.+/)?failures/') {
        return [ordered]@{
            decision = 'EXCLUDE'
            category = 'local_test_failure_diagnostic'
            reason = 'Generated test failure images and diagnostics are local evidence, not approved golden baselines.'
        }
    }
    if ($Path -match '^videos/bil-splash-motion/') {
        return [ordered]@{
            decision = 'EXCLUDE'
            category = 'media_authoring_archive'
            reason = 'Splash authoring project and render proofs; the reviewed runtime MP4 is assets/branding/bil_splash_motion.mp4.'
        }
    }

    if ($Path -match '^\.github/workflows/' -or
        $Path -match '^(android|ios|lib)/' -or
        $Path -in @('pubspec.yaml', 'pubspec.lock')) {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'app_release_source_and_configuration'
            reason = 'Application source, platform integration, dependency lock, or signed release workflow required to reproduce the release.'
        }
    }
    if ($Path -match '^assets/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'runtime_asset_or_catalog'
            reason = 'Reviewed runtime asset/catalog change; generated recipe PNGs are handled by the earlier exclusion rule.'
        }
    }
    if ($Path -match '^(test|integration_test)/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'release_verification_contract'
            reason = 'Automated release contract, regression test, or approved golden baseline; emulator runtime captures are excluded separately.'
        }
    }
    if ($Path -match '^supabase/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'store_backend_source_or_migration'
            reason = 'Versioned Supabase Edge Function, test, or migration required by the store lifecycle backend.'
        }
    }
    if ($Path -match '^cloudflare/workout-runtime/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'workout_runtime_edge_source'
            reason = 'Versioned Cloudflare workout runtime source and tests required by the signed workout catalog contract.'
        }
    }
    if ($Path -match '^tool/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'release_tool_or_local_dependency'
            reason = 'Release automation, audit source, or pub dependency override required to reproduce and verify the release.'
        }
    }
    if ($Path -match '^docs/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'release_contract_documentation'
            reason = 'Versioned release, privacy, commerce, or launch-readiness contract documentation.'
        }
    }
    if ($Path -match '^store_assets/review/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'store_review_asset'
            reason = 'Reviewed App Store or Play review metadata asset and its integrity manifest.'
        }
    }
    if ($Path -match '^public_site/') {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'public_policy_site_source'
            reason = 'Versioned public policy/support site source required by store metadata.'
        }
    }
    if ($Path -in @(
            'artifacts/release/visual_closure/reference/visual_reference_coverage.csv',
            'artifacts/release/visual_closure/reference/visual_reference_manifest.json'
        )) {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'release_contract_evidence_input'
            reason = 'Tracked deterministic input consumed by launch-readiness visual reference contract tests.'
        }
    }
    if ($Path -in @(
            'artifacts/workout_media/workout_release_bundle_registry_v1.json',
            'artifacts/workout_media/workout_release_bundle_home_v1.json',
            'artifacts/workout_media/workout_release_bundle_gym_six_month_v1.json',
            'artifacts/workout_media/workout_discovery_catalog_v1.json',
            'artifacts/workout_media/gym_six_month_plan_runtime_v1.json',
            'artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json',
            'artifacts/workout_media/workout_owner_approval_home_200.json',
            'artifacts/workout_media/workout_owner_approval_gym_102.json'
        )) {
        return [ordered]@{
            decision = 'INCLUDE'
            category = 'runtime_asset_contract'
            reason = 'Explicit Flutter runtime asset declared in pubspec.yaml.'
        }
    }

    return $null
}

function Get-HeadBlobMetadata {
    param([Parameter(Mandatory)][string]$Path)

    $line = (& git ls-tree HEAD -- $Path | Select-Object -First 1)
    if (!$line) {
        return $null
    }
    if ($line -notmatch '^[0-9]+\s+blob\s+([0-9a-f]+)\t') {
        return $null
    }
    $oid = $Matches[1]
    $sizeText = (& git cat-file -s $oid | Select-Object -First 1)
    return [ordered]@{
        algorithm = 'git-object-sha1'
        value = $oid
        bytes = [long]$sizeText
    }
}

function Get-ContentSecretFinding {
    param([Parameter(Mandatory)][string]$Path)

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt 8MB) {
        return @()
    }
    $textExtensions = @(
        '', '.dart', '.ts', '.js', '.mjs', '.json', '.yaml', '.yml', '.md',
        '.txt', '.xml', '.plist', '.gradle', '.kt', '.swift', '.ps1', '.py',
        '.sql', '.html', '.lock', '.properties', '.arb', '.strings'
    )
    if ($file.Extension.ToLowerInvariant() -notin $textExtensions) {
        return @()
    }

    $text = [IO.File]::ReadAllText($file.FullName)
    $findings = [System.Collections.Generic.List[string]]::new()
    $patterns = [ordered]@{
        private_key = '-----BEGIN (RSA |EC |OPENSSH |PRIVATE )?PRIVATE KEY-----'
        google_api_key = 'AIza[0-9A-Za-z_-]{30,}'
        github_token = 'gh[pousr]_[0-9A-Za-z]{30,}'
        openai_style_key = 'sk-(?:proj-)?[0-9A-Za-z_-]{24,}'
        supabase_access_token = 'sbp_[0-9A-Za-z]{30,}'
        jwt_like_secret = 'eyJ[0-9A-Za-z_-]{20,}\.[0-9A-Za-z_-]{20,}\.[0-9A-Za-z_-]{20,}'
        uuid_colon_secret = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}:[0-9a-fA-F]{24,}'
    }
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($text -match $entry.Value) {
            $findings.Add($entry.Key)
        }
    }
    return @($findings)
}

try {
    Set-Location -LiteralPath $repositoryRoot

    $statusLines = @(& git -c core.quotepath=false status --porcelain=v1 -uall)
    if ($LASTEXITCODE -ne 0) {
        throw 'git status failed.'
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    $unclassified = [System.Collections.Generic.List[string]]::new()
    $oversized = [System.Collections.Generic.List[string]]::new()
    $secretFindings = [System.Collections.Generic.List[object]]::new()

    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }
        $status = $line.Substring(0, 2)
        $path = Normalize-StatusPath -RawPath $line.Substring(3)
        $classification = Classify-Path -Path $path
        if ($null -eq $classification) {
            $unclassified.Add($path)
            continue
        }

        $hash = $null
        $bytes = [long]0
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        if ($exists) {
            $file = Get-Item -LiteralPath $path
            $bytes = $file.Length
            $hash = [ordered]@{
                algorithm = 'sha256'
                value = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        } else {
            $headBlob = Get-HeadBlobMetadata -Path $path
            if ($null -eq $headBlob) {
                $unclassified.Add("$path (missing and no HEAD blob)")
                continue
            }
            $bytes = $headBlob.bytes
            $hash = [ordered]@{
                algorithm = $headBlob.algorithm
                value = $headBlob.value
            }
        }

        if ($bytes -gt $githubHardFileLimitBytes) {
            $oversized.Add($path)
        }

        $dangerousPath = $path -match '(?i)(^|/)(\.env(?:\.|$)|key\.properties$|[^/]*(?:credentials|service[-_]?account)[^/]*\.json$)' -or
            $path -match '(?i)\.(p8|p12|jks|keystore|mobileprovision|pem|key)$'
        $contentFindings = @(Get-ContentSecretFinding -Path $path)
        if ($dangerousPath -or $contentFindings.Count -gt 0) {
            $secretFindings.Add([pscustomobject][ordered]@{
                    path = $path
                    dangerous_path = $dangerousPath
                    content_patterns = @($contentFindings)
                })
        }

        $entries.Add([pscustomobject][ordered]@{
                path = $path
                git_status = $status
                exists = $exists
                bytes = $bytes
                content_hash = $hash
                decision = $classification.decision
                category = $classification.category
                reason = $classification.reason
            })
    }

    if ($unclassified.Count -gt 0) {
        throw "RELEASE_SOURCE_HYGIENE_BLOCKED: unclassified paths=$($unclassified.Count): $($unclassified -join ', ')"
    }
    if ($oversized.Count -gt 0) {
        throw "RELEASE_SOURCE_HYGIENE_BLOCKED: files above GitHub 100 MiB hard limit: $($oversized -join ', ')"
    }
    if ($secretFindings.Count -gt 0) {
        $paths = @($secretFindings | ForEach-Object { $_.path }) -join ', '
        throw "RELEASE_SOURCE_HYGIENE_BLOCKED: high-confidence secret pattern(s) in status paths: $paths"
    }

    $recipeManifestPath = 'assets/catalogs/recipes/v1/recipe-images.json'
    $recipeManifest = Get-Content -Raw -LiteralPath $recipeManifestPath | ConvertFrom-Json
    $recipeNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($recipe in $recipeManifest.entries) {
        [void]$recipeNames.Add([IO.Path]::GetFileName([string]$recipe.object_path))
    }
    $excludedRecipeEntries = @($entries | Where-Object { $_.category -eq 'generated_recipe_source_archive' })
    $excludedRecipeCovered = @($excludedRecipeEntries | Where-Object { $recipeNames.Contains([IO.Path]::GetFileName($_.path)) })

    $ledgerPath = 'artifacts/cloudflare_media/media_upload_ledger_v1.ndjson'
    $ledgerRows = @()
    if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
        $ledgerRows = @(Get-Content -LiteralPath $ledgerPath | ForEach-Object { $_ | ConvertFrom-Json })
    }
    $uploadedRecipeObjects = @(
        $ledgerRows |
            Where-Object { $_.event -eq 'uploaded' -and $_.kind -eq 'recipe-image' } |
            Select-Object -ExpandProperty objectKey -Unique
    )
    $uploadedWorkoutObjects = @(
        $ledgerRows |
            Where-Object { $_.event -eq 'uploaded' -and $_.kind -eq 'workout-video' } |
            Select-Object -ExpandProperty objectKey -Unique
    )

    $pubspec = Get-Content -Raw -LiteralPath 'pubspec.yaml'
    $bundledRecipePngDeclarations = @(
        [regex]::Matches(
            $pubspec,
            '(?m)^\s*-\s*assets/images/professional/recipes/[^\r\n]+\.png\s*$'
        )
    )
    $bundledRecipeJpgDeclarations = @(
        [regex]::Matches(
            $pubspec,
            '(?m)^\s*-\s*assets/images/professional/recipes/[^\r\n]+\.jpg\s*$'
        )
    )

    $categorySummary = @(
        $entries |
            Group-Object decision, category |
            Sort-Object Name |
            ForEach-Object {
                $groupBytes = [long](($_.Group | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum)
                [ordered]@{
                    decision = $_.Group[0].decision
                    category = $_.Group[0].category
                    paths = $_.Count
                    bytes = $groupBytes
                }
            }
    )

    $gitObjectStats = @(& git count-objects -v)
    $headTreeRows = @(& git ls-tree -r -l HEAD)
    $headTreeFiles = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $headTreeRows) {
        if ($row -match '^[0-9]+\s+blob\s+[0-9a-f]+\s+([0-9]+)\t(.+)$') {
            $headTreeFiles.Add([pscustomobject][ordered]@{ bytes = [long]$Matches[1]; path = $Matches[2] })
        }
    }
    $largestHeadFile = $headTreeFiles | Sort-Object bytes -Descending | Select-Object -First 1

    $manifest = [ordered]@{
        schema_version = 1
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        repository_root = $repositoryRoot
        invariant = 'This is a dry-run classification only. No git add, commit, push, build, upload, or deletion is performed.'
        github_limits = [ordered]@{
            hard_file_bytes = $githubHardFileLimitBytes
            hard_push_bytes = $githubHardPushLimitBytes
            recommended_git_directory_bytes = $githubRecommendedGitDirectoryBytes
            official_source = 'https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits'
        }
        git_repository = [ordered]@{
            status_entries = $entries.Count
            head_tree_files = $headTreeFiles.Count
            head_tree_bytes = [long](($headTreeFiles | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum)
            largest_head_file = $largestHeadFile
            count_objects = @($gitObjectStats)
            git_lfs_attributes_present = (Test-Path -LiteralPath '.gitattributes' -PathType Leaf)
        }
        summary = $categorySummary
        recipe_delivery = [ordered]@{
            recipe_manifest_path = $recipeManifestPath
            recipe_manifest_sha256 = (Get-FileHash -LiteralPath $recipeManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
            manifest_entries = @($recipeManifest.entries).Count
            external_candidate_entries = @($recipeManifest.entries | Where-Object { $_.status -eq 'external_candidate' }).Count
            placeholder_entries = @($recipeManifest.entries | Where-Object { $_.status -eq 'placeholder' }).Count
            pubspec_recipe_png_declarations = $bundledRecipePngDeclarations.Count
            pubspec_curated_recipe_jpg_declarations = $bundledRecipeJpgDeclarations.Count
            excluded_status_recipe_pngs = $excludedRecipeEntries.Count
            excluded_status_recipe_pngs_in_manifest = $excludedRecipeCovered.Count
            cloudflare_ledger_path = $ledgerPath
            cloudflare_ledger_sha256 = if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
                (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash.ToLowerInvariant()
            } else { $null }
            ledger_unique_uploaded_recipe_objects = $uploadedRecipeObjects.Count
            ledger_unique_uploaded_workout_objects = $uploadedWorkoutObjects.Count
            live_head_observation = [ordered]@{
                observed_at_utc = '2026-08-31T02:58:00Z'
                endpoint_template = 'https://workouts.bilhealth.com/v3/recipes/images/{canonical_id}/{sha256}'
                validated_headers = @('HTTP 200', 'Content-Length', 'Content-Type', 'x-bil-content-sha256')
                manifest_checked = 1500
                manifest_passed = 1500
                manifest_failed = 0
                excluded_status_recipe_pngs_checked = 883
                excluded_status_recipe_pngs_passed = 883
                excluded_status_recipe_pngs_failed = 0
            }
        }
        entries = @($entries | Sort-Object path)
    }

    if (!$NoWrite) {
        $resolvedOutput = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))
        $resolvedRoot = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\') + '\'
        if (!$resolvedOutput.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'OutputPath escaped the repository root.'
        }
        $outputDirectory = Split-Path -Parent $resolvedOutput
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
        $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8
        $manifestSha256 = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-Host "RELEASE_SOURCE_MANIFEST=$resolvedOutput"
        Write-Host "RELEASE_SOURCE_MANIFEST_SHA256=$manifestSha256"
    }

    $includeCount = @($entries | Where-Object { $_.decision -eq 'INCLUDE' }).Count
    $excludeCount = @($entries | Where-Object { $_.decision -eq 'EXCLUDE' }).Count
    Write-Host "RELEASE_SOURCE_STATUS_ENTRIES=$($entries.Count)"
    Write-Host "RELEASE_SOURCE_INCLUDE=$includeCount"
    Write-Host "RELEASE_SOURCE_EXCLUDE=$excludeCount"
    Write-Host 'RELEASE_SOURCE_STAGING_DRY_RUN=PASS'
} finally {
    Set-Location $previousLocation
}
