import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final goalStart = DateTime.utc(2026, 8, 1);
  final samples = <({DateTime date, double weight})>[
    (date: DateTime.utc(2026, 8, 10), weight: 78),
    (date: DateTime.utc(2026, 8, 2), weight: 80),
    (date: DateTime.utc(2026, 7, 1), weight: 90),
  ];

  test('lose progress uses first weight inside current goal only', () {
    expect(
      profileWeightProgress(
        goalType: 'lose',
        goalCreatedAt: goalStart,
        weightsNewestFirst: samples,
      ),
      2,
    );
  });

  test('gain and maintain directions are calculated honestly', () {
    final gain = <({DateTime date, double weight})>[
      (date: DateTime.utc(2026, 8, 10), weight: 82),
      (date: DateTime.utc(2026, 8, 2), weight: 80),
    ];
    expect(
      profileWeightProgress(
        goalType: 'gain',
        goalCreatedAt: goalStart,
        weightsNewestFirst: gain,
      ),
      2,
    );
    expect(
      profileWeightProgress(
        goalType: 'maintain',
        goalCreatedAt: goalStart,
        weightsNewestFirst: gain,
      ),
      2,
    );
  });

  test('fewer than two current-goal weights reports unavailable', () {
    expect(
      profileWeightProgress(
        goalType: 'lose',
        goalCreatedAt: DateTime.utc(2026, 8, 5),
        weightsNewestFirst: samples,
      ),
      isNull,
    );
  });
}
