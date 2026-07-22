# Implementation Notes

This is the first package in the new sequential delivery program.

It intentionally changes no production code. Its purpose is to lock the latest uploaded baseline, preserve every agreed product commitment, record verified findings, and govern all following implementation packages.

## Apply

Extract into the repository root.

## Verify

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bdar_preflight.ps1
git diff -- docs scripts PACKAGE_CONSTITUTION.md PACKAGE_MANIFEST.md IMPLEMENTATION_NOTES.md
```

## Commit

Suggested commit:

```text
docs(governance): establish BDAR baseline and execution program
```

Do not include unrelated working-tree files in the commit.
