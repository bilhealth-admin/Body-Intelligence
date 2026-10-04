import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_rewards.dart';
import 'package:body_intelligence_log/features/community/presentation/community_rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final class _AuditRewardsRepository implements CommunityRepository {
  @override
  Future<CommunityGoldBalance> loadGoldBalance() async =>
      const CommunityGoldBalance(balance: 50);

  @override
  Future<List<CommunityGoldLedgerEntry>> loadGoldHistory({
    DateTime? beforeCreatedAt,
    int? beforeId,
    int limit = 30,
  }) async => const <CommunityGoldLedgerEntry>[];

  @override
  Future<List<CommunityQuest>> loadCommunityQuests() async =>
      const <CommunityQuest>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unstubbed Rewards repository operation: ${invocation.memberName}',
  );
}

double _contrast(Color foreground, Color background) {
  final visible = Color.alphaBlend(foreground, background);
  final a = visible.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
}

void main() {
  test('Rewards source respects the unchanged 700-line ceiling', () {
    final source = File(
      'lib/features/community/presentation/community_rewards_page.dart',
    );
    expect(source.readAsLinesSync().length, lessThanOrEqualTo(700));
  });

  for (final arabic in <bool>[false, true]) {
    for (final dark in <bool>[false, true]) {
      for (final scale in <double>[1.0, 1.6, 2.0]) {
        for (final size in <Size>[const Size(320, 568), const Size(414, 896)]) {
          final label = '$arabic/$dark/$scale/${size.width}';
          testWidgets('Rewards contrast/layout: $label', (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark
                    ? BilFlagshipTheme.dark(isArabic: arabic)
                    : BilFlagshipTheme.light(isArabic: arabic),
                locale: Locale(arabic ? 'ar' : 'en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: CommunityRewardsPage(
                  repository: _AuditRewardsRepository(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final balance = find.byKey(const Key('community-gold-balance'));
            expect(balance, findsOneWidget);
            final column = find
                .ancestor(of: balance, matching: find.byType(Column))
                .first;
            final texts = tester
                .widgetList<Text>(
                  find.descendant(of: column, matching: find.byType(Text)),
                )
                .toList();
            final caption = texts.last;
            final foreground = caption.style?.color;
            expect(foreground, isNotNull);
            final card = tester
                .widgetList<Container>(
                  find.ancestor(of: balance, matching: find.byType(Container)),
                )
                .firstWhere(
                  (widget) =>
                      widget.decoration is BoxDecoration &&
                      (widget.decoration! as BoxDecoration).gradient != null,
                );
            final gradient = (card.decoration! as BoxDecoration).gradient!;
            for (final background in gradient.colors) {
              expect(
                _contrast(foreground!, background),
                greaterThanOrEqualTo(4.5),
                reason: 'Small Gold caption must remain readable in $label',
              );
            }
            final captionFinder = find.byWidget(caption);
            final cardRect = tester.getRect(find.byWidget(card));
            final captionRect = tester.getRect(captionFinder);
            expect(cardRect.contains(captionRect.topLeft), isTrue);
            expect(cardRect.contains(captionRect.bottomRight), isTrue);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }
}
