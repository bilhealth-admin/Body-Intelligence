# BDAR-002R5 Implementation Notes

## Failure

Pressing Update Quantity caused:

- `You have popped the last page off of the stack`
- `currentConfiguration.isNotEmpty`
- a subsequent Navigator `!_debugLocked` assertion
- a fully black application window

## Correction

The dialog builder now exposes `dialogContext`.

Both Cancel and Update close that dialog with:

- `Navigator.pop(dialogContext)`
- `Navigator.pop(dialogContext, parsedQuantity)`

The Daily Log page route is no longer popped.

No quantity calculation, storage, or visual behavior is otherwise changed.
