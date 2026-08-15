import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/runtime_copy.dart';
import '../../connected_health/providers/connected_health_provider.dart';
import '../domain/exercise_calorie_policy.dart';
import '../providers/exercise_calorie_providers.dart';

class ExerciseCalorieSettingsPage extends ConsumerWidget {
  const ExerciseCalorieSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final copy = _copies[language] ?? _extendedCopy(locale);
    final preferences = ref.watch(exerciseCaloriePreferencesProvider);
    final energy = ref.watch(todayAuthoritativeExerciseEnergyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.title), centerTitle: true),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(exerciseCaloriePreferencesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_retryLabel(locale)),
          ),
        ),
        data: (value) => energy.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton.icon(
              onPressed: () => ref.invalidate(connectedHealthProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_retryLabel(locale)),
            ),
          ),
          data: (verifiedEnergy) => _ExerciseCaloriePreferencesBody(
            copy: copy,
            preferences: value,
            energy: verifiedEnergy,
          ),
        ),
      ),
    );
  }
}

_Copy _extendedCopy(Locale locale) {
  final en = _copies['en']!;
  String resolve(String value) =>
      RuntimeCopy.resolve(value, locale.toLanguageTag()) ?? value;
  return _Copy(
    title: resolve(en.title),
    intro: resolve(en.intro),
    includeTitle: resolve(en.includeTitle),
    includeBody: resolve(en.includeBody),
    macrosTitle: resolve(en.macrosTitle),
    macrosBody: resolve(en.macrosBody),
    unavailable: resolve(en.unavailable),
    unavailableBody: resolve(en.unavailableBody),
    available: resolve(en.available),
    evidenceTemplate: resolve(en.evidenceTemplate),
  );
}

class _ExerciseCaloriePreferencesBody extends ConsumerStatefulWidget {
  const _ExerciseCaloriePreferencesBody({
    required this.copy,
    required this.preferences,
    required this.energy,
  });
  final _Copy copy;
  final ExerciseCaloriePreferences preferences;
  final AuthoritativeExerciseEnergy? energy;

  @override
  ConsumerState<_ExerciseCaloriePreferencesBody> createState() =>
      _ExerciseCaloriePreferencesBodyState();
}

class _ExerciseCaloriePreferencesBodyState
    extends ConsumerState<_ExerciseCaloriePreferencesBody> {
  bool saving = false;

  Future<void> save(ExerciseCaloriePreferences next) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await saveExerciseCaloriePreferences(ref, next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_failureLabel(Localizations.localeOf(context))),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    final copy = widget.copy;
    final energy = widget.energy;
    return PopScope(
      canPop: !saving,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(copy.intro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(copy.includeTitle),
                  subtitle: Text(copy.includeBody),
                  value: preferences.includeInRemainingGoal,
                  onChanged: saving
                      ? null
                      : (value) => save(
                          ExerciseCaloriePreferences(
                            includeInRemainingGoal: value,
                            adjustMacroGoals:
                                value && preferences.adjustMacroGoals,
                          ),
                        ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: Text(copy.macrosTitle),
                  subtitle: Text(copy.macrosBody),
                  value: preferences.adjustMacroGoals,
                  onChanged: preferences.includeInRemainingGoal && !saving
                      ? (value) => save(
                          ExerciseCaloriePreferences(
                            includeInRemainingGoal: true,
                            adjustMacroGoals: value,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _EnergyStateCard(
            available: energy != null,
            title: energy == null ? copy.unavailable : copy.available,
            detail: energy == null
                ? copy.unavailableBody
                : copy.evidence(energy.kcal.round(), energy.source),
          ),
        ],
      ),
    );
  }
}

String _retryLabel(Locale locale) => switch (locale.languageCode) {
  'ar' => 'إعادة المحاولة',
  'fr' => 'Réessayer',
  'es' => 'Reintentar',
  'tr' => 'Yeniden dene',
  _ => RuntimeCopy.resolve('Retry', locale.toLanguageTag()) ?? 'Retry',
};

String _failureLabel(Locale locale) => switch (locale.languageCode) {
  'ar' => 'تعذر حفظ إعدادات سعرات التمرين.',
  'fr' => "Impossible d’enregistrer les réglages des calories d’exercice.",
  'es' => 'No se pudieron guardar los ajustes de calorías de ejercicio.',
  'tr' => 'Egzersiz kalorisi ayarları kaydedilemedi.',
  _ =>
    RuntimeCopy.resolve(
          'Exercise calorie settings could not be saved.',
          locale.toLanguageTag(),
        ) ??
        'Exercise calorie settings could not be saved.',
};

class _EnergyStateCard extends StatelessWidget {
  const _EnergyStateCard({
    required this.available,
    required this.title,
    required this.detail,
  });

  final bool available;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = available ? const Color(0xFF10A878) : colors.tertiary;
    return Semantics(
      key: const Key('exercise-energy-evidence-state'),
      label: '$title. $detail',
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: .15),
              colors.surfaceContainerLow,
              colors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: .36)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ListTile(
          minVerticalPadding: 16,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          minLeadingWidth: 52,
          horizontalTitleGap: 20,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: .68)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .25),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              available ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              detail,
              style: const TextStyle(fontSize: 16, height: 1.35),
            ),
          ),
        ),
      ),
    );
  }
}

final class _Copy {
  const _Copy({
    required this.title,
    required this.intro,
    required this.includeTitle,
    required this.includeBody,
    required this.macrosTitle,
    required this.macrosBody,
    required this.unavailable,
    required this.unavailableBody,
    required this.available,
    required this.evidenceTemplate,
  });
  final String title, intro, includeTitle, includeBody, macrosTitle, macrosBody;
  final String unavailable, unavailableBody, available, evidenceTemplate;
  String evidence(int kcal, String source) => evidenceTemplate
      .replaceFirst('{kcal}', '$kcal')
      .replaceFirst('{source}', source);
}

const _copies = <String, _Copy>{
  'en': _Copy(
    title: 'Exercise calories',
    intro: 'Choose how verified active energy affects today’s nutrition goals.',
    includeTitle: 'Add exercise calories to remaining goal',
    includeBody:
        'Only verified active energy from a connected health source is eligible.',
    macrosTitle: 'Adjust macro goals too',
    macrosBody:
        'Scale protein, carbohydrate, and fat goals only when verified energy is applied.',
    unavailable: 'Verified exercise energy unavailable',
    unavailableBody:
        'No goal is changed. Connect and sync a supported health source to supply evidence.',
    available: 'Verified exercise energy available',
    evidenceTemplate: '{kcal} kcal from {source}',
  ),
  'ar': _Copy(
    title: 'سعرات التمرين',
    intro: 'اختر كيف تؤثر الطاقة النشطة الموثقة في أهداف تغذية اليوم.',
    includeTitle: 'إضافة سعرات التمرين إلى الهدف المتبقي',
    includeBody: 'تُقبل فقط الطاقة النشطة الموثقة من مصدر صحي متصل.',
    macrosTitle: 'تعديل أهداف الماكروز أيضًا',
    macrosBody:
        'تُعدّل أهداف البروتين والكربوهيدرات والدهون فقط عند تطبيق طاقة موثقة.',
    unavailable: 'طاقة التمرين الموثقة غير متاحة',
    unavailableBody:
        'لن يتغير أي هدف. اربط مصدرًا صحيًا مدعومًا وزامنه لتوفير الدليل.',
    available: 'طاقة تمرين موثقة متاحة',
    evidenceTemplate: '{kcal} سعرة من {source}',
  ),
  'fr': _Copy(
    title: 'Calories d’exercice',
    intro:
        'Choisissez comment l’énergie active vérifiée affecte les objectifs du jour.',
    includeTitle: 'Ajouter les calories d’exercice au restant',
    includeBody:
        'Seule l’énergie active vérifiée d’une source santé connectée est admise.',
    macrosTitle: 'Ajuster aussi les objectifs de macros',
    macrosBody:
        'Ajuster protéines, glucides et lipides uniquement avec une énergie vérifiée.',
    unavailable: 'Énergie d’exercice vérifiée indisponible',
    unavailableBody:
        'Aucun objectif ne change. Connectez et synchronisez une source santé compatible.',
    available: 'Énergie d’exercice vérifiée disponible',
    evidenceTemplate: '{kcal} kcal depuis {source}',
  ),
  'es': _Copy(
    title: 'Calorías de ejercicio',
    intro:
        'Elige cómo afecta la energía activa verificada a los objetivos de hoy.',
    includeTitle: 'Añadir calorías de ejercicio al objetivo restante',
    includeBody:
        'Solo se admite energía activa verificada de una fuente de salud conectada.',
    macrosTitle: 'Ajustar también los objetivos de macros',
    macrosBody:
        'Ajusta proteína, carbohidratos y grasa solo con energía verificada.',
    unavailable: 'Energía de ejercicio verificada no disponible',
    unavailableBody:
        'No se cambia ningún objetivo. Conecta y sincroniza una fuente compatible.',
    available: 'Energía de ejercicio verificada disponible',
    evidenceTemplate: '{kcal} kcal de {source}',
  ),
  'tr': _Copy(
    title: 'Egzersiz kalorileri',
    intro:
        'Doğrulanmış aktif enerjinin bugünkü hedefleri nasıl etkileyeceğini seçin.',
    includeTitle: 'Egzersiz kalorilerini kalan hedefe ekle',
    includeBody:
        'Yalnızca bağlı sağlık kaynağından doğrulanmış aktif enerji kullanılır.',
    macrosTitle: 'Makro hedeflerini de ayarla',
    macrosBody:
        'Protein, karbonhidrat ve yağ hedefleri yalnızca doğrulanmış enerjiyle ölçeklenir.',
    unavailable: 'Doğrulanmış egzersiz enerjisi yok',
    unavailableBody:
        'Hiçbir hedef değişmez. Desteklenen bir sağlık kaynağını bağlayıp eşitleyin.',
    available: 'Doğrulanmış egzersiz enerjisi var',
    evidenceTemplate: '{source} kaynağından {kcal} kcal',
  ),
};
