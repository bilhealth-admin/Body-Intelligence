import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/health_storage_privacy.dart';
import 'package:body_intelligence_log/features/startup/premium_splash_experience.dart';
import 'package:body_intelligence_log/main.dart' as application;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _privacyChannel = MethodChannel('bil/health_storage_privacy');
const _launchChannel = MethodChannel('bil/launch');
const _protected = <String, Object?>{
  'scopeVersion': 1,
  'applicationSupportExcluded': true,
  'documentsExcluded': true,
  'preferencesExcluded': true,
};
const _readyKey = ValueKey('bootstrap-ready-writers-probe');

enum _InitialFailure {
  nativeFailure,
  missingBridge,
  unverifiedParents,
  timeout,
}

Future<void> _flushFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final language in ['en', 'ar']) {
    final retry = language == 'ar' ? 'حاول مرة أخرى' : 'Try again';
    final errorCopy = language == 'ar'
        ? 'تعذر تأكيد حماية بيانات الصحة من النسخ الاحتياطي. لم تتغير بياناتك. أعد المحاولة.'
        : 'Health data backup protection could not be verified. Your data has not changed. Please retry.';

    for (final failure in _InitialFailure.values) {
      testWidgets(
        'real bootstrap $language ${failure.name} exposes usable retry and resumes only after verified protection',
        (tester) async {
          final originalLocale = AppLocalizations.activeLocale;
          tester.platformDispatcher.localesTestValue = [Locale(language)];
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          addTearDown(() => AppLocalizations.activate(originalLocale));
          addTearDown(() {
            messenger.setMockMethodCallHandler(_privacyChannel, null);
            messenger.setMockMethodCallHandler(_launchChannel, null);
          });
          var nativeCalls = 0;
          var launchCalls = 0;
          var readyMounts = 0;
          final stalled = Completer<Map<String, Object?>>();
          messenger.setMockMethodCallHandler(_launchChannel, (call) async {
            expect(call.method, 'ready');
            launchCalls++;
            return null;
          });
          messenger.setMockMethodCallHandler(_privacyChannel, (call) async {
            expect(call.method, 'protectHealthStorage');
            expect(call.arguments, isNull);
            nativeCalls++;
            if (nativeCalls > 1) return _protected;
            switch (failure) {
              case _InitialFailure.nativeFailure:
                throw PlatformException(
                  code: 'health_backup_exclusion_failed',
                  message: 'private-health-database-location',
                );
              case _InitialFailure.missingBridge:
                throw MissingPluginException('protectHealthStorage');
              case _InitialFailure.unverifiedParents:
                return {..._protected, 'preferencesExcluded': false};
              case _InitialFailure.timeout:
                return stalled.future;
            }
          });
          await tester.pumpWidget(
            application.bilBootstrapForTesting(
              healthStoragePrivacy: BilHealthStoragePrivacy(
                isIos: true,
                channel: _privacyChannel,
              ),
              readyChild: MaterialApp(
                home: Builder(
                  builder: (context) {
                    readyMounts++;
                    return const Scaffold(body: Text('Ready', key: _readyKey));
                  },
                ),
              ),
            ),
          );
          await _flushFrames(tester);
          expect(readyMounts, 0);
          expect(find.byKey(_readyKey), findsNothing);
          expect(nativeCalls, 1);
          if (failure == _InitialFailure.timeout) {
            expect(find.text(retry), findsNothing);
            await tester.pump(const Duration(seconds: 8));
            await _flushFrames(tester);
          }
          // This is the real temporary MaterialApp and retry button, not a
          // separate replica of the failed bootstrap presentation.
          expect(find.byType(BilStartupLoadingSurface), findsOneWidget);
          expect(find.text(errorCopy), findsOneWidget);
          expect(
            find.textContaining('private-health-database-location'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          final retryButton = find.widgetWithText(FilledButton, retry);
          expect(retryButton.hitTestable(), findsOneWidget);
          expect(
            Directionality.of(tester.element(retryButton)),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          await tester.tap(retryButton);
          await _flushFrames(tester);
          await tester.pumpAndSettle();
          expect(nativeCalls, 2);
          expect(readyMounts, greaterThan(0));
          expect(find.byKey(_readyKey), findsOneWidget);
          expect(find.text(errorCopy), findsNothing);
          expect(find.text(retry), findsNothing);
          expect(find.byType(BilStartupLoadingSurface), findsNothing);
          expect(launchCalls, 1);
          expect(tester.takeException(), isNull);
          if (failure == _InitialFailure.timeout) {
            final mountsAfterSuccess = readyMounts;
            stalled.complete(_protected);
            await _flushFrames(tester);
            expect(readyMounts, mountsAfterSuccess);
            expect(nativeCalls, 2);
            expect(find.byKey(_readyKey), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'real bootstrap $language keeps its first-frame splash and writers blocked during delayed privacy verification',
      (tester) async {
        final originalLocale = AppLocalizations.activeLocale;
        tester.platformDispatcher.localesTestValue = [Locale(language)];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(() => AppLocalizations.activate(originalLocale));
        addTearDown(() {
          messenger.setMockMethodCallHandler(_privacyChannel, null);
          messenger.setMockMethodCallHandler(_launchChannel, null);
        });
        final verification = Completer<Map<String, Object?>>();
        var nativeCalls = 0;
        var readyMounts = 0;
        messenger.setMockMethodCallHandler(_launchChannel, (_) async => null);
        messenger.setMockMethodCallHandler(_privacyChannel, (call) async {
          expect(call.method, 'protectHealthStorage');
          nativeCalls++;
          return verification.future;
        });
        await tester.pumpWidget(
          application.bilBootstrapForTesting(
            healthStoragePrivacy: BilHealthStoragePrivacy(
              isIos: true,
              channel: _privacyChannel,
            ),
            readyChild: MaterialApp(
              home: Builder(
                builder: (context) {
                  readyMounts++;
                  return const Scaffold(body: Text('Ready', key: _readyKey));
                },
              ),
            ),
          ),
        );
        await _flushFrames(tester);
        await tester.pump(const Duration(milliseconds: 100));
        expect(nativeCalls, 1);
        expect(find.byType(BilStartupLoadingSurface), findsOneWidget);
        expect(find.byKey(_readyKey), findsNothing);
        expect(find.text(retry), findsNothing);
        expect(readyMounts, 0);
        expect(tester.takeException(), isNull);
        verification.complete(_protected);
        await _flushFrames(tester);
        await tester.pumpAndSettle();
        expect(nativeCalls, 1);
        expect(readyMounts, greaterThan(0));
        expect(find.byKey(_readyKey), findsOneWidget);
        expect(find.byType(BilStartupLoadingSurface), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
