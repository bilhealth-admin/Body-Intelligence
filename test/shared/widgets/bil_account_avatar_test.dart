import 'dart:convert';

import 'package:body_intelligence_log/shared/widgets/bil_account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the fixed AI Coach portrait only as account fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BilAccountAvatar(radius: 24)),
    );

    final fallback = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      fallback.backgroundImage,
      const AssetImage(bilCoachFallbackAvatarAsset),
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
