# BDAR-003B-R1 Implementation Notes

R1 corrects three test defects without touching production code:

1. Dart does not allow a constant map with `double` keys in this context, so the
   viewport cases now use records in a normal list.
2. The responsive source contract now uses a whitespace-tolerant regular
   expression and no longer fails when `dart format` wraps the resolver call.
3. The legacy composition test now reflects the approved product contract:
   1280px remains stacked; 1600px and 1920px use two regions.
