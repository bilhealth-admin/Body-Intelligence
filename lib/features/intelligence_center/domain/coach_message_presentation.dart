// Optional local archive attachment. Remote gateway never decodes this type.
import 'food_v2/coach_food_v2.dart';

enum CoachVisualKind { nutrition, comparison, measurement, weight }

enum CoachVisualCoverage { complete, partial, unavailable }

final class CoachVisualMetric {
  const CoachVisualMetric._({
    required this.id,
    required this.unit,
    required this.knownSubtotal,
    required this.knownItems,
    required this.missingItems,
    required this.estimated,
  });

  static final units = Map<String, String>.unmodifiable(<String, String>{
    for (final entry in CoachFoodNutrients.units.entries)
      entry.key.name: entry.value,
    'netCarbohydrates': 'g',
    'neck': 'cm',
    'waist': 'cm',
    'hips': 'cm',
    'chest': 'cm',
    'arm': 'cm',
    'thigh': 'cm',
  });

  final String id, unit;
  final double? knownSubtotal;
  final int knownItems, missingItems;
  final bool estimated;

  CoachVisualCoverage get coverage => knownItems == 0
      ? CoachVisualCoverage.unavailable
      : missingItems == 0
      ? CoachVisualCoverage.complete
      : CoachVisualCoverage.partial;
  double? get completeValue =>
      coverage == CoachVisualCoverage.complete ? knownSubtotal : null;

  factory CoachVisualMetric.localRead({
    required String id,
    required double? knownSubtotal,
    required int knownItems,
    required int missingItems,
    bool estimated = false,
  }) {
    final unit = units[id];
    if (unit == null ||
        knownItems < 0 ||
        missingItems < 0 ||
        knownItems + missingItems > 10000 ||
        (knownItems == 0) != (knownSubtotal == null) ||
        (knownSubtotal != null &&
            (!knownSubtotal.isFinite || knownSubtotal < 0))) {
      throw const FormatException('Invalid local metric');
    }
    return CoachVisualMetric._(
      id: id,
      unit: unit,
      knownSubtotal: knownSubtotal,
      knownItems: knownItems,
      missingItems: missingItems,
      estimated: estimated,
    );
  }

  factory CoachVisualMetric.fromArchive(Object? raw) {
    final map = _object(raw);
    final id = _text(map['id'], 60);
    if (map['unit'] != units[id] || map['estimated'] is! bool) {
      throw const FormatException('Invalid metric unit');
    }
    return CoachVisualMetric.localRead(
      id: id,
      knownSubtotal: _optionalFinite(map['knownSubtotal']),
      knownItems: _integer(map['knownItems']),
      missingItems: _integer(map['missingItems']),
      estimated: map['estimated']! as bool,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'unit': unit,
    'knownSubtotal': knownSubtotal,
    'knownItems': knownItems,
    'missingItems': missingItems,
    'estimated': estimated,
  };
}

final class CoachVisualNutritionColumn {
  CoachVisualNutritionColumn({
    required this.title,
    required this.dayKey,
    required List<CoachVisualMetric> metrics,
    required List<String> sourceKinds,
    required this.capturedAtUtc,
    this.mealType,
    List<String> sourceRevisions = const [],
    int? sourceRevisionCount,
  }) : metrics = List.unmodifiable(metrics),
       sourceKinds = List.unmodifiable(sourceKinds),
       sourceRevisions = List.unmodifiable(sourceRevisions),
       sourceRevisionCount = sourceRevisionCount ?? sourceRevisions.length {
    _text(title, 500);
    _day(dayKey);
    if (!capturedAtUtc.isUtc ||
        metrics.isEmpty ||
        metrics.length > 26 ||
        metrics.map((x) => x.id).toSet().length != metrics.length ||
        sourceKinds.length > 30 ||
        sourceRevisions.length > 30 ||
        this.sourceRevisionCount < sourceRevisions.length ||
        this.sourceRevisionCount > 10000) {
      throw const FormatException('Invalid local column');
    }
    for (final source in [...sourceKinds, ...sourceRevisions]) {
      _text(source, 120);
    }
    if (mealType != null &&
        !const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw const FormatException('Invalid meal type');
    }
  }

  final String title, dayKey;
  final String? mealType;
  final List<CoachVisualMetric> metrics;
  // Source attribution from actual evidence, not rendered as URLs automatically.
  final List<String> sourceKinds, sourceRevisions;
  final int sourceRevisionCount;
  bool get sourceRevisionsComplete =>
      sourceRevisionCount == sourceRevisions.length;
  final DateTime capturedAtUtc;

  factory CoachVisualNutritionColumn.fromArchive(Object? raw) {
    final map = _object(raw);
    return CoachVisualNutritionColumn(
      title: _text(map['title'], 500),
      dayKey: _day(map['dayKey']),
      mealType: map['mealType'] as String?,
      metrics: _boundedList(
        map['metrics'],
        26,
      ).map(CoachVisualMetric.fromArchive).toList(growable: false),
      sourceKinds: _boundedList(
        map['sourceKinds'],
        30,
      ).map((x) => _text(x, 120)).toList(growable: false),
      sourceRevisionCount: map['sourceRevisionCount'] == null
          ? null
          : _integer(map['sourceRevisionCount']),
      sourceRevisions: _boundedList(
        map['sourceRevisions'],
        30,
      ).map((x) => _text(x, 120)).toList(growable: false),
      capturedAtUtc: _utc(map['capturedAtUtc']),
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'dayKey': dayKey,
    'mealType': mealType,
    'metrics': metrics.map((x) => x.toJson()).toList(growable: false),
    'sourceKinds': sourceKinds,
    'sourceRevisions': sourceRevisions,
    'sourceRevisionCount': sourceRevisionCount,
    'capturedAtUtc': capturedAtUtc.toIso8601String(),
  };
}

final class CoachVisualWeightPoint {
  CoachVisualWeightPoint({
    required this.recordedAtUtc,
    required this.dayKey,
    required this.kg,
    required this.context,
  }) {
    _day(dayKey);
    if (!recordedAtUtc.isUtc ||
        !kg.isFinite ||
        kg < 20 ||
        kg > 500 ||
        context.length > 120) {
      throw const FormatException('Invalid weight point');
    }
  }
  final DateTime recordedAtUtc;
  final String dayKey;
  final double kg;
  // Actual repository measurementContext; unknown context is not invented.
  final String context;

  factory CoachVisualWeightPoint.fromArchive(Object? raw) {
    final map = _object(raw);
    return CoachVisualWeightPoint(
      recordedAtUtc: _utc(map['recordedAtUtc']),
      dayKey: _day(map['dayKey']),
      kg:
          _optionalFinite(map['kg']) ??
          (throw const FormatException('Missing weight')),
      context: map['context'] == null
          ? ''
          : map['context'] is String &&
                (map['context']! as String).length <= 120
          ? map['context']! as String
          : throw const FormatException('Invalid context'),
    );
  }

  Map<String, Object?> toJson() => {
    'recordedAtUtc': recordedAtUtc.toIso8601String(),
    'dayKey': dayKey,
    'kg': kg,
    'context': context,
  };
}

final class CoachMessagePresentation {
  CoachMessagePresentation._({
    required this.ownerKey,
    required this.capturedAtUtc,
    required this.kind,
    required this.title,
    required this.fromDay,
    required this.throughDay,
    required this.columns,
    required this.weightPoints,
    required this.notes,
  });

  static const schema = 'bil.coach.message.presentation.v1';
  final String ownerKey, title, fromDay, throughDay;
  final DateTime capturedAtUtc;
  final CoachVisualKind kind;
  final List<CoachVisualNutritionColumn> columns;
  final List<CoachVisualWeightPoint> weightPoints;
  final List<String> notes;

  factory CoachMessagePresentation.localRead({
    required String ownerKey,
    required DateTime capturedAtUtc,
    required CoachVisualKind kind,
    required String title,
    required String fromDay,
    required String throughDay,
    List<CoachVisualNutritionColumn> columns = const [],
    List<CoachVisualWeightPoint> weightPoints = const [],
    List<String> notes = const [],
  }) {
    _text(ownerKey, 200);
    _text(title, 500);
    if (notes.length > 10) {
      throw const FormatException('Too many context notes');
    }
    for (final note in notes) {
      _text(note, 1000);
    }
    _day(fromDay);
    _day(throughDay);
    if (!capturedAtUtc.isUtc ||
        fromDay.compareTo(throughDay) > 0 ||
        DateTime.parse(throughDay).difference(DateTime.parse(fromDay)).inDays >
            30 ||
        columns.length > 31 ||
        weightPoints.length > 31) {
      throw const FormatException('Invalid local presentation period');
    }
    switch (kind) {
      case CoachVisualKind.nutrition:
      case CoachVisualKind.measurement:
        if (columns.length != 1 || weightPoints.isNotEmpty) {
          throw const FormatException('Invalid nutrition presentation');
        }
      case CoachVisualKind.comparison:
        if (columns.length < 2 || weightPoints.isNotEmpty) {
          throw const FormatException('Invalid comparison presentation');
        }
      case CoachVisualKind.weight:
        if (weightPoints.isEmpty || columns.isNotEmpty) {
          throw const FormatException('Invalid weight presentation');
        }
    }
    final nutritionIds = {
      ...FoodNutrient.values.map((x) => x.name),
      'netCarbohydrates',
    };
    const measurementIds = {'neck', 'waist', 'hips', 'chest', 'arm', 'thigh'};
    bool nutritionColumn(CoachVisualNutritionColumn column) =>
        column.metrics.every((metric) => nutritionIds.contains(metric.id));
    bool measurementColumn(CoachVisualNutritionColumn column) =>
        column.metrics.every((metric) => measurementIds.contains(metric.id));
    final familyValid = switch (kind) {
      CoachVisualKind.nutrition => columns.every(nutritionColumn),
      CoachVisualKind.measurement => columns.every(measurementColumn),
      CoachVisualKind.comparison =>
        columns.every(nutritionColumn) || columns.every(measurementColumn),
      CoachVisualKind.weight => columns.isEmpty,
    };
    if (!familyValid) throw const FormatException('Incompatible metric family');
    for (final column in columns) {
      if (column.dayKey.compareTo(fromDay) < 0 ||
          column.dayKey.compareTo(throughDay) > 0) {
        throw const FormatException('Column outside period');
      }
    }
    DateTime? previous;
    final seen = <DateTime>{};
    for (final point in weightPoints) {
      if (point.dayKey.compareTo(fromDay) < 0 ||
          point.dayKey.compareTo(throughDay) > 0 ||
          !seen.add(point.recordedAtUtc) ||
          (previous != null && !point.recordedAtUtc.isAfter(previous))) {
        throw const FormatException('Unordered weight points');
      }
      previous = point.recordedAtUtc;
    }
    return CoachMessagePresentation._(
      ownerKey: ownerKey,
      capturedAtUtc: capturedAtUtc,
      kind: kind,
      title: title,
      fromDay: fromDay,
      throughDay: throughDay,
      columns: List.unmodifiable(columns),
      weightPoints: List.unmodifiable(weightPoints),
      notes: List.unmodifiable(notes),
    );
  }

  /// Restore ONLY from an owner-scoped local conversation archive.
  /// Unknown/invalid attachment cannot damage the existing readable text.
  static CoachMessagePresentation? tryFromArchive(
    Object? raw, {
    required String expectedOwnerKey,
  }) {
    try {
      final map = _object(raw);
      if (map['schema'] != schema || map['ownerKey'] != expectedOwnerKey) {
        return null;
      }
      return CoachMessagePresentation.localRead(
        ownerKey: _text(map['ownerKey'], 200),
        capturedAtUtc: _utc(map['capturedAtUtc']),
        kind: CoachVisualKind.values.byName(_text(map['kind'], 30)),
        title: _text(map['title'], 500),
        fromDay: _day(map['fromDay']),
        throughDay: _day(map['throughDay']),
        notes: map['notes'] == null
            ? const []
            : _boundedList(
                map['notes'],
                10,
              ).map((x) => _text(x, 1000)).toList(growable: false),
        columns: _boundedList(
          map['columns'],
          31,
        ).map(CoachVisualNutritionColumn.fromArchive).toList(growable: false),
        weightPoints: _boundedList(
          map['weightPoints'],
          31,
        ).map(CoachVisualWeightPoint.fromArchive).toList(growable: false),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    'ownerKey': ownerKey,
    'capturedAtUtc': capturedAtUtc.toIso8601String(),
    'kind': kind.name,
    'title': title,
    'fromDay': fromDay,
    'throughDay': throughDay,
    'notes': notes,
    'columns': columns.map((x) => x.toJson()).toList(growable: false),
    'weightPoints': weightPoints.map((x) => x.toJson()).toList(growable: false),
  };
}

// All arithmetic is presentation of two actual compatible facts, never parsing
// numbers in model prose and never inventing a goal/weight/measurement.
double? coachVisualMetricDifference(
  CoachVisualMetric first,
  CoachVisualMetric second,
) {
  if (first.id != second.id || first.unit != second.unit) return null;
  final a = first.completeValue, b = second.completeValue;
  if (a == null || b == null) return null;
  final value = b - a;
  return value.isFinite ? value : null;
}

/// Real UTC spacing; missing civil days remain gaps, not invented zero points.
double coachVisualWeightFraction(
  CoachVisualWeightPoint point,
  List<CoachVisualWeightPoint> ordered,
) {
  if (ordered.length < 2) return .5;
  final start = ordered.first.recordedAtUtc.microsecondsSinceEpoch;
  final span = ordered.last.recordedAtUtc.microsecondsSinceEpoch - start;
  if (span <= 0) return .5;
  return (point.recordedAtUtc.microsecondsSinceEpoch - start) / span;
}

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map || raw.length > 30 || raw.keys.any((x) => x is! String)) {
    throw const FormatException('Invalid attachment object');
  }
  return Map<String, Object?>.from(raw);
}

List<Object?> _boundedList(Object? raw, int maximum) {
  if (raw is! List || raw.length > maximum) {
    throw const FormatException('Invalid attachment list');
  }
  return List<Object?>.from(raw);
}

String _text(Object? raw, int maximum) {
  if (raw is! String || raw.trim().isEmpty || raw.length > maximum) {
    throw const FormatException('Invalid attachment text');
  }
  return raw;
}

int _integer(Object? raw) {
  if (raw is! int) throw const FormatException('Invalid attachment count');
  return raw;
}

double? _optionalFinite(Object? raw) {
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite) {
    throw const FormatException('Invalid attachment number');
  }
  return raw.toDouble();
}

DateTime _utc(Object? raw) {
  final text = _text(raw, 40);
  if (!text.endsWith('Z')) throw const FormatException('Expected UTC date');
  final value = DateTime.parse(text);
  if (!value.isUtc ||
      text.length < 20 ||
      value.toIso8601String().substring(0, 19) != text.substring(0, 19)) {
    throw const FormatException('Invalid UTC date');
  }
  return value;
}

String _day(Object? raw) {
  final text = _text(raw, 10);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    throw const FormatException('Invalid civil day');
  }
  final value = DateTime.parse(text);
  if (value.toIso8601String().split('T').first != text) {
    throw const FormatException('Invalid civil day');
  }
  return text;
}

const coachVisualWeightChartInset = 8.0;
double coachVisualWeightTapFraction(double dx, double width) {
  if (!dx.isFinite ||
      !width.isFinite ||
      width <= 2 * coachVisualWeightChartInset) {
    return .5;
  }
  return ((dx - coachVisualWeightChartInset) /
          (width - 2 * coachVisualWeightChartInset))
      .clamp(0, 1)
      .toDouble();
}
