import 'package:flutter/material.dart';

import '../../../shared/widgets/bil_modal_bottom_sheet.dart';
import '../intelligence_locale_copy.dart';

@immutable
class AiCoachAnswerReportDraft {
  const AiCoachAnswerReportDraft({
    required this.reason,
    required this.explicitConsentAccepted,
    this.optionalNote,
  });

  final String reason;
  final bool explicitConsentAccepted;
  final String? optionalNote;
}

Future<void> showAiCoachAnswerReportSheet(
  BuildContext context,
  ValueChanged<AiCoachAnswerReportDraft> onReport,
) async {
  String? reason;
  var consentAccepted = false;
  var privacyDetailsExpanded = false;
  final noteController = TextEditingController();
  try {
    final draft = await showBilModalBottomSheet<AiCoachAnswerReportDraft>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final english = Localizations.localeOf(context).languageCode != 'ar';
          final scheme = Theme.of(context).colorScheme;
          final options = <(String, String, String, IconData)>[
            (
              'unsafe',
              'Unsafe or harmful',
              'غير آمن أو ضار',
              Icons.health_and_safety_outlined,
            ),
            (
              'medical_accuracy',
              'Inaccurate or misleading information',
              'معلومة غير دقيقة أو مضللة',
              Icons.fact_check_outlined,
            ),
            (
              'offensive',
              'Offensive or inappropriate',
              'مسيء أو غير مناسب',
              Icons.shield_outlined,
            ),
            ('other', 'Other', 'سبب آخر', Icons.more_horiz_rounded),
          ];
          final canSubmit = reason != null && consentAccepted;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  scheme.surface.withValues(alpha: .98),
                  scheme.surfaceContainerLow.withValues(alpha: .96),
                  scheme.surface.withValues(alpha: .99),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .42),
                  width: .8,
                ),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.surfaceContainerHighest.withValues(
                                alpha: .9,
                              ),
                              scheme.surfaceContainerLow.withValues(alpha: .7),
                            ],
                          ),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: .56),
                          ),
                        ),
                        child: Icon(
                          Icons.outlined_flag_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          intelligenceText(
                            context,
                            'Report this AI response',
                            'الإبلاغ عن إجابة AI Coach',
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 54),
                    child: Text(
                      intelligenceText(
                        context,
                        'Choose one reason. A note is optional.',
                        'اختر سببًا واحدًا. الملاحظة اختيارية.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final option in options) ...[
                    _ReportReasonOption(
                      key: Key('ai-coach-report-reason-${option.$1}'),
                      value: option.$1,
                      title: english ? option.$2 : option.$3,
                      icon: option.$4,
                      selected: reason == option.$1,
                      onTap: () => setSheetState(() => reason = option.$1),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (reason == 'other') ...[
                    const SizedBox(height: 2),
                    TextField(
                      key: const Key('ai-coach-report-optional-note'),
                      controller: noteController,
                      maxLength: 1000,
                      maxLines: 3,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: intelligenceText(
                          context,
                          'Optional note for moderators',
                          'ملاحظة اختيارية للمشرفين',
                        ),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: scheme.surface.withValues(alpha: .62),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: .48),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: .48),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      12,
                      14,
                      10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: .34,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: .48),
                        width: .8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(top: 2),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                intelligenceText(
                                  context,
                                  'Only your chosen answer and any note you add go to authorized BIL moderators. The answer may include health information.',
                                  'تُرسل الإجابة التي تختارها وأي ملاحظة تضيفها إلى مشرفي BIL المخولين فقط. وقد تتضمن الإجابة معلومات صحية.',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        TextButton(
                          key: const Key('ai-coach-report-privacy-details'),
                          onPressed: () => setSheetState(
                            () => privacyDetailsExpanded =
                                !privacyDetailsExpanded,
                          ),
                          style: TextButton.styleFrom(
                            alignment: AlignmentDirectional.centerStart,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                intelligenceText(
                                  context,
                                  'Details',
                                  'التفاصيل',
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedRotation(
                                turns: privacyDetailsExpanded ? .5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 28,
                              bottom: 8,
                            ),
                            child: Text(
                              intelligenceText(
                                context,
                                'The selected answer, reason, language, AI runtime, and any optional note are shared only for safety review. Your question, other messages, and health profile are not included.',
                                'تُشارك الإجابة المختارة والسبب واللغة ونوع تشغيل الذكاء الاصطناعي وأي ملاحظة اختيارية لمراجعة السلامة فقط. لا يُرسل سؤالك أو بقية المحادثة أو ملفك الصحي.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                          crossFadeState: privacyDetailsExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 160),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              key: const Key('ai-coach-report-consent'),
                              value: consentAccepted,
                              onChanged: (value) => setSheetState(
                                () => consentAccepted = value ?? false,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setSheetState(
                                  () => consentAccepted = !consentAccepted,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    intelligenceText(
                                      context,
                                      'I agree to send this answer for safety review.',
                                      'أوافق على إرسال هذه الإجابة لمراجعة السلامة.',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurface,
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('ai-coach-confirm-report'),
                    onPressed: canSubmit
                        ? () => Navigator.of(sheetContext).pop(
                            AiCoachAnswerReportDraft(
                              reason: reason!,
                              explicitConsentAccepted: consentAccepted,
                              optionalNote:
                                  reason == 'other' &&
                                      noteController.text.trim().isNotEmpty
                                  ? noteController.text.trim()
                                  : null,
                            ),
                          )
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: canSubmit
                          ? Colors.white
                          : scheme.onSurface,
                      disabledBackgroundColor: scheme.surfaceContainerHighest,
                      disabledForegroundColor: scheme.onSurface,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: Icon(
                      Icons.outlined_flag_rounded,
                      color: canSubmit ? Colors.white : scheme.onSurface,
                    ),
                    label: Text(
                      intelligenceText(
                        context,
                        'Submit Report',
                        'إرسال البلاغ',
                      ),
                      style: TextStyle(
                        color: canSubmit ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('ai-coach-cancel-report'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (draft != null) onReport(draft);
  } finally {
    noteController.dispose();
  }
}

class _ReportReasonOption extends StatelessWidget {
  const _ReportReasonOption({
    required this.value,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String value;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: .58)
        : scheme.outlineVariant.withValues(alpha: .5);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: Key('ai-coach-report-reason-tap-$value'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: selected
                    ? [
                        scheme.primaryContainer.withValues(alpha: .38),
                        scheme.surface.withValues(alpha: .88),
                      ]
                    : [
                        scheme.surface.withValues(alpha: .76),
                        scheme.surfaceContainerLow.withValues(alpha: .72),
                      ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.1 : .8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? scheme.primaryContainer.withValues(alpha: .64)
                        : scheme.surfaceContainerHighest.withValues(alpha: .68),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: .36),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: .68),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
