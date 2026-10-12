import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/services/scoped_media_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11);
  Uri photo(int seconds, {String path = 'author/post/photo.png'}) {
    final exp =
        now.add(Duration(seconds: seconds)).millisecondsSinceEpoch ~/ 1000;
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'exp': exp})))
        .replaceAll('=', '');
    return Uri.parse(
      '${AppEnvironment.supabaseUrl}/storage/v1/object/sign/community-post-images/$path?token=header.$payload.signature',
    );
  }

  test(
    'visible token renews before expiry and concurrent consumers share authorization',
    () async {
      final pending = Completer<Uri?>();
      var calls = 0;
      final access = ScopedMediaAccess(
        clock: () => now,
        signer: (_, viewer) {
          expect(viewer, 'A');
          calls++;
          return pending.future;
        },
      )..bindViewer('A');
      final first = access.authorize(photo(30), 'A');
      final second = access.authorize(photo(30), 'A');
      expect(calls, 1);
      expect(pending.isCompleted, isFalse);
      pending.complete(photo(3600));
      expect(await first, photo(3600));
      expect(await second, photo(3600));
      expect(await access.authorize(photo(30), 'A'), photo(3600));
      expect(calls, 1);
    },
  );
  test('denied visibility cannot extend access or reuse a CDN token', () async {
    final access = ScopedMediaAccess(
      clock: () => now,
      signer: (_, _) async => null,
    )..bindViewer('A');
    await expectLater(
      access.authorize(photo(30), 'A'),
      throwsA(isA<PhotoAccessDenied>()),
    );
  });
  test(
    'a long-lived signed URL from another session is not a viewer authorization',
    () async {
      var calls = 0;
      final access = ScopedMediaAccess(
        clock: () => now,
        signer: (_, viewer) async {
          calls++;
          expect(viewer, 'B');
          return null;
        },
      )..bindViewer('B');
      await expectLater(
        access.authorize(photo(3600), 'B'),
        throwsA(isA<PhotoAccessDenied>()),
      );
      expect(calls, 1);
    },
  );
  test(
    'A B A retires the first authorization even if account IDs match again',
    () async {
      final pending = Completer<Uri?>();
      final access = ScopedMediaAccess(
        clock: () => now,
        signer: (_, _) => pending.future,
      )..bindViewer('A');
      final result = access.authorize(photo(30), 'A');
      final check = expectLater(result, throwsStateError);
      access.bindViewer('B');
      access.bindViewer('A');
      pending.complete(photo(3600));
      await check;
    },
  );
  test(
    'backend cannot substitute another object or an expired capability',
    () async {
      final access = ScopedMediaAccess(
        clock: () => now,
        signer: (_, _) async => photo(3600, path: 'author/other/photo.png'),
      )..bindViewer('A');
      await expectLater(
        access.authorize(photo(30), 'A'),
        throwsA(isA<PhotoAccessDenied>()),
      );
      final expired = ScopedMediaAccess(
        clock: () => now,
        signer: (_, _) async => photo(-1),
      )..bindViewer('A');
      await expectLater(
        expired.authorize(photo(30), 'A'),
        throwsA(isA<PhotoAccessDenied>()),
      );
    },
  );
}
