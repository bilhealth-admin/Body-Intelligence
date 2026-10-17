import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/settings/cloud_sync_status_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget outcome(CloudManualSyncResult result, {String language = 'en'}) {
    return MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Text(
            cloudManualSyncOutcomeText(context, result),
            key: const Key('cloud-sync-outcome'),
          ),
        ),
      ),
    );
  }

  testWidgets('sync feedback distinguishes offline, owner mismatch and consent', (
    tester,
  ) async {
    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.offline,
    )));
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Encrypted cloud sync completed.'), findsNothing);

    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.localOwnerMismatch,
    )));
    expect(find.textContaining('another account'), findsOneWidget);

    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.consentMissing,
    )));
    expect(find.textContaining('no data was uploaded'), findsOneWidget);

    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.entitlementMissing,
    )));
    expect(find.textContaining('eligible subscription'), findsOneWidget);
  });

  testWidgets('partial and conflict outcomes cannot claim success', (
    tester,
  ) async {
    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.partial,
      pending: 3,
    )));
    expect(find.textContaining('3 record(s)'), findsOneWidget);
    expect(find.text('Encrypted cloud sync completed.'), findsNothing);
    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.partial,
      reason: 'conflict_review_required',
      conflicts: 1,
    )));
    expect(find.textContaining('Review backup conflicts'), findsOneWidget);
    await tester.pumpWidget(outcome(CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.completed,
      completedAt: DateTime.utc(2026, 10, 17),
    )));
    expect(find.text('Encrypted cloud sync completed.'), findsOneWidget);
  });

  testWidgets('Arabic errors distinguish offline from missing consent', (
    tester,
  ) async {
    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.offline,
    ), language: 'ar'));
    expect(find.textContaining('غير متصل بالإنترنت'), findsOneWidget);
    await tester.pumpWidget(outcome(const CloudManualSyncResult(
      disposition: CloudManualSyncDisposition.consentMissing,
    ), language: 'ar'));
    expect(find.textContaining('لم تُرفع بيانات'), findsOneWidget);
  });
}
