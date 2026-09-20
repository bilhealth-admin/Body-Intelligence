/// Formats diary macro grams for the compact diary summary.
///
/// The underlying nutrition value remains precise; this helper only controls
/// the displayed whole-gram value so compact rows do not grow fractional text.
String formatDiaryMacroGrams(double value) {
  if (!value.isFinite || value < 0) return '—';
  return value.round().toString();
}
