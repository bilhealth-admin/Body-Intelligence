import 'dart:io';

import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_platform_policy.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retry policy is bounded exponential and deterministic', () {
    const policy = CloudRetryPolicy(
      initialDelay: Duration(seconds: 2),
      maximumDelay: Duration(seconds: 10),
    );
    expect(policy.delayForAttempt(0), Duration.zero);
    expect(policy.delayForAttempt(1), const Duration(seconds: 2));
    expect(policy.delayForAttempt(3), const Duration(seconds: 8));
    expect(policy.delayForAttempt(8), const Duration(seconds: 10));
  });

  test('cloud platform has one provider-neutral production composition root', () {
    final cloudRoot = Directory('lib/features/cloud_platform');
    expect(cloudRoot.existsSync(), isTrue);

    final productionFiles = cloudRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);

    const forbiddenProviderTokens = <String>[
      'package:supabase_flutter/',
      'package:firebase_core/',
      'package:firebase_',
      'package:amplify_',
      'Supabase.instance',
      'Firebase.initializeApp',
      'Amplify.configure',
    ];

    // Provider SDK references are permitted only inside the explicit Supabase
    // integration boundary. The domain, ports, persistence and offline-first
    // engine must remain provider-neutral.
    const providerBoundaryFiles = <String>{
      'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
      'lib/features/cloud_platform/services/cloud_platform_composition_root.dart',
      'lib/features/cloud_platform/services/cloud_session_sync_coordinator.dart',
      'lib/features/cloud_platform/services/supabase_cloud_authentication_provider.dart',
      'lib/features/cloud_platform/services/supabase_cloud_transport.dart',
    };
    for (final file in productionFiles) {
      final normalizedPath = file.path.replaceAll('\\', '/');
      if (providerBoundaryFiles.contains(normalizedPath)) continue;
      final source = file.readAsStringSync();
      for (final token in forbiddenProviderTokens) {
        expect(
          source,
          isNot(contains(token)),
          reason: '${file.path} directly depends on provider token $token',
        );
      }
    }

    final compositionRoots = productionFiles
        .where((file) {
          final source = file.readAsStringSync();
          return source.contains('final class CloudPlatformCompositionRoot') ||
              source.contains('class CloudPlatformCompositionRoot');
        })
        .toList(growable: false);

    expect(
      compositionRoots,
      hasLength(1),
      reason:
          'Cloud Platform must expose exactly one production composition root.',
    );
    expect(
      compositionRoots.single.path.replaceAll('\\', '/'),
      endsWith(
        'lib/features/cloud_platform/services/cloud_platform_composition_root.dart',
      ),
    );

    final rootSource = compositionRoots.single.readAsStringSync();
    expect(rootSource, contains('CloudPlatformCompositionRoot'));
    expect(rootSource, contains('OfflineFirstCloudPlatform'));

    final ports = File(
      'lib/features/cloud_platform/services/cloud_platform_ports.dart',
    ).readAsStringSync();
    expect(ports, contains('abstract interface class'));
    for (final token in forbiddenProviderTokens) {
      expect(ports, isNot(contains(token)));
    }
  });

  test('cloud entity coverage includes every protected data branch', () {
    expect(
      CloudEntityKind.values.map((e) => e.name),
      containsAll(<String>[
        'profile',
        'goal',
        'weight',
        'measurement',
        'nutrition',
        'hydration',
        'sleep',
        'activity',
        'decisionMemory',
        'intelligenceOutput',
        'coach',
        'community',
        'file',
        'settings',
      ]),
    );
  });
}
