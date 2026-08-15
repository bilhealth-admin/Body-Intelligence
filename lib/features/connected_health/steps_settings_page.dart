import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../data/repositories/preferences_repository.dart';
import '../profile/providers/user_profile_provider.dart';
import 'providers/connected_health_provider.dart';

const stepGoalMinimum = 1000;
const stepGoalMaximum = 100000;

@visibleForTesting
int? parseStoredStepGoal(String? raw) {
  if (raw == null || !RegExp(r'^\d+$').hasMatch(raw.trim())) return null;
  final value = int.tryParse(raw.trim());
  if (value == null || value < stepGoalMinimum || value > stepGoalMaximum) {
    return null;
  }
  return value;
}

@visibleForTesting
String? parseStoredStepSource(String? raw) =>
    const {'device', 'watch', 'none'}.contains(raw) ? raw : null;

@visibleForTesting
final class StepsPreferenceSnapshot {
  const StepsPreferenceSnapshot({required this.source, required this.goal});
  final String? source;
  final int? goal;
}

/// Typed boundary for step preferences. Invalid values cannot enter storage
/// through this feature, while legacy/corrupt values fail closed on read.
@visibleForTesting
final class StepsPreferencesStore {
  StepsPreferencesStore(this._repository);
  final PreferencesRepository _repository;

  Future<StepsPreferenceSnapshot> load() async {
    final values = await Future.wait([
      _repository.get('steps.source'),
      _repository.get('steps.dailyGoal'),
    ]);
    return StepsPreferenceSnapshot(
      source: parseStoredStepSource(values[0]),
      goal: parseStoredStepGoal(values[1]),
    );
  }

  Future<void> saveSource(String value) {
    if (parseStoredStepSource(value) == null) {
      throw ArgumentError.value(value, 'value', 'unsupported step source');
    }
    return _repository.set('steps.source', value);
  }

  Future<void> saveGoal(int value) {
    if (parseStoredStepGoal('$value') != value) {
      throw ArgumentError.value(value, 'value', 'invalid step goal');
    }
    return _repository.set('steps.dailyGoal', '$value');
  }
}

class StepsSettingsPage extends ConsumerStatefulWidget {
  const StepsSettingsPage({super.key});

  @override
  ConsumerState<StepsSettingsPage> createState() => _StepsSettingsPageState();
}

class _StepsSettingsPageState extends ConsumerState<StepsSettingsPage> {
  String? source;
  int? goal;
  bool loading = true;
  bool saving = false;
  Object? loadError;

  String t(String key) {
    final code = Localizations.localeOf(context).languageCode;
    return _stepsCopy[code]?[key] ?? context.strings.text(key);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final values = await StepsPreferencesStore(
        ref.read(preferencesRepositoryProvider),
      ).load();
      if (!mounted) return;
      setState(() {
        source = values.source;
        goal = values.goal;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = error;
      });
    }
  }

  Future<void> selectSource(String value) async {
    if (saving || value == source) return;
    setState(() => saving = true);
    try {
      await StepsPreferencesStore(
        ref.read(preferencesRepositoryProvider),
      ).saveSource(value);
      if (mounted) setState(() => source = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Could not save step settings. Try again.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editGoal() async {
    if (saving) return;
    final controller = TextEditingController(text: goal?.toString() ?? '');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var dialogSaving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: !dialogSaving,
            child: AlertDialog(
              title: Text(t('Daily step goal')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    enabled: !dialogSaving,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t('Steps'),
                      errorText: error,
                      helperText: '$stepGoalMinimum–$stepGoalMaximum',
                    ),
                  ),
                  if (dialogSaving)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(t('Cancel')),
                ),
                FilledButton(
                  onPressed: dialogSaving
                      ? null
                      : () async {
                          final parsed = parseStoredStepGoal(controller.text);
                          if (parsed == null) {
                            setDialogState(
                              () => error = t(
                                'Enter a whole-number goal from 1000 to 100000.',
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            dialogSaving = true;
                            error = null;
                          });
                          if (mounted) setState(() => saving = true);
                          try {
                            await StepsPreferencesStore(
                              ref.read(preferencesRepositoryProvider),
                            ).saveGoal(parsed);
                            if (!mounted) return;
                            setState(() => goal = parsed);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                dialogSaving = false;
                                error = t(
                                  'Could not save step settings. Try again.',
                                );
                              });
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(t('Save')),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Let the dialog route finish its reverse transition before disposing the
    // controller still referenced by its outgoing TextField.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(connectedHealthProvider);
    final snapshot = health.value;
    final watchAvailable =
        snapshot?.deviceVerified == true &&
        snapshot!.availableSources.any((value) {
          final normalized = value.toLowerCase();
          return normalized.contains('watch') || normalized.contains('wear');
        });
    final watchStatus = health.isLoading
        ? t('Checking connected sources…')
        : health.hasError
        ? t('Connected sources could not be checked.')
        : watchAvailable
        ? t('A connected watch source is available.')
        : t('No connected watch source is available.');
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: saving
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/connected-health');
                    }
                  },
          ),
          title: Text(t('Steps')),
        ),
        body: loading
            ? Center(
                child: Semantics(
                  label: t('Loading step settings'),
                  child: const CircularProgressIndicator(),
                ),
              )
            : loadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('Step settings could not be loaded.')),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(t('Retry')),
                    ),
                  ],
                ),
              )
            : ListView(
                children: [
                  _Section(t('Choose a source')),
                  RadioGroup<String>(
                    groupValue: source,
                    onChanged: (value) {
                      if (!saving && value != null) selectSource(value);
                    },
                    child: Column(
                      children: [
                        RadioListTile(
                          value: 'device',
                          title: Text(t('Phone motion and health source')),
                          subtitle: Text(
                            t(
                              'Uses a source only after you authorize it on this device.',
                            ),
                          ),
                        ),
                        RadioListTile(
                          value: 'watch',
                          enabled: watchAvailable && !saving,
                          title: Text(t('Connected watch')),
                          subtitle: Text(watchStatus),
                        ),
                        if (health.hasError)
                          ListTile(
                            leading: const Icon(Icons.refresh),
                            title: Text(t('Retry connected sources')),
                            onTap: saving
                                ? null
                                : () => ref
                                      .read(connectedHealthProvider.notifier)
                                      .refresh(),
                          ),
                        ListTile(
                          enabled: !saving,
                          titleAlignment: ListTileTitleAlignment.top,
                          minLeadingWidth: 28,
                          horizontalTitleGap: 16,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: const Icon(Icons.add_circle_outline_rounded),
                          title: Text(t('Add a device')),
                          subtitle: Text(
                            t('Open connected-health sources and permissions.'),
                          ),
                          onTap: saving
                              ? null
                              : () => context.push('/connected-health'),
                        ),
                        RadioListTile(
                          value: 'none',
                          title: Text(t('Do not track steps')),
                        ),
                      ],
                    ),
                  ),
                  _Section(t('Step goal')),
                  ListTile(
                    key: const Key('daily-step-goal'),
                    enabled: !saving,
                    title: Text(t('Daily step goal')),
                    subtitle: goal == null ? Text(t('Not set')) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(goal?.toString() ?? '—'),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: saving ? null : editGoal,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

const _stepsCopy = <String, Map<String, String>>{
  'en': {},
  'ar': {
    'Steps': 'الخطوات',
    'Choose a source': 'اختر مصدرًا',
    'Phone motion and health source': 'حركة الهاتف ومصدر الصحة',
    'Uses a source only after you authorize it on this device.':
        'يُستخدم المصدر فقط بعد أن تمنحه الإذن على هذا الجهاز.',
    'Connected watch': 'ساعة متصلة',
    'A connected watch source is available.': 'يتوفر مصدر من ساعة متصلة.',
    'No connected watch source is available.': 'لا يتوفر مصدر من ساعة متصلة.',
    'Add a device': 'إضافة جهاز',
    'Open connected-health sources and permissions.':
        'افتح مصادر الصحة المتصلة وأذوناتها.',
    'Do not track steps': 'عدم تتبع الخطوات',
    'Step goal': 'هدف الخطوات',
    'Daily step goal': 'هدف الخطوات اليومي',
    'Not set': 'غير محدد',
    'Cancel': 'إلغاء',
    'Save': 'حفظ',
    'Retry': 'إعادة المحاولة',
    'Step settings could not be loaded.': 'تعذر تحميل إعدادات الخطوات.',
    'Could not save step settings. Try again.':
        'تعذر حفظ إعدادات الخطوات. حاول مرة أخرى.',
    'Enter a whole-number goal from 1000 to 100000.':
        'أدخل هدفًا صحيحًا من 1000 إلى 100000.',
    'Loading step settings': 'جارٍ تحميل إعدادات الخطوات',
    'Checking connected sources…': 'جارٍ التحقق من المصادر المتصلة…',
    'Connected sources could not be checked.':
        'تعذر التحقق من المصادر المتصلة.',
    'Retry connected sources': 'إعادة فحص المصادر المتصلة',
  },
  'fr': {
    'Steps': 'Pas',
    'Choose a source': 'Choisir une source',
    'Daily step goal': 'Objectif quotidien de pas',
    'Not set': 'Non défini',
    'Cancel': 'Annuler',
    'Save': 'Enregistrer',
    'Retry': 'Réessayer',
  },
  'es': {
    'Steps': 'Pasos',
    'Choose a source': 'Elegir una fuente',
    'Daily step goal': 'Objetivo diario de pasos',
    'Not set': 'Sin definir',
    'Cancel': 'Cancelar',
    'Save': 'Guardar',
    'Retry': 'Reintentar',
  },
  'tr': {
    'Steps': 'Adımlar',
    'Choose a source': 'Kaynak seç',
    'Daily step goal': 'Günlük adım hedefi',
    'Not set': 'Ayarlanmadı',
    'Cancel': 'İptal',
    'Save': 'Kaydet',
    'Retry': 'Yeniden dene',
  },
};
