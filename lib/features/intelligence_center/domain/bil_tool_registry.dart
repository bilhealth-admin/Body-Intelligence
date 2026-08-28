import 'intelligence_action.dart';
import 'bil_navigation_registry.dart';
import '../../../app/localization/bil_locale_policy.dart';

enum BilToolRisk { readOnly, lowRisk, reversibleWrite, sensitive, destructive }

enum BilToolTrustBoundary {
  clientNavigation,
  trustedLocalRepository,
  serverVerified,
}

enum BilToolTier { free, premium, premiumAiCoach }

class BilToolDescriptor {
  const BilToolDescriptor({
    required this.name,
    required this.type,
    required this.risk,
    required this.trustBoundary,
    this.minimumTier = BilToolTier.free,
    this.requiredArguments = const <String>{},
    this.allowedArguments = const <String>{},
  });

  final String name;
  final IntelligenceActionType type;
  final BilToolRisk risk;
  final BilToolTrustBoundary trustBoundary;
  final BilToolTier minimumTier;
  final Set<String> requiredArguments;
  final Set<String> allowedArguments;

  bool get requiresConfirmation => switch (risk) {
    BilToolRisk.readOnly || BilToolRisk.lowRisk => false,
    BilToolRisk.reversibleWrite ||
    BilToolRisk.sensitive ||
    BilToolRisk.destructive => true,
  };

  bool get destructive => risk == BilToolRisk.destructive;

  int get confirmationStages => switch (risk) {
    BilToolRisk.readOnly || BilToolRisk.lowRisk => 0,
    BilToolRisk.reversibleWrite || BilToolRisk.sensitive => 1,
    BilToolRisk.destructive => 2,
  };

  Map<String, Object?>? validateArguments(Map<String, Object?> raw) {
    if (!raw.keys.every(allowedArguments.contains) ||
        !requiredArguments.every(raw.containsKey)) {
      return null;
    }
    switch (name) {
      case 'navigate':
        if (!BilNavigationRegistry.targets.containsKey(raw['target'])) {
          return null;
        }
      case 'read_nutrition_remaining':
      case 'read_profile_identity':
        if (raw.isNotEmpty) return null;
      case 'log_water':
        final amount = raw['amountMl'];
        if (amount is! int || amount < 1 || amount > 5000) return null;
      case 'log_weight':
        final weight = raw['weightKg'];
        if (weight is! num || weight < 20 || weight > 500) return null;
        final date = raw['date'];
        if (date != null && DateTime.tryParse(date.toString()) == null) {
          return null;
        }
      case 'open_meals_yesterday':
        if (raw.isNotEmpty) return null;
      case 'set_theme_mode':
        if (!const {'dark', 'light', 'system'}.contains(raw['mode'])) {
          return null;
        }
      case 'set_language':
        final locale = BilLocalePolicy.canonicalSupportedTag(
          raw['locale']?.toString(),
        );
        if (locale == null) {
          return null;
        }
        raw = <String, Object?>{...raw, 'locale': locale};
      case 'update_goal':
        final target = raw['targetWeightKg'];
        if (target is! num || target < 20 || target > 500) return null;
        final date = raw['targetDate'];
        if (date != null && DateTime.tryParse(date.toString()) == null) {
          return null;
        }
      case 'save_measurements':
        final date = raw['date'];
        if (date != null && DateTime.tryParse(date.toString()) == null) {
          return null;
        }
        const keys = {
          'neckCm',
          'waistCm',
          'hipsCm',
          'chestCm',
          'armCm',
          'thighCm',
        };
        final values = keys.where(raw.containsKey).map((key) => raw[key]);
        if (values.isEmpty ||
            values.any((v) => v is! num || v < 20 || v > 300)) {
          return null;
        }
      case 'quick_add_macros':
        if (!const {
          'breakfast',
          'lunch',
          'dinner',
          'snack',
        }.contains(raw['mealType'])) {
          return null;
        }
        for (final key in const [
          'calories',
          'protein',
          'carbohydrates',
          'fat',
        ]) {
          final value = raw[key];
          if (value is! num || !value.isFinite || value < 0) return null;
        }
        if (const [
          'calories',
          'protein',
          'carbohydrates',
          'fat',
        ].every((key) => (raw[key] as num) == 0)) {
          return null;
        }
      case 'update_meal_item':
        if (raw['itemId'] is! int || (raw['itemId'] as int) < 1) return null;
        final quantity = raw['quantityGrams'];
        if (quantity is! num ||
            !quantity.isFinite ||
            quantity <= 0 ||
            quantity > 100000) {
          return null;
        }
      case 'delete_meal_item':
        if (raw['itemId'] is! int || (raw['itemId'] as int) < 1) return null;
      case 'save_memory':
        final text = raw['text']?.toString().trim() ?? '';
        if (text.isEmpty || text.length > 500) return null;
        final kind = raw['kind']?.toString() ?? 'user_fact';
        if (!const {
          'user_fact',
          'preference',
          'constraint',
          'goal',
          'routine',
        }.contains(kind)) {
          return null;
        }
      case 'move_meal_item':
        if (raw['itemId'] is! int || (raw['itemId'] as int) < 1) return null;
        if (!const {
          'breakfast',
          'lunch',
          'dinner',
          'snack',
        }.contains(raw['mealType'])) {
          return null;
        }
    }
    return Map<String, Object?>.unmodifiable(raw);
  }
}

/// Central allow-list for AI-selected BIL capabilities.
///
/// Descriptors contain policy and schema only. Execution remains in the
/// existing navigation/repository layer; a model never receives SQL access.
class BilToolRegistry {
  const BilToolRegistry();

  static const tools = <String, BilToolDescriptor>{
    'navigate': BilToolDescriptor(
      name: 'navigate',
      type: IntelligenceActionType.navigate,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
      requiredArguments: {'target'},
      allowedArguments: {'target'},
    ),
    'read_nutrition_remaining': BilToolDescriptor(
      name: 'read_nutrition_remaining',
      type: IntelligenceActionType.readNutritionRemaining,
      risk: BilToolRisk.readOnly,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
    ),
    'read_profile_identity': BilToolDescriptor(
      name: 'read_profile_identity',
      type: IntelligenceActionType.readProfileIdentity,
      risk: BilToolRisk.readOnly,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
    ),
    'open_weight_log': BilToolDescriptor(
      name: 'open_weight_log',
      type: IntelligenceActionType.addWeight,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
    ),
    'open_meals': BilToolDescriptor(
      name: 'open_meals',
      type: IntelligenceActionType.reviewMeal,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
    ),
    'open_meals_yesterday': BilToolDescriptor(
      name: 'open_meals_yesterday',
      type: IntelligenceActionType.reviewMeal,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
    ),
    'open_workouts': BilToolDescriptor(
      name: 'open_workouts',
      type: IntelligenceActionType.reviewWorkout,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
    ),
    'open_plan': BilToolDescriptor(
      name: 'open_plan',
      type: IntelligenceActionType.openPlan,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
    ),
    'open_report': BilToolDescriptor(
      name: 'open_report',
      type: IntelligenceActionType.openReport,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
    ),
    'manage_subscription': BilToolDescriptor(
      name: 'manage_subscription',
      type: IntelligenceActionType.manageSubscription,
      risk: BilToolRisk.sensitive,
      trustBoundary: BilToolTrustBoundary.serverVerified,
    ),
    'set_theme_mode': BilToolDescriptor(
      name: 'set_theme_mode',
      type: IntelligenceActionType.setThemeMode,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'mode'},
      allowedArguments: {'mode'},
    ),
    'set_language': BilToolDescriptor(
      name: 'set_language',
      type: IntelligenceActionType.setLanguage,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'locale'},
      allowedArguments: {'locale'},
    ),
    'update_goal': BilToolDescriptor(
      name: 'update_goal',
      type: IntelligenceActionType.updateGoal,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'targetWeightKg'},
      allowedArguments: {'targetWeightKg', 'targetDate'},
    ),
    'save_measurements': BilToolDescriptor(
      name: 'save_measurements',
      type: IntelligenceActionType.saveMeasurements,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      allowedArguments: {
        'date',
        'neckCm',
        'waistCm',
        'hipsCm',
        'chestCm',
        'armCm',
        'thighCm',
      },
    ),
    'quick_add_macros': BilToolDescriptor(
      name: 'quick_add_macros',
      type: IntelligenceActionType.quickAddMacros,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {
        'mealType',
        'calories',
        'protein',
        'carbohydrates',
        'fat',
      },
      allowedArguments: {
        'date',
        'mealType',
        'calories',
        'protein',
        'carbohydrates',
        'fat',
      },
    ),
    'update_meal_item': BilToolDescriptor(
      name: 'update_meal_item',
      type: IntelligenceActionType.updateMealItem,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'itemId', 'quantityGrams'},
      allowedArguments: {'itemId', 'quantityGrams'},
    ),
    'delete_meal_item': BilToolDescriptor(
      name: 'delete_meal_item',
      type: IntelligenceActionType.deleteMealItem,
      risk: BilToolRisk.sensitive,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'itemId'},
      allowedArguments: {'itemId'},
    ),
    'move_meal_item': BilToolDescriptor(
      name: 'move_meal_item',
      type: IntelligenceActionType.moveMealItem,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'itemId', 'mealType'},
      allowedArguments: {'itemId', 'mealType'},
    ),
    'request_account_deletion': BilToolDescriptor(
      name: 'request_account_deletion',
      type: IntelligenceActionType.requestAccountDeletion,
      risk: BilToolRisk.destructive,
      trustBoundary: BilToolTrustBoundary.serverVerified,
    ),
    'log_water': BilToolDescriptor(
      name: 'log_water',
      type: IntelligenceActionType.addWater,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'amountMl'},
      allowedArguments: {'amountMl'},
    ),
    'log_weight': BilToolDescriptor(
      name: 'log_weight',
      type: IntelligenceActionType.addWeight,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'weightKg'},
      allowedArguments: {'weightKg', 'date'},
    ),
    'save_memory': BilToolDescriptor(
      name: 'save_memory',
      type: IntelligenceActionType.saveMemory,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'text'},
      allowedArguments: {'text', 'kind'},
    ),
  };

  BilToolDescriptor? lookup(String name) => tools[name];

  IntelligenceAction? createAction({
    required String name,
    required Map<String, Object?> arguments,
    required String label,
  }) {
    final descriptor = lookup(name);
    if (descriptor == null) return null;
    final validated = descriptor.validateArguments(arguments);
    if (validated == null) return null;
    final payload = name == 'open_meals_yesterday'
        ? const <String, Object?>{'dayOffset': -1}
        : validated;
    return IntelligenceAction(
      id: name,
      type: descriptor.type,
      label: label,
      requiresConfirmation: descriptor.requiresConfirmation,
      destructive: descriptor.destructive,
      payload: payload,
    );
  }
}
