import 'dart:convert';

import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('general question sends no personal category', () {
    final projection = _project('Tell me something encouraging');
    expect(projection.context.keys, <String>{'schema', 'generatedAt'});
    _expectDisclosureMatches(projection, const <String>[]);
    expect(jsonEncode(projection.context), isNot(contains('private-marker')));
  });

  test('nutrition question sends nutrition and water only', () {
    final projection = _project('How were my meals and water today?');
    expect(
      projection.context.keys,
      containsAll(<String>[
        'profile',
        'nutritionHistory',
        'waterHistory',
        'computedHealth',
      ]),
    );
    expect(
      projection.context.keys,
      isNot(containsAll(<String>['weight', 'activityHistory'])),
    );
    expect(projection.context, isNot(contains('bodyContextHistory')));
    final profile = projection.context['profile']! as Map;
    expect(profile, contains('dietaryPreferences'));
    expect(profile, isNot(contains('waistCm')));
    expect(profile, isNot(contains('email')));
    final today =
        (projection.context['computedHealth']! as Map)['today'] as Map;
    expect(today, contains('nutrition'));
    expect(today, isNot(contains('sleep')));
    expect(today, isNot(contains('exerciseEnergy')));
    _expectDisclosureMatches(projection, const <String>['nutrition_water']);
  });

  test('weight question sends body measurements and bounded weight only', () {
    final projection = _project('What is my weight progress and waist goal?');
    expect(projection.context, contains('weight'));
    expect(projection.context, contains('canonicalIntelligence'));
    expect(projection.context, isNot(contains('nutritionHistory')));
    expect(projection.context, isNot(contains('waterHistory')));
    expect(projection.context, isNot(contains('activityHistory')));
    final canonical = projection.context['canonicalIntelligence']! as Map;
    expect(canonical, contains('forecast'));
    expect(canonical, isNot(contains('primaryMessage')));
    final profile = projection.context['profile']! as Map;
    expect(profile, contains('waistCm'));
    expect(profile, isNot(contains('dietaryPreferences')));
    _expectDisclosureMatches(projection, const <String>[
      'weight_measurements_goal',
    ]);
  });

  test('sleep question strips training fields from shared activity rows', () {
    final projection = _project('Review my sleep and fasting routine');
    expect(projection.context, contains('bodyContextHistory'));
    final activity = projection.context['activityHistory']! as List;
    expect(activity.single, contains('sleepHours'));
    expect(activity.single, isNot(contains('steps')));
    expect(activity.single, isNot(contains('exercises')));
    final today =
        (projection.context['computedHealth']! as Map)['today'] as Map;
    expect(
      today.keys,
      containsAll(<String>['sleep', 'fasting', 'bodyContext']),
    );
    expect(today, isNot(contains('nutrition')));
    _expectDisclosureMatches(projection, const <String>['sleep_habits']);
  });

  test('training question strips sleep fields from shared activity rows', () {
    final projection = _project('How was my workout and step activity?');
    final activity = projection.context['activityHistory']! as List;
    expect(
      (activity.single as Map).keys,
      containsAll(<String>['steps', 'exercises']),
    );
    expect(activity.single, isNot(contains('sleepHours')));
    expect(projection.context, isNot(contains('bodyContextHistory')));
    final today =
        (projection.context['computedHealth']! as Map)['today'] as Map;
    expect(today, contains('exerciseEnergy'));
    expect(today, isNot(contains('sleep')));
    _expectDisclosureMatches(projection, const <String>['training_activity']);
  });

  test('combined question sends the exact union and disclosure', () {
    final projection = _project(
      'Does my sleep affect my workout, weight, meals, and water?',
    );
    expect(
      projection.context.keys,
      containsAll(<String>[
        'weight',
        'nutritionHistory',
        'waterHistory',
        'activityHistory',
        'bodyContextHistory',
      ]),
    );
    _expectDisclosureMatches(projection, const <String>[
      'nutrition_water',
      'sleep_habits',
      'training_activity',
      'weight_measurements_goal',
    ]);
  });

  test('short follow-up inherits only the prior user topic', () {
    final projection = projectCoachCloudContext(
      question: 'And yesterday?',
      context: _richContext(),
      conversation: const <CoachConversationTurn>[
        CoachConversationTurn(role: 'user', content: 'Review my meals'),
        CoachConversationTurn(
          role: 'assistant',
          content: 'Your weight changed',
        ),
      ],
    );
    expect(projection.context, contains('nutritionHistory'));
    expect(projection.context, isNot(contains('weight')));
    _expectDisclosureMatches(projection, const <String>['nutrition_water']);
  });

  test(
    'cloud conversation excludes prior unrelated and mixed-category turns',
    () {
      final turns = questionScopedCoachCloudConversation(
        question: 'How was my weight today?',
        conversation: const <CoachConversationTurn>[
          CoachConversationTurn(role: 'user', content: 'Review my meals'),
          CoachConversationTurn(role: 'assistant', content: 'Protein was low'),
          CoachConversationTurn(role: 'user', content: 'Review my weight'),
          CoachConversationTurn(
            role: 'assistant',
            content: 'It changed slightly',
          ),
          CoachConversationTurn(
            role: 'user',
            content: 'Compare my weight and sleep',
          ),
          CoachConversationTurn(role: 'assistant', content: 'Both improved'),
        ],
      );

      expect(turns.map((turn) => turn.content), <String>[
        'Review my weight',
        'It changed slightly',
      ]);
    },
  );

  test('classifier covers representative supported scripts', () {
    expect(
      coachCloudContextCategoriesForQuestion(question: 'راجع وزني'),
      contains(CoachCloudContextCategory.weightMeasurementsAndGoal),
    );
    expect(
      coachCloudContextCategoriesForQuestion(question: 'Analyse mon sommeil'),
      contains(CoachCloudContextCategory.sleepAndHabits),
    );
    expect(
      coachCloudContextCategoriesForQuestion(question: '我的营养怎么样'),
      contains(CoachCloudContextCategory.nutritionAndWater),
    );
    expect(
      coachCloudContextCategoriesForQuestion(question: '운동 기록 보여줘'),
      contains(CoachCloudContextCategory.trainingAndActivity),
    );
  });

  test('oversized item history never exceeds server context budget', () {
    final huge = 'x' * 5000;
    final context = CoachContextSnapshot(
      generatedAt: DateTime.utc(2026, 9, 5),
      profile: const <String, Object?>{},
      weights: const <CoachWeightPoint>[],
      nutritionDays: <CoachNutritionDay>[
        for (var index = 0; index < 7; index++)
          CoachNutritionDay(
            day: '2026-09-0${index + 1}',
            meals: <Map<String, Object?>>[
              <String, Object?>{
                'type': 'lunch',
                'items': <Map<String, Object?>>[
                  <String, Object?>{'food': huge, 'caloriesKcal': 100},
                ],
              },
            ],
            calories: 100,
            protein: 10,
            carbs: 10,
            fat: 2,
            sodium: 20,
          ),
      ],
      waterHistory: const <Map<String, Object?>>[],
      computedHealth: const <String, Object?>{},
    );
    final projection = projectCoachCloudContext(
      question: 'Review my nutrition',
      context: context,
    );
    expect(jsonEncode(projection.context).length, lessThanOrEqualTo(19000));
    _expectDisclosureMatches(projection, const <String>['nutrition_water']);
  });
}

CoachCloudContextProjection _project(String question) =>
    projectCoachCloudContext(question: question, context: _richContext());

void _expectDisclosureMatches(
  CoachCloudContextProjection projection,
  List<String> categories,
) {
  expect(projection.disclosure['categories'], categories);
  expect(
    projection.disclosure['included_context_fields'],
    (projection.context.keys.toList(growable: false)..sort()),
  );
}

CoachContextSnapshot _richContext() => CoachContextSnapshot(
  generatedAt: DateTime.utc(2026, 9, 5),
  profile: const <String, Object?>{
    'displayName': 'private-marker-name',
    'email': 'private-marker@example.com',
    'age': 35,
    'gender': 'male',
    'heightCm': 180,
    'currentWeightKg': 87,
    'targetWeightKg': 79,
    'waistCm': 94,
    'activityLevel': 'active',
    'exercises': <String>['walking'],
    'dietaryPreferences': <String, Object?>{
      'allergens': <String>['peanut'],
    },
    'selectedGoals': <String>['weight'],
    'goalConsumers': <String>['coach'],
  },
  weights: <CoachWeightPoint>[
    CoachWeightPoint(at: DateTime.utc(2026, 9, 4), kg: 87),
  ],
  nutritionDays: const <CoachNutritionDay>[
    CoachNutritionDay(
      day: '2026-09-04',
      meals: <Map<String, Object?>>[
        <String, Object?>{
          'type': 'lunch',
          'items': <Map<String, Object?>>[
            <String, Object?>{'food': 'rice', 'caloriesKcal': 200},
          ],
        },
      ],
      calories: 200,
      protein: 10,
      carbs: 30,
      fat: 4,
      sodium: 20,
    ),
  ],
  waterHistory: const <Map<String, Object?>>[
    <String, Object?>{'at': '2026-09-04T10:00:00Z', 'amountMl': 500},
  ],
  computedHealth: const <String, Object?>{
    'status': 'ready',
    'kilogramsToGoal': 8,
    'dailyTargets': <String, Object?>{'caloriesKcal': 2000},
    'today': <String, Object?>{
      'day': '2026-09-05',
      'nutrition': <String, Object?>{'caloriesKcal': 200},
      'exerciseEnergy': <String, Object?>{'verifiedBurnedKcal': 100},
      'sleep': <String, Object?>{'hours': 7},
      'fasting': <String, Object?>{'status': 'inactive'},
      'bodyContext': <String, Object?>{
        'types': <String>['stress'],
      },
    },
  },
  canonicalIntelligence: const <String, Object?>{
    'status': 'ready',
    'primaryMessage': 'private-marker-unscoped-advice',
    'forecast': <Object?>[
      <String, Object?>{'days': 30, 'projectedWeightKg': 84},
    ],
  },
  decisionMemory: const <Map<String, Object?>>[
    <String, Object?>{'title': 'weight check-in', 'response': 'accepted'},
    <String, Object?>{'title': 'meal protein', 'response': 'accepted'},
  ],
  explicitMemories: const <Map<String, Object?>>[
    <String, Object?>{'text': 'Remember my weight goal'},
    <String, Object?>{'text': 'Remember my workout preference'},
  ],
  activityHistory: const <Map<String, Object?>>[
    <String, Object?>{
      'day': '2026-09-04',
      'sleepHours': 7,
      'sleepSource': 'connected_health',
      'steps': 8000,
      'exercises': <Object?>[
        <String, Object?>{'name': 'walk'},
      ],
    },
  ],
  bodyContextHistory: const <Map<String, Object?>>[
    <String, Object?>{
      'day': '2026-09-04',
      'types': <String>['stress'],
    },
  ],
  personalExperiments: const <Map<String, Object?>>[
    <String, Object?>{'hypothesis': 'sleep routine helps'},
    <String, Object?>{'hypothesis': 'protein meal helps'},
  ],
);
