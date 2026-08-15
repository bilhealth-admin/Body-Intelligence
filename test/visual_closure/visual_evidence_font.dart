import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void>? _fontLoad;

/// Replaces Flutter test's block-shaped Ahem glyphs with the real Android
/// system typeface distributed inside the active Flutter SDK. The font is
/// loaded only for visual evidence; production still uses each platform's
/// native system family.
Future<void> loadVisualEvidenceFont() {
  return _fontLoad ??= _loadRobotoIntoTestFamily();
}

Future<void> _loadRobotoIntoTestFamily() async {
  var cursor = File(Platform.resolvedExecutable).parent;
  File? font;
  while (true) {
    final candidate = File(
      '${cursor.path}${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts${Platform.pathSeparator}roboto-regular.ttf',
    );
    if (candidate.existsSync()) {
      font = candidate;
      break;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) break;
    cursor = parent;
  }
  if (font == null) {
    throw StateError('Flutter SDK Roboto font was not found.');
  }
  Future<ByteData> bytes(File source) =>
      source.readAsBytes().then((value) => ByteData.sublistView(value));
  final fontDirectory = font.parent;
  final projectArabicRegular = File(
    '${Directory.current.path}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}fonts${Platform.pathSeparator}'
    'NotoNaskhArabic-Regular.ttf',
  );
  final projectArabicBold = File(
    '${Directory.current.path}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}fonts${Platform.pathSeparator}'
    'NotoNaskhArabic-Bold.ttf',
  );
  final loader = FontLoader('RobotoEvidence')
    ..addFont(bytes(font))
    ..addFont(bytes(File('${fontDirectory.path}/roboto-medium.ttf')))
    ..addFont(bytes(File('${fontDirectory.path}/roboto-bold.ttf')))
    ..addFont(bytes(projectArabicRegular))
    ..addFont(bytes(projectArabicBold));
  // Widget tests install Ahem as the implicit fallback. A number of legacy
  // production controls intentionally inherit the platform family instead of
  // the Material text theme, so they otherwise render as Ahem rectangles in
  // visual evidence. Register the real UI face for that fallback family too.
  final fallback = FontLoader('Ahem')
    ..addFont(bytes(font))
    ..addFont(bytes(File('${fontDirectory.path}/roboto-medium.ttf')))
    ..addFont(bytes(File('${fontDirectory.path}/roboto-bold.ttf')))
    ..addFont(bytes(projectArabicRegular))
    ..addFont(bytes(projectArabicBold));
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes(File('${fontDirectory.path}/materialicons-regular.otf')));
  final arabic = FontLoader('NotoArabicEvidence')
    ..addFont(bytes(projectArabicRegular))
    ..addFont(bytes(projectArabicBold));
  await Future.wait([
    loader.load(),
    fallback.load(),
    arabic.load(),
    icons.load(),
  ]);
}

Future<void> settleVisualAssetImages(WidgetTester tester) async {
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  for (final imageWidget in images) {
    final provider = imageWidget.image;
    final isLocalAsset =
        provider is AssetImage ||
        (provider is ResizeImage && provider.imageProvider is AssetImage);
    if (!isLocalAsset) continue;

    var completed = false;
    Object? decodeError;
    // A production page can replace an image while another asset is decoding
    // (for example after an async provider resolves). Skip that stale snapshot
    // instead of asking WidgetTester.element for a widget that is no longer in
    // the tree.
    final imageFinder = find.byWidget(imageWidget);
    final imageElements = imageFinder.evaluate();
    if (imageElements.isEmpty) continue;
    final stream = provider.resolve(
      createLocalImageConfiguration(imageElements.first),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) => completed = true,
      onError: (Object error, StackTrace? stackTrace) {
        decodeError = error;
        completed = true;
      },
    );
    stream.addListener(listener);
    try {
      // Large production artwork is decoded on an engine worker. Alternate a
      // small amount of real wall-clock time with a widget frame; waiting for
      // the stream wholly inside runAsync deadlocks because image delivery
      // itself requires the test binding to pump.
      for (var frame = 0; frame < 200 && !completed; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
    } finally {
      stream.removeListener(listener);
    }
    if (decodeError != null) {
      throw StateError('Visual evidence asset failed to decode: $decodeError');
    }
    if (!completed) {
      throw StateError('Visual evidence asset decode timed out.');
    }
    await tester.pump();
  }
  await tester.pump();
}

Widget visualEvidenceTextSurface(
  Widget? child, {
  String fontFamily = 'RobotoEvidence',
}) {
  return DefaultTextStyle.merge(
    style: TextStyle(fontFamily: fontFamily),
    child: child ?? const SizedBox.shrink(),
  );
}

ThemeData visualEvidenceTheme(
  ThemeData theme, {
  String fontFamily = 'RobotoEvidence',
}) {
  TextStyle? face(TextStyle? style) => style?.copyWith(fontFamily: fontFamily);
  ButtonStyle? buttonFace(ButtonStyle? style) {
    if (style == null) return null;
    final inherited = style.textStyle;
    return style.copyWith(
      textStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        return face(inherited?.resolve(states));
      }),
    );
  }

  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: fontFamily),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: fontFamily),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: face(theme.appBarTheme.titleTextStyle),
      toolbarTextStyle: face(theme.appBarTheme.toolbarTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonFace(theme.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonFace(theme.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonFace(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonFace(theme.textButtonTheme.style),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: buttonFace(theme.segmentedButtonTheme.style),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: face(theme.chipTheme.labelStyle),
      secondaryLabelStyle: face(theme.chipTheme.secondaryLabelStyle),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: face(theme.listTileTheme.titleTextStyle),
      subtitleTextStyle: face(theme.listTileTheme.subtitleTextStyle),
      leadingAndTrailingTextStyle: face(
        theme.listTileTheme.leadingAndTrailingTextStyle,
      ),
    ),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      labelStyle: face(theme.inputDecorationTheme.labelStyle),
      floatingLabelStyle: face(theme.inputDecorationTheme.floatingLabelStyle),
      helperStyle: face(theme.inputDecorationTheme.helperStyle),
      hintStyle: face(theme.inputDecorationTheme.hintStyle),
      errorStyle: face(theme.inputDecorationTheme.errorStyle),
      counterStyle: face(theme.inputDecorationTheme.counterStyle),
      prefixStyle: face(theme.inputDecorationTheme.prefixStyle),
      suffixStyle: face(theme.inputDecorationTheme.suffixStyle),
    ),
    tabBarTheme: theme.tabBarTheme.copyWith(
      labelStyle: face(theme.tabBarTheme.labelStyle),
      unselectedLabelStyle: face(theme.tabBarTheme.unselectedLabelStyle),
    ),
  );
}
