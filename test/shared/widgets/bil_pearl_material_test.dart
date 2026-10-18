import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'decision preserves cancel and confirm at enlarged text dark=$dark',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? BilFlagshipTheme.dark() : BilFlagshipTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await showDialog<bool>(
                    context: context,
                    builder: (context) => BilPearlMaterialAlertDialog(
                      title: const Text('Permission decision'),
                      content: const Text('Only share when you allow it.'),
                      scrollable: true,
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Allow'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(BilFrostedPanel), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('card taps survive the finish and status colors are preserved', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BilPearlMaterialCard(
                child: InkWell(
                  onTap: () => taps++,
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Tap card'),
                  ),
                ),
              ),
              const BilPearlMaterialCard(
                color: Colors.red,
                child: Text('Critical status'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tap card'));
    await tester.pump();
    expect(taps, 1);
    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards.last.color, Colors.red);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pearl ink does not consume the compact card border twice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 64,
            child: BilPearlMaterialCard(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(side: BorderSide(width: 2)),
              child: SizedBox.expand(key: Key('card-content')),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('card-content'))),
      const Size(80, 64),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sheet preserves navigator scope, result and non-dismissable barrier',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showBilPearlBottomSheet<String>(
                        context: context,
                        isDismissible: false,
                        enableDrag: false,
                        builder: (context) => TextButton(
                          onPressed: () => Navigator.pop(context, 'selected'),
                          child: const Text('Choose'),
                        ),
                      );
                    },
                    child: const Text('Open sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(BilFrostedPanel), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Choose'), findsOneWidget);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(result, 'selected');
      expect(tester.takeException(), isNull);
    },
  );
}
