import '../domain/bil_tool_registry.dart';
import '../domain/intelligence_action.dart';
import 'local_coach_command_parser.dart';
import 'local_model_gateway.dart';
import '../domain/coach_context_snapshot.dart';
import '../intelligence_locale_copy.dart';
import 'coach_intent_normalizer.dart';

class LocalCoachRequest {
  const LocalCoachRequest({
    required this.text,
    required this.locale,
    this.channel = CoachInputChannel.text,
    this.userContext = const <String, Object?>{},
  });

  final String text;
  final String locale;
  final CoachInputChannel channel;
  final Map<String, Object?> userContext;
}

class LocalCoachResult {
  const LocalCoachResult({
    required this.actions,
    required this.processedOnDevice,
    this.answer,
    this.spokenAnswer,
  });

  final List<IntelligenceAction> actions;
  final bool processedOnDevice;
  final String? answer;
  final String? spokenAnswer;
}

/// In-process API boundary for the BIL coach.
///
/// The release implementation is deterministic and sends no personal data to
/// a server. A future on-device language model can implement this interface
/// without changing screens, repositories, confirmations, or safety gates.
abstract interface class LocalCoachApi {
  Future<LocalCoachResult> understand(LocalCoachRequest request);
}

class DeterministicLocalCoachApi implements LocalCoachApi {
  const DeterministicLocalCoachApi({
    this.parser = const LocalCoachCommandParser(),
    this.normalizer = const CoachIntentNormalizer(),
  });

  final LocalCoachCommandParser parser;
  final CoachIntentNormalizer normalizer;

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) async {
    final input = normalizer.normalize(
      text: request.text,
      locale: request.locale,
      channel: request.channel,
    );
    return LocalCoachResult(
      actions: parser.parse(input.normalized, locale: request.locale),
      processedOnDevice: true,
    );
  }
}

class ModelBackedLocalCoachApi implements LocalCoachApi {
  const ModelBackedLocalCoachApi({
    required this.gateway,
    required this.context,
    this.parser = const LocalCoachCommandParser(),
    this.registry = const BilToolRegistry(),
    this.normalizer = const CoachIntentNormalizer(),
  });

  final LocalModelGateway gateway;
  final CoachContextSnapshot context;
  final LocalCoachCommandParser parser;
  final BilToolRegistry registry;
  final CoachIntentNormalizer normalizer;

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) async {
    final input = normalizer.normalize(
      text: request.text,
      locale: request.locale,
      channel: request.channel,
    );
    final deterministic = parser.parse(
      input.normalized,
      locale: request.locale,
    );
    if (deterministic.isNotEmpty) {
      return LocalCoachResult(actions: deterministic, processedOnDevice: true);
    }
    final model = await gateway.answer(
      question: input.normalized,
      locale: request.locale,
      context: context,
    );
    if (model == null) {
      // Continue through the engine's grounded health, intent, and safety
      // fallbacks. An optional model endpoint is not a prerequisite for chat.
      return const LocalCoachResult(actions: [], processedOnDevice: true);
    }
    final action = _validatedModelAction(model.action, request.locale);
    return LocalCoachResult(
      actions: action == null ? const [] : [action],
      processedOnDevice: model.processedOnDevice,
      answer: model.text,
      spokenAnswer: model.spokenText,
    );
  }

  IntelligenceAction? _validatedModelAction(
    Map<String, Object?>? raw,
    String locale,
  ) {
    if (raw == null) return null;
    final name = raw['name']?.toString();
    final arguments = raw['arguments'] is Map
        ? Map<String, Object?>.from(raw['arguments']! as Map)
        : const <String, Object?>{};
    String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
    final legacy = switch (name) {
      'navigate' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.navigate,
        label: tr('Open requested screen', 'فتح الشاشة المطلوبة'),
        requiresConfirmation: false,
        payload: arguments,
      ),
      'read_nutrition_remaining' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.readNutritionRemaining,
        label: tr('Read nutrition remaining', 'قراءة المتبقي من التغذية'),
        requiresConfirmation: false,
      ),
      'read_profile_identity' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.readProfileIdentity,
        label: tr('Read profile name', 'قراءة اسم الملف الشخصي'),
        requiresConfirmation: false,
      ),
      'open_weight_log' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.addWeight,
        label: tr('Open weight log', 'فتح سجل الوزن'),
        requiresConfirmation: false,
      ),
      'open_meals' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.reviewMeal,
        label: tr('Open meal log', 'فتح سجل الوجبات'),
        requiresConfirmation: false,
      ),
      'open_meals_yesterday' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.reviewMeal,
        label: tr("Show yesterday's meals", 'عرض وجبات أمس'),
        requiresConfirmation: false,
        payload: const {'dayOffset': -1},
      ),
      'open_workouts' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.reviewWorkout,
        label: tr('Open workouts', 'فتح التمارين'),
        requiresConfirmation: false,
      ),
      'open_plan' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.openPlan,
        label: tr('Open plan', 'فتح الخطة'),
        requiresConfirmation: false,
      ),
      'open_report' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.openReport,
        label: tr('Open report', 'فتح التقرير'),
        requiresConfirmation: false,
      ),
      'manage_subscription' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.manageSubscription,
        label: tr('Manage subscription', 'إدارة الاشتراك'),
        requiresConfirmation: true,
      ),
      'set_theme_mode' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.setThemeMode,
        label: tr('Change appearance', 'تغيير المظهر'),
        requiresConfirmation: false,
        payload: arguments,
      ),
      'set_language' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.setLanguage,
        label: tr('Change language', 'تغيير اللغة'),
        requiresConfirmation: false,
        payload: arguments,
      ),
      'update_goal' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.updateGoal,
        label: tr('Update goal', 'تحديث الهدف'),
        requiresConfirmation: true,
        payload: arguments,
      ),
      'save_measurements' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.saveMeasurements,
        label: tr('Save measurements', 'حفظ القياسات'),
        requiresConfirmation: true,
        payload: arguments,
      ),
      'quick_add_macros' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.quickAddMacros,
        label: tr('Add meal macros', 'إضافة مغذيات الوجبة'),
        requiresConfirmation: true,
        payload: arguments,
      ),
      'update_meal_item' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.updateMealItem,
        label: tr('Update meal item', 'تحديث عنصر الوجبة'),
        requiresConfirmation: true,
        payload: arguments,
      ),
      'delete_meal_item' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.deleteMealItem,
        label: tr('Delete meal item', 'حذف عنصر الوجبة'),
        requiresConfirmation: true,
        payload: arguments,
      ),
      'move_meal_item' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.moveMealItem,
        label: tr('Move meal item', 'نقل عنصر الوجبة'),
        requiresConfirmation: true,
        payload: arguments,
      ),
      'request_account_deletion' => IntelligenceAction(
        id: name!,
        type: IntelligenceActionType.requestAccountDeletion,
        label: tr('Review account deletion', 'مراجعة حذف الحساب'),
        requiresConfirmation: true,
        destructive: true,
      ),
      'log_water'
          when arguments['amountMl'] is int &&
              (arguments['amountMl']! as int) >= 1 &&
              (arguments['amountMl']! as int) <= 5000 =>
        IntelligenceAction(
          id: name!,
          type: IntelligenceActionType.addWater,
          label: tr('Confirm water log', 'تأكيد تسجيل الماء'),
          requiresConfirmation: true,
          payload: arguments,
        ),
      'log_weight'
          when arguments['weightKg'] is num &&
              (arguments['weightKg']! as num) >= 20 &&
              (arguments['weightKg']! as num) <= 500 =>
        IntelligenceAction(
          id: name!,
          type: IntelligenceActionType.addWeight,
          label: tr('Confirm weight log', 'تأكيد تسجيل الوزن'),
          requiresConfirmation: true,
          payload: arguments,
        ),
      _ => null,
    };
    if (name == null || legacy == null) return null;
    return registry.createAction(
      name: name,
      arguments: arguments,
      label: legacy.label,
    );
  }
}
