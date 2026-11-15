// QA-only protocol shared by the native paint probe and host evidence driver.
// It describes observed production pixels, never a fabricated progress value.
const nativeCompactActivityEvidenceSchema = 'bil.native-compact-activity.v1';
const nativeCompactActivityIndicatorKind = 'BIL_COMPACT_SEGMENTED_WAIT';
const nativeCompactActivityNeutralArgb = {0xFF697178, 0xFFBBC4CD, 0xFFE5E7EB};
const nativeCompactActivitySamplingScope =
    'actual ancestor RepaintBoundary RGBA crop; separate pending visit';

/// Cupertino ticks use alpha 47..147, so observe their actual composited color.
/// An unchanged background or a transparent/blank pixel cannot count as paint.
bool isNativeSegmentedActivityForegroundPixel(
  List<int> pixel,
  List<int> background, {
  List<int> foregroundRgb = const [0x69, 0x71, 0x78],
}) {
  if (pixel.length != 4 ||
      background.length != 4 ||
      foregroundRgb.length != 3 ||
      pixel.any((channel) => channel < 0 || channel > 255) ||
      background.any((channel) => channel < 0 || channel > 255) ||
      foregroundRgb.any((channel) => channel < 0 || channel > 255) ||
      pixel[3] != 255 ||
      background[3] != 255 ||
      List.generate(
        3,
        (channel) => (pixel[channel] - background[channel]).abs(),
      ).every((difference) => difference < 10)) {
    return false;
  }
  final foregroundArgb =
      0xFF000000 |
      (foregroundRgb[0] << 16) |
      (foregroundRgb[1] << 8) |
      foregroundRgb[2];
  if (!nativeCompactActivityNeutralArgb.contains(foregroundArgb)) return false;
  for (final alpha in [47, 72, 97, 122, 147]) {
    var matches = true;
    for (var channel = 0; channel < 3; channel++) {
      final expected =
          (foregroundRgb[channel] * alpha +
              background[channel] * (255 - alpha) +
              127) ~/
          255;
      if ((pixel[channel] - expected).abs() > 6) matches = false;
    }
    if (matches) return true;
  }
  return false;
}

bool isNativeCompactActivityPaintEvidence(Object? value) {
  if (value is! Map) return false;
  const keys = {
    'schema',
    'indicator_kind',
    'render_width',
    'render_height',
    'crop_width',
    'crop_height',
    'reduced_motion',
    'first_foreground_pixel_count',
    'second_foreground_pixel_count',
    'distinct_rgba_colors',
    'changed_rgba_pixel_count',
    'indeterminate_without_percentage',
    'sample_interval_ms',
    'sampling_scope',
  };
  if (value.length != keys.length ||
      !keys.every(value.containsKey) ||
      value['schema'] != nativeCompactActivityEvidenceSchema ||
      value['indicator_kind'] != nativeCompactActivityIndicatorKind ||
      value['sampling_scope'] != nativeCompactActivitySamplingScope ||
      value['sample_interval_ms'] != 320 ||
      value['indeterminate_without_percentage'] != true ||
      value['reduced_motion'] is! bool) {
    return false;
  }
  for (final key in ['render_width', 'render_height']) {
    final dimension = value[key];
    if (dimension is! num ||
        !dimension.isFinite ||
        (dimension - 24).abs() > 1e-6) {
      return false;
    }
  }
  final width = value['crop_width'];
  final height = value['crop_height'];
  if (width is! int ||
      height is! int ||
      width < 24 ||
      width > 25 ||
      height < 24 ||
      height > 25) {
    return false;
  }
  final pixels = width * height;
  for (final key in [
    'first_foreground_pixel_count',
    'second_foreground_pixel_count',
  ]) {
    final count = value[key];
    if (count is! int || count <= 0 || count > pixels) return false;
  }
  final colors = value['distinct_rgba_colors'];
  final changed = value['changed_rgba_pixel_count'];
  if (colors is! int ||
      colors < 2 ||
      colors > pixels ||
      changed is! int ||
      changed < 0 ||
      changed > pixels) {
    return false;
  }
  return value['reduced_motion'] == true ? changed == 0 : changed > 0;
}
