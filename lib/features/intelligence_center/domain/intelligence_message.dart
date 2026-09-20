import 'bil_navigation_registry.dart';
import 'intelligence_action.dart';

enum IntelligenceMessageRole { bil, user }

/// The interaction contract is intentionally explicit: typed turns stay
/// visual, voice turns remain readable while live-call speech is automatic,
/// and camera turns stay visual. Voice text is retained locally for the visible transcript and the
/// bounded conversation context.
enum IntelligenceMessageModality { text, voice, image, system }

enum IntelligenceMessageKind {
  coach,
  freeQuestion,
  evidence,
  action,
  memory,
  safety,
}

enum IntelligenceMessageLinkKind { recipe, workout }

/// A replayable, app-owned action attached to a saved coach message.
///
/// This is deliberately narrower than [IntelligenceAction]. Navigation and
/// read-only actions can cross the local conversation persistence boundary.
/// The narrowly validated `updateGoal` proposal can also survive briefly so a
/// user does not lose an unconfirmed goal change by dismissing the sheet,
/// leaving the screen, or restarting the app. Every restored goal proposal is
/// forced back through confirmation and expires after 24 hours. All other
/// writes and every destructive operation remain transient.
class IntelligenceMessageAction {
  const IntelligenceMessageAction._({
    required this.id,
    required this.label,
    required this.type,
    required this.payload,
    required this.requiresConfirmation,
    this.expiresAt,
  });

  final String id;
  final String label;
  final IntelligenceActionType type;
  final Map<String, Object?> payload;
  final bool requiresConfirmation;
  final DateTime? expiresAt;

  static final RegExp _safeId = RegExp(r'^[a-zA-Z0-9._:-]{1,160}$');
  static const Set<String> _dailyLogActions = <String>{
    'barcode',
    'voice',
    'photo',
    'water',
    'notes',
    'exercise',
  };

  /// Converts an already validated runtime action into a durable shortcut.
  ///
  /// Returns null for destructive actions, writes other than the narrowly
  /// bounded goal proposal, or arguments that cannot be reduced to the local
  /// allow-list.
  static IntelligenceMessageAction? fromAction(
    IntelligenceAction action, {
    DateTime? now,
  }) {
    if (action.destructive) return null;
    final label = action.label.trim();
    if (!_safeId.hasMatch(action.id) || !_isSafeLabel(label)) return null;
    final payload = _safePayloadFor(
      action.type,
      action.payload,
      allowDiscardedPresentationArguments: true,
    );
    if (payload == null) return null;
    return IntelligenceMessageAction._(
      id: action.id,
      label: label,
      type: action.type,
      payload: payload,
      requiresConfirmation:
          action.type == IntelligenceActionType.updateGoal ||
          action.requiresConfirmation,
      expiresAt: action.type == IntelligenceActionType.updateGoal
          ? (now ?? DateTime.now()).toUtc().add(const Duration(hours: 24))
          : null,
    );
  }

  /// Restores only an action that still matches today's local allow-list.
  ///
  /// A modified preferences row cannot introduce a raw route or replay an
  /// arbitrary write: unexpected keys/types are rejected, and the sole
  /// durable write proposal is short-lived and confirmation-gated.
  static IntelligenceMessageAction? tryFromJson(
    Map<String, Object?> json, {
    DateTime? now,
  }) {
    final id = json['id']?.toString() ?? '';
    final label = json['label']?.toString().trim() ?? '';
    final rawType = json['type']?.toString();
    final rawRequiresConfirmation = json['requiresConfirmation'];
    final rawExpiresAt = json['expiresAt'];
    final type = IntelligenceActionType.values
        .cast<IntelligenceActionType?>()
        .firstWhere((value) => value?.name == rawType, orElse: () => null);
    if (!_safeId.hasMatch(id) ||
        !_isSafeLabel(label) ||
        type == null ||
        (rawRequiresConfirmation != null && rawRequiresConfirmation is! bool)) {
      return null;
    }
    final rawPayload = json['payload'];
    if (rawPayload != null && rawPayload is! Map) return null;
    if (rawPayload is Map && !rawPayload.keys.every((key) => key is String)) {
      return null;
    }
    final payload = _safePayloadFor(
      type,
      rawPayload == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(rawPayload as Map),
      allowDiscardedPresentationArguments: false,
    );
    if (payload == null) return null;
    DateTime? expiresAt;
    if (type == IntelligenceActionType.updateGoal) {
      if (rawExpiresAt is! String) return null;
      expiresAt = DateTime.tryParse(rawExpiresAt)?.toUtc();
      final current = (now ?? DateTime.now()).toUtc();
      if (expiresAt == null || !expiresAt.isAfter(current)) return null;
      // Refuse a tampered proposal with an effectively unbounded lifetime.
      if (expiresAt.difference(current) > const Duration(hours: 24)) {
        return null;
      }
    } else if (rawExpiresAt != null) {
      return null;
    }
    return IntelligenceMessageAction._(
      id: id,
      label: label,
      type: type,
      payload: payload,
      // Subscription management keeps its existing explicit confirmation
      // even if a local preferences record is modified. Other navigation can
      // safely retain a stricter confirmation bit from the original reply.
      requiresConfirmation:
          type == IntelligenceActionType.manageSubscription ||
          type == IntelligenceActionType.updateGoal ||
          rawRequiresConfirmation == true,
      expiresAt: expiresAt,
    );
  }

  bool get isTrusted => isTrustedAt(DateTime.now());

  bool isTrustedAt(DateTime now) =>
      _safeId.hasMatch(id) &&
      _isSafeLabel(label) &&
      (!const {
            IntelligenceActionType.manageSubscription,
            IntelligenceActionType.updateGoal,
          }.contains(type) ||
          requiresConfirmation) &&
      (expiresAt == null || expiresAt!.toUtc().isAfter(now.toUtc())) &&
      _safePayloadFor(
            type,
            payload,
            allowDiscardedPresentationArguments: false,
          ) !=
          null;

  IntelligenceAction toAction() => IntelligenceAction(
    id: id,
    type: type,
    label: label,
    requiresConfirmation: requiresConfirmation,
    payload: payload,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'type': type.name,
    'payload': payload,
    'requiresConfirmation': requiresConfirmation,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
  };

  static bool _isSafeLabel(String value) =>
      value.isNotEmpty &&
      value.length <= 240 &&
      !value.contains(
        RegExp(r'[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]'),
      );

  static Map<String, Object?>? _safePayloadFor(
    IntelligenceActionType type,
    Map<String, Object?> raw, {
    required bool allowDiscardedPresentationArguments,
  }) {
    switch (type) {
      case IntelligenceActionType.navigate:
        if (raw.length != 1) return null;
        final target = raw['target']?.toString();
        if (target == null ||
            !BilNavigationRegistry.targets.containsKey(target)) {
          return null;
        }
        return Map<String, Object?>.unmodifiable(<String, Object?>{
          'target': target,
        });
      case IntelligenceActionType.readNutritionRemaining:
      case IntelligenceActionType.readProfileIdentity:
        if (raw.isNotEmpty) return null;
        return const <String, Object?>{};
      case IntelligenceActionType.openDailyLog:
        if (raw.isEmpty) return const <String, Object?>{};
        if (raw.length != 1 || !_dailyLogActions.contains(raw['action'])) {
          return null;
        }
        return Map<String, Object?>.unmodifiable(<String, Object?>{
          'action': raw['action'],
        });
      case IntelligenceActionType.addWeight:
        // addWeight without a value only opens the check-in screen. Any value
        // would turn this into a write and therefore cannot be persisted.
        if (raw.isNotEmpty) return null;
        return const <String, Object?>{};
      case IntelligenceActionType.reviewMeal:
        final dayOffset = raw['dayOffset'];
        if (dayOffset != null &&
            (dayOffset is! int || dayOffset < -31 || dayOffset > 31)) {
          return null;
        }
        final allowedKeys = allowDiscardedPresentationArguments
            ? const <String>{'dayOffset', 'query'}
            : const <String>{'dayOffset'};
        if (!raw.keys.every(allowedKeys.contains)) return null;
        return Map<String, Object?>.unmodifiable(<String, Object?>{
          'dayOffset': ?dayOffset,
        });
      case IntelligenceActionType.reviewWorkout:
        if (raw.isNotEmpty &&
            !(allowDiscardedPresentationArguments &&
                raw.keys.every(const <String>{'query'}.contains))) {
          return null;
        }
        return const <String, Object?>{};
      case IntelligenceActionType.openPlan:
      case IntelligenceActionType.openReport:
      case IntelligenceActionType.openAiCoachSubscription:
      case IntelligenceActionType.buyAiBoost:
      case IntelligenceActionType.manageSubscription:
        if (raw.isNotEmpty) return null;
        return const <String, Object?>{};
      case IntelligenceActionType.setThemeMode:
      case IntelligenceActionType.setLanguage:
      case IntelligenceActionType.addWater:
      case IntelligenceActionType.saveMeasurements:
      case IntelligenceActionType.quickAddMacros:
      case IntelligenceActionType.updateMealItem:
      case IntelligenceActionType.moveMealItem:
      case IntelligenceActionType.deleteMealItem:
      case IntelligenceActionType.requestAccountDeletion:
      case IntelligenceActionType.updateGoal:
        if (!raw.keys.every(
          const <String>{'targetWeightKg', 'targetDate'}.contains,
        )) {
          return null;
        }
        final target = raw['targetWeightKg'];
        if (target is! num ||
            !target.toDouble().isFinite ||
            target < 20 ||
            target > 500) {
          return null;
        }
        final rawDate = raw['targetDate'];
        String? targetDate;
        if (rawDate != null) {
          if (rawDate is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)) {
            return null;
          }
          final parsed = DateTime.tryParse(rawDate);
          if (parsed == null ||
              '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
                  rawDate) {
            return null;
          }
          targetDate = rawDate;
        }
        final validated = <String, Object?>{
          'targetWeightKg': target.toDouble(),
        };
        if (targetDate != null) validated['targetDate'] = targetDate;
        return Map<String, Object?>.unmodifiable(validated);
      case IntelligenceActionType.saveMemory:
        return null;
    }
  }
}

/// A catalog-grounded, app-local destination attached to a coach reply.
///
/// Only the two verified wellness libraries are accepted. This prevents a
/// restored conversation from turning arbitrary persisted text into an
/// external link or an unrelated in-app route.
class IntelligenceMessageLink {
  const IntelligenceMessageLink({
    required this.id,
    required this.label,
    required this.route,
    required this.kind,
  });

  final String id;
  final String label;
  final String route;
  final IntelligenceMessageLinkKind kind;

  bool get isTrustedLocalRoute {
    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
    final expectedPath = switch (kind) {
      IntelligenceMessageLinkKind.recipe => '/wellness/recipes',
      IntelligenceMessageLinkKind.workout => '/wellness/workouts/routines',
    };
    final queryKey = switch (kind) {
      IntelligenceMessageLinkKind.recipe => 'recipe',
      IntelligenceMessageLinkKind.workout => 'item',
    };
    final targetId = uri.queryParameters[queryKey];
    return uri.path == expectedPath &&
        targetId == id &&
        RegExp(r'^[a-zA-Z0-9._:-]{1,160}$').hasMatch(id);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'route': route,
    'kind': kind.name,
  };

  factory IntelligenceMessageLink.fromJson(Map<String, Object?> json) =>
      IntelligenceMessageLink(
        id: json['id'] as String,
        label: json['label'] as String,
        route: json['route'] as String,
        kind: IntelligenceMessageLinkKind.values.byName(json['kind'] as String),
      );
}

List<IntelligenceMessageAction> _decodeMessageActionLinks(Object? raw) {
  if (raw is! List) return const <IntelligenceMessageAction>[];
  final restored = <IntelligenceMessageAction>[];
  for (final value in raw.whereType<Map>()) {
    if (!value.keys.every((key) => key is String)) continue;
    final action = IntelligenceMessageAction.tryFromJson(
      Map<String, Object?>.from(value),
    );
    if (action != null) restored.add(action);
  }
  return List<IntelligenceMessageAction>.unmodifiable(restored);
}

class IntelligenceMessage {
  const IntelligenceMessage({
    required this.id,
    required this.role,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.evidence = const <String>[],
    this.confidence,
    this.actionId,
    this.memoryCandidate,
    this.reason,
    this.missingData = const <String>[],
    this.modality = IntelligenceMessageModality.text,
    this.links = const <IntelligenceMessageLink>[],
    this.actionLinks = const <IntelligenceMessageAction>[],
  });

  final String id;
  final IntelligenceMessageRole role;
  final IntelligenceMessageKind kind;
  final String text;
  final DateTime createdAt;
  final List<String> evidence;
  final double? confidence;
  final String? actionId;
  final String? memoryCandidate;
  final String? reason;
  final List<String> missingData;
  final IntelligenceMessageModality modality;
  final List<IntelligenceMessageLink> links;
  final List<IntelligenceMessageAction> actionLinks;

  IntelligenceMessage copyWith({
    IntelligenceMessageRole? role,
    IntelligenceMessageKind? kind,
    String? text,
    DateTime? createdAt,
    List<String>? evidence,
    double? confidence,
    String? actionId,
    String? memoryCandidate,
    String? reason,
    List<String>? missingData,
    IntelligenceMessageModality? modality,
    List<IntelligenceMessageLink>? links,
    List<IntelligenceMessageAction>? actionLinks,
  }) => IntelligenceMessage(
    id: id,
    role: role ?? this.role,
    kind: kind ?? this.kind,
    text: text ?? this.text,
    createdAt: createdAt ?? this.createdAt,
    evidence: evidence ?? this.evidence,
    confidence: confidence ?? this.confidence,
    actionId: actionId ?? this.actionId,
    memoryCandidate: memoryCandidate ?? this.memoryCandidate,
    reason: reason ?? this.reason,
    missingData: missingData ?? this.missingData,
    modality: modality ?? this.modality,
    links: links ?? this.links,
    actionLinks: actionLinks ?? this.actionLinks,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'kind': kind.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'evidence': evidence,
    'confidence': confidence,
    'actionId': actionId,
    'memoryCandidate': memoryCandidate,
    'reason': reason,
    'missingData': missingData,
    'modality': modality.name,
    'links': links.map((link) => link.toJson()).toList(growable: false),
    'actionLinks': actionLinks
        .where((action) => action.isTrusted)
        .map((action) => action.toJson())
        .toList(growable: false),
  };

  factory IntelligenceMessage.fromJson(Map<String, Object?> json) =>
      IntelligenceMessage(
        id: json['id'] as String,
        role: IntelligenceMessageRole.values.byName(json['role'] as String),
        kind: IntelligenceMessageKind.values.byName(json['kind'] as String),
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        evidence: (json['evidence'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        confidence: (json['confidence'] as num?)?.toDouble(),
        actionId: json['actionId'] as String?,
        memoryCandidate: json['memoryCandidate'] as String?,
        reason: json['reason'] as String?,
        missingData: (json['missingData'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        modality: IntelligenceMessageModality.values.firstWhere(
          (value) => value.name == json['modality'],
          orElse: () => IntelligenceMessageModality.text,
        ),
        links: (json['links'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map>()
            .map(
              (value) => IntelligenceMessageLink.fromJson(
                Map<String, Object?>.from(value),
              ),
            )
            .where((link) => link.isTrustedLocalRoute)
            .toList(growable: false),
        // Missing actionLinks is the V1 conversation shape and intentionally
        // migrates to an empty list. `suggestedActions` is accepted as a
        // short-lived pre-release alias so no tester transcript is lost.
        actionLinks: _decodeMessageActionLinks(
          json['actionLinks'] ?? json['suggestedActions'],
        ),
      );
}
