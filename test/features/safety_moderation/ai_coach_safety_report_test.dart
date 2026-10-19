import 'package:body_intelligence_log/features/safety_moderation/domain/ai_coach_safety_report.dart';
import '../../support/legacy_mobile_admin/features/safety_moderation/presentation/ai_coach_safety_report_queue_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final openReport = AiCoachSafetyReport(
    id: '00000000-0000-4000-8000-000000000101',
    reason: 'medical_accuracy',
    locale: 'ar',
    runtime: 'cloud_personalized',
    status: 'open',
    reportedAt: DateTime.utc(2026, 10, 14, 9),
    answerText: 'اختبار إجابة مرسلة للمراجعة.',
    userNote: 'يرجى مراجعة هذه العبارة.',
  );

  test(
    'queue parser keeps open content and rejects malformed reviewed content',
    () {
      final parsed = AiCoachSafetyReport.fromJson({
        'report_id': openReport.id,
        'reason': 'medical_accuracy',
        'locale': 'ar',
        'runtime': 'cloud_personalized',
        'status': 'open',
        'created_at': '2026-10-14T09:00:00Z',
        'answer_text': 'اختبار إجابة مرسلة للمراجعة.',
        'decision': null,
        'reviewed_at': null,
      });
      expect(parsed.answerText, openReport.answerText);
      expect(parsed.userNote, isNull);
      expect(parsed.isOpen, isTrue);
      expect(
        AiCoachSafetyReport.fromJson({
          'report_id': openReport.id,
          'reason': 'offensive',
          'locale': 'en',
          'runtime': 'on_device',
          'status': 'open',
          'created_at': '2026-10-14T09:00:00Z',
          'answer_text': 'Synthetic report.',
          'decision': null,
          'reviewed_at': null,
        }).reason,
        'offensive',
      );
      expect(
        () => AiCoachSafetyReport.fromJson({
          'report_id': openReport.id,
          'reason': 'medical_accuracy',
          'locale': 'ar',
          'runtime': 'cloud_personalized',
          'status': 'reviewed',
          'created_at': '2026-10-14T09:00:00Z',
          'answer_text': 'must be erased after review',
          'decision': 'confirmed_safety_issue',
          'reviewed_at': '2026-10-14T10:00:00Z',
        }),
        throwsFormatException,
      );
      final legacyPrivacy = AiCoachSafetyReport.fromJson({
        'report_id': openReport.id,
        'reason': 'privacy',
        'locale': 'en',
        'runtime': 'on_device',
        'status': 'open',
        'created_at': '2026-10-14T09:00:00Z',
        'answer_text': 'Synthetic report.',
        'decision': null,
        'reviewed_at': null,
      });
      expect(legacyPrivacy.reason, 'privacy');
    },
  );

  testWidgets('queue shows the distinct AI report and forwards a real decision', (
    tester,
  ) async {
    final decisions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiCoachSafetyReportQueueSection(
              reports: [openReport],
              reviewUnavailable: false,
              busyReportIds: const {},
              onReview: (report, decision) async {
                expect(report.id, openReport.id);
                decisions.add(decision);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('AI Coach safety reports'), findsOneWidget);
    expect(find.text('اختبار إجابة مرسلة للمراجعة.'), findsOneWidget);
    expect(
      find.textContaining('Inaccurate or misleading information'),
      findsOneWidget,
    );
    expect(find.textContaining('Optional note'), findsOneWidget);
    expect(find.textContaining('يرجى مراجعة هذه العبارة.'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(
        const Key(
          'ai-coach-report-confirm-issue-00000000-0000-4000-8000-000000000101',
        ),
      ),
    );
    await tester.tap(
      find.byKey(
        const Key(
          'ai-coach-report-confirm-issue-00000000-0000-4000-8000-000000000101',
        ),
      ),
    );
    await tester.pump();
    expect(decisions, ['confirmed_safety_issue']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older server reports the AI review queue as unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiCoachSafetyReportQueueSection(
            reports: [],
            reviewUnavailable: true,
            busyReportIds: {},
            onReview: _ignoreReview,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('ai-coach-report-review-unavailable')),
      findsOneWidget,
    );
    expect(find.text('AI Coach safety reports'), findsOneWidget);
  });
}

Future<void> _ignoreReview(AiCoachSafetyReport report, String decision) async {}
