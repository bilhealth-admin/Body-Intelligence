import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commerce Epic reconciliation', () {
    test('commerce production remains isolated from forbidden platforms', () {
      final root = Directory('lib/features/commerce');
      expect(root.existsSync(), isTrue);

      final forbiddenImports = <String>[
        'features/ai/',
        'features/cloud/',
        'features/dashboard/',
        'features/nutrition/',
        'features/premium/',
        'features/profile/',
        'features/startup/',
      ];

      final violations = <String>[];
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final forbidden in forbiddenImports) {
          if (source.contains(forbidden)) {
            violations.add('${entity.path}: imports $forbidden');
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('paywall remains non-authoritative and callback-driven', () {
      final presentation = Directory('lib/features/commerce/presentation');
      expect(presentation.existsSync(), isTrue);

      final sources = presentation
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(sources, isNot(contains('SubscriptionState(')));
      expect(sources, isNot(contains('authorityVerified: true')));
      // Presentation may explain that metadata is store-authoritative, but it
      // must never import or invoke either native billing SDK directly.
      expect(sources, isNot(contains('package:in_app_purchase')));
      expect(sources, isNot(contains('SKPaymentQueue')));
      expect(sources, isNot(contains('BillingClient(')));
      expect(sources, isNot(contains('stripe')));
    });

    test('paywall state model is tracked and referenced by production', () {
      const statePath = 'lib/features/commerce/presentation/paywall_state.dart';
      final stateFile = File(statePath);
      expect(stateFile.existsSync(), isTrue);

      final stateSource = stateFile.readAsStringSync();
      expect(stateSource, contains('class PaywallState'));

      final productionConsumers = <String>[
        'lib/features/commerce/presentation/commerce_paywall.dart',
        'lib/features/commerce/presentation/paywall_controller.dart',
      ];
      for (final path in productionConsumers) {
        final source = File(path).readAsStringSync();
        expect(source, contains('paywall_state.dart'), reason: path);
        expect(source, contains('PaywallState'), reason: path);
      }
    });

    test('all required Commerce layers and living documents exist', () {
      final required = <String>[
        'lib/features/commerce/domain',
        'lib/features/commerce/repositories',
        'lib/features/commerce/services',
        'lib/features/commerce/providers',
        'lib/features/commerce/presentation',
        'lib/features/commerce/presentation/paywall_state.dart',
        'test/features/commerce',
        'docs/MASTER_ROADMAP.md',
        'docs/PROJECT_STATE.md',
        'docs/EXECUTION_LEDGER.md',
        'docs/ARCHITECTURE_DECISIONS.md',
        'docs/NEXT_PACKAGES.md',
        'docs/KNOWN_LIMITATIONS.md',
      ];

      final missing = required.where((path) {
        return !File(path).existsSync() && !Directory(path).existsSync();
      }).toList();

      expect(missing, isEmpty, reason: 'Missing: ${missing.join(', ')}');
    });
  });
}
