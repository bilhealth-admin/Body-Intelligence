# Package Manifest

Package ID: `BDAR-001`  
Name: Current Baseline Forensic Audit  
Type: Governance + audit baseline  
Production code changes: None  
Data/schema changes: None  
Risk: Low  
Rollback: Remove the package-added documentation and scripts before commit.

## Files

- `PACKAGE_CONSTITUTION.md`
- `PACKAGE_MANIFEST.md`
- `docs/audits/BDAR_V1_FORENSIC_AUDIT.md`
- `docs/governance/BDAR_PROGRAM_CONSTITUTION.md`
- `docs/governance/BDAR_MASTER_EXECUTION_PLAN.md`
- `docs/governance/BDAR_DECISION_LOG.md`
- `docs/governance/BIL_QUALITY_BOARD.md`
- `docs/governance/BIL_STABILIZATION_EXECUTION_LEDGER.md`
- `scripts/bdar_preflight.ps1`
- `IMPLEMENTATION_NOTES.md`

## Acceptance

- Files extract into the repository root.
- Preflight identifies the expected branch and baseline files.
- No production Dart file is changed.
- Documentation does not close a production bug.
- Commit is limited to BDAR governance/audit baseline.
