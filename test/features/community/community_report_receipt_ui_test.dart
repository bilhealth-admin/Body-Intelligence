import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_report_receipt_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_report_sheet.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'already-reported copy resolves all25 supported locales without English fallback',
    () {
      final tags = AppLocalizations.supportedLocales
          .map(BilLocalePolicy.canonicalTag)
          .toSet();
      expect(tags, hasLength(25));
      expect(CommunityReportReceiptCopy.values.keys.toSet(), tags);
      for (final tag in tags) {
        final text = communityTextForLanguage(
          tag,
          CommunityReportReceiptCopy.alreadyReported,
          CommunityReportReceiptCopy.values['ar']!,
        );
        expect(text, CommunityReportReceiptCopy.values[tag]);
        if (tag != 'en') {
          expect(text, isNot(CommunityReportReceiptCopy.alreadyReported));
        }
      }
    },
  );

  for (final duplicate in [false, true]) {
    testWidgets(
      'receipt feedback is withheld after owner withdrawal duplicate=$duplicate',
      (tester) async {
        final receipt = Completer<void>();
        var currentOwner = true;
        var sends = 0;
        Future<bool>? submitted;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    submitted = submitCommunityReportWithReceipt(
                      context: context,
                      checkOwner: () {
                        if (!currentOwner) {
                          throw const CommunityOwnerOperationCancelled();
                        }
                      },
                      send: () {
                        sends++;
                        return receipt.future;
                      },
                    );
                    submitted!.ignore();
                  },
                  child: const Text('Submit'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Submit'));
        expect(sends, 1);
        currentOwner = false;
        final assertion = expectLater(
          submitted,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        if (duplicate) {
          receipt.completeError(const CommunityReportAlreadyPending());
        } else {
          receipt.complete();
        }
        await tester.pumpAndSettle();
        await assertion;
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
