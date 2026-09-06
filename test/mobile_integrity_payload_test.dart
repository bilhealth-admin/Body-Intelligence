import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/security/bil_integrity_exception.dart';
import 'package:body_intelligence_log/app/security/bil_integrity_payload.dart';
import 'package:body_intelligence_log/app/security/bil_mobile_integrity_service.dart';

void main() {
  test('semantic payload canonicalization is ordered and float-bit stable', () {
    final first = <String, Object?>{
      'z': <Object?>[true, null, 1.5],
      'a': 'é',
    };
    final second = <String, Object?>{
      'a': 'é',
      'z': <Object?>[true, null, 1.5],
    };

    expect(
      bilIntegrityCanonicalValue(first),
      bilIntegrityCanonicalValue(second),
    );
    expect(
      bilIntegrityCanonicalValue(first),
      'M2:{K1:a;S2:é;K1:z;L3:[B1;N;D3ff8000000000000;];};',
    );
    expect(
      bilIntegrityPayloadDigest(first),
      'ecf9a57e9ab1837cee86267e950eb5aae33d3e5b5010699e2adcb4824590f3c4',
    );
  });

  test(
    'rollout-disabled client does not invoke a native attestation surface',
    () async {
      final service = BilMobileIntegrityService(
        integrityRequired: () => false,
        isWeb: () => true,
      );

      expect(
        await service.protect(
          action: 'test.sensitive',
          payload: <String, Object?>{'value': 7},
        ),
        <String, Object?>{'value': 7},
      );
    },
  );

  test(
    'rollout-enabled client fails closed when attestation is unavailable',
    () async {
      final service = BilMobileIntegrityService(
        integrityRequired: () => true,
        isWeb: () => true,
      );

      await expectLater(
        service.protect(
          action: 'test.sensitive',
          payload: <String, Object?>{'value': 7},
        ),
        throwsA(
          isA<BilIntegrityException>().having(
            (error) => error.code,
            'code',
            'mobile_integrity_not_supported',
          ),
        ),
      );
    },
  );

  test(
    'native and server boundaries require JIT grants, not launch claims',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      final appAttest = File(
        'ios/Runner/BILAppAttestBridge.swift',
      ).readAsStringSync();
      final releaseEntitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final play = File(
        'supabase/functions/play-integrity/index.ts',
      ).readAsStringSync();
      final grantGuard = File(
        'supabase/functions/_shared/mobile_integrity.ts',
      ).readAsStringSync();
      final androidRelease = File(
        '.github/workflows/bil_android_release_candidate.yml',
      ).readAsStringSync();

      expect(main, isNot(contains('session.bootstrap')));
      expect(appAttest, contains('DCAppAttestService.shared'));
      expect(appAttest, contains('generateAssertion'));
      expect(
        releaseEntitlements,
        contains('com.apple.developer.devicecheck.appattest-environment'),
      );
      expect(
        play,
        anyOf(contains("platform: 'android'"), contains('platform: "android"')),
      );
      expect(play, contains('bil_mobile_integrity_grants'));
      expect(grantGuard, contains('bil_consume_mobile_integrity_grant'));
      expect(grantGuard, contains('delete protectedBody._integrity'));
      expect(
        androidRelease,
        contains('--dart-define=BIL_MOBILE_INTEGRITY_REQUIRED=true'),
      );
      expect(
        androidRelease,
        contains('BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID'),
      );
      expect(androidRelease, contains('BIL_PLAY_INTEGRITY_PROJECT_NUMBER'));
    },
  );

  test('mobile integrity storage is transactional, narrow, and retained', () {
    final sql = File(
      'supabase/migrations/20260905010000_mobile_integrity_jit_grants.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql.trimLeft(), startsWith('-- one-use grants'));
    expect(sql, contains('\nbegin;'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(sql, isNot(contains('grant all on table')));
    expect(
      sql,
      contains(
        'grant select, insert, update\n'
        '  on table public.bil_mobile_integrity_challenges to service_role',
      ),
    );
    expect(
      sql,
      contains(
        'grant select, insert, update\n'
        '  on table public.bil_app_attest_keys to service_role',
      ),
    );
    expect(sql, contains('bil_cleanup_mobile_integrity_artifacts'));
    expect(sql, contains("interval '24 hours'"));
    expect(sql, contains("interval '30 days'"));
    expect(sql, contains('receipt_purge_after'));
    expect(sql, contains('receipt_purged_at'));
    expect(sql, contains('v_batch_size'));
    expect(sql, contains('5000'));
    expect(sql, contains("set search_path = ''"));
    expect(sql, contains('from public, anon, authenticated, service_role'));
  });
}
