import 'dart:io';

import 'package:body_intelligence_log/app/services/app_switcher_privacy_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app switcher redacts user health content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSwitcherPrivacyShield(child: Text('private health value')),
      ),
    );
    expect(find.text('private health value'), findsOneWidget);
    expect(find.byKey(const Key('app-switcher-privacy-shield')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      find.byKey(const Key('app-switcher-privacy-shield')),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('app-switcher-privacy-shield')), findsNothing);
  });

  test('private export never uses the global clipboard', () {
    final source = File(
      'lib/app/services/data_export_service.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Clipboard')));
    expect(source, contains('SharePlus.instance.share'));
  });

  test('native backup and cleartext boundaries fail closed', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(android, contains('android:allowBackup="false"'));
    expect(android, contains('android:usesCleartextTraffic="false"'));
  });

  test('Android Kotlin mode is explicit and keeps legacy plugins isolated', () {
    final properties = File('android/gradle.properties').readAsStringSync();
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final speechBridge = File(
      'android/app/src/main/kotlin/com/kadem/bil/BILSpeechBridge.kt',
    ).readAsStringSync();

    // Flutter versions before 3.47 need the audited AGP 9 compatibility
    // bridge while transitive plugins finish migrating to built-in Kotlin.
    expect(properties, contains('android.builtInKotlin=false'));
    expect(properties, contains('android.newDsl=false'));
    expect(
      settings,
      contains(
        'id("org.jetbrains.kotlin.android") version "2.2.20" apply false',
      ),
    );
    expect(pubspec, isNot(contains('speech_to_text:')));
    expect(speechBridge, contains('SpeechRecognizer'));
    expect(speechBridge, isNot(contains('kotlin-android')));
  });

  test('sensitive server operations are replay and ownership protected', () {
    final migration = File(
      'supabase/migrations/202608040003_bil_security_privacy_closure.sql',
    ).readAsStringSync();
    final function = File(
      'supabase/functions/analyze-meal/index.ts',
    ).readAsStringSync();
    expect(migration, contains('enable row level security'));
    expect(migration, contains('auth.uid()'));
    expect(migration, contains('bil_claim_sensitive_request'));
    expect(function, contains("request.headers.get('x-idempotency-key')"));
    expect(function, contains("auth.auth.getUser()"));
  });
}
