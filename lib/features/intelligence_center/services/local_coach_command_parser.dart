import '../domain/intelligence_action.dart';
import '../domain/coach_action_admission.dart';
import '../intelligence_locale_copy.dart';
import 'coach_date_resolver.dart';
import 'local_coach_calorie_command.dart';
import '../app_commands/coach_health_parser.dart';

part 'local_coach_command_quantity.dart';

/// Deterministic, offline command understanding for user-owned BIL data.
/// Structured values are validated locally and writes still require consent.
class LocalCoachCommandParser {
  const LocalCoachCommandParser({
    this.dateResolver = const CoachDateResolver(),
  });

  final CoachDateResolver dateResolver;

  List<IntelligenceAction> parse(
    String input, {
    bool? arabic,
    String? locale,
    DateTime? referenceLocal,
  }) {
    const admission = CoachActionAdmission();
    return [
      for (final action in _parse(
        input,
        arabic: arabic,
        locale: locale,
        referenceLocal: referenceLocal ?? DateTime.now(),
      ))
        if (admission.bind(action) case final binding?) binding.action,
    ];
  }

  List<IntelligenceAction> _parse(
    String input, {
    bool? arabic,
    String? locale,
    required DateTime referenceLocal,
  }) {
    final code = locale ?? (arabic == true ? 'ar' : 'en');
    String tr(String en, String ar) => intelligenceTextFor(code, en, ar);
    final value = _normalizeForMatching(input);
    if (value.isEmpty) return const [];
    final healthParser = LocalCoachHealthCommandParser(
      dateResolver: dateResolver,
    );
    final health = healthParser.parse(
      input,
      locale: code,
      referenceLocal: referenceLocal,
    );
    if (health != null) return [health];
    if (healthParser.recognizesHealthIntent(input)) return const [];
    final calorieOnly = LocalCoachCalorieCommand(
      dateResolver: dateResolver,
    ).parse(input, locale: code, referenceLocal: referenceLocal);
    if (calorieOnly != null) return [calorieOnly];

    final themeMode = _requestedThemeMode(value);
    if (themeMode != null) {
      return [
        IntelligenceAction(
          id: 'set-theme-$themeMode',
          toolId: 'set_theme_mode',
          type: IntelligenceActionType.setThemeMode,
          label: tr('Change app appearance', 'تغيير مظهر التطبيق'),
          requiresConfirmation: false,
          payload: {'mode': themeMode},
        ),
      ];
    }
    final requestedLocale = _requestedLocale(value);
    if (requestedLocale != null) {
      return [
        IntelligenceAction(
          id: 'set-language-$requestedLocale',
          toolId: 'set_language',
          type: IntelligenceActionType.setLanguage,
          label: tr('Change app language', 'تغيير لغة التطبيق'),
          requiresConfirmation: false,
          payload: {'locale': requestedLocale},
        ),
      ];
    }

    if (_contains(value, const [
      'delete my account',
      'delete account',
      'حذف حسابي',
      'احذف حسابي',
      'حذف الحساب',
      'supprimer mon compte',
      'eliminar mi cuenta',
      'hesabımı sil',
    ])) {
      return [
        IntelligenceAction(
          id: 'request-account-deletion',
          toolId: 'request_account_deletion',
          type: IntelligenceActionType.requestAccountDeletion,
          label: tr(
            'Review account and data deletion',
            'مراجعة حذف الحساب والبيانات',
          ),
          requiresConfirmation: true,
          destructive: true,
        ),
      ];
    }
    if (_contains(value, const [
      'cancel subscription',
      'manage subscription',
      'الغاء الاشتراك',
      'إلغاء الاشتراك',
      'ادارة الاشتراك',
      'إدارة الاشتراك',
      'gérer l’abonnement',
      'cancelar suscripción',
      'gestionar suscripción',
      'aboneliği iptal et',
      'aboneliği yönet',
    ])) {
      return [
        IntelligenceAction(
          id: 'manage-subscription',
          toolId: 'manage_subscription',
          type: IntelligenceActionType.manageSubscription,
          label: tr(
            'Open official subscription management',
            'فتح إدارة الاشتراك الرسمية',
          ),
          requiresConfirmation: true,
        ),
      ];
    }

    final hasWaterConcept = _hasQuantityUnit(
      value,
      'water|eau|agua|su|ماء|الماء|مياه|المياه|مويه|المويه|موية|الموية|ميه|الميه',
    );
    final hasWaterLogIntent = _contains(value, const [
      'log water',
      'add water',
      'record water',
      'open water',
      'review water',
      'سجل ماء',
      'سجل الماء',
      'اضف ماء',
      'اضف الماء',
      'افتح سجل الماء',
      'راجع سجل الماء',
    ]);
    if (hasWaterConcept) {
      final waterDate = dateResolver.resolve(
        input,
        referenceLocal: referenceLocal,
      );
      if (_hasAmbiguousQuantityDate(value, referenceLocal)) {
        return const [];
      }
      final amount = _waterMilliliters(value);
      if (amount != null && amount >= 1 && amount <= 5000) {
        return [
          IntelligenceAction(
            id: 'add-water-$amount',
            toolId: 'log_water',
            type: IntelligenceActionType.addWater,
            label: _waterLabel(code, amount),
            requiresConfirmation: true,
            payload: {
              'amountMl': amount,
              if (waterDate != null) 'date': _dateOnly(waterDate),
            },
          ),
        ];
      }
      if (hasWaterLogIntent) {
        return [
          IntelligenceAction(
            id: 'review-water',
            type: IntelligenceActionType.openDailyLog,
            label: tr('Review water log', 'مراجعة تسجيل الماء'),
            requiresConfirmation: false,
            payload: const {'action': 'water'},
          ),
        ];
      }
    }
    final hasGoalUpdateIntent = _contains(value, const [
      'change my target',
      'change target weight',
      'set my target',
      'set target weight',
      'update my goal',
      'new target weight',
      'غير الهدف',
      'تغيير الهدف',
      'غير الوزن المستهدف',
      'تغيير الوزن المستهدف',
      'الهدف الجديد',
      'اجعل هدفي',
      'modifier mon objectif',
      'cambiar mi objetivo',
      'hedefimi değiştir',
    ]);
    if (hasGoalUpdateIntent) {
      if (_hasAmbiguousQuantityDate(value, referenceLocal)) return const [];
      final number = _bodyWeightKilograms(value);
      if (number == null || number < 20 || number > 500) {
        // An unresolved goal must not fall through into a body-weight write.
        return const [];
      }
      return [
        IntelligenceAction(
          id: 'update-goal-$number',
          toolId: 'update_goal',
          type: IntelligenceActionType.updateGoal,
          label: tr(
            'Update target weight to $number kg',
            'تحديث الوزن المستهدف إلى $number كغ',
          ),
          // Goal changes always require an explicit confirmation in the
          // action sheet; parsing alone never mutates profile data.
          requiresConfirmation: true,
          payload: {'targetWeightKg': number},
        ),
      ];
    }
    final hasWeightConcept = _contains(value, const [
      'weight',
      'weigh',
      'kg',
      'وزني',
      'وزن',
      'اوزان',
      'كغ',
      'كيلو',
      'poids',
      'peso',
      'kilo',
      'ağırlık',
    ]);
    if (hasWeightConcept && _isBodyWeightStatement(value)) {
      if (_hasAmbiguousQuantityDate(value, referenceLocal)) return const [];
      final weight = _bodyWeightKilograms(value);
      if (weight != null && weight >= 20 && weight <= 500) {
        final date = dateResolver.resolve(
          input,
          referenceLocal: referenceLocal,
        );
        if (date == null && dateResolver.hasExplicitDate(input)) {
          return const [];
        }
        return [
          IntelligenceAction(
            id: 'add-weight-$weight',
            toolId: 'log_weight',
            type: IntelligenceActionType.addWeight,
            label: _weightLabel(code, weight),
            requiresConfirmation: true,
            payload: {
              'weightKg': weight,
              if (date != null) 'date': _dateOnly(date),
            },
          ),
        ];
      }
      final hasWeightHistoryIntent = _contains(value, const [
        'open weight',
        'open my weight',
        'view weight history',
        'view my weight history',
        'show weight history',
        'show my weight history',
        'افتح سجل الوزن',
        'استعرض سجل وزني',
        'استعرض سجل اوزاني',
        'اعرض سجل وزني',
        'اعرض سجل اوزاني',
        'تاريخ وزني',
        'تاريخ اوزاني',
      ]);
      if (hasWeightHistoryIntent) {
        return [
          IntelligenceAction(
            id: 'open-weight-history',
            type: IntelligenceActionType.navigate,
            label: tr('Open weight history', 'فتح سجل الأوزان'),
            requiresConfirmation: false,
            payload: const {'target': 'weight_history'},
          ),
        ];
      }
      final hasWeightCheckInIntent = _contains(value, const [
        'log weight',
        'record weight',
        'add weight',
        'weight check-in',
        'سجل الوزن',
        'اضف الوزن',
      ]);
      if (hasWeightCheckInIntent) {
        return [
          IntelligenceAction(
            id: 'review-weight',
            type: IntelligenceActionType.addWeight,
            label: tr('Open weight check-in', 'فتح تسجيل الوزن'),
            requiresConfirmation: false,
          ),
        ];
      }
    }
    final hasMealConcept = _contains(value, const [
      'i ate',
      'meal',
      'food',
      'أكلت',
      'اكلت',
      'وجبة',
      'طعام',
      'repas',
      'nourriture',
      'comida',
      'yemek',
      'öğün',
    ]);
    final hasMealActionIntent = _contains(value, const [
      'i ate',
      'log meal',
      'add meal',
      'record meal',
      'open meal log',
      'أكلت',
      'اكلت',
      'سجل وجبة',
      'اضف وجبة',
      'افتح سجل الوجبات',
    ]);
    if (hasMealConcept && hasMealActionIntent) {
      return [
        IntelligenceAction(
          id: 'review-meal',
          type: IntelligenceActionType.reviewMeal,
          label: tr('Review meal before logging', 'مراجعة الوجبة قبل تسجيلها'),
          requiresConfirmation: false,
          payload: {'query': input.trim()},
        ),
      ];
    }
    final hasWorkoutConcept = _contains(value, const [
      'i trained',
      'workout',
      'exercise',
      'تمرنت',
      'تمرين',
      'رياضة',
      'entraînement',
      'exercice',
      'entrenamiento',
      'ejercicio',
      'antrenman',
      'egzersiz',
    ]);
    final hasWorkoutActionIntent = _contains(value, const [
      'i trained',
      'log workout',
      'add workout',
      'record workout',
      'open workout',
      'تمرنت',
      'سجل تمرين',
      'اضف تمرين',
      'افتح التمارين',
    ]);
    if (hasWorkoutConcept && hasWorkoutActionIntent) {
      return [
        IntelligenceAction(
          id: 'review-workout',
          type: IntelligenceActionType.reviewWorkout,
          label: tr(
            'Review workout before logging',
            'مراجعة التمرين قبل تسجيله',
          ),
          requiresConfirmation: false,
          payload: {'query': input.trim()},
        ),
      ];
    }
    return const [];
  }

  bool _contains(String value, List<String> markers) =>
      markers.any(value.contains);

  bool _containsWholeToken(String value, List<String> markers) => markers.any(
    (marker) => RegExp(
      '(?:^|[^\\p{L}\\p{N}])${RegExp.escape(marker)}(?:\$|[^\\p{L}\\p{N}])',
      unicode: true,
    ).hasMatch(value),
  );

  String _normalizeForMatching(String input) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    var value = input.trim().toLowerCase();
    for (var index = 0; index < 10; index += 1) {
      value = value
          .replaceAll(arabicIndic[index], '$index')
          .replaceAll(easternArabic[index], '$index');
    }
    return value
        .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670\u06d6-\u06ed]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');
  }

  String _waterLabel(String locale, int amount) => switch (_code(locale)) {
    'ar' => 'تسجيل $amount مل ماء',
    'fr' => 'Enregistrer $amount ml d’eau',
    'es' => 'Registrar $amount ml de agua',
    'tr' => '$amount ml su kaydet',
    _ => 'Log $amount ml water',
  };

  String _weightLabel(String locale, double value) => switch (_code(locale)) {
    'ar' => 'تسجيل وزن $value كغ',
    'fr' => 'Enregistrer un poids de $value kg',
    'es' => 'Registrar un peso de $value kg',
    'tr' => '$value kg kilo kaydet',
    _ => 'Log $value kg weight',
  };

  String _code(String locale) =>
      locale.toLowerCase().split(RegExp('[-_]')).first;

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String? _requestedThemeMode(String value) {
    if (_contains(value, const ['dark mode', 'الوضع الليلي', 'الوضع الداكن'])) {
      return 'dark';
    }
    if (_contains(value, const [
      'light mode',
      'الوضع النهاري',
      'الوضع الفاتح',
    ])) {
      return 'light';
    }
    if (_contains(value, const ['system mode', 'وضع الجهاز', 'حسب الجهاز'])) {
      return 'system';
    }
    return null;
  }

  String? _requestedLocale(String value) {
    if (!_contains(value, const ['language', 'لغة', 'اللغه', 'غير اللغة'])) {
      return null;
    }
    const variants = <String, List<String>>{
      'ar': ['arabic', 'العربي', 'عربي'],
      'en': ['english', 'الانجليزي', 'إنجليزي'],
      'fr': ['french', 'الفرنسي', 'فرنسي'],
      'es': ['spanish', 'الاسباني', 'إسباني'],
      'tr': ['turkish', 'التركي', 'تركي'],
    };
    for (final entry in variants.entries) {
      if (_contains(value, entry.value)) return entry.key;
    }
    return null;
  }
}
