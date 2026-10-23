import 'dart:io';
import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/startup/startup_page.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('support categories never expose native messages, codes or payloads', () {
    final errors = <Object>[
      TimeoutException('private timeout context'),
      MissingPluginException('private plugin details'),
      PlatformException(
        code: 'health_backup_exclusion_failed',
        message: 'private path',
      ),
      PlatformException(
        code: 'system_crypto_failed',
        details: {'key': 'private key'},
      ),
      PlatformException(
        code: 'private account or native code',
        message: 'private message',
      ),
      const FormatException('private payload'),
      StateError('private database details'),
    ];
    for (final error in errors) {
      for (final cloud in [false, true]) {
        final code = startupFailureSupportCode(
          cloudRecovery: cloud,
          error: error,
        );
        expect(
          code,
          matches(
            RegExp(
              r'^BIL-S-(LOCAL|CLOUD)-(TIMEOUT|BRIDGE|PRIVACY|CRYPTO|PLATFORM|FORMAT|UNAVAILABLE)$',
            ),
          ),
        );
        expect(code, isNot(contains('private')));
      }
    }
  });
  test(
    'failed opener stays failed until the connection is recreated; saved rows survive',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'bil-startup-retry-',
      );
      final file = File('${folder.path}/existing.sqlite');
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed
          .into(seed.preferences)
          .insert(
            PreferencesCompanion.insert(
              key: 'retained-test-value',
              value: 'saved',
            ),
          );
      await seed
          .into(seed.weightEntries)
          .insert(
            WeightEntriesCompanion.insert(
              uuid: const Value('retained-test-weight'),
              weight: 75,
            ),
          );
      await seed.close();
      var openAttempts = 0;
      final retiring = <Future<void>>[];
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final database = AppDatabase.forTesting(
              LazyDatabase(() {
                if (++openAttempts == 1) {
                  throw PlatformException(
                    code: 'health_backup_exclusion_failed',
                  );
                }
                return NativeDatabase(file);
              }),
            );
            ref.onDispose(() {
              retiring.add(
                database.close().catchError((Object _, StackTrace _) {}),
              );
            });
            return database;
          }),
        ],
      );
      try {
        final failed = container.read(databaseProvider);
        await expectLater(
          failed.select(failed.weightEntries).get(),
          throwsA(isA<PlatformException>()),
        );
        await expectLater(
          failed.select(failed.weightEntries).get(),
          throwsA(isA<PlatformException>()),
        );
        expect(openAttempts, 1);
        container.invalidate(databaseProvider);
        await Future.wait(retiring);
        final recovered = container.read(databaseProvider);
        expect(
          (await recovered.select(recovered.weightEntries).get()).single.uuid,
          'retained-test-weight',
        );
        expect(openAttempts, 2);
        expect(
          (await (recovered.select(recovered.preferences)
                    ..where((row) => row.key.equals('retained-test-value')))
                  .getSingle())
              .value,
          'saved',
        );
      } finally {
        container.dispose();
        await Future.wait(retiring);
        await folder.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'startup retry replaces the failed local connection before retrying readers',
    (tester) async {
      var connections = 0;
      final retiring = <Future<void>>[];
      final router = GoRouter(
        initialLocation: '/startup',
        routes: [
          GoRoute(
            path: '/startup',
            builder: (_, _) =>
                StartupPage(imagePickerResumeResolver: (_) async => null),
          ),
          GoRoute(
            path: '/account-gateway',
            builder: (_, _) => const Scaffold(body: Text('Recovered startup')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) {
              connections++;
              final database = AppDatabase.forTesting(NativeDatabase.memory());
              ref.onDispose(() => retiring.add(database.close()));
              return database;
            }),
            userProfileProvider.overrideWith((ref) {
              ref.watch(databaseProvider);
              return connections == 1
                  ? Stream.error(
                      StateError('private native location must stay hidden'),
                    )
                  : Stream.value(null);
            }),
            dailyCheckInDueProvider.overrideWith((ref) async => false),
            forceOnboardingProvider.overrideWith((ref) async => false),
            accountGatewayReviewedProvider.overrideWith((ref) async => false),
          ],
          child: MaterialApp.router(
            locale: const Locale('ar'),
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تعذّر فتح بياناتك المحلية'), findsOneWidget);
      expect(find.textContaining('private native location'), findsNothing);
      expect(connections, 1);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(connections, 2);
      expect(find.text('Recovered startup'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await Future.wait(retiring);
      expect(tester.takeException(), isNull);
    },
  );
}
