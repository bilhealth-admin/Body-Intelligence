import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/commerce/presentation/ai_boost_coach_artwork.dart';
import 'package:body_intelligence_log/shared/widgets/bil_account_avatar.dart';
import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses a neutral account fallback and never the AI Coach', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BilAccountAvatar(radius: 24)),
    );

    final fallback = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(fallback.backgroundImage, isNull);
    expect(fallback.foregroundImage, isNull);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(BilCoachPortrait), findsNothing);
  });

  testWidgets('changing the member photo leaves the approved coach unchanged', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    Future<void> pump(Uint8List? photo) => tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            BilAccountAvatar(radius: 24, photoBytes: photo),
            const BilAiBoostCoachArtwork(size: 64, semanticLabel: 'AI Coach'),
          ],
        ),
      ),
    );

    await pump(null);
    var coach = tester.widget<Image>(
      find.byKey(const ValueKey('ai-boost-coach-artwork-image')),
    );
    expect((coach.image as ResizeImage).imageProvider, isA<AssetImage>());
    expect(
      ((coach.image as ResizeImage).imageProvider as AssetImage).assetName,
      bilApprovedAiCoachAsset,
    );

    await pump(bytes);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isA<MemoryImage>(),
    );
    coach = tester.widget<Image>(
      find.byKey(const ValueKey('ai-boost-coach-artwork-image')),
    );
    expect(
      ((coach.image as ResizeImage).imageProvider as AssetImage).assetName,
      bilApprovedAiCoachAsset,
    );
  });

  testWidgets('a chosen member photo takes precedence over the fallback', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(home: BilAccountAvatar(radius: 24, photoBytes: bytes)),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<MemoryImage>());
  });

  testWidgets('cloud photo is authoritative with local bytes as fallback', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BilAccountAvatar(
          radius: 24,
          photoBytes: bytes,
          networkUrl: 'https://bilhealth.com/avatar.png',
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect(avatar.backgroundImage, isA<MemoryImage>());
  });
}
