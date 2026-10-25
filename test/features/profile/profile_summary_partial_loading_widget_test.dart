import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'secondary loading/error does not hide available profile and owner avatar',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'synthetic-owner',
      );
      addTearDown(db.close);
      final preferences = PreferencesRepository(db);
      final friendsPending = Completer<int?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(preferences),
            verifiedEntitlementOwnerIdProvider.overrideWithValue(
              'synthetic-owner',
            ),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            displayNameProvider.overrideWith(
              (ref) => Stream.value('Synthetic member'),
            ),
            weightHistoryProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
            measurementSystemProvider.overrideWith(
              (ref) => Stream.value(MeasurementSystem.metric),
            ),
            profileFriendsCountProvider.overrideWith(
              (ref) => friendsPending.future,
            ),
            profileMemberSinceProvider.overrideWithValue(null),
            profilePhotoProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            profilePhotoMetadataProvider.overrideWith(
              (ref) => Stream.value(<String, String>{}),
            ),
            profilePhotoPublicUrlProvider.overrideWith(
              (ref) async => null,
            ),
            verifiedSubscriptionAccessProvider.overrideWithValue(
              AsyncData(
                SubscriptionState(
                  plan: CommercePlan.premium,
                  entitlements: const {},
                  authority: EntitlementAuthority.verifiedServer,
                  isPurchasable: false,
                  canRestorePurchases: false,
                  currentPeriodEndsAt: DateTime(2027),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: const ProfileSummaryPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      // Friends and weights are still pending, but the primary page is usable.
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Synthetic member'), findsWidgets);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bil-profile-details-retry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      friendsPending.completeError(StateError('synthetic network failure'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bil-profile-details-retry')),
        findsOneWidget,
      );
      expect(find.text('Synthetic member'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
