import 'dart:async';
import 'dart:typed_data';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shared avatar retains loading data across surfaces and retires A B A; explicit deletion wins',
    (tester) async {
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'A',
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'B',
      );
      final prefsA = PreferencesRepository(a),
          prefsB = PreferencesRepository(b);
      final localA = StreamController<Uint8List?>.broadcast(),
          localB = StreamController<Uint8List?>.broadcast();
      final metadata = StreamController<Map<String, String>>.broadcast();
      final localOverride = profilePhotoProvider.overrideWith(
        (ref) => ref.watch(preferencesRepositoryProvider).localOwnerId == 'A'
            ? localA.stream
            : localB.stream,
      );
      final remoteOverride = profilePhotoPublicUrlProvider.overrideWith(
        (ref) async => null,
      );
      final metadataOverride = profilePhotoMetadataProvider.overrideWith(
        (ref) => metadata.stream,
      );
      final container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(prefsA),
          verifiedEntitlementOwnerIdProvider.overrideWithValue('A'),
          localOverride,
          remoteOverride,
          metadataOverride,
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (_, ref, _) {
              final state = ref.watch(profileAvatarStateProvider);
              return Text(
                '${state.owner}:${state.bytes?.length}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      localA.add(bytes);
      metadata.add({});
      await tester.pump();
      expect(container.read(profileAvatarStateProvider).bytes, same(bytes));
      container.invalidate(profilePhotoProvider);
      await tester.pump();
      expect(container.read(profileAvatarStateProvider).bytes, same(bytes));
      metadata.add({'profilePhotoDeleted': 'true'});
      await tester.pump();
      expect(container.read(profileAvatarStateProvider).bytes, isNull);
      metadata.add({});
      localA.add(bytes);
      await tester.pump();
      for (final pair in [(prefsB, 'B'), (prefsA, 'A')]) {
        container.updateOverrides([
          preferencesRepositoryProvider.overrideWithValue(pair.$1),
          verifiedEntitlementOwnerIdProvider.overrideWithValue(pair.$2),
          localOverride,
          remoteOverride,
          metadataOverride,
        ]);
        await tester.pump();
        expect(container.read(profileAvatarStateProvider).bytes, isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await localA.close();
      await localB.close();
      await metadata.close();
      await a.close();
      await b.close();
    },
  );
}
