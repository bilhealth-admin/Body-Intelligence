import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/shared/widgets/actionable_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('actionable empty state survives compact Arabic large text', (
    tester,
  ) async {
    var actions = 0;
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: Scaffold(
          body: ActionableEmptyState(
            icon: Icons.monitor_weight_outlined,
            title: 'ابنِ أول اتجاه قابل للمقارنة',
            body:
                'يحدد قياس واحد نقطة البداية. ينتظر BIL أيامًا أكثر قابلية للمقارنة قبل وصف أي اتجاه.',
            actionLabel: 'سجّل أول وزن',
            onAction: () => actions++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ابنِ أول اتجاه قابل للمقارنة'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.ensureVisible(find.text('سجّل أول وزن'));
    await tester.tap(find.text('سجّل أول وزن'));
    expect(actions, 1);
    expect(tester.takeException(), isNull);
  });
}
