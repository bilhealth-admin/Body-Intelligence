import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_reader.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final roundTrip in [false, true]) {
    test('pending context rejects owner A B roundTrip=$roundTrip', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final owner = StateProvider<String?>((ref) => 'owner-a');
      final started = Completer<void>();
      final pending = Completer<CoachContextSnapshot>();
      var cancellations = 0;
      final container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(database),
          ),
          verifiedEntitlementOwnerIdProvider.overrideWith(
            (ref) => ref.watch(owner),
          ),
          coachContextSnapshotProvider.overrideWith((ref) {
            ref.onCancel(() => cancellations++);
            started.complete();
            return pending.future;
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      final rejected = expectLater(
        readCoachContextSnapshot(container),
        throwsA(isA<StateError>()),
      );
      await started.future;
      container.read(owner.notifier).state = 'owner-b';
      await container.pump();
      if (roundTrip) {
        container.read(owner.notifier).state = 'owner-a';
        await container.pump();
      }
      await rejected;
      expect(cancellations, 1);
      pending.complete(CoachContextSnapshot.empty());
      expect(await database.select(database.weightEntries).get(), isEmpty);
    });
  }
}
