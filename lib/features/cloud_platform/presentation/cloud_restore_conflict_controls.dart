import '../../../shared/widgets/bil_pearl_material.dart';
import '../../../shared/widgets/bil_glass_press_feedback.dart';
import '../providers/cloud_restore_conflict_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cloud_manual_sync_status_provider.dart';
import '../services/cloud_nutrition_snapshot_codec.dart';

class CloudRestoreConflictControls extends ConsumerStatefulWidget {
  const CloudRestoreConflictControls({super.key});
  @override
  ConsumerState<CloudRestoreConflictControls> createState() =>
      _ConflictControlsState();
}

class _ConflictControlsState
    extends ConsumerState<CloudRestoreConflictControls> {
  bool busy = false;
  String? message;
  String tr(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  Widget build(BuildContext context) {
    final syncing = ref.watch(cloudManualSyncStatusProvider).isSyncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const BilGlassPressFeedback(
            child: Icon(Icons.compare_arrows),
          ),
          title: Text(
            tr('Review backup conflicts', 'مراجعة تعارضات النسخة الاحتياطية'),
          ),
          subtitle: Text(
            tr(
              'Choose a version; local changes remain saved until your decision.',
              'اختر النسخة؛ تبقى تعديلاتك المحلية محفوظة حتى قرارك.',
            ),
          ),
          onTap: busy || syncing ? null : _review,
          key: const Key('cloud-restore-review-conflicts'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(liveRegion: true, child: Text(message!)),
          ),
      ],
    );
  }

  Future<void> _review() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final service = ref.read(cloudRestoreConflictServiceProvider);
      final choices = await service.read();
      if (!mounted) return;
      setState(() => busy = false);
      if (choices.isEmpty) {
        setState(
          () => message = tr(
            'No unresolved conflicts.',
            'لا توجد تعارضات معلقة.',
          ),
        );
        return;
      }
      for (final choice in choices) {
        if (!mounted) return;
        final keep = await showDialog<bool>(
          context: context,
          builder: (context) => BilPearlMaterialAlertDialog(
            scrollable: true,
            title: Text(tr('Choose the saved version', 'اختر النسخة المحفوظة')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_describe(choice.local)),
                const SizedBox(height: 12),
                Text(tr('Cloud: ', 'السحابة: ') + _describe(choice.remote)),
                const SizedBox(height: 16),
                Text(
                  tr(
                    'Your local version is retained in recovery history before replacement.',
                    'تُحفظ نسختك المحلية في سجل الاستعادة قبل استبدالها.',
                  ),
                ),
              ],
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Cancel', 'إلغاء')),
              ),
              TextButton(
                key: const Key('restore-keep-local'),
                onPressed: choice.remote.deleted
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(
                  tr('Keep this device’s version', 'الاحتفاظ بنسخة هذا الجهاز'),
                ),
              ),
              FilledButton(
                key: const Key('restore-use-cloud'),
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Use cloud version', 'استخدام نسخة السحابة')),
              ),
            ],
          ),
        );
        if (keep == null || !mounted) return;
        setState(() => busy = true);
        final result = await service.resolve(choice, keepLocal: keep);
        if (!mounted) return;
        if (!result.completed) {
          setState(
            () => message = tr(
              'The choice is saved; synchronization still needs a retry or review.',
              'حُفظ الاختيار؛ ما زالت المزامنة تحتاج إعادة محاولة أو مراجعة.',
            ),
          );
          return;
        }
        setState(() => busy = false);
      }
      if (mounted) {
        setState(
          () => message = tr(
            'Saved versions verified.',
            'تم التحقق من النسخ المحفوظة.',
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => message = tr(
            'Unable to complete the review. Refresh and try again; your data remains saved.',
            'تعذر إكمال المراجعة. حدّث وحاول مجددًا؛ بياناتك محفوظة.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _describe(CloudNutritionSnapshot? snapshot) {
    if (snapshot == null || snapshot.deleted) {
      return tr('Deleted record', 'سجل محذوف');
    }
    final data = snapshot.data;
    if (snapshot.type == 'food') {
      return ((data['food'] as Map?)?['name'] ?? tr('Food', 'غذاء')).toString();
    }
    if (snapshot.type == 'recipe') {
      return (((data['recipe'] as Map?)?['recipe'] as Map?)?['name'] ??
              tr('Recipe', 'وصفة'))
          .toString();
    }
    if (snapshot.type == 'meal') {
      return '${(data['meal'] as Map?)?['dayKey']} · ${(data['meal'] as Map?)?['name']}';
    }
    final values = data['values'] as Map?;
    return '${tr('Nutrition goals', 'أهداف التغذية')} · ${values?['goal.calories'] ?? '—'} kcal';
  }
}
