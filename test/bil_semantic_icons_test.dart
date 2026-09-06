import 'dart:io';

import 'package:body_intelligence_log/app/theme/bil_semantic_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BIL semantic icon contract', () {
    test('core actions keep distinct glyphs and stable functional colors', () {
      const core = <BilSemanticIconKind>[
        BilSemanticIconKind.foodLog,
        BilSemanticIconKind.barcode,
        BilSemanticIconKind.voice,
        BilSemanticIconKind.mealPhoto,
        BilSemanticIconKind.water,
        BilSemanticIconKind.weight,
        BilSemanticIconKind.exercise,
      ];

      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        final glyphs = core
            .map((kind) => BilSemanticIcons.spec(kind).iconFor(platform))
            .toSet();
        expect(glyphs, hasLength(core.length), reason: '$platform glyphs');
      }

      final accents = core
          .map((kind) => BilSemanticIcons.spec(kind).accent(Brightness.light))
          .toSet();
      expect(accents, hasLength(core.length));
    });

    test('every icon has at least 3:1 graphical contrast', () {
      for (final kind in BilSemanticIconKind.values) {
        final spec = BilSemanticIcons.spec(kind);
        for (final brightness in Brightness.values) {
          expect(
            _contrast(spec.accent(brightness), spec.container(brightness)),
            greaterThanOrEqualTo(3),
            reason: '$kind $brightness',
          );
          expect(
            _contrast(spec.accent(brightness), spec.onAccent(brightness)),
            greaterThanOrEqualTo(3),
            reason: '$kind solid $brightness',
          );
        }
      }
    });

    test('platform glyphs retain precise semantic fallbacks', () {
      for (final kind in BilSemanticIconKind.values) {
        final spec = BilSemanticIcons.spec(kind);
        expect(spec.iconFor(TargetPlatform.android), spec.icon);
        expect(spec.iconFor(TargetPlatform.iOS), spec.appleIcon);
        expect(spec.iconFor(TargetPlatform.macOS), spec.appleIcon);
        expect(
          spec.icon.fontFamily,
          kind == BilSemanticIconKind.barcode
              ? 'CupertinoIcons'
              : 'MaterialIcons',
        );
      }

      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.barcode,
        ).iconFor(TargetPlatform.iOS),
        CupertinoIcons.barcode_viewfinder,
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.barcode,
        ).iconFor(TargetPlatform.android),
        CupertinoIcons.barcode_viewfinder,
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.heartRate,
        ).iconFor(TargetPlatform.iOS),
        CupertinoIcons.waveform_path_ecg,
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.steps,
        ).iconFor(TargetPlatform.iOS),
        Icons.directions_walk_rounded,
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.steps,
        ).iconFor(TargetPlatform.iOS),
        isNot(CupertinoIcons.hare),
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.weight,
        ).iconFor(TargetPlatform.iOS),
        Icons.monitor_weight_outlined,
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.weight,
        ).iconFor(TargetPlatform.iOS),
        isNot(CupertinoIcons.gauge),
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.oxygen,
        ).iconFor(TargetPlatform.iOS),
        CupertinoIcons.wind,
      );
      expect(
        BilSemanticIcons.spec(
          BilSemanticIconKind.oxygen,
        ).iconFor(TargetPlatform.iOS),
        isNot(CupertinoIcons.drop),
      );
    });

    test('route and health fallbacks remain honest', () {
      expect(BilSemanticIcons.kindForRoute('/unknown'), isNull);
      expect(
        BilSemanticIcons.kindForRoute('/settings/appearance'),
        BilSemanticIconKind.appearance,
      );
      expect(
        BilSemanticIcons.kindForHealthSignal('resting_heart_rate'),
        BilSemanticIconKind.heartRate,
      );
      expect(
        BilSemanticIcons.kindForHealthSignal('blood_oxygen_spo2'),
        BilSemanticIconKind.oxygen,
      );
      expect(
        BilSemanticIcons.kindForHealthSignal('unknown_signal'),
        BilSemanticIconKind.health,
      );
    });
  });

  testWidgets('a badge inside a labelled tile does not repeat its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            key: const Key('water-tile'),
            leading: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.water,
            ),
            title: const Text('Water'),
            onTap: () {},
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byKey(const Key('water-tile')));
    expect(RegExp(r'Water').allMatches(node.label), hasLength(1));
    semantics.dispose();
  });

  testWidgets('a standalone badge may expose one explicit semantic label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BilSemanticIconBadge(
            key: Key('standalone-water'),
            kind: BilSemanticIconKind.water,
            semanticLabel: 'Hydration shortcut',
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byKey(const Key('standalone-water')));
    expect(node.label, 'Hydration shortcut');
    expect(node.flagsCollection.isImage, isTrue);
    semantics.dispose();
  });

  testWidgets('badges survive the release layout/platform matrix', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final brightness in Brightness.values) {
        for (final direction in TextDirection.values) {
          for (final size in const [Size(390, 844), Size(1024, 1366)]) {
            for (final scale in const [1.0, 2.0]) {
              tester.view.physicalSize = size;
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(
                    useMaterial3: true,
                    platform: platform,
                    brightness: brightness,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Directionality(
                      textDirection: direction,
                      child: child!,
                    ),
                  ),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: size.width < 600 ? size.width : 520,
                        child: ListTile(
                          key: const Key('matrix-tile'),
                          minTileHeight: 48,
                          leading: BilSemanticIconBadge(
                            key: const Key('matrix-badge'),
                            kind: BilSemanticIconKind.barcode,
                            shape: BoxShape.rectangle,
                            platformOverride: platform,
                          ),
                          title: const Text('Scan barcode'),
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              );

              expect(tester.takeException(), isNull);
              expect(
                tester.getSize(find.byKey(const Key('matrix-tile'))).height,
                greaterThanOrEqualTo(48),
              );
              final icon = tester.widget<Icon>(
                find.descendant(
                  of: find.byKey(const Key('matrix-badge')),
                  matching: find.byType(Icon),
                ),
              );
              expect(
                icon.icon,
                BilSemanticIcons.spec(
                  BilSemanticIconKind.barcode,
                ).iconFor(platform),
              );
            }
          }
        }
      }
    }
  });

  test('major user-facing surfaces use the central badge contract', () {
    const paths = <String>[
      'lib/features/dashboard/widgets/dashboard_reference_goal_components.dart',
      'lib/features/dashboard/widgets/dashboard_water_card.dart',
      'lib/features/settings/settings_page.dart',
      'lib/features/settings/reference_settings_home_page.dart',
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
      'lib/features/daily_log/presentation/quick_macro_entry_dialog.dart',
      'lib/features/wellness/presentation/wellness_library_page.dart',
      'lib/features/wellness/presentation/wellness_learn_page.dart',
      'lib/features/history/history_page.dart',
      'lib/features/history/progress_page.dart',
      'lib/features/connected_health/connected_health_page.dart',
      'lib/features/community/presentation/community_hub_page.dart',
      'lib/features/settings/trust_support_page.dart',
    ];

    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
      final source = File(path).readAsStringSync();
      expect(source, contains('BilSemanticIconBadge'), reason: path);
    }

    final health = File(
      'lib/features/connected_health/connected_health_page.dart',
    ).readAsStringSync();
    expect(health, contains('kindForHealthSignal'));

    final iosSettings = File(
      'lib/features/settings/reference_settings_home_page.dart',
    ).readAsStringSync();
    expect(iosSettings, isNot(contains('Color(0xFF007AFF)')));

    final quickAdd = File(
      'lib/app/router/bil_quick_add_sheet.dart',
    ).readAsStringSync();
    expect(quickAdd, contains('BilSemanticIcons.spec'));
    expect(quickAdd, contains('BilSemanticIconKind.foodSearch'));
    expect(quickAdd, isNot(contains('BilQuickAddActionColors')));
  });
}

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}
