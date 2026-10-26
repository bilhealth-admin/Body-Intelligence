import '../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/bil_pearl_material.dart';
import '../intelligence_center/intelligence_locale_copy.dart';
import '../intelligence_center/services/coach_memory_repository.dart';
import '../profile/providers/user_profile_provider.dart';

final coachMemorySyncRepositoryProvider = Provider(
  (ref) => CoachMemoryRepository(
    preferences: ref.watch(preferencesRepositoryProvider),
  ),
);
final coachMemorySyncIssuesProvider = FutureProvider(
  (ref) => ref.watch(coachMemorySyncRepositoryProvider).readSyncIssues(),
);

class CoachMemorySyncReviewPanel extends ConsumerStatefulWidget {
  const CoachMemorySyncReviewPanel({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  ConsumerState<CoachMemorySyncReviewPanel> createState() =>
      _CoachMemorySyncReviewPanelState();
}

class _CoachMemorySyncReviewPanelState
    extends ConsumerState<CoachMemorySyncReviewPanel> {
  bool _busy = false;
  String t(String en, String ar) => intelligenceText(context, en, ar);
  @override
  Widget build(BuildContext context) => ref
      .watch(coachMemorySyncIssuesProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (issues) => issues.isEmpty
            ? const SizedBox.shrink()
            : BilPearlMaterialCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t('Coach memory sync', 'مزامنة ذاكرة المدرب'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'Some memories need synchronization or a choice between device versions. Your local facts are kept until you review.',
                          'تحتاج بعض المعلومات إلى مزامنة أو اختيار بين نسختي الجهاز والسحابة. تُحفظ معلوماتك المحلية إلى أن تراجعها.',
                        ),
                      ),
                      if (_busy) const BilFeatureWelcomeStatus(),
                      for (final issue in issues.where(
                        (i) => i.state == 'conflict',
                      ))
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _review(issue.id),
                          icon: const Icon(Icons.compare_arrows_rounded),
                          label: Text(
                            issue.deleted
                                ? t(
                                    'Review a pending memory deletion',
                                    'مراجعة حذف معلومة معلّق',
                                  )
                                : t(
                                    'Compare memory versions',
                                    'مقارنة نسختي المعلومة',
                                  ),
                          ),
                        ),
                      if (issues.any((i) => i.state == 'pending'))
                        TextButton.icon(
                          onPressed: _busy ? null : _retry,
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(
                            t('Retry synchronization', 'إعادة محاولة المزامنة'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      );

  Future<void> _retry() => _perform((repo, _) async => repo.mergeFromCloud());

  Future<void> _review(String id) => _perform((repo, stillCurrent) async {
    final review = await repo.reviewSyncConflict(id);
    try {
      if (!mounted || !stillCurrent()) return;
      final useCloud = await showDialog<bool>(
        context: context,
        builder: (dialog) => BilPearlMaterialAlertDialog(
          scrollable: true,
          title: Text(t('Compare memory versions', 'مقارنة نسختي المعلومة')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('On this device', 'على هذا الجهاز'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                review.local?['text'] as String? ??
                    t('Deleted on this device', 'محذوفة من هذا الجهاز'),
              ),
              if (review.local?['updatedAt'] != null)
                Text(
                  '${review.local!['updatedAt']}',
                  textDirection: TextDirection.ltr,
                ),
              const Divider(height: 24),
              Text(
                t('In your cloud memory', 'في ذاكرتك السحابية'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                review.remote?['text'] as String? ??
                    t('No active cloud version', 'لا توجد نسخة سحابية نشطة'),
              ),
              if (review.remoteVersion != null)
                Text(review.remoteVersion!, textDirection: TextDirection.ltr),
              const SizedBox(height: 12),
              Text(
                t(
                  'Choose only after reviewing both versions. A newer change requires another review.',
                  'اختر بعد مراجعة النسختين. أي تغيير أحدث يتطلب مراجعة جديدة.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(t('Cancel', 'إلغاء')),
            ),
            if (!review.remoteDeleted || review.local == null)
              OutlinedButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(
                  review.local == null
                      ? t('Confirm cloud deletion', 'تأكيد الحذف السحابي')
                      : t('Use this device version', 'استخدام نسخة هذا الجهاز'),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(
                review.remote == null
                    ? t('Use cloud deletion', 'اعتماد الحذف السحابي')
                    : t('Use cloud version', 'استخدام النسخة السحابية'),
              ),
            ),
          ],
        ),
      );
      if (useCloud == null || !stillCurrent()) return;
      final verified = await repo.resolveSyncConflict(
        review,
        useCloud: useCloud,
        isCurrentOwner: stillCurrent,
      );
      if (!mounted || !stillCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? t(
                    'Memory choice saved and verified.',
                    'تم حفظ اختيار الذاكرة والتحقق منه.',
                  )
                : t(
                    'Your choice is saved locally. Cloud synchronization is still pending.',
                    'حُفظ اختيارك محليًا. ما زالت المزامنة السحابية معلّقة.',
                  ),
          ),
        ),
      );
    } finally {
      await review.dispose();
    }
  });

  Future<void> _perform(
    Future<void> Function(CoachMemoryRepository, bool Function()) action,
  ) async {
    if (_busy) return;
    final preferences = ref.read(preferencesRepositoryProvider);
    final owner = preferences.localOwnerId;
    bool stillCurrent() =>
        mounted &&
        identical(preferences, ref.read(preferencesRepositoryProvider)) &&
        preferences.localOwnerId == owner;
    setState(() => _busy = true);
    try {
      await action(ref.read(coachMemorySyncRepositoryProvider), stillCurrent);
    } on Object {
      if (mounted && stillCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Could not verify this memory choice. Refresh and review again.',
                'تعذّر التحقق من اختيار الذاكرة. حدّث الصفحة وراجع مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(coachMemorySyncIssuesProvider);
        widget.onChanged();
      }
    }
  }
}
