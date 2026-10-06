import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_post_gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final media = [
    for (var i = 0; i < 4; i++)
      CommunityPostMedia.fromJson({
        'media_position': i,
        'object_path': 'synthetic/post/photo-$i.jpg',
        'mime_type': 'image/jpeg',
        'bytes': 1000,
        'width': 1200,
        'height': 800,
        'url': 'https://gallery-fixture.invalid/$i.jpg',
      }),
  ];

  for (var index = 0; index < 4; index++) {
    testWidgets(
      'gallery opens tapped media $index with actual identity and navigates',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityPostGalleryPage(media: media, initialIndex: index),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('${index + 1}/4'), findsOneWidget);
        final viewer = find.byKey(Key('community-gallery-viewer-$index'));
        final image = tester.widget<Image>(
          find.descendant(of: viewer, matching: find.byType(Image)),
        );
        expect(
          (image.image as NetworkImage).url,
          'https://gallery-fixture.invalid/$index.jpg',
        );
        expect(tester.widget<InteractiveViewer>(viewer).maxScale, 4);
        if (index < 3) {
          await tester.tap(find.byKey(const Key('community-gallery-next')));
          await tester.pumpAndSettle();
          expect(find.text('${index + 2}/4'), findsOneWidget);
          await tester.tap(find.byKey(const Key('community-gallery-previous')));
          await tester.pumpAndSettle();
          expect(find.text('${index + 1}/4'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('zoom holds horizontal page and back preserves caller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunityPostGalleryPage(media: media),
                ),
              ),
              child: const Text('Open gallery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('community-gallery-viewer-0')),
    );
    viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    final pages = tester.widget<PageView>(
      find.byKey(const Key('community-full-gallery-pages')),
    );
    expect(pages.physics, isA<NeverScrollableScrollPhysics>());
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
