# Codex storage maintenance — 2026-09-06

## Result and boundary

- C: free space before the audit: approximately **9.55 GiB**.
- C: free space after completion: **10.48 GiB** (the running app continues writing).
- No conversation, current rollout, repository file, credential, configuration,
  SQLite state, or installed runtime was deleted.
- G: had approximately 282.18 GiB free; no project data was relocated.

The audit used the OpenAI Docs guidance to identify Codex state locations, then
checked actual local paths, ages, sizes, references and reparse points. Official
documentation describes the state layout; it does not certify this particular
cleanup: https://learn.chatgpt.com/docs/config-file/config-advanced

## Exact operations

1. Applied transparent, reversible NTFS compression to one idle JSONL as a
   controlled trial. SHA-256 was unchanged. Its logical length remained
   796,417,199 bytes; allocated length became 752,685,056 bytes.
2. Compressed **77 further eligible idle JSONL files**, each older than 24 hours,
   larger than 20 MiB, inside the verified Codex sessions directory. Verified
   SHA-256 before and after each operation: **77/77 unchanged**, exit 0.
   The active conversation file was not a target. Total compressed files: 78.
3. Deleted **17 old component archive-cache files, 57.56 MiB**, under
   `AppData/Roaming/Codex/web/Codex/component_crx_cache`. Targets had 64-character
   hexadecimal names and were older than 24 hours. Installed components,
   metadata, cookies, session storage and current archives were preserved.
4. Deleted **48 diagnostic log files, 20.34 MiB**, older than three days under
   `AppData/Local/Codex/Logs`. Current diagnostic logs were retained.

Deletion used individual validated literal paths, not a recursive deletion of
Codex or a workspace. Cache archives are downloadable again. Deleted diagnostic
logs were not backed up; they are not conversation history. NTFS compression
does not change JSONL contents and can be reversed with NTFS decompression.

## Deliberately preserved

- All conversation histories and the 250-message source/trace ledgers.
- Auth, configuration, state databases, current logs and all project changes.
- Codex's `.tmp` marketplace source: despite the name, current configuration
  references it, so it was **not** treated as disposable cache.
- Plugin and generated-image junctions already pointing to G:.
- Application binaries, bundled dependency runtimes and browser session data.

The final compression-process report returned `VerifiedFiles=77`,
`EligibleFiles=77`, `DeletedConversations=0`. Its `FreedMB=925.1` was a concurrent
free-space delta, not an additive compression-only total; adding cache deletion
to that number would double-count. The before/after C: reading is the reported
net result.
