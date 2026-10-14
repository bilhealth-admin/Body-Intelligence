import 'dart:convert';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_message_presentation.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/coach_message_presentation_fixture.dart';

void main() {
  CoachMessagePresentation? decode(Object? raw) =>
      CoachMessagePresentation.tryFromArchive(
        raw,
        expectedOwnerKey: presentationFixtureOwnerKey,
      );
  test(
    'weight tap inverse uses the same painted inset and finite width guard',
    () {
      expect(coachVisualWeightTapFraction(8, 300), 0);
      expect(
        coachVisualWeightTapFraction(8 + 284 / 31, 300),
        closeTo(1 / 31, 1e-12),
      );
      expect(coachVisualWeightTapFraction(292, 300), 1);
      expect(coachVisualWeightTapFraction(0, 0), .5);
    },
  );
  test(
    'local nutrition archive roundtrip retains units known zero and unknown',
    () {
      final restored = decode(
        jsonDecode(jsonEncode(fixtureVisual().toJson())),
      )!;
      final metrics = restored.columns.single.metrics;
      expect(metrics.first.unit, 'kcal');
      expect(metrics.singleWhere((x) => x.id == 'potassium').completeValue, 0);
      expect(
        metrics.singleWhere((x) => x.id == 'magnesium').knownSubtotal,
        isNull,
      );
    },
  );
  test(
    'weight empty measurement context survives archive and UTC spacing is actual',
    () {
      final restored = decode(fixtureWeight().toJson())!;
      expect(restored.weightPoints.every((x) => x.context.isEmpty), isTrue);
      expect(
        coachVisualWeightFraction(
          restored.weightPoints[1],
          restored.weightPoints,
        ),
        closeTo(1 / 30, 1e-12),
      );
      expect(restored.weightPoints, hasLength(3));
    },
  );
  test(
    'nested caller collections are immutable and cannot alter validated facts',
    () {
      final metrics = [fixtureMetric('calories', 130)],
          sources = ['reference'],
          revisions = ['r1'];
      final column = CoachVisualNutritionColumn(
        title: 'Lunch',
        dayKey: '2026-10-09',
        capturedAtUtc: presentationFixtureClock,
        metrics: metrics,
        sourceKinds: sources,
        sourceRevisions: revisions,
      );
      metrics.clear();
      sources.clear();
      revisions.clear();
      expect(column.metrics, hasLength(1));
      expect(column.sourceKinds, ['reference']);
      expect(column.sourceRevisions, ['r1']);
      expect(() => column.metrics.clear(), throwsUnsupportedError);
    },
  );
  test('partial values do not produce complete difference or a zero', () {
    final partial = fixtureMetric('protein', 11, known: 1, missing: 1);
    expect(partial.coverage, CoachVisualCoverage.partial);
    expect(partial.completeValue, isNull);
    expect(
      coachVisualMetricDifference(partial, fixtureMetric('protein', 30)),
      isNull,
    );
    expect(
      coachVisualMetricDifference(
        fixtureMetric('protein', 11),
        fixtureMetric('protein', 30),
      ),
      19,
    );
  });
  test('foreign owner and unknown schema do not decode as local facts', () {
    expect(decode(fixtureVisual(owner: 'foreign-owner').toJson()), isNull);
    expect(
      decode({...fixtureVisual().toJson(), 'schema': 'unknown-v9'}),
      isNull,
    );
  });
  test(
    'nutrition archive cannot contain weight or mixed measurement family',
    () {
      final raw = fixtureVisual().toJson();
      final column = Map<String, Object?>.from(
        (raw['columns']! as List).single as Map,
      );
      for (final replacement in [
        {
          'id': 'weight',
          'unit': 'kg',
          'knownSubtotal': 81.4,
          'knownItems': 1,
          'missingItems': 0,
          'estimated': false,
        },
        fixtureMetric('waist', 82).toJson(),
      ]) {
        expect(
          decode({
            ...raw,
            'columns': [
              {
                ...column,
                'metrics': [replacement],
              },
            ],
          }),
          isNull,
        );
      }
    },
  );
  test('comparison cannot combine nutrition and cm metrics', () {
    final raw = fixtureVisual(
      kind: CoachVisualKind.comparison,
      columns: [
        fixtureColumn(),
        fixtureColumn(meal: 'dinner'),
      ],
    ).toJson();
    final columns = raw['columns']! as List;
    final second = Map<String, Object?>.from(columns[1] as Map);
    expect(
      decode({
        ...raw,
        'columns': [
          columns[0],
          {
            ...second,
            'metrics': [fixtureMetric('waist', 82).toJson()],
          },
        ],
      }),
      isNull,
    );
  });
  test('NaN invalid units and rolled dates cannot create a visual block', () {
    final raw = fixtureVisual().toJson();
    final column = Map<String, Object?>.from(
      (raw['columns']! as List).single as Map,
    );
    final metric = Map<String, Object?>.from(
      (column['metrics']! as List).first as Map,
    );
    for (final corrupt in [
      {...raw, 'fromDay': '2026-02-30'},
      {...raw, 'capturedAtUtc': '2026-02-30T12:00:00.000Z'},
      {
        ...raw,
        'columns': [
          {
            ...column,
            'metrics': [
              {...metric, 'unit': '%'},
            ],
          },
        ],
      },
      {
        ...raw,
        'columns': [
          {
            ...column,
            'metrics': [
              {...metric, 'knownSubtotal': double.nan},
            ],
          },
        ],
      },
    ]) {
      expect(decode(corrupt), isNull);
    }
  });
  test('source provenance summary remains honest when bounded', () {
    final column = CoachVisualNutritionColumn(
      title: 'Lunch',
      dayKey: '2026-10-09',
      capturedAtUtc: presentationFixtureClock,
      metrics: [fixtureMetric('calories', 130)],
      sourceKinds: const ['reference'],
      sourceRevisions: List.generate(30, (i) => 'r$i'),
      sourceRevisionCount: 42,
    );
    final restored = decode(fixtureVisual(columns: [column]).toJson())!;
    expect(restored.columns.single.sourceRevisionsComplete, isFalse);
    expect(restored.columns.single.sourceRevisionCount, 42);
  });
  test(
    'old and invalid same-owner messages keep readable text on reopening',
    () {
      final old = IntelligenceMessage(
        id: 'old',
        role: IntelligenceMessageRole.bil,
        kind: IntelligenceMessageKind.coach,
        text: 'A readable old reply.',
        createdAt: presentationFixtureClock,
      );
      expect(IntelligenceMessage.fromJson(old.toJson()).text, old.text);
      final raw = {
        ...old.toJson(),
        'localPresentation': {
          'schema': 'unknown-v9',
          'ownerKey': presentationFixtureOwnerKey,
        },
      };
      final restored = IntelligenceMessage.fromJson(raw);
      expect(restored.presentation, isNull);
      expect(restored.text, old.text);
      expect(restored.presentationOwnerKey, presentationFixtureOwnerKey);
    },
  );
  test('message archive copies retain attachment and foreign owner marker', () {
    final current = IntelligenceMessage(
      id: 'current',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.evidence,
      text: 'Local facts.',
      createdAt: presentationFixtureClock,
      presentation: fixtureVisual(),
    );
    final restored = IntelligenceMessage.fromJson(current.toJson());
    expect(
      restored
          .copyWith(text: 'Reworded')
          .presentation!
          .columns
          .single
          .metrics
          .first
          .completeValue,
      130,
    );
    final foreign = IntelligenceMessage.fromJson({
      ...current.toJson(),
      'localPresentation': {
        'schema': 'unknown-v9',
        'ownerKey': 'foreign-owner',
      },
    });
    expect(foreign.presentation, isNull);
    expect(
      IntelligenceMessage.fromJson(foreign.toJson()).presentationOwnerKey,
      'foreign-owner',
    );
  });
}
