/// Formats diary macro grams as a compact whole-number display.
///
/// Calculations and persisted values remain doubles; rounding happens only at
/// the final presentation boundary so summaries never expose noisy decimals.
String formatDiaryMacroGrams(double value) {
  if (!value.isFinite || value < 0) return '—';
  return value.round().toString();
}
