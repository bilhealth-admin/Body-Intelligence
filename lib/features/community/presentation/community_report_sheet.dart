import 'package:flutter/material.dart';

import '../../../shared/widgets/bil_modal_bottom_sheet.dart';
import '../../../shared/widgets/bil_report_reason_option.dart';
import '../data/community_repository.dart';
import '../channels/presentation/community_channels_copy.dart';
import 'community_copy.dart';
import 'community_report_receipt_copy.dart';

/// Returns true only for a newly stored report. A duplicate keeps the prior
/// report and cannot claim that the new note was added. Owner/visit validation
/// remains with the caller, including before any feedback is displayed.
Future<bool> submitCommunityReportWithReceipt({
  required BuildContext context,
  required Future<void> Function() send,
  required VoidCallback checkOwner,
}) async {
  try {
    await send();
    checkOwner();
    return true;
  } on CommunityReportAlreadyPending {
    checkOwner();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              CommunityReportReceiptCopy.alreadyReported,
              'سبق أن أبلغت عن هذا العنصر. لم تُضف ملاحظتك الجديدة.',
            ),
          ),
        ),
      );
    }
    return false;
  }
}

enum CommunityReportTarget { post, comment, reply, profile, message, circle }

@immutable
class CommunityReportDraft {
  const CommunityReportDraft(this.category, this.note);
  final String category;
  final String note;
  String get reason => note.isEmpty ? category : '$category: $note';
}

/// Only returns an explicit confirmation; callers retain owner/target checks.
Future<CommunityReportDraft?> showCommunityReportSheet(
  BuildContext context, {
  required CommunityReportTarget target,
  Widget Function(Widget child)? guard,
  bool allowNote = true,
}) async {
  final note = TextEditingController();
  String? category;
  var confirmed = false;
  try {
    return await showBilModalBottomSheet<CommunityReportDraft>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final content = StatefulBuilder(
          builder: (context, update) {
            final scheme = Theme.of(context).colorScheme;
            final title = switch (target) {
              CommunityReportTarget.circle => communityText(
                context,
                'Report circle',
                'الإبلاغ عن الدائرة',
              ),
              CommunityReportTarget.post => communityText(
                context,
                'Report post',
                'الإبلاغ عن المنشور',
              ),
              CommunityReportTarget.comment => communityText(
                context,
                'Report comment',
                'الإبلاغ عن التعليق',
              ),
              CommunityReportTarget.reply => communityText(
                context,
                'Report reply',
                'الإبلاغ عن الرد',
              ),
              CommunityReportTarget.profile => communityText(
                context,
                'Report member',
                'الإبلاغ عن العضو',
              ),
              CommunityReportTarget.message => CommunityChannelsCopy.text(
                context,
                CommunityChannelsCopyKey.reportMessage,
              ),
            };
            const options = <(String, CommunityChannelsCopyKey, IconData)>[
              (
                'spam',
                CommunityChannelsCopyKey.reportSpam,
                Icons.mark_email_unread_outlined,
              ),
              (
                'harassment',
                CommunityChannelsCopyKey.reportHarassment,
                Icons.person_off_outlined,
              ),
              (
                'hate_speech',
                CommunityChannelsCopyKey.reportHate,
                Icons.shield_outlined,
              ),
              (
                'other',
                CommunityChannelsCopyKey.reportOther,
                Icons.more_horiz_rounded,
              ),
            ];
            final noteValid = note.text.trim().runes.length <= 400;
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
                padding: EdgeInsetsDirectional.fromSTEB(
                  20,
                  10,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                scheme.surfaceContainerHighest.withValues(
                                  alpha: .9,
                                ),
                                scheme.surfaceContainerLow.withValues(
                                  alpha: .7,
                                ),
                              ],
                            ),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: .56,
                              ),
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
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final option in options) ...[
                      BilReportReasonOption(
                        key: Key('community-report-reason-${option.$1}'),
                        tapKey: Key('community-report-reason-tap-${option.$1}'),
                        value: option.$1,
                        title: CommunityChannelsCopy.text(context, option.$2),
                        icon: option.$3,
                        selected: category == option.$1,
                        onTap: () => update(() => category = option.$1),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (allowNote) ...[
                      TextField(
                        key: const Key('community-report-note'),
                        controller: note,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 400,
                        onChanged: (_) => update(() {}),
                        decoration: InputDecoration(
                          labelText: communityText(
                            context,
                            'Optional note for moderators',
                            'ملاحظة اختيارية للمشرفين',
                          ),
                          errorText: noteValid
                              ? null
                              : communityText(
                                  context,
                                  'Keep the note within 400 characters.',
                                  'اجعل الملاحظة في حدود ٤٠٠ حرف.',
                                ),
                          filled: true,
                          fillColor: scheme.surface.withValues(alpha: .62),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      communityText(
                        context,
                        'The reported content and your reason will be reviewed by moderators. Reporting does not block this member.',
                        'سيراجع المشرفون المحتوى المبلّغ عنه وسبب البلاغ. إرسال البلاغ لا يحظر العضو.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('community-report-submit'),
                      onPressed: category == null || !noteValid || confirmed
                          ? null
                          : () {
                              if (confirmed) return;
                              confirmed = true;
                              Navigator.of(sheetContext).pop(
                                CommunityReportDraft(
                                  category!,
                                  allowNote ? note.text.trim() : '',
                                ),
                              );
                            },
                      icon: const Icon(Icons.outlined_flag_rounded),
                      label: Text(
                        communityText(context, 'Send report', 'إرسال البلاغ'),
                      ),
                    ),
                    TextButton(
                      key: const Key('community-report-cancel'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(
                        CommunityChannelsCopy.text(
                          context,
                          CommunityChannelsCopyKey.cancel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return guard?.call(content) ?? content;
      },
    );
  } finally {
    note.dispose();
  }
}
