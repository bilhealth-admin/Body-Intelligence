# BIL Release Tree Freeze Audit — 2026-09-05

## Decision

Use a new clean worktree for the `1.0.0+8` candidate and copy only an explicit allowlist into it. Keep the current dirty worktree untouched. Do **not** use `git add -A`, `git stash -u`, `git clean`, `git reset`, or a bulk move/delete: several excluded groups are valuable local evidence or unreconciled remote-state captures, even though they do not belong in release Git history.

This audit was read-only except for this report. No file was deleted, moved, staged, reset, built, committed, or cleaned.

## Git evidence and count drift

- Repository: `G:/BIL_Project/body_intelligence_log`
- Branch: `release/store-rc-20260831`
- HEAD and upstream: `21f16767fad82d625ced9b6da2146b66b4b27953`, with `0` ahead and `0` behind `origin/release/store-rc-20260831`.
- Tag position: `bil-v1.0.0-build8-c2a4f7ab32` is one commit behind HEAD. Both the tag and HEAD still contain `version: 1.0.0+5`; the worktree contains `version: 1.0.0+8`.
- Index: clean (`git diff --cached --quiet` returned `0`). All 507 tracked changes are unstaged working-tree modifications; there are no tracked deletions or renames.
- Tracked diff: 507 files, 21,699 insertions, 7,749 deletions; 115 modified binary PNGs; `git diff --check` returned no findings.
- Audit-start status: 1,894 entries = 507 tracked modifications + 1,387 untracked files.
- During the read-only audit, another task created `docs/release/APP_STORE_CONNECT_DSA_RELEASE_AUDIT_2026-09-05.md`. That explains the observed increase to 1,895 entries = 507 + 1,388; it was not caused by this audit.
- The post-report status and path-set fingerprints are recorded in the final section. The report itself adds one expected untracked documentation path.

## Exact pre-report release classification

The 1,895-entry snapshot at `2026-09-05T14:43:29+03:00` has the following complete partition. “Exclude” means exclude from the clean candidate while preserving the file in the current worktree; it does not authorize deletion.

| Decision | Category / exact path rule | Tracked | Untracked | Total |
|---|---|---:|---:|---:|
| Include | App/backend/tool/config source described below | 238 | 68 | 306 |
| Include | `test/**/*.dart` | 139 | 54 | 193 |
| Include | `docs/**` | 13 | 13 | 26 |
| Include | Approved tracked goldens described below | 91 | 0 | 91 |
| Include | `artifacts/release/visual_closure/reference/visual_reference_coverage.csv` and `visual_reference_manifest.json` | 2 | 0 | 2 |
| Include | `assets/catalogs/recipes/v1/recipe-thumbnails-v4.json` | 0 | 1 | 1 |
| **Include subtotal** |  | **483** | **136** | **619** |
| Exclude/preserve | `assets/images/professional/recipes/*.png` | 0 | 883 | 883 |
| Exclude/preserve | `test/emulator_qa/**` | 0 | 124 | 124 |
| Exclude/preserve | `test/**/failures/**` | 24 | 52 | 76 |
| Exclude/preserve | `videos/**` | 0 | 67 | 67 |
| Exclude/preserve | `.codex_supabase_fetch_probe_20260901_2320/**` | 0 | 91 | 91 |
| Exclude/preserve | `.agents/**` and `skills-lock.json` | 0 | 30 | 30 |
| Exclude/preserve | `tool/*.wav` | 0 | 5 | 5 |
| **Exclude/preserve subtotal** |  | **24** | **1,252** | **1,276** |
| **Snapshot total** |  | **507** | **1,388** | **1,895** |

The pre-report sorted path-set SHA-256 fingerprints (UTF-8, LF, one path per line) are:

- all status paths: `b859d95773e04d735ace6e7174745a40bba7cd1b600d3d27bdf120d2de04f89a`
- tracked paths: `b0762065b45676d2304aa93591c2d88afe7c722d534eddeb3d497d3962e7bf55`
- untracked paths: `587591b9888fbec2832ace2e5625abc14ca42090f43cbe881ac1467403db75e1`
- proposed include paths: `f7ae365191a79504913808a4ccd89beaf7e1297788ecadf09b46cd75f7bb0659`
- proposed exclude/preserve paths: `d8af9b05889f4aa891d88fb9096b3a6fca381f374e1be2febeff2f21d24c68d0`

### Include boundary

The 306 source/config paths are the status paths under `.github/workflows/**`, `android/**`, `cloudflare/workout-runtime/**`, `ios/**`, `lib/**`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `public_site/**`, `supabase/**`, and `tool/**` except the five root preview WAVs, plus `.gitignore`, `.gitattributes`, `pubspec.yaml`, `pubspec.lock`, and `wrangler.site.jsonc`.

The 91 approved tracked golden changes are exactly:

- `test/features/commerce/goldens/**`: 6
- `test/features/onboarding/goldens/**`: 9
- `test/goldens/**`: 37
- `test/visual_closure/goldens/**`: 39

The 68 untracked source/config additions break down as follows: `lib/**` 25, `android/**` 3, `ios/**` 5, `supabase/**` 14, `cloudflare/workout-runtime/**` 4, `tool/**` excluding root WAVs 15, `public_site/.assetsignore` 1, and `.gitattributes` 1. The `.gitattributes` addition is material: it marks the v4 manifest `-text` so its pinned bytes are not line-ending transformed.

Before staging, reviewers should still inspect the 91 changed golden baselines and the generated `macos/Flutter/GeneratedPluginRegistrant.swift`; their classification as release inputs does not itself approve their content.

### Exclude/preserve boundary

- The 883 generated recipe source PNGs occupy approximately 2.17 GiB. `pubspec.yaml` declares zero recipe PNGs and 18 curated recipe JPGs. The PNGs feed external Cloudflare delivery and must not be added to Git. The v4 manifest has 1,500 records; a current read-only SHA-256 pass matched all 883 untracked PNGs to their manifest `canonical_id` and `source_sha256` (`883` matched, `0` missing, `0` mismatched). Manifest SHA-256: `24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029`.
- The 76 failure diagnostics are exactly `test/features/commerce/failures/**` 24 (8 tracked, 16 untracked), `test/features/onboarding/failures/**` 36, `test/features/wellness/failures/**` 12 tracked, and `test/visual_closure/failures/**` 4 tracked. They are not approved golden baselines.
- `videos/bil-splash-motion/**` has 48 paths and `videos/bil-product-launch/**` has 19. Within all 67 video paths, 29 are authoring/planning sources and 38 are render proofs, captures, extracted metadata, or local state. Preserve the whole media workspace but exclude it from the app candidate.
- The Supabase fetch probe contains 89 SQL files plus 2 `.temp` metadata files. Every SQL basename also exists under `supabase/migrations`; 37 are byte-identical and 52 differ after line-ending normalization. Therefore the probe is not candidate source, but it must remain preserved until the 52 differences are deliberately reconciled.
- `.agents/**` has 29 local skill files and `skills-lock.json` is its lock metadata. They are workstation tooling, not app release source.
- The five local preview files are `tool/bil_mic_end_preview.wav`, `tool/bil_mic_end_vibration_preview.wav`, `tool/bil_mic_open_preview.wav`, `tool/bil_mic_open_vibration_preview.wav`, and `tool/bil_mic_tap_preview.wav`. The actual candidate sounds are the platform files under `android/app/src/main/res/raw/` and `ios/Runner/`.

Ignored files were outside the 1,895-entry status partition. A collapsed `git status --ignored --untracked-files=normal` view reported 1,180 ignored entries, dominated by `artifacts` (909) and `test` (220), plus known caches/build/temp roots such as `.dart_tool/`, `build/`, `.tmp/`, `.wrangler/`, `.codex_upload_tmp/`, `.bil-package-backups/`, `.bil-package-evidence/`, `android/.gradle/`, and `android/.kotlin/`. It also includes sensitive local configuration such as `android/key.properties` and `android/keystores/`; ignored content must never be bulk-copied into the candidate or staged.

## Accidental-text audit

The accidental text visible in the earlier screenshot does not remain in the source tree.

- Before this report was written, whole-worktree `rg --hidden -g '!.git/**'` returned no matches for any of the four supplied Arabic fragments (closing Codex, the desktop, consuming credit, and “if you want me”).
- Broader spelling variants of the distinctive Codex/close/“if you want me” terms also returned no matches.
- `git grep` returned no exact-fragment matches in either HEAD or `bil-v1.0.0-build8-c2a4f7ab32` for `lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart`.
- Current line 42 is the legitimate microphone rationale: `يبدأ BIL الاستماع فقط بعد الضغط على زر الصوت. قد يطلب iPhone إذن التعرف على الكلام بشكل منفصل.`
- All Arabic literals near the `Access is off` permission flow are camera, microphone, speech-recognition, notification, settings, continue/cancel, voice-feedback, or voice-unavailable UI copy. No unrelated Arabic literal is present there.

## Proposed clean-worktree freeze procedure — not executed

The following is a plan for an authorized release operator. It intentionally leaves the dirty source worktree in place and creates a second candidate worktree. Recompute the allowlist from a stable status snapshot immediately before use; do not rely on counts if another task has added a file.

```powershell
$sourceRepo = 'G:\BIL_Project\body_intelligence_log'
$candidateTree = 'G:\BIL_Project\body_intelligence_log_build8_freeze'
$candidateBranch = 'release/store-rc-build8-freeze'
$freezeEvidence = 'G:\BIL_Project\release-freeze-evidence-20260905'

# Preconditions: operator verifies that both destination paths do not exist,
# that the source HEAD is the audited commit, and that the index remains clean.
if (Test-Path -LiteralPath $candidateTree) { throw 'Candidate path already exists.' }
if (Test-Path -LiteralPath $freezeEvidence) { throw 'Evidence path already exists.' }
if ((git -C $sourceRepo rev-parse HEAD) -ne '21f16767fad82d625ced9b6da2146b66b4b27953') {
  throw 'HEAD changed; repeat the audit.'
}
git -C $sourceRepo diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw 'Index is not clean.' }

New-Item -ItemType Directory -Path $freezeEvidence | Out-Null
git -C $sourceRepo diff --binary --full-index --output="$freezeEvidence\tracked-working-tree.patch"

$status = @(git -C $sourceRepo -c core.quotePath=false status --porcelain=v1 --untracked-files=all)
$rows = foreach ($line in $status) {
  [pscustomobject]@{ Status = $line.Substring(0, 2); Path = $line.Substring(3) }
}
$excluded = {
  param($path)
  $path -match '^assets/images/professional/recipes/[^/]+\.png$' -or
  $path -match '^\.agents/' -or $path -eq 'skills-lock.json' -or
  $path -match '^test/emulator_qa/' -or
  $path -match '^test/(?:.+/)?failures/' -or
  $path -match '^videos/' -or
  $path -match '^\.codex_supabase_fetch_probe_20260901_2320/' -or
  $path -match '^tool/[^/]+\.wav$'
}
$allow = @($rows | Where-Object { -not (& $excluded $_.Path) } | ForEach-Object Path | Sort-Object -Unique)
$preserveOnly = @($rows | Where-Object { (& $excluded $_.Path) } | ForEach-Object Path | Sort-Object -Unique)

function Get-PathSetSha256([string[]]$paths) {
  $payload = (@($paths | Sort-Object) -join "`n") + "`n"
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}
if ($allow.Count -ne 620 -or (Get-PathSetSha256 $allow) -ne 'c8cc9f0b91cf5d34d20a177098918c6c60f0cab716b4b091579e429e02437bc3') {
  throw 'Allowlist drifted; repeat the audit.'
}
if ($preserveOnly.Count -ne 1276 -or (Get-PathSetSha256 $preserveOnly) -ne 'd8af9b05889f4aa891d88fb9096b3a6fca381f374e1be2febeff2f21d24c68d0') {
  throw 'Preserve-only set drifted; repeat the audit.'
}

# Prove that every excluded recipe PNG is represented byte-for-byte by the
# release manifest before making the candidate. This reads but does not alter it.
$sourceManifestPath = Join-Path $sourceRepo 'assets/catalogs/recipes/v1/recipe-thumbnails-v4.json'
$sourceManifest = Get-Content -Raw -LiteralPath $sourceManifestPath | ConvertFrom-Json
$sourceHashById = @{}
foreach ($entry in $sourceManifest.entries) { $sourceHashById[[string]$entry.canonical_id] = [string]$entry.source_sha256 }
$recipeSources = @($preserveOnly | Where-Object { $_ -match '^assets/images/professional/recipes/[^/]+\.png$' })
$recipeFailures = @($recipeSources | Where-Object {
  $id = [IO.Path]::GetFileNameWithoutExtension($_)
  !$sourceHashById.ContainsKey($id) -or
  (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $sourceRepo $_)).Hash.ToLowerInvariant() -ne $sourceHashById[$id]
})
if ($sourceManifest.record_count -ne 1500 -or $recipeSources.Count -ne 883 -or $recipeFailures.Count -ne 0) {
  throw 'Recipe source/manifest verification failed.'
}

[IO.File]::WriteAllLines("$freezeEvidence\allowlist.txt", $allow, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllLines("$freezeEvidence\preserve-only.txt", $preserveOnly, [Text.UTF8Encoding]::new($false))

# Create the clean candidate beside, not on top of, the dirty source tree.
git -C $sourceRepo worktree add -b $candidateBranch $candidateTree 21f16767fad82d625ced9b6da2146b66b4b27953
if ($LASTEXITCODE -ne 0) { throw 'Could not create candidate worktree.' }

# There are currently no deleted/renamed tracked paths. Copy literal allowlisted files only.
foreach ($relativePath in $allow) {
  $from = Join-Path $sourceRepo $relativePath
  if (!(Test-Path -LiteralPath $from -PathType Leaf)) { throw "Missing allowlisted file: $relativePath" }
  $to = Join-Path $candidateTree $relativePath
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
  Copy-Item -LiteralPath $from -Destination $to
}

# Fail closed if any preserve-only path crossed the boundary.
$candidateStatus = @(git -C $candidateTree -c core.quotePath=false status --porcelain=v1 --untracked-files=all)
$candidatePaths = @($candidateStatus | ForEach-Object { $_.Substring(3) } | Sort-Object -Unique)
$unexpected = @($candidatePaths | Where-Object { $_ -notin $allow })
$missing = @($allow | Where-Object { $_ -notin $candidatePaths })
if ($unexpected.Count -or $missing.Count) {
  throw "Candidate differs from allowlist: unexpected=$($unexpected.Count), missing=$($missing.Count)"
}

# Verify the pinned manifest before staging. Re-run the 883-source-hash audit
# in the preserved source tree; expected result is 883/883 with zero mismatch.
$manifestPath = Join-Path $candidateTree 'assets/catalogs/recipes/v1/recipe-thumbnails-v4.json'
$manifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()
if ($manifestHash -ne '24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029') {
  throw 'Recipe thumbnail manifest changed; repeat manifest/source validation.'
}
git -C $candidateTree check-attr text -- assets/catalogs/recipes/v1/recipe-thumbnails-v4.json

# Stage only the reviewed allowlist; never use `git add -A` in this workflow.
git -C $candidateTree add --pathspec-from-file="$freezeEvidence\allowlist.txt"
git -C $candidateTree diff --cached --check
git -C $candidateTree status --short
git -C $candidateTree diff --cached --stat
```

Expected gate: the candidate worktree contains only the allowlisted release paths, `version: 1.0.0+8`, the v4 manifest hash above, and no preserve-only paths. Review and tests remain separate gates; this audit did not build or run the application. Keep the original dirty worktree and freeze-evidence directory intact until the candidate commit, reproducibility checks, and user review are complete.

## Post-report verification

At `2026-09-05T14:46:07+03:00`, creation of this report was the only additional status change: 1,896 entries = 507 unstaged tracked modifications + 1,389 untracked paths. The include set is now 620 paths (the pre-report 619 plus this report); the exclude/preserve set remains 1,276 paths.

- all status paths SHA-256: `49215efb85466e7257a29f30aecc5c49709ea65895f4f2d1b7bc08570ceca9b0`
- tracked path-set SHA-256: `b0762065b45676d2304aa93591c2d88afe7c722d534eddeb3d497d3962e7bf55`
- untracked path-set SHA-256: `8687f77d40913ee4f062222eb7c7c08824bb0613363f20e58667b16a45256e8f`
- include path-set SHA-256: `c8cc9f0b91cf5d34d20a177098918c6c60f0cab716b4b091579e429e02437bc3`
- exclude/preserve path-set SHA-256: `d8af9b05889f4aa891d88fb9096b3a6fca381f374e1be2febeff2f21d24c68d0`

`git diff --check` remained clean for tracked changes. A no-index whitespace check and trailing-whitespace scan were also applied to this untracked report. A final `rg` excluding this evidence report still returned zero matches for all supplied accidental-text fragments; the report deliberately describes, rather than reproduces, those fragments so the repository-wide assertion remains testable.
