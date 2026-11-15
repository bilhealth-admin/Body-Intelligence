part of 'native_feature_splashes_test.dart';

Future<({Size size, int width, int height, List<int> rgba, int foreground})>
_readNativeCompactActivityPaint(WidgetTester tester, Finder indicator) async {
  expect(indicator, findsOneWidget);
  final element = indicator.evaluate().single;
  expect(element.widget, isA<BilCompactActivityIndicator>());
  final activity = tester.widget<CupertinoActivityIndicator>(
    find.descendant(
      of: indicator,
      matching: find.byType(CupertinoActivityIndicator),
    ),
  );
  expect(
    nativeCompactActivityNeutralArgb,
    contains(activity.color?.toARGB32()),
  );
  final argb = activity.color!.toARGB32();
  final foregroundRgb = [(argb >> 16) & 255, (argb >> 8) & 255, argb & 255];
  final rect = _nativeRect(indicator);
  expect(rect.width, closeTo(24, 1e-6));
  expect(rect.height, closeTo(24, 1e-6));
  final boundary = element
      .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
  expect(boundary, isNotNull);
  final origin = boundary!.globalToLocal(rect.topLeft);
  final left = origin.dx.floor();
  final top = origin.dy.floor();
  final right = (origin.dx + rect.width).ceil();
  final bottom = (origin.dy + rect.height).ceil();
  final snapshot = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(left, greaterThanOrEqualTo(0));
      expect(top, greaterThanOrEqualTo(0));
      expect(right, lessThanOrEqualTo(image.width));
      expect(bottom, lessThanOrEqualTo(image.height));
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(raw, isNotNull);
      final bytes = raw!.buffer.asUint8List(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      final rgba = <int>[];
      var foreground = 0;
      List<int> pixelAt(int x, int y) {
        final offset = (y * image.width + x) * 4;
        return bytes.sublist(offset, offset + 4);
      }

      // The 24px segmented ring never reaches its crop's four corners.
      // Read actual opaque background colors rather than assuming a theme.
      final backgrounds = [
        pixelAt(left, top),
        pixelAt(right - 1, top),
        pixelAt(left, bottom - 1),
        pixelAt(right - 1, bottom - 1),
      ];
      expect(backgrounds.every((pixel) => pixel[3] == 255), isTrue);
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          final pixel = pixelAt(x, y);
          rgba.addAll(pixel);
          if (backgrounds.any(
            (background) => isNativeSegmentedActivityForegroundPixel(
              pixel,
              background,
              foregroundRgb: foregroundRgb,
            ),
          )) {
            foreground++;
          }
        }
      }
      return (
        size: rect.size,
        width: right - left,
        height: bottom - top,
        rgba: rgba,
        foreground: foreground,
      );
    } finally {
      image.dispose();
    }
  });
  expect(snapshot, isNotNull);
  return snapshot!;
}

// Shared verbatim by actual native Store visits and the host regression.
// Only an observed production24px spinner crop is sampled; no widget is
// wrapped, repainted manually, frozen or replaced for this evidence.
Future<Map<String, Object?>> verifyNativeCompactActivityProbe(
  WidgetTester tester,
  Finder indicator, {
  required bool reduced,
}) async {
  expect(indicator, findsOneWidget);
  final activity = find.descendant(
    of: indicator,
    matching: find.byType(CupertinoActivityIndicator),
  );
  expect(activity, findsOneWidget);
  expect(
    find.descendant(
      of: indicator,
      matching: find.byType(CircularProgressIndicator),
    ),
    findsNothing,
  );
  final segmented = tester.widget<CupertinoActivityIndicator>(activity);
  expect(segmented.radius, 12);
  expect(
    nativeCompactActivityNeutralArgb,
    contains(segmented.color?.toARGB32()),
  );
  expect(segmented.animating, !reduced);
  expect(segmented.progress, 1);
  final semantics = tester.widget<Semantics>(
    find.descendant(of: indicator, matching: find.byType(Semantics)).first,
  );
  expect(semantics.properties.role, ui.SemanticsRole.loadingSpinner);
  expect(semantics.properties.value, isNull);
  final first = await _readNativeCompactActivityPaint(tester, indicator);
  await tester.pump(const Duration(milliseconds: 320));
  final second = await _readNativeCompactActivityPaint(tester, indicator);
  expect(second.size, first.size);
  expect(second.width, first.width);
  expect(second.height, first.height);
  expect(second.rgba.length, first.rgba.length);
  expect(first.foreground, greaterThan(0));
  expect(second.foreground, greaterThan(0));
  var changed = 0;
  final colors = <int>{};
  for (var i = 0; i < first.rgba.length; i += 4) {
    colors.add(
      (first.rgba[i] << 24) |
          (first.rgba[i + 1] << 16) |
          (first.rgba[i + 2] << 8) |
          first.rgba[i + 3],
    );
    if (first.rgba[i] != second.rgba[i] ||
        first.rgba[i + 1] != second.rgba[i + 1] ||
        first.rgba[i + 2] != second.rgba[i + 2] ||
        first.rgba[i + 3] != second.rgba[i + 3]) {
      changed++;
    }
  }
  expect(colors.length, greaterThan(1));
  expect(changed, reduced ? 0 : greaterThan(0));
  final result = <String, Object?>{
    'schema': nativeCompactActivityEvidenceSchema,
    'indicator_kind': nativeCompactActivityIndicatorKind,
    'render_width': first.size.width,
    'render_height': first.size.height,
    'crop_width': first.width,
    'crop_height': first.height,
    'reduced_motion': reduced,
    'first_foreground_pixel_count': first.foreground,
    'second_foreground_pixel_count': second.foreground,
    'distinct_rgba_colors': colors.length,
    'changed_rgba_pixel_count': changed,
    'indeterminate_without_percentage': true,
    'sample_interval_ms': 320,
    'sampling_scope': nativeCompactActivitySamplingScope,
  };
  expect(isNativeCompactActivityPaintEvidence(result), isTrue);
  return result;
}
