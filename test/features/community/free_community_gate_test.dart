import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final pending in [true, false]) {
    testWidgets(
      'Community remains interactive with billing ${pending ? 'pending' : 'unavailable'}',
      (tester) async {
        var taps = 0;
        var storefrontReads = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedSubscriptionStateProvider.overrideWithValue(
                pending
                    ? const AsyncLoading<SubscriptionState>()
                    : AsyncError<SubscriptionState>(
                        StateError('billing offline'),
                        StackTrace.current,
                      ),
              ),
              storefrontTargetPlanProvider.overrideWith((_) async {
                storefrontReads++;
                throw StateError('Community must not consult store prices');
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: PremiumRouteGlassGate(
                  feature: PremiumGateFeature.community,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Open friends'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Open friends'));
        expect(taps, 1);
        expect(storefrontReads, 0);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is AbsorbPointer && widget.absorbing,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
