import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizes = <Size>[
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(800, 1280),
    Size(1024, 1366),
  ];
  const locales = <Locale>[Locale('en'), Locale('ar')];

  Future<void> pumpHeader(
    WidgetTester tester, {
    required Size size,
    required Locale locale,
    List<int>? photo,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            child: DashboardTopBar(
              onProfile: () {},
              profilePhoto: photo == null ? null : Uint8List.fromList(photo),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in sizes) {
    for (final locale in locales) {
      testWidgets(
        'identity header is physically centered at ${size.width.toInt()} '
        '${locale.languageCode}',
        (tester) async {
          await pumpHeader(tester, size: size, locale: locale);

          final wordmark = find.byKey(const Key('dashboard-wordmark'));
          final profile = find.byKey(const Key('dashboard-profile-control'));
          final notifications = find.byKey(
            const Key('dashboard-notifications'),
          );
          final edit = find.byKey(const Key('dashboard-edit-today'));
          final wordmarkLockup = find
              .ancestor(
                of: find.descendant(
                  of: wordmark,
                  matching: find.text('BODY INTELLIGENCE LOG'),
                ),
                matching: find.byType(Row),
              )
              .first;
          final wordmarkRect = tester.getRect(wordmarkLockup);
          final expectedCenter = size.width / 2;

          expect(
            (wordmarkRect.center.dx - expectedCenter).abs(),
            lessThanOrEqualTo(1),
          );
          expect(tester.getRect(profile).right, lessThan(wordmarkRect.left));
          expect(
            tester.getRect(notifications).left,
            greaterThan(wordmarkRect.right),
          );
          expect(tester.getRect(edit).left, greaterThan(wordmarkRect.right));
          expect(tester.getSize(profile), const Size.square(48));
          expect(tester.getSize(notifications).width, greaterThanOrEqualTo(48));
          expect(
            tester.getSize(notifications).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.getSize(edit), const Size.square(48));

          // The canonical mark itself and its Dashboard header path stay
          // transparent: no legacy white card, border or rounded container.
          expect(
            find.ancestor(of: wordmark, matching: find.byType(Container)),
            findsNothing,
          );
          expect(
            find.ancestor(of: wordmark, matching: find.byType(DecoratedBox)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('default profile avatar uses explicit BIL navy contrast', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      size: const Size(390, 844),
      locale: const Locale('en'),
    );

    final avatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byKey(const Key('dashboard-default-profile-avatar')),
        matching: find.byType(CircleAvatar),
      ),
    );
    final placeholder = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('dashboard-default-profile-avatar')),
        matching: find.byIcon(Icons.person_rounded),
      ),
    );
    expect(avatar.backgroundColor, const Color(0xFF12394E));
    expect(placeholder.color, Colors.white);
  });

  testWidgets('a member photo remains an unmodified image provider', (
    tester,
  ) async {
    final onePixelPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4'
      '//8/AwAI/AL+KDvKAAAAAElFTkSuQmCC',
    );
    await pumpHeader(
      tester,
      size: const Size(390, 844),
      locale: const Locale('en'),
      photo: onePixelPng,
    );

    final avatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byKey(const Key('dashboard-user-profile-avatar')),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(avatar.backgroundImage, isA<MemoryImage>());
    expect(avatar.child, isNull);
  });
}
