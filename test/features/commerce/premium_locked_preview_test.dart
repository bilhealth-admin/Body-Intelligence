import 'package:body_intelligence_log/features/commerce/presentation/premium_locked_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locked preview never builds full paid payload', (tester) async {
    var fullBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PremiumLockedPreview(
          requiredTier: BilPaidContentTier.premiumAiCoach,
          hasEntitlement: false,
          preview: const Text('Preview'),
          fullContentBuilder: (_) {
            fullBuilds++;
            return const Text('Secret payload');
          },
          lockedTitle: 'Premium AI Coach required',
          upgradeLabel: 'View plans',
          onUpgrade: () {},
        ),
      ),
    );
    expect(fullBuilds, 0);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Secret payload'), findsNothing);
  });

  testWidgets('entitlement refresh immediately swaps to full content', (
    tester,
  ) async {
    final entitlement = ValueNotifier(false);
    addTearDown(entitlement.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: entitlement,
          builder: (_, allowed, _) => PremiumLockedPreview(
            requiredTier: BilPaidContentTier.premium,
            hasEntitlement: allowed,
            preview: const Text('Preview'),
            fullContentBuilder: (_) => const Text('Full content'),
            lockedTitle: 'Premium required',
            upgradeLabel: 'Upgrade',
            onUpgrade: () {},
          ),
        ),
      ),
    );
    expect(find.text('Full content'), findsNothing);
    entitlement.value = true;
    await tester.pump();
    expect(find.text('Full content'), findsOneWidget);
    expect(find.text('Premium required'), findsNothing);
  });
}
