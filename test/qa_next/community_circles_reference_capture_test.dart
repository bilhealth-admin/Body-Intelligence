import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_community_circles.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_flat_icon.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../visual_closure/visual_evidence_font.dart';

part 'community_circles_reference_fixture.dart';
part 'community_circles_reference_behavior_cases.dart';

void main() {
  late SupabaseClient client;
  late _CircleVisualRepository repository;
  setUpAll(loadVisualEvidenceFont);
  setUp(() async {
    client = SupabaseClient(
      'https://circle-visual.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_circleVisualHttp)),
    );
    // A visual capture must exercise the same authenticated owner fence as
    // the actual screen. The synthetic auth transport is fully local.
    await client.auth.signInWithPassword(
      email: 'circle-visual@example.invalid',
      password: 'synthetic',
    );
    repository = _CircleVisualRepository(client);
  });
  tearDown(() async => client.dispose());

  test('Circles copy closes every release locale without English fallback', () {
    expect(CommunityCirclesRuntimeCopy.rows, hasLength(25));
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      final row = CommunityCirclesRuntimeCopy.rows[tag]!;
      expect(row, hasLength(CommunityCirclesRuntimeCopy.sources.length));
      for (var index = 0; index < row.length; index++) {
        final source = CommunityCirclesRuntimeCopy.sources[index];
        final resolved = communityTextForLanguage(
          tag,
          source,
          CommunityCirclesRuntimeCopy.rows['ar']![index],
        );
        expect(resolved, row[index], reason: '$tag: $source');
        expect(resolved.trim(), isNotEmpty);
        if (tag != 'en') expect(resolved, isNot(source), reason: tag);
      }
    }
  });

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        final suffix = '$language-${dark ? 'dark' : 'light'}-${scale.toInt()}';
        _circlesTest(
          'populated Circles Discover My circles and detail $suffix',
          (tester) async {
            final host = await _mountCircles(
              tester,
              repository,
              language: language,
              dark: dark,
              scale: scale,
            );
            final search = find.byKey(const Key('community-circles-search'));
            final discover = find.byKey(
              const Key('community-circles-discover'),
            );
            final cover = find.byKey(
              const Key('community-circle-cover-10k-steps'),
            );
            expect(
              tester.getRect(search).bottom,
              lessThan(tester.getRect(discover).top),
            );
            expect(
              tester.getRect(discover).bottom,
              lessThan(tester.getRect(cover).top),
            );
            expect(tester.getSize(cover), const Size(56, 56));
            expect(tester.widget<BilFlatIcon>(cover).iconSize, 28);
            expect(
              find.descendant(of: cover, matching: find.byType(DecoratedBox)),
              findsNothing,
              reason: 'A Circle glyph has no gradient, glow or shadow',
            );
            expect(repository.lists, 1);
            expect(repository.joins, 0);
            expect(repository.leaves, 0);
            expect(repository.composed, isEmpty);
            expect(
              find.byType(Image),
              findsNothing,
              reason: 'No circle photo URL exists in this API.',
            );
            if (scale == 1) {
              expect(
                tester
                    .getSize(
                      find.byKey(const Key('community-circle-row-10k-steps')),
                    )
                    .height,
                closeTo(70, .2),
              );
            }
            final membership = find.byKey(
              const Key('community-circle-membership-10k-steps'),
            );
            final style = tester
                .widget<OutlinedButton>(membership)
                .style!
                .textStyle!
                .resolve({});
            expect(
              style?.fontFamily,
              Theme.of(
                tester.element(membership),
              ).textTheme.labelLarge?.fontFamily,
            );
            expect(tester.takeException(), isNull);
            await _circleCapture(tester, host.boundary, '$suffix-discover');

            await _tapCircle(
              tester,
              find.byKey(const Key('community-circles-mine')),
            );
            expect(
              find.byKey(const Key('community-circle-row-10k-steps')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('community-circle-row-healthy-eating')),
              findsOneWidget,
            );
            expect(
              repository.lists,
              1,
              reason: 'My circles filters the loaded authoritative rows.',
            );
            await _circleCapture(tester, host.boundary, '$suffix-mine');

            await _tapCircle(
              tester,
              find.byKey(const Key('community-circle-row-healthy-eating')),
            );
            expect(repository.feeds, 1);
            expect(repository.metrics, 1);
            expect(find.text('Approved healthy-eating post 1'), findsOneWidget);
            expect(repository.composed, isEmpty);
            expect(tester.takeException(), isNull);
            await _circleCapture(tester, host.boundary, '$suffix-detail');
          },
        );
      }
    }
  }

  for (final language in ['en', 'ar']) {
    _circlesTest(
      'Circle controls remain reachable at320dp and200percent $language',
      (tester) async {
        final host = await _mountCircles(
          tester,
          repository,
          language: language,
          scale: 2,
          width: 320,
        );
        expect(tester.takeException(), isNull);
        await _circleCapture(tester, host.boundary, '$language-narrow-200-top');
        final last = find.byKey(
          const Key('community-circle-membership-weight-loss-journey'),
        );
        await tester.scrollUntilVisible(
          last,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _circleCapture(
          tester,
          host.boundary,
          '$language-narrow-200-last',
        );
      },
    );

    _circlesTest(
      'local search keeps text with the keyboard visible $language',
      (tester) async {
        final host = await _mountCircles(
          tester,
          repository,
          language: language,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.enterText(
          find.byKey(const Key('community-circles-search')),
          'healthy',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('community-circle-row-healthy-eating')),
          findsOneWidget,
        );
        expect(repository.lists, 1);
        expect(tester.takeException(), isNull);
        await _circleCapture(
          tester,
          host.boundary,
          '$language-keyboard-search',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('community-circles-search')),
              )
              .controller!
              .text,
          'healthy',
        );
      },
    );
  }

  _circlesTest('French circle discovery is localized and remains local', (
    tester,
  ) async {
    final host = await _mountCircles(tester, repository, language: 'fr');
    expect(find.text('Mes cercles'), findsOneWidget);
    expect(find.text('Rechercher des cercles'), findsOneWidget);
    expect(find.text('My circles'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('community-circles-search')),
      'strength',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('community-circle-row-strength')),
      findsOneWidget,
    );
    expect(repository.lists, 1);
    await _circleCapture(tester, host.boundary, 'fr-local-search');
  });

  _circleBehaviorCases(() => repository, () => client);
}
