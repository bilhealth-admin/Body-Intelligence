import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/first_meal_milestone.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../../shared/widgets/first_use_target_guide.dart';
import 'first_use_context_coachmark.dart';

final _daysGuideStatus = StreamProvider<String?>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .watch(firstMealStreakGuidePreferenceKey),
);

/// BIL's approved Home has no week row. Teach the actual Diary date selector
/// without adding a replica to Home or inventing completed-day evidence.
class FirstFoodDaysGuide extends ConsumerStatefulWidget {
  const FirstFoodDaysGuide({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<FirstFoodDaysGuide> createState() => _DaysGuideState();
}

class _DaysGuideState extends ConsumerState<FirstFoodDaysGuide> {
  bool _dismissed = false;
  Object? _repository;
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(_daysGuideStatus).value;
    final preferences = ref.watch(preferencesRepositoryProvider);
    if (!identical(_repository, preferences)) {
      _repository = preferences;
      _dismissed = false;
    }
    String copy(String en, String ar, String fr, String es, String tr) =>
        switch (Localizations.localeOf(context).languageCode) {
          'ar' => ar,
          'fr' => fr,
          'es' => es,
          'tr' => tr,
          _ => en,
        };
    Future<void> finish() async {
      if (!context.mounted ||
          !identical(preferences, ref.read(preferencesRepositoryProvider))) {
        return;
      }
      setState(() => _dismissed = true);
      try {
        await preferences.set(firstMealStreakGuidePreferenceKey, 'seen');
      } on Object {
        // An optional guide must never change or block food/date selection.
      }
    }

    return FirstUseTargetGuide(
      onTargetActivated: finish,
      guide: status == 'ready' && !_dismissed
          ? FirstUseContextCoachmark(
              key: const Key('dashboard-first-food-streak-guide'),
              compact: true,
              title: copy(
                'Day one of your journey!',
                'أول يوم في رحلتك!',
                'Le premier jour !',
                '¡Tu primer día!',
                'Yolculuğunun ilk günü!',
              ),
              message: copy(
                'Choose a day here to review its recorded meals. Date circles select a day; they do not claim that food was logged.',
                'اختر يومًا هنا لمراجعة وجباته المسجلة. الدوائر لا تعني أن وجبة سُجلت في كل يوم.',
                'Choisissez un jour pour consulter ses repas. Les cercles sélectionnent la date, sans indiquer un repas enregistré.',
                'Elige un día para revisar sus comidas. Los círculos seleccionan fechas, sin afirmar que hayas registrado comida.',
                'Öğünlerini incelemek için bir gün seç. Daireler tarih seçer; yemek kaydedildiğini göstermez.',
              ),
              icon: Icons.calendar_month_rounded,
              accent: const Color(0xFFFBD583),
              onSkip: finish,
              skipKey: const Key('dashboard-streak-guide-skip'),
              onAction: finish,
              actionLabel: copy(
                'Got it',
                'رائع، فهمت',
                'Compris',
                'Entendido',
                'Anladım',
              ),
              actionKey: const Key('dashboard-streak-guide-done'),
            )
          : null,
      child: widget.child,
    );
  }
}
