import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_export_command.dart';
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/features/settings/local_export_range_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (scale, bottomInset, label) in const [
    (1.15, 44.0, 'OPPO 360x800 with three-button navigation'),
    (2.0, 44.0, 'large text with the same navigation inset'),
    (1.15, 0.0, 'zero-inset control'),
  ]) {
    testWidgets('prepared export stays fully reachable: $label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final data = _Data();
      final share = _Share();
      final day = DateTime(2026, 11, 18);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileAuthIdentityProvider.overrideWith(
              (ref) => Stream.value(
                const ProfileAuthIdentity(
                  ownerId: '11111111-1111-4111-8111-111111111111',
                  email: null,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: BilFlagshipTheme.light().copyWith(
              platform: TargetPlatform.android,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(top: 24, bottom: bottomInset),
                viewPadding: EdgeInsets.only(top: 24, bottom: bottomInset),
                viewInsets: EdgeInsets.zero,
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: LocalExportRangePage(
              initialFrom: day,
              initialTo: day,
              initialDatasets: const {'progress'},
              commandService: CoachExportCommandService(
                data: data,
                share: share,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final create = _button('Create CSV export');
      await tester.scrollUntilVisible(
        create,
        300,
        scrollable: find.descendant(
          of: find.byType(LocalExportRangePage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(data.calls, 1);
      expect(data.from, day);
      expect(data.to, day);
      expect(share.calls, 0, reason: 'Preparation is local and never shares.');
      // Let the genuine preparation snackbar leave the final hit target.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _reachActualBottom(tester);

      final button = _button('Share prepared export');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      final page = tester.element(find.byType(LocalExportRangePage));
      final media = MediaQuery.of(page);
      expect(media.size, const Size(360, 800));
      expect(media.padding.bottom, bottomInset);
      final safeBottom = media.size.height - media.padding.bottom;
      final rect = tester.getRect(button);
      final card = find.ancestor(
        of: find.text('Export files are ready'),
        matching: find.byType(BilPearlMaterialCard),
      );
      expect(card, findsOneWidget);
      expect(
        tester.getRect(card).bottom,
        lessThanOrEqualTo(safeBottom + .01),
        reason: 'The prepared card must clear the system navigation region.',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(safeBottom + .01),
        reason: 'The full action, not only its visible top, must be safe.',
      );
      expect(rect.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(button.hitTestable(), findsOneWidget);
      expect(find.text('• BIL-progress.csv'), findsOneWidget);
      expect(find.text('• BIL-meal-nutrition.csv'), findsNothing);
      expect(find.text('• BIL-exercise.csv'), findsNothing);
      expect(share.calls, 0);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(share.calls, 1);
      expect(share.files, {'BIL-progress.csv': _Data.progress});
      expect(data.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

Future<void> _reachActualBottom(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byType(LocalExportRangePage),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsOneWidget);
  for (var attempt = 0; attempt < 8; attempt++) {
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(scrollable).position;
    if ((position.pixels - position.maxScrollExtent).abs() < .01) {
      final previous = position.pixels;
      await tester.drag(scrollable, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, .01));
      expect(position.pixels, closeTo(previous, .01));
      return;
    }
  }
  fail('The actual list did not reach its reported maximum offset.');
}

class _Data implements CoachExportDataGateway {
  static const progress = 'date,weightKg\n2026-11-18,70.0';
  int calls = 0;
  DateTime? from;
  DateTime? to;

  @override
  Future<Map<String, String>> exportCsvFiles({
    DateTime? from,
    DateTime? to,
  }) async {
    calls++;
    this.from = from;
    this.to = to;
    return const {
      'BIL-progress.csv': progress,
      'BIL-meal-nutrition.csv': 'date,calories\n2026-11-18,1200',
      'BIL-exercise.csv': 'date,note\n2026-11-18,walk',
    };
  }
}

class _Share implements CoachExportShareGateway {
  int calls = 0;
  Map<String, String>? files;

  @override
  Future<void> sharePortableCsvFiles(Map<String, String> files) async {
    calls++;
    this.files = Map.of(files);
  }
}
