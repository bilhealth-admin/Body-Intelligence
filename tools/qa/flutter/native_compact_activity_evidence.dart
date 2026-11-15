// QA-only protocol shared by the native paint probe and host evidence driver.
// It describes observed production pixels, never a fabricated progress value.
const nativeCompactActivityEvidenceSchema = 'bil.native-compact-activity.v1';
const nativeCompactActivitySamplingScope =
    'actual ancestor RepaintBoundary RGBA crop; separate pending visit';

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
      value['indicator_kind'] != 'BIL_COMPACT_CIRCULAR_WAIT' ||
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
