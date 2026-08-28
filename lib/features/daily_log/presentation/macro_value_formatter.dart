/// Formats diary macro grams without erasing meaningful sub-gram values.
///
/// Whole values stay compact (`14 g`), while a value such as `0.2 g` never
/// becomes the misleading `0 g` shown by integer rounding.
String formatDiaryMacroGrams(double value) {
  if (!value.isFinite || value < 0) return '—';
  if ((value - value.roundToDouble()).abs() < 0.000001) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
