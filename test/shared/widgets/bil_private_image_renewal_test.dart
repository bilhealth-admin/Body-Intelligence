import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/services/scoped_media_access.dart';
import 'package:body_intelligence_log/app/services/scoped_media_file_cache.dart';
import 'package:body_intelligence_log/shared/widgets/bil_persistent_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets(
    'visible pixels survive a permitted renewal; access denial deletes bytes and account changes cannot inherit',
    (tester) async {
      late Directory root;
      late ScopedMediaFileCache cache;
      final pending = <Completer<Uri?>>[];
      final access = ScopedMediaAccess(
        signer: (_, _) {
          final p = Completer<Uri?>();
          pending.add(p);
          return p.future;
        },
      );
      Uri signed(int seconds) {
        final exp =
            DateTime.now()
                .add(Duration(seconds: seconds))
                .millisecondsSinceEpoch ~/
            1000;
        final token = base64Url
            .encode(utf8.encode(jsonEncode({'exp': exp})))
            .replaceAll('=', '');
        return Uri.parse(
          '${AppEnvironment.supabaseUrl}/storage/v1/object/sign/community-post-images/author/post/photo.png?token=h.$token.s',
        );
      }

      final initial = signed(3600);
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('bil-renew-test');
        cache = ScopedMediaFileCache(directory: root)..bindViewer('A');
        final bytes = Uint8List.fromList(
          image.encodePng(
            image.Image(width: 32, height: 32)
              ..clear(image.ColorRgb8(20, 140, 160)),
          ),
        );
        final digest = sha256.convert(bytes).toString(),
            key = ScopedMediaFileCache.identity(initial, 'A');
        await File('${root.path}/${key}_$digest.img').writeAsBytes(bytes);
        await File('${root.path}/$key.json').writeAsString(
          jsonEncode({
            'digest': digest,
            'length': bytes.length,
            'saved': DateTime.now().millisecondsSinceEpoch,
            'path': initial.path,
          }),
        );
      });
      Future<void> settleIO() async {
        for (var i = 0; i < 80; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
      }

      Future<void> show(String owner) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BilPersistentNetworkImage(
              initial.toString(),
              viewerId: owner,
              cache: cache,
              access: access,
              errorBuilder: (_, _, _) => const Text('TEST access unavailable'),
            ),
          ),
        );
        await settleIO();
      }

      await show('A');
      expect(pending, hasLength(1));
      expect(
        find.byType(Image),
        findsNothing,
        reason:
            'A cached private photo needs fresh authorization for this viewer',
      );
      pending.single.complete(initial);
      await settleIO();
      expect(find.byType(Image), findsOneWidget);
      final decoded = tester.widget<Image>(find.byType(Image)).image;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(pending.length, 2);
      expect(tester.widget<Image>(find.byType(Image)).image, decoded);
      pending.last.complete(signed(7200));
      await settleIO();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).image, decoded);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(pending.length, 3);
      pending.last.complete(null);
      await settleIO();
      expect(find.text('TEST access unavailable'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      final files = await tester.runAsync(() => root.list().toList());
      expect(files, isEmpty);
      await show('B');
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await cache.clear();
        cache.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });
      expect(tester.takeException(), isNull);
    },
  );
}
