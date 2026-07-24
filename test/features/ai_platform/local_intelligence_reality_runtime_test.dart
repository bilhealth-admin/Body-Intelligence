import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_composition_root.dart';
import 'package:body_intelligence_log/features/ai_platform/services/local_intelligence_reality_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composition root exposes the canonical Reality Runtime only', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final runtime = const BilLocalIntelligenceCompositionRoot().create(
      database: database,
    );

    expect(runtime, isA<BilLocalIntelligenceRealityRuntime>());
  });
}
