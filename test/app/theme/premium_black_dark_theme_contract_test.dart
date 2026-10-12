import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  // The owner's 2026-10-11 polish order replaces the old matte-black palette.
  // Check readability against every actual pearl gradient endpoint.
  for (final dark in [false, true]) {
    testWidgets('premium pearl $dark preserves legible surface/action roles', (
      tester,
    ) async {
      final theme = dark ? BilFlagshipTheme.dark() : BilFlagshipTheme.light();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      final scheme = theme.colorScheme;
      final surfaces = <Color>[
        theme.scaffoldBackgroundColor,
        scheme.surface,
        scheme.surfaceContainerHighest,
        ...(BilPearlFinish.panel(context).gradient! as LinearGradient).colors,
      ];
      for (final surface in surfaces) {
        expect(contrast(scheme.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      for (final style in [
        theme.textTheme.titleLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelLarge,
      ]) {
        expect(style?.shadows, isNull);
        expect(style?.foreground, isNull);
      }
    });
  }
  testWidgets('high contrast frost is opaque and removes blur', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: BilFlagshipTheme.light(),
        home: Builder(
          builder: (value) => MediaQuery(
            data: MediaQuery.of(value).copyWith(highContrast: true),
            child: Builder(
              builder: (value) {
                context = value;
                return const Scaffold(
                  body: BilFrostedPanel(child: Text('Readable')),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final gradient =
        BilPearlFinish.panel(context, translucent: true).gradient!
            as LinearGradient;
    expect(gradient.colors.every((color) => color.a == 1), isTrue);
  });
}
