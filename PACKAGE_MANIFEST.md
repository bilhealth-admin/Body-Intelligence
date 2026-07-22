# Package Manifest

Package ID: `BDAR-003A-R1`
Type: Test-only compatibility correction

## Changed files

- `test/first_value_handoff_test.dart`
- `PACKAGE_CONSTITUTION.md`

## Production changes

None.

## Root cause

BDAR-003A moved `FirstValueHandoffCard` from `dashboard_page.dart` into
`widgets/first_value_handoff_card.dart`. The pre-existing test still imported
the old file, so analyzer could not resolve the widget.

## Rollback

Restore only the two files listed above. Never reset the repository.
