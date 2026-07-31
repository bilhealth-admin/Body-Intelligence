# Security, privacy, and operations

## Privacy boundary

USDA and other public catalog data contain no BIL user health records. Build tooling must remain separate from user databases and must never inspect personal logs.

## Supply-chain controls

- Pin and record source archive hashes.
- Record importer and policy versions.
- Reject unexpected schemas.
- Never execute content from source archives.
- Sanitize archive member paths and prevent path traversal.
- Use bounded decompression and disk-space checks.

## Database integrity

- Read-only delivery databases.
- SQLite integrity and foreign-key checks before publication.
- SHA-256 verification before activation.
- Future remote distribution requires a signed manifest; a hash from an untrusted channel alone is insufficient.

## Build operations

Long-running imports must support:

- checkpoints and safe resume;
- explicit cancellation state;
- progress by stage and source;
- bounded transactions;
- structured logs;
- final reconciliation report;
- no false success message after interruption.

Temporary files use a dedicated build directory. A failed build must not leave a database with a production filename.

## Observability

Build reports include counts and timings without personal information. Runtime catalog telemetry, if ever added, follows BIL privacy policy and must not transmit food searches by default.
