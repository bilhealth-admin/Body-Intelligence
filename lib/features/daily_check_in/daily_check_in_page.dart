import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/units/measurement_units.dart';
import '../../data/database/date_keys.dart';
import '../profile/providers/user_profile_provider.dart';
import '../profile/profile_locale_copy.dart';
import '../weight/providers/weight_provider.dart';
import '../../shared/widgets/actionable_error_state.dart';
import 'check_in_mutation_coordinator.dart';

class DailyCheckInPage extends ConsumerStatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  ConsumerState<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends ConsumerState<DailyCheckInPage> {
  double? weightKg;
  String measurementContext = 'unspecified';
  bool initialized = false;
  late final CheckInMutationCoordinator mutations;
  bool get saving => mutations.active == CheckInMutationKind.save;
  bool get deleting => mutations.active == CheckInMutationKind.delete;
  bool get skipping => mutations.active == CheckInMutationKind.skip;
  String? progressPhotoPath;
  bool clearProgressPhoto = false;

  String tr(String en, String ar) => profileLocaleText(context, en, ar);

  @override
  void initState() {
    super.initState();
    mutations = CheckInMutationCoordinator(
      onStateChanged: (_) {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> pickProgressPhoto() async {
    if (saving || deleting || skipping) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Progress photo', 'صورة التقدّم'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.pop(sheetContext, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(tr('Take a private photo', 'التقط صورة خاصة')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(tr('Choose from device', 'اختر من الجهاز')),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (picked == null) return;
      final documents = await getApplicationDocumentsDirectory();
      final folder = Directory(
        p.join(documents.path, 'bil', 'progress_photos'),
      );
      await folder.create(recursive: true);
      final extension = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final target = File(
        p.join(
          folder.path,
          'weight_${DateTime.now().microsecondsSinceEpoch}$extension',
        ),
      );
      await File(picked.path).copy(target.path);
      if (!mounted) return;
      setState(() {
        progressPhotoPath = target.path;
        clearProgressPhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Camera is unavailable here. Choose a photo from the device.',
              'الكاميرا غير متاحة هنا. اختر صورة محفوظة على الجهاز.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> enterWeight(MeasurementSystem system) async {
    if (saving || deleting || skipping) return;
    final current = weightKg == null
        ? null
        : UnitConverter.weightFromKg(weightKg!, system);
    final controller = TextEditingController(
      text: current?.toStringAsFixed(1) ?? '',
    );
    final entered = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Enter weight', 'أدخل الوزن')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: UnitConverter.weightUnit(system),
            helperText: tr(
              'Use the value shown on your scale.',
              'استخدم القيمة الظاهرة على الميزان.',
            ),
          ),
          onSubmitted: (value) {
            final parsed = double.tryParse(value.replaceAll(',', '.'));
            Navigator.pop(dialogContext, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(tr('Apply', 'تطبيق')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null) return;
    final kilograms = UnitConverter.weightToKg(entered, system);
    if (!kilograms.isFinite || kilograms < 20 || kilograms > 500) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Enter a valid weight.', 'أدخل وزنًا صالحًا.')),
        ),
      );
      return;
    }
    setState(() => weightKg = kilograms);
  }

  Future<void> save() async {
    final value = weightKg;
    if (value == null || mutations.busy) return;
    final outcome = await mutations.run(CheckInMutationKind.save, () async {
      await ref
          .read(weightRepositoryProvider)
          .addWeight(
            value,
            measurementContext: measurementContext,
            progressPhotoPath: progressPhotoPath,
            clearProgressPhoto: clearProgressPhoto,
          );
    });
    if (outcome == CheckInMutationOutcome.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Check-in saved. Consistent conditions make your trend clearer.',
              'تم حفظ القياس. ثبات ظروف القياس يجعل اتجاهك أوضح.',
            ),
          ),
        ),
      );
      context.go('/dashboard');
    } else if (outcome == CheckInMutationOutcome.failure) {
      if (!mounted) return;
      _showStorageFailure();
    }
  }

  Future<void> skipToday() async {
    if (mutations.busy) return;
    final outcome = await mutations.run(CheckInMutationKind.skip, () async {
      await ref
          .read(preferencesRepositoryProvider)
          .set('weightReminderSkippedDay', dayKeyFor(DateTime.now()));
    });
    if (outcome == CheckInMutationOutcome.success) {
      if (mounted) context.go('/dashboard');
    } else if (outcome == CheckInMutationOutcome.failure && mounted) {
      _showStorageFailure();
    }
  }

  Future<void> deleteToday(int id) async {
    if (mutations.busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("Delete today's weight?", 'حذف وزن اليوم؟')),
        content: Text(
          tr(
            'This removes today’s check-in from trend calculations.',
            'سيؤدي ذلك إلى إزالة قياس اليوم من حسابات الاتجاه.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final outcome = await mutations.run(CheckInMutationKind.delete, () async {
        await ref.read(weightRepositoryProvider).deleteWeight(id);
      });
      if (outcome == CheckInMutationOutcome.success) {
        if (mounted) {
          setState(() {
            initialized = false;
          });
        }
      } else if (outcome == CheckInMutationOutcome.failure && mounted) {
        _showStorageFailure();
      }
    }
  }

  void _showStorageFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'The check-in could not be changed on this device. Try again.',
            'تعذر تعديل القياس على هذا الجهاز. حاول مرة أخرى.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayWeightProvider);
    final profileState = ref.watch(userProfileProvider);
    final systemState = ref.watch(measurementSystemProvider);
    final loading =
        today.isLoading || profileState.isLoading || systemState.isLoading;
    final hasError =
        today.hasError || profileState.hasError || systemState.hasError;
    final profile = profileState.value;
    final system = systemState.value;
    final existing = today.value;
    if (!initialized && !loading && !hasError && system != null) {
      initialized = true;
      weightKg = existing?.weight ?? profile?.currentWeight;
      measurementContext = existing?.measurementContext ?? 'unspecified';
      progressPhotoPath = existing?.progressPhotoPath;
    }
    final canonical = weightKg ?? profile?.currentWeight;
    final display = canonical == null
        ? null
        : UnitConverter.weightFromKg(canonical, system!);

    return PopScope(
      canPop: !saving && !deleting && !skipping,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(tr('Daily check-in', 'القياس اليومي')),
          leading: IconButton(
            tooltip: tr('Not now', 'ليس الآن'),
            onPressed: saving || deleting || skipping
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : hasError || system == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ActionableErrorState(
                      title: tr(
                        'Weight data could not be loaded.',
                        'تعذر تحميل بيانات الوزن.',
                      ),
                      onRetry: () {
                        ref.invalidate(todayWeightProvider);
                        ref.invalidate(userProfileProvider);
                        ref.invalidate(measurementSystemProvider);
                      },
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 104),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.monitor_weight_outlined,
                            size: 44,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('Good morning', 'صباح الخير'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('Shall we log your weight?', 'نسجّل وزنك؟'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            existing == null
                                ? tr(
                                    'A quick check-in for a clearer trend.',
                                    'تسجيل سريع لاتجاه أوضح.',
                                  )
                                : '${tr('Last measurement', 'آخر قياس')}: ${display!.toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 22,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton.outlined(
                                  onPressed:
                                      weightKg == null ||
                                          saving ||
                                          deleting ||
                                          skipping
                                      ? null
                                      : () => setState(
                                          () => weightKg = (weightKg! - 0.1)
                                              .clamp(20, 500),
                                        ),
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: saving || deleting || skipping
                                        ? null
                                        : () => enterWeight(system),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            display?.toStringAsFixed(1) ?? '—',
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          Text(
                                            '${UnitConverter.weightUnit(system)} · ${tr('tap to enter', 'اضغط للإدخال')}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton.outlined(
                                  onPressed:
                                      weightKg == null ||
                                          saving ||
                                          deleting ||
                                          skipping
                                      ? null
                                      : () => setState(
                                          () => weightKg = (weightKg! + 0.1)
                                              .clamp(20, 500),
                                        ),
                                  icon: const Icon(Icons.add_rounded),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ProgressPhotoCard(
                            path: progressPhotoPath,
                            onPick: pickProgressPhoto,
                            onRemove:
                                progressPhotoPath == null ||
                                    saving ||
                                    deleting ||
                                    skipping
                                ? null
                                : () => setState(() {
                                    progressPhotoPath = null;
                                    clearProgressPhoto = true;
                                  }),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in <(String, String, String)>[
                                ('morning', 'After waking', 'بعد الاستيقاظ'),
                                (
                                  'afterBathroom',
                                  'After bathroom',
                                  'بعد الحمام',
                                ),
                                (
                                  'differentConditions',
                                  'Different time',
                                  'وقت مختلف',
                                ),
                              ])
                                ChoiceChip(
                                  selected: measurementContext == option.$1,
                                  label: Text(tr(option.$2, option.$3)),
                                  onSelected: saving || deleting || skipping
                                      ? null
                                      : (_) => setState(
                                          () => measurementContext = option.$1,
                                        ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 58,
                            child: FilledButton.icon(
                              key: const ValueKey('daily-check-in-save'),
                              onPressed:
                                  saving ||
                                      deleting ||
                                      skipping ||
                                      weightKg == null
                                  ? null
                                  : save,
                              icon: saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_circle_outline_rounded,
                                    ),
                              label: Text(
                                existing == null
                                    ? weightKg == null
                                          ? tr('Enter weight', 'أدخل الوزن')
                                          : '${tr('Record', 'تسجيل')} ${display!.toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}'
                                    : tr(
                                        "Update today's weight",
                                        'تحديث وزن اليوم',
                                      ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: saving || deleting || skipping
                                ? null
                                : skipToday,
                            child: skipping
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(tr('Later', 'لاحقًا')),
                          ),
                          if (existing != null)
                            TextButton.icon(
                              onPressed: saving || deleting || skipping
                                  ? null
                                  : () => deleteToday(existing.id),
                              icon: deleting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              label: Text(
                                tr("Delete today's weight", 'حذف وزن اليوم'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProgressPhotoCard extends StatelessWidget {
  const _ProgressPhotoCard({
    required this.path,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final available = file?.existsSync() ?? false;
    return Container(
      key: const Key('daily-check-in-progress-photo'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (available)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(file!, fit: BoxFit.cover),
              ),
            )
          else
            const SizedBox(
              height: 92,
              child: Icon(Icons.add_a_photo_outlined, size: 38),
            ),
          const SizedBox(height: 10),
          Text(
            profileLocaleText(
              context,
              'Private progress photo',
              'صورة تقدّم خاصة',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            profileLocaleText(
              context,
              'Linked to today’s measurement and kept on this device.',
              'ترتبط بقياس اليوم وتبقى على جهازك.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: Icon(
                    available
                        ? Icons.edit_outlined
                        : Icons.add_a_photo_outlined,
                  ),
                  label: Text(
                    available
                        ? profileLocaleText(context, 'Change', 'تغيير')
                        : profileLocaleText(context, 'Add photo', 'إضافة صورة'),
                  ),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: profileLocaleText(
                    context,
                    'Remove photo',
                    'إزالة الصورة',
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
