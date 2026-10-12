import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:body_intelligence_log/shared/widgets/bil_account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  final valid = Uint8List.fromList(
    image.encodePng(
      image.Image(width: 32, height: 32)..clear(image.ColorRgb8(20, 180, 140)),
    ),
  );
  testWidgets(
    'same-owner loading and corrupt replacement retain decoded photo; deletion clears; ABA does not inherit',
    (tester) async {
      final boundary = GlobalKey();
      Future<void> show(
        String owner,
        Uint8List? bytes, {
        bool loading = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: boundary,
              child: Center(
                child: BilAccountAvatar(
                  radius: 42,
                  ownerId: owner,
                  photoBytes: bytes,
                  loading: loading,
                ),
              ),
            ),
          ),
        );
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 200));
          if (bytes == null ||
              bytes.length < 4 ||
              tester
                      .widget<CircleAvatar>(find.byType(CircleAvatar))
                      .foregroundImage !=
                  null) {
            break;
          }
        }
      }

      ImageProvider? visible() => tester
          .widget<CircleAvatar>(find.byType(CircleAvatar))
          .foregroundImage;
      Future<Uint8List> pixels(String name) async {
        return (await tester.runAsync(() async {
          final rendered =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = (await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          rendered.dispose();
          final file = File('build/stage1-closure/images/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data);
          return data;
        }))!;
      }

      await show('A', valid);
      final decoded = visible();
      expect(decoded, isA<ResizeImage>());
      final before = await pixels('avatar-valid');
      await show('A', null, loading: true);
      expect(visible(), decoded);
      expect(await pixels('avatar-refresh-retained'), orderedEquals(before));
      await show('A', Uint8List.fromList([1, 2, 3]));
      expect(
        visible(),
        decoded,
        reason: 'corrupt bytes cannot replace a decoded valid photo',
      );
      await show('A', null, loading: true);
      await show('A', null);
      expect(visible(), isNull);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      await pixels('avatar-deleted');
      await show('A', valid);
      await show('B', null, loading: true);
      expect(visible(), isNull);
      await show('A', null, loading: true);
      expect(
        visible(),
        isNull,
        reason: 'old A pixels cannot survive A -> B -> A',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
