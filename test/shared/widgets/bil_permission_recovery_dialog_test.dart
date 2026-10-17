import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/shared/widgets/bil_permission_recovery_dialog.dart';

void main() {
  testWidgets('permission explainer uses pearl dialog with cancellation', (tester) async {
    bool? allowed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                allowed = await showBilPearlPermissionDecision(
                  context,
                  title: 'Camera access',
                  description: 'Use the camera only to scan food.',
                  cancelLabel: 'Not now',
                  confirmLabel: 'Open settings',
                );
              },
              child: const Text('Check permission'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check permission'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bil-permission-pearl-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bil-permission-cancel')));
    await tester.pumpAndSettle();
    expect(allowed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
