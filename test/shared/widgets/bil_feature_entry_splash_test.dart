import 'dart:async';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/shared/widgets/bil_feature_entry_splash.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_next/feature_splashes_test_support.dart';
import '../../visual_closure/visual_evidence_font.dart';

class _Destination extends StatefulWidget {
  const _Destination({
    required this.onInit,
    required this.onPressed,
    required this.load,
  });
  final VoidCallback onInit;
  final VoidCallback onPressed;
  final Future<void> load;
  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<void>(
      future: widget.load,
      builder: (context, state) => Center(
        child: TextButton(
          key: const Key('destination'),
          onPressed: widget.onPressed,
          child: Text(
            state.connectionState == ConnectionState.done
                ? 'destination action ready'
                : 'destination action loading',
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final kind in BilFeatureEntryKind.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        '${kind.name} entry splash is bounded and releases destination at 2200ms reduced=$reduced',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          try {
            var initializations = 0;
            var taps = 0;
            final pending = Completer<void>();
            await tester.pumpWidget(
              featureSplashApp(
                language: 'ar',
                dark: false,
                scale: 2,
                reduceMotion: reduced,
                child: BilFeatureEntrySplashGate(
                  kind: kind,
                  child: _Destination(
                    onInit: () => initializations++,
                    onPressed: () => taps++,
                    load: pending.future,
                  ),
                ),
              ),
            );
            await tester.pump();
            final state = tester.state(find.byType(_Destination));
            expect(
              initializations,
              1,
              reason: 'real destination prewarms before release',
            );
            expect(find.byKey(const Key('destination')), findsOneWidget);
            expect(
              find.bySemanticsLabel(RegExp('destination action')),
              findsNothing,
            );
            await tester.tapAt(
              tester.getCenter(find.byKey(const Key('destination'))),
            );
            expect(
              taps,
              0,
              reason: 'destination is not interactive beneath splash',
            );
            await tester.pump(const Duration(milliseconds: 2199));
            expect(
              find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
            expect(
              find.byKey(ValueKey('feature-entry-splash-${kind.name}')),
              findsNothing,
            );
            expect(
              identical(state, tester.state(find.byType(_Destination))),
              isTrue,
            );
            expect(initializations, 1);
            expect(
              find.text('destination action loading'),
              findsOneWidget,
              reason: 'data readiness never extends the 2.2-second visual hold',
            );
            pending.complete();
            await tester.pump();
            expect(find.text('destination action ready'), findsOneWidget);
            await tester.tap(find.byKey(const Key('destination')));
            await tester.pump();
            expect(taps, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
    for (final language in ['ar', 'en']) {
      for (final dark in [false, true]) {
        testWidgets(
          '${kind.name} pearl title and iOS status remain readable $language dark=$dark at 320px 2x',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                featureSplashApp(
                  language: language,
                  dark: dark,
                  scale: 2,
                  reduceMotion: true,
                  highContrast: dark,
                  child: BilFeatureEntrySplashGate(
                    kind: kind,
                    child: const Scaffold(body: Text('Destination')),
                  ),
                ),
              );
              await tester.pump();
              expect(
                tester.getRect(
                  find.byKey(const Key('bil-pearl-feature-canvas')),
                ),
                const Rect.fromLTWH(0, 0, 320, 568),
              );
              final title = tester.widget<Text>(
                find.byKey(const Key('bil-feature-welcome-title')),
              );
              expect(title.data?.isNotEmpty, isTrue);
              expect(title.style?.shadows ?? const [], isEmpty);
              final luminance = title.style!.color!.computeLuminance();
              expect(luminance, dark ? greaterThan(.7) : lessThan(.05));
              expect(find.bySemanticsLabel(title.data!), findsOneWidget);
              final indicator = tester.widget<CupertinoActivityIndicator>(
                find.byType(CupertinoActivityIndicator),
              );
              expect(indicator.animating, isFalse);
              expect(indicator.radius, 12);
              expect(find.byType(CircularProgressIndicator), findsNothing);
              expect(find.byType(LinearProgressIndicator), findsNothing);
              expect(
                find.byType(BackdropFilter),
                findsNothing,
                reason:
                    'opaque pearl does not need repeated blur or reveal underlying text',
              );
              expect(tester.takeException(), isNull);
              await tester.ensureVisible(
                find.byKey(const Key('bil-feature-welcome-subtitle')),
              );
              await tester.pump();
              expect(
                find
                    .byKey(const Key('bil-feature-welcome-subtitle'))
                    .hitTestable(),
                findsOneWidget,
              );
              // A real finger gesture reaches the readable status at large text.
              // The Cupertino glyph itself is decorative, not a touch target.
              await tester.drag(
                find.byKey(const Key('bil-feature-welcome-scroll')),
                const Offset(0, -300),
              );
              await tester.pump(const Duration(milliseconds: 100));
              final statusText = find.text(
                language == 'ar' ? 'جارٍ التحضير…' : 'Preparing…',
              );
              expect(statusText.hitTestable(), findsOneWidget);
              final statusRect = tester.getRect(statusText);
              expect(statusRect.top, greaterThanOrEqualTo(0));
              expect(statusRect.bottom, lessThanOrEqualTo(568));
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets(
    'internal feature status uses the same iOS spinner on Android and iOS',
    (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: const BilPearlFeatureWelcome(
              title: 'Feature',
              subtitle: 'Context',
              statusLabel: 'Preparing',
              artwork: Icon(Icons.menu_book_rounded),
            ),
          ),
        );
        expect(
          tester
              .widget<CupertinoActivityIndicator>(
                find.byType(CupertinoActivityIndicator),
              )
              .animating,
          isTrue,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'native iOS reduceMotion changes stop the indicator without shortening the hold',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        featureSplashApp(
          language: 'en',
          dark: false,
          child: const BilFeatureEntrySplashGate(
            kind: BilFeatureEntryKind.diet,
            child: Scaffold(body: Text('Destination')),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<CupertinoActivityIndicator>(
              find.byType(CupertinoActivityIndicator),
            )
            .animating,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pump();
      expect(
        tester
            .widget<CupertinoActivityIndicator>(
              find.byType(CupertinoActivityIndicator),
            )
            .animating,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 1899));
      expect(
        find.byKey(const ValueKey('feature-entry-splash-diet')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('feature-entry-splash-diet')),
        findsNothing,
      );
      expect(find.text('Destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: false);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'native accessibility observer is disposed on exit',
      );
    },
  );
  testWidgets(
    'route exit disposes the feature hold without remount or delayed exception',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('Origin')),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const BilFeatureEntrySplashGate(
            kind: BilFeatureEntryKind.recipes,
            child: Scaffold(body: Text('Destination')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('feature-entry-splash-recipes')),
        findsOneWidget,
      );
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('actual artwork pixels fade to the pearl canvas on every edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      featureSplashApp(
        language: 'en',
        dark: false,
        reduceMotion: true,
        child: RepaintBoundary(
          key: key,
          child: const BilPearlFeatureWelcome(
            title: 'Feature',
            subtitle: 'Context',
            artwork: ColoredBox(color: Color(0xFFFF0000)),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final rect = tester.getRect(
      find.byKey(const Key('bil-feature-welcome-artwork')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        List<int> pixel(Offset point) {
          final local = boundary.globalToLocal(point);
          final index = (local.dy.floor() * image.width + local.dx.floor()) * 4;
          return bytes.sublist(index, index + 4);
        }

        final center = pixel(rect.center);
        expect(center[0], greaterThan(240));
        expect(center[1], lessThan(20));
        expect(center[2], lessThan(20));
        for (final point in [
          Offset(rect.left + .5, rect.center.dy),
          Offset(rect.right - .5, rect.center.dy),
          Offset(rect.center.dx, rect.top + .5),
          Offset(rect.center.dx, rect.bottom - .5),
        ]) {
          final edge = pixel(point);
          expect(
            edge[1],
            greaterThan(180),
            reason:
                'artwork boundary blends into pearl, not a red image rectangle',
          );
          expect(edge[2], greaterThan(180));
          expect(
            edge[3],
            255,
            reason:
                'opaque canvas remains opaque even though decorative artwork is feathered',
          );
        }
      } finally {
        image.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'feathered artwork has no external card border or clipping frame',
    (tester) async {
      await tester.pumpWidget(
        featureSplashApp(
          language: 'en',
          dark: false,
          reduceMotion: true,
          child: const BilPearlFeatureWelcome(
            title: 'Measured feature',
            subtitle: 'Context',
            statusLabel: 'Preparing',
            artwork: ColoredBox(color: Color(0xFFFF0000)),
          ),
        ),
      );
      // AppLocalizations.delegate.load is async: its first frame deliberately
      // omits the route subtree. Pump the localized content frame before finding
      // the production decoration, just as the pixel test above does.
      await tester.pump();
      expect(find.byType(BilPearlFeatureWelcome), findsOneWidget);
      expect(
        tester
            .widget<BilPearlFeatureWelcome>(find.byType(BilPearlFeatureWelcome))
            .featherArtwork,
        isTrue,
      );
      expect(find.byType(ShaderMask), findsOneWidget);
      final shader = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(shader.blendMode, BlendMode.dstIn);
      expect(find.byType(ClipOval), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('bil-pearl-feature-canvas')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, isNull);
      expect(decoration.boxShadow, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
