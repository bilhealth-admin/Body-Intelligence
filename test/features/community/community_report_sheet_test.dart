import 'package:body_intelligence_log/features/community/presentation/community_report_sheet.dart';
import 'package:body_intelligence_log/shared/widgets/bil_report_reason_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final target in CommunityReportTarget.values) {
    testWidgets(
      '$target requires explicit selection and confirmation; cancel has no receipt',
      (tester) async {
        CommunityReportDraft? draft;
        var completions = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    draft = await showCommunityReportSheet(
                      context,
                      target: target,
                    );
                    completions++;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(BilReportReasonOption), findsNWidgets(4));
        final send = find.byKey(const Key('community-report-submit'));
        expect(tester.widget<FilledButton>(send).onPressed, isNull);
        await tester.tap(
          find.byKey(const Key('community-report-reason-tap-harassment')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('community-report-note')),
        );
        await tester.enterText(
          find.byKey(const Key('community-report-note')),
          'Please review this content',
        );
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(completions, 1);
        expect(draft?.reason, 'harassment: Please review this content');
        draft = null;
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('community-report-cancel')),
        );
        await tester.tap(find.byKey(const Key('community-report-cancel')));
        await tester.pumpAndSettle();
        expect(draft, isNull);
        expect(completions, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'channel reporting retains exact supported category without an unsent note',
    (tester) async {
      CommunityReportDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  draft = await showCommunityReportSheet(
                    context,
                    target: CommunityReportTarget.message,
                    allowNote: false,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community-report-note')), findsNothing);
      await tester.tap(
        find.byKey(const Key('community-report-reason-tap-hate_speech')),
      );
      await tester.pumpAndSettle();
      final send = find.byKey(const Key('community-report-submit'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(draft?.category, 'hate_speech');
      expect(draft?.reason, 'hate_speech');
      expect(tester.takeException(), isNull);
    },
  );
}
