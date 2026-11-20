import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/auth/account_data_conflict_page.dart';
import 'package:body_intelligence_log/features/auth/account_gateway_page.dart';
import 'package:body_intelligence_log/features/auth/auth_callback_page.dart';
import 'package:body_intelligence_log/features/auth/login_page.dart';
import 'package:body_intelligence_log/features/auth/register_page.dart';
import 'package:body_intelligence_log/features/auth/reset_password_page.dart';
import 'package:body_intelligence_log/features/auth/verify_email_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pinned_header_body.dart';
import 'package:body_intelligence_log/shared/widgets/bil_account_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../visual_closure/visual_evidence_font.dart';

const _capture = Key('auth-pinned-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var authRequests = 0;
  setUpAll(() async {
    await loadVisualEvidenceFont();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://pinned-layout.invalid',
      publishableKey: 'synthetic-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        authRequests++;
        throw StateError('Layout tests must never send an auth request.');
      }),
    );
  });
  tearDownAll(() async {
    expect(authRequests, 0);
    await Supabase.instance.dispose();
  });

  final pages = <(String, Widget, String)>[
    ('reviewer', const StoreReviewerLoginPage(), 'reviewer-login-body-scroll'),
    ('register', const RegisterPage(), 'register-body-scroll'),
    (
      'verify',
      const VerifyEmailPage(email: 'person@example.invalid'),
      'verify-email-body-scroll',
    ),
    (
      'reset',
      const ResetPasswordPage(
        initiallyFailed: true,
        cloudConfiguredOverride: true,
      ),
      'reset-password-body-scroll',
    ),
    (
      'conflict',
      const AccountDataConflictPage(),
      'account-conflict-body-scroll',
    ),
    ('gateway', const AccountGatewayPage(), 'account-gateway-body-scroll'),
    (
      'callback',
      const AuthCallbackPage(initiallyFailed: true),
      'auth-callback-body-scroll',
    ),
  ];

  for (final (name, page, scrollKey) in pages) {
    for (final largeRtl in [false, true]) {
      testWidgets('$name keeps its title and intro fixed while body scrolls '
          '${largeRtl ? 'RTL 220% keyboard' : 'LTR 100%'}', (tester) async {
        await _mount(tester, page, largeRtl: largeRtl);
        final titleKey = switch (name) {
          'reviewer' => 'reviewer-login-page-heading',
          'register' => 'register-page-heading',
          'verify' => 'verify-code-heading',
          'reset' => 'reset-password-page-heading',
          'conflict' => 'account-conflict-page-heading',
          'gateway' => 'gateway-welcome-heading',
          _ => null,
        };
        if (titleKey != null) {
          _expectCanonicalHeading(tester, find.byKey(Key(titleKey)));
        }
        if (name == 'verify') {
          _expectCanonicalHeading(
            tester,
            find.byKey(const Key('auth-page-title')),
          );
        }
        expect(find.byType(BilPinnedHeaderBody), findsOneWidget);
        final headerViewport = find.byKey(
          const Key('bil-pinned-header-region'),
        );
        final header = find
            .descendant(of: headerViewport, matching: find.byType(Column))
            .first;
        final headerRect = tester.getRect(header);
        final fixedRect = tester.getRect(headerViewport);
        final body = find.byKey(Key(scrollKey));
        final bodyRect = tester.getRect(body);
        expect(bodyRect.top, greaterThanOrEqualTo(fixedRect.bottom - .01));
        expect(bodyRect.height, greaterThan(0));
        final state = tester.state<ScrollableState>(
          find.descendant(of: body, matching: find.byType(Scrollable)).first,
        );
        if (largeRtl) {
          expect(state.position.maxScrollExtent, greaterThan(0));
        }
        await tester.drag(body, const Offset(0, -220));
        await tester.pump(const Duration(milliseconds: 350));
        if (state.position.maxScrollExtent > 0) {
          expect(state.position.pixels, greaterThan(0));
        }
        expect(tester.getRect(header), headerRect);
        expect(tester.getRect(headerViewport), fixedRect);
        final headingText = find
            .descendant(of: header, matching: find.byType(Text))
            .first;
        expect(
          MediaQuery.textScalerOf(tester.element(headingText)).scale(16),
          closeTo(largeRtl ? 35.2 : 16, .01),
        );
        expect(tester.takeException(), isNull);
        await _captureIfRequested(
          tester,
          '$name-${largeRtl ? 'ar220-keyboard' : 'en100'}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }

  for (final width in [360.0, 320.0]) {
    testWidgets('registration consent stays reachable and changes local state '
        'below the pinned title with RTL keyboard ${width.toInt()}', (
      tester,
    ) async {
      await _mount(tester, const RegisterPage(), largeRtl: true, width: width);
      final header = find.byKey(const Key('bil-pinned-header-region'));
      final headerRect = tester.getRect(header);
      final consent = find.byType(CheckboxListTile);
      await tester.ensureVisible(consent);
      await tester.pump();
      final body = find.byKey(const Key('register-body-scroll'));
      final bodyRect = tester.getRect(body);
      final checkbox = find.descendant(
        of: consent,
        matching: find.byType(Checkbox),
      );
      final checkboxRect = tester.getRect(checkbox);
      expect(checkbox.hitTestable(), findsOneWidget);
      expect(checkboxRect.top, greaterThanOrEqualTo(bodyRect.top));
      expect(checkboxRect.bottom, lessThanOrEqualTo(bodyRect.bottom));
      expect(checkboxRect.height, greaterThanOrEqualTo(48));
      final label = find.descendant(of: consent, matching: find.byType(Text));
      final labelRect = tester.getRect(label);
      expect(labelRect.top, greaterThanOrEqualTo(bodyRect.top));
      expect(labelRect.top, lessThan(bodyRect.bottom));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        consent.hitTestable(),
        findsOneWidget,
        reason:
            'agreement=${tester.getRect(consent)}; '
            'body=${tester.getRect(find.byKey(const Key('register-body-scroll')))}',
      );
      await _captureIfRequested(
        tester,
        'register-agreement-target-ar220-${width.toInt()}-keyboard',
      );
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(consent).value, isTrue);
      await Scrollable.ensureVisible(tester.element(label), alignment: 1);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(label).bottom,
        lessThanOrEqualTo(bodyRect.bottom + .01),
      );
      expect(tester.getRect(label).bottom, greaterThan(bodyRect.top));
      await _captureIfRequested(
        tester,
        'register-agreement-label-end-ar220-${width.toInt()}-keyboard',
      );
      await tester.ensureVisible(find.byKey(const Key('register-submit')));
      await tester.pump();
      expect(
        find.byKey(const Key('register-submit')).hitTestable(),
        findsOneWidget,
      );
      final submitRect = tester.getRect(
        find.byKey(const Key('register-submit')),
      );
      expect(submitRect.top, greaterThanOrEqualTo(bodyRect.top));
      expect(submitRect.bottom, lessThanOrEqualTo(bodyRect.bottom));
      final captureDirectory =
          Platform.environment['BIL_PINNED_HEADER_CAPTURE_DIR'];
      if (captureDirectory != null) {
        await tester.runAsync(() async {
          await File(
            '$captureDirectory/register-agreement-${width.toInt()}-geometry.json',
          ).writeAsString(
            jsonEncode({
              'body_height': bodyRect.height,
              'agreement_height': tester.getSize(consent).height,
              'native_checkbox_width': checkboxRect.width,
              'native_checkbox_height': checkboxRect.height,
              'native_checkbox_fully_contained': true,
              'full_label_untruncated': !paragraph.didExceedMaxLines,
              'label_start_and_end_scrolled_into_body': true,
              'submit_height': submitRect.height,
              'submit_fully_contained': true,
            }),
          );
        });
      }
      await _captureIfRequested(
        tester,
        'register-agreement-end-ar220-${width.toInt()}-keyboard',
      );
      expect(tester.getRect(header), headerRect);
      expect(tester.takeException(), isNull);
    });
  }

  for (final largeRtl in [false, true]) {
    testWidgets('login page title matches Conversations and stays fixed '
        '${largeRtl ? 'RTL 220% keyboard' : 'LTR 100%'}', (tester) async {
      await _mount(tester, const LoginPage(), largeRtl: largeRtl);
      final title = find.byKey(const Key('auth-page-title'));
      _expectCanonicalHeading(tester, title);
      final titleRect = tester.getRect(title);
      final body = find.ancestor(
        of: find.byKey(const Key('login-email')),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(body, const Offset(0, -180));
      await tester.pump();
      expect(tester.getRect(title), titleRect);
      expect(tester.takeException(), isNull);
    });
  }

  for (final keyboard in [0.0, 240.0]) {
    testWidgets('account header fits full Arabic 220% title and both controls '
        'at320 with keyboard ${keyboard.toInt()}', (tester) async {
      var backCalls = 0;
      var languageCalls = 0;
      var bodyCalls = 0;
      await _mount(
        tester,
        BilAccountSurface(
          title: 'إنشاء حساب',
          onBack: () => backCalls++,
          languageSelector: TextButton(
            key: const Key('account-pressure-language'),
            onPressed: () => languageCalls++,
            child: const Text('العربية'),
          ),
          child: ListView(
            key: const Key('account-pressure-body'),
            children: [
              const SizedBox(height: 1100),
              FilledButton(
                key: const Key('account-pressure-last-action'),
                onPressed: () => bodyCalls++,
                child: const Text('متابعة'),
              ),
            ],
          ),
        ),
        largeRtl: true,
        width: 320,
        keyboardInset: keyboard,
      );
      final header = find.byKey(const Key('bil-account-header'));
      final title = find.byKey(const Key('bil-account-page-title'));
      _expectCanonicalHeading(tester, title);
      final headerRect = tester.getRect(header);
      final titleRect = tester.getRect(title);
      expect(titleRect.top, greaterThanOrEqualTo(headerRect.top));
      expect(titleRect.bottom, lessThanOrEqualTo(headerRect.bottom));
      for (final key in const [
        Key('bil-account-back'),
        Key('account-pressure-language'),
      ]) {
        final control = find.byKey(key);
        expect(control.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(control).top,
          greaterThanOrEqualTo(headerRect.top),
        );
        expect(
          tester.getRect(control).bottom,
          lessThanOrEqualTo(headerRect.bottom),
        );
        await tester.tap(control);
        await tester.pumpAndSettle();
      }
      expect(backCalls, 1);
      expect(languageCalls, 1);
      final last = find.byKey(const Key('account-pressure-last-action'));
      await tester.scrollUntilVisible(
        last,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('account-pressure-body')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(bodyCalls, 1);
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(title), titleRect);
      expect(tester.takeException(), isNull);
      await _captureIfRequested(
        tester,
        'account-bar-ar220-320-keyboard${keyboard.toInt()}',
      );
    });
  }
}

void _expectCanonicalHeading(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final expected = Theme.of(tester.element(finder)).textTheme.titleLarge!;
  expect(text.style?.fontSize, expected.fontSize);
  expect(text.style?.fontFamily, expected.fontFamily);
  expect(text.style?.fontWeight, FontWeight.w800);
}

Future<void> _mount(
  WidgetTester tester,
  Widget page, {
  required bool largeRtl,
  double width = 360,
  double? keyboardInset,
}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        validRecoverySnapshotProvider.overrideWith((_) async => false),
      ],
      child: MaterialApp(
        theme: visualEvidenceTheme(
          BilFlagshipTheme.light(isArabic: largeRtl),
          fontFamily: largeRtl ? 'NotoArabicEvidence' : 'RobotoEvidence',
        ),
        locale: Locale(largeRtl ? 'ar' : 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(largeRtl ? 2.2 : 1),
            viewInsets: EdgeInsets.only(
              bottom: keyboardInset ?? (largeRtl ? 240 : 0),
            ),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: _capture, child: child!),
        ),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(tester.takeException(), isNull);
}

Future<void> _captureIfRequested(WidgetTester tester, String name) async {
  final directory = Platform.environment['BIL_PINNED_HEADER_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
