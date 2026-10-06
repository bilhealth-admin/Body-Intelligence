import 'dart:ui' show Tristate;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_navigation_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_shell_test.dart' show shellApp;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      for (final width in [390.0, 1024.0]) {
        for (final locale in [const Locale('en'), const Locale('ar')]) {
          testWidgets(
            'navigation remains readable and screen-reader actionable '
            '$platform $brightness $width ${locale.languageCode}',
            (tester) async {
              final semantics = tester.ensureSemantics();
              tester.view.physicalSize = Size(width, 1000);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              await tester.pumpWidget(
                shellApp(
                  locale: locale,
                  theme: ThemeData(platform: platform, brightness: brightness),
                ),
              );
              await tester.pumpAndSettle();

              final wide = width >= 900;
              final strings = AppLocalizations.of(
                tester.element(find.text('dashboard')),
              );
              final todayLabel = wide
                  ? strings.text('Today')
                  : strings.text('Home');
              final moreLabel = strings.text('More');
              Finder button(String label) => find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.button == true &&
                    widget.properties.label == label,
              );
              final today = button(todayLabel);
              final more = button(moreLabel);
              expect(today, findsOneWidget);
              expect(more, findsOneWidget);
              final todayNode = tester.getSemantics(today);
              final moreNode = tester.getSemantics(more);
              expect(todayNode.flagsCollection.isSelected, Tristate.isTrue);
              expect(moreNode.flagsCollection.isSelected, Tristate.isFalse);
              expect(
                moreNode.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
              );
              expect(tester.getSize(more).height, greaterThanOrEqualTo(48));

              final Icon? todayIcon;
              if (wide) {
                todayIcon = tester.widget<Icon>(
                  find.descendant(of: today, matching: find.byType(Icon)),
                );
                expect(
                  todayIcon.icon,
                  platform == TargetPlatform.iOS
                      ? CupertinoIcons.square_grid_2x2_fill
                      : Icons.dashboard_rounded,
                );
                final plus = find.byKey(const Key('shell-quick-add-icon'));
                expect(plus, findsOneWidget);
                expect(
                  tester.widget<Icon>(plus).icon,
                  platform == TargetPlatform.iOS
                      ? CupertinoIcons.plus
                      : Icons.add_rounded,
                );
              } else {
                todayIcon = null;
                final todayGlyph = tester.widget<BilReferenceNavigationGlyph>(
                  find.byKey(const Key('bil-reference-nav-glyph-0')),
                );
                final plusGlyph = tester.widget<BilReferenceNavigationGlyph>(
                  find.byKey(const Key('bil-reference-nav-glyph-2')),
                );
                expect(todayGlyph.destination, 0);
                expect(todayGlyph.selected, isTrue);
                expect(plusGlyph.destination, 2);
                final surface =
                    tester
                            .widget<DecoratedBox>(
                              find.byKey(
                                const Key('bil-reference-nav-surface'),
                              ),
                            )
                            .decoration
                        as BoxDecoration;
                final background = surface.gradient!.colors.first;
                expect(
                  _contrast(todayGlyph.color, background),
                  greaterThanOrEqualTo(3),
                );
                final text = tester.widget<Text>(
                  find.byKey(const Key('bil-reference-nav-label-0')),
                );
                expect(
                  _contrast(text.style!.color!, background),
                  greaterThanOrEqualTo(4.5),
                );
                for (var index = 0; index < 5; index++) {
                  final target = find.byKey(Key('bil-reference-nav-$index'));
                  expect(
                    tester.getSize(target).width,
                    greaterThanOrEqualTo(48),
                  );
                  expect(
                    tester.getSize(target).height,
                    greaterThanOrEqualTo(48),
                  );
                }
              }

              if (wide) {
                final colors = Theme.of(tester.element(today)).colorScheme;
                expect(
                  _contrast(todayIcon!.color!, colors.primaryContainer),
                  greaterThanOrEqualTo(3),
                );
                final text = tester.widget<Text>(
                  find.descendant(of: today, matching: find.text(todayLabel)),
                );
                expect(
                  _contrast(text.style!.color!, colors.primaryContainer),
                  greaterThanOrEqualTo(4.5),
                );
              }

              tester.binding.renderViews.single.owner!.semanticsOwner!
                  .performAction(moreNode.id, SemanticsAction.tap);
              await tester.pumpAndSettle();
              expect(find.text('settings'), findsOneWidget);
              expect(
                tester
                    .getSemantics(button(moreLabel))
                    .flagsCollection
                    .isSelected,
                Tristate.isTrue,
              );
              expect(tester.takeException(), isNull);
              semantics.dispose();
            },
          );
        }
      }
    }
  }
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
}
