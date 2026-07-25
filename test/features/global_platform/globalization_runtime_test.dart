import 'global_platform_test_support.dart';

void main() {
  testWidgets('globalization supports RTL semantics touch target and text', (
    tester,
  ) async {
    final runtime = GlobalizationRuntime(
      catalogs: [
        const GlobalLocaleCatalog('en', {'status': 'Status'}),
        const GlobalLocaleCatalog('ar', {'status': 'الحالة'}),
      ],
      requiredKeys: {'status'},
    );
    expect(runtime.validate(), isEmpty);
    expect(runtime.direction('ar'), TextDirection.rtl);
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AccessibleGlobalStatus(
          label: runtime.text('ar', 'status'),
          value: 'ready',
          onTap: () {
            tapped = true;
          },
        ),
      ),
    );
    expect(find.bySemanticsLabel('الحالة'), findsOneWidget);
    await tester.tap(find.textContaining('الحالة'));
    expect(tapped, true);
  });
}
