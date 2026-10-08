import '../domain/bil_tool_registry.dart';
import '../domain/intelligence_action.dart';
import '../../notifications/domain/daily_reminder.dart';
import 'coach_unit_settings_command.dart';

/// Local-only Coach settings capabilities. They deliberately reuse the same
/// descriptor policy as canonical tools while remaining outside
/// [BilToolRegistry.tools], preserving the published 23-tool server contract.
class CoachSettingsToolCatalog {
  const CoachSettingsToolCatalog();

  static const descriptors = <String, BilToolDescriptor>{
    'set_unit_preference': BilToolDescriptor(
      name: 'set_unit_preference',
      type: IntelligenceActionType.setUnitPreference,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'dimension', 'value'},
      allowedArguments: {'dimension', 'value'},
    ),
    'set_reminder': BilToolDescriptor(
      name: 'set_reminder',
      type: IntelligenceActionType.setReminder,
      risk: BilToolRisk.reversibleWrite,
      trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
      requiredArguments: {'kind', 'enabled'},
      allowedArguments: {'kind', 'enabled', 'hour', 'minute'},
    ),
    'review_memories': BilToolDescriptor(
      name: 'review_memories',
      type: IntelligenceActionType.reviewMemories,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
      allowedArguments: {},
    ),
    'prepare_local_export': BilToolDescriptor(
      name: 'prepare_local_export',
      type: IntelligenceActionType.prepareLocalExport,
      risk: BilToolRisk.lowRisk,
      trustBoundary: BilToolTrustBoundary.clientNavigation,
      allowedArguments: {'from', 'to', 'datasets'},
    ),
  };

  static Set<String> get toolNames => descriptors.keys.toSet();

  BilToolDescriptor? lookup(String name) => descriptors[name];

  Map<String, Object?>? validate(String name, Map<String, Object?> raw) {
    final descriptor = descriptors[name];
    if (descriptor == null ||
        !raw.keys.every(descriptor.allowedArguments.contains) ||
        !descriptor.requiredArguments.every(raw.containsKey)) {
      return null;
    }
    switch (name) {
      case 'set_unit_preference':
        final dimension = CoachUnitDimension.values
            .where((item) => item.name == raw['dimension'])
            .firstOrNull;
        final value = raw['value'];
        if (dimension == null ||
            value is! String ||
            !dimension.allowedValues.contains(value)) {
          return null;
        }
      case 'set_reminder':
        final kind = DailyReminderKind.values
            .where((item) => item.name == raw['kind'])
            .firstOrNull;
        if (kind == null || raw['enabled'] is! bool) return null;
        final hour = raw['hour'];
        final minute = raw['minute'];
        if (hour != null && (hour is! int || hour < 0 || hour > 23)) {
          return null;
        }
        if (minute != null && (minute is! int || minute < 0 || minute > 59)) {
          return null;
        }
      case 'review_memories':
        if (raw.isNotEmpty) return null;
      case 'prepare_local_export':
        for (final key in const ['from', 'to']) {
          final value = raw[key];
          if (value != null && !_isCanonicalDate(value)) return null;
        }
        final datasets = raw['datasets'];
        if (datasets != null) {
          if (datasets is! List || datasets.isEmpty) return null;
          const allowedDatasets = {
            'progress',
            'meal_nutrition',
            'exercise_notes',
          };
          if (datasets.any(
            (item) => item is! String || !allowedDatasets.contains(item),
          )) {
            return null;
          }
        }
        final from = raw['from'];
        final to = raw['to'];
        if (from is String && to is String) {
          final fromDate = DateTime.parse(from);
          final toDate = DateTime.parse(to);
          if (fromDate.isAfter(toDate)) return null;
        }
    }
    return Map<String, Object?>.unmodifiable(raw);
  }

  IntelligenceAction? createAction({
    required String name,
    required Map<String, Object?> arguments,
    required String label,
  }) {
    final descriptor = descriptors[name];
    final payload = validate(name, arguments);
    if (descriptor == null || payload == null) return null;
    return IntelligenceAction(
      id: name,
      toolId: name,
      type: descriptor.type,
      label: label,
      requiresConfirmation: descriptor.requiresConfirmation,
      destructive: descriptor.destructive,
      payload: payload,
    );
  }

  static bool _isCanonicalDate(Object value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return '${parsed.year.toString().padLeft(4, '0')}-'
            '${parsed.month.toString().padLeft(2, '0')}-'
            '${parsed.day.toString().padLeft(2, '0')}' ==
        value;
  }
}
