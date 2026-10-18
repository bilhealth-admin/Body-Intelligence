import '../../../shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';

import '../domain/ai_coach_safety_report.dart';

class AiCoachSafetyReportQueueSection extends StatelessWidget {
  const AiCoachSafetyReportQueueSection({
    required this.reports,
    required this.reviewUnavailable,
    required this.busyReportIds,
    required this.onReview,
    super.key,
  });

  final List<AiCoachSafetyReport> reports;
  final bool reviewUnavailable;
  final Set<String> busyReportIds;
  final Future<void> Function(AiCoachSafetyReport report, String decision)
  onReview;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode != 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _copy(english, 'AI Coach safety reports', 'بلاغات سلامة AI Coach'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (reviewUnavailable)
          BilPearlMaterialCard(
            key: const Key('ai-coach-report-review-unavailable'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _copy(
                  english,
                  'AI Coach reports are not available on this server yet. The queue will appear after its reviewed backend migration is deployed.',
                  'بلاغات AI Coach غير متاحة على هذا الخادم بعد. ستظهر القائمة بعد نشر ترحيل الخادم المعتمد.',
                ),
              ),
            ),
          )
        else if (reports.isEmpty)
          Text(
            _copy(english, 'No AI Coach reports.', 'لا توجد بلاغات AI Coach.'),
          )
        else
          for (final report in reports) ...[
            _AiCoachSafetyReportCard(
              report: report,
              busy: busyReportIds.contains(report.id),
              onReview: (decision) => onReview(report, decision),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AiCoachSafetyReportCard extends StatelessWidget {
  const _AiCoachSafetyReportCard({
    required this.report,
    required this.busy,
    required this.onReview,
  });

  final AiCoachSafetyReport report;
  final bool busy;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode != 'ar';
    final palette = Theme.of(context).colorScheme;
    final reportedAt = report.reportedAt.toLocal();
    final reportedTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(reportedAt));
    final reviewedAt = report.reviewedAt?.toLocal();
    final reviewedTime = reviewedAt == null
        ? null
        : '${MaterialLocalizations.of(context).formatMediumDate(reviewedAt)} · '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(reviewedAt))}';
    return BilPearlMaterialCard(
      key: Key('ai-coach-safety-report-${report.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    report.isOpen
                        ? _copy(english, 'Open', 'مفتوح')
                        : _copy(english, 'Reviewed', 'تمت المراجعة'),
                  ),
                ),
                Text(
                  '${_copy(english, 'Reported', 'تاريخ البلاغ')}: '
                  '${MaterialLocalizations.of(context).formatMediumDate(reportedAt)} · $reportedTime',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_copy(english, 'Reason', 'السبب')}: ${_reasonCopy(english, report.reason)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${_copy(english, 'Language', 'اللغة')}: ${report.locale} · '
              '${_copy(english, 'Runtime', 'التشغيل')}: ${_runtimeCopy(english, report.runtime)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (report.isOpen)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surfaceContainerHighest.withValues(alpha: .48),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: palette.outlineVariant.withValues(alpha: .65),
                  ),
                ),
                child: SelectableText(
                  report.answerText!,
                  key: const Key('ai-coach-safety-report-answer'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              Text(
                '${_copy(english, 'Decision', 'القرار')}: ${_decisionCopy(english, report.decision)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (reviewedTime != null)
                Text(
                  '${_copy(english, 'Reviewed', 'تاريخ المراجعة')}: $reviewedTime',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                _copy(
                  english,
                  'Answer text was removed after review.',
                  'أزيل نص الإجابة بعد المراجعة.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (report.isOpen &&
                report.userNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surfaceContainerLow.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: palette.outlineVariant.withValues(alpha: .48),
                  ),
                ),
                child: SelectableText(
                  '${_copy(english, 'Optional note', 'ملاحظة اختيارية')}:\n${report.userNote}',
                  key: const Key('ai-coach-safety-report-optional-note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (report.isOpen) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: Key('ai-coach-report-no-violation-${report.id}'),
                    onPressed: busy ? null : () => onReview('no_violation'),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _copy(english, 'No violation', 'لا توجد مخالفة'),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: Key('ai-coach-report-confirm-issue-${report.id}'),
                    onPressed: busy
                        ? null
                        : () => onReview('confirmed_safety_issue'),
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                      _copy(
                        english,
                        'Confirm safety issue',
                        'تأكيد مشكلة سلامة',
                      ),
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _reasonCopy(bool english, String reason) => switch (reason) {
  'unsafe' => _copy(english, 'Unsafe or harmful', 'غير آمن أو ضار'),
  'offensive' => _copy(
    english,
    'Offensive or inappropriate',
    'مسيء أو غير مناسب',
  ),
  'medical_accuracy' => _copy(
    english,
    'Inaccurate or misleading information',
    'معلومة غير دقيقة أو مضللة',
  ),
  'privacy' => _copy(english, 'Privacy', 'الخصوصية'),
  _ => _copy(english, 'Other', 'سبب آخر'),
};

String _runtimeCopy(bool english, String runtime) => switch (runtime) {
  'cloud_personalized' => _copy(english, 'Cloud', 'سحابي'),
  'on_device' => _copy(english, 'On device', 'على الجهاز'),
  _ => _copy(english, 'Local fallback', 'بديل محلي'),
};

String _decisionCopy(bool english, String? decision) => switch (decision) {
  'confirmed_safety_issue' => _copy(
    english,
    'Safety issue confirmed',
    'تم تأكيد مشكلة السلامة',
  ),
  'no_violation' => _copy(english, 'No violation', 'لا توجد مخالفة'),
  _ => _copy(english, 'Unknown', 'غير معروف'),
};

String _copy(bool english, String en, String ar) => english ? en : ar;
