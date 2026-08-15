import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpVisualSystem(
    WidgetTester tester, {
    required ThemeData theme,
    required TextDirection direction,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            appBar: AppBar(title: const Text('BIL')),
            body: const DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.monitor_heart_outlined),
                    title: Text('Health'),
                    subtitle: Text('Recorded data'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  TabBar(
                    tabs: [
                      Tab(text: 'Day'),
                      Tab(text: 'Week'),
                    ],
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  label: 'Progress',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('canonical mobile system renders in light LTR', (tester) async {
    await pumpVisualSystem(
      tester,
      theme: AppThemeData.lightTheme(Brightness.light),
      direction: TextDirection.ltr,
    );

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    expect(theme.appBarTheme.centerTitle, isTrue);
    expect(theme.navigationBarTheme.height, 68);
    expect(theme.listTileTheme.minTileHeight, 54);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canonical mobile system renders in dark RTL at large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpVisualSystem(
      tester,
      theme: AppThemeData.lightTheme(Brightness.dark),
      direction: TextDirection.rtl,
    );

    expect(find.text('Health'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
