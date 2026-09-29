import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/localization/sapphire_copy.dart';
import 'package:body_intelligence_log/features/community/domain/community_attention.dart';
import 'package:body_intelligence_log/features/community/presentation/community_sapphire.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';

void main() {
  for (final locale in SapphireCopy.values.keys) {
    test('Sapphire copy covers every key in $locale', () {
      expect(SapphireCopy.values[locale]!.length, SapphireCopy.keys.length);
      for (final key in SapphireCopy.keys)
        expect(SapphireCopy.text(locale, key).trim(), isNotEmpty);
    });
  }
  Map<String, dynamic> row(
    String id,
    String peer,
    int hour, {
    bool read = false,
  }) => {
    'id': id,
    'sender_id': peer,
    'recipient_id': 'owner',
    'body': '[BIL-SUBJECT]Subject\nBody',
    'created_at': DateTime(2026, 9, 29, hour).toIso8601String(),
    'read_at': read ? '2026-09-29T14:00:00' : null,
    'profile': {'display_name': 'Same name'},
  };
  test('thread previews group identities instead of shared names', () {
    final input = [row('1', 'a', 8), row('2', 'a', 9), row('3', 'b', 10)];
    final result = communityThreadPreviewRows(input, incoming: true);
    expect(result.map((r) => r['id']), ['3', '2']);
    expect(result.last['body'], '[BIL-SUBJECT]Subject\nBody');
    expect(input.map((r) => r['id']), ['1', '2', '3']);
  });
  test('authoritative zero wins over stale preview flags', () {
    final input = [row('a', 'peer', 8)];
    expect(communityThreadUnreadCount('peer', input), 1);
    expect(
      communityThreadUnreadCount('peer', input, authoritative: const {}),
      0,
    );
    expect(
      communityThreadUnreadCount(
        'peer',
        input,
        authoritative: const {'peer': 500},
      ),
      500,
    );
  });
  test(
    'attention distinguishes pending first load from confirmed zero',
    () async {
      final pending = Completer<CommunityAttention>();
      final c = CommunityAttentionController(() => pending.future);
      c.setOwner('a');
      expect(c.hasSnapshot, isFalse);
      pending.complete(const CommunityAttention());
      await c.refresh();
      expect(c.hasSnapshot, isTrue);
      expect(c.value.total, 0);
      c.setOwner(null);
      expect(c.hasSnapshot, isFalse);
      c.dispose();
    },
  );
  testWidgets('Sapphire theme never leaks into the dashboard/watch ancestor', (
    tester,
  ) async {
    Color? outside;
    Color? inside;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.green),
        home: Builder(
          builder: (context) {
            outside = Theme.of(context).colorScheme.primary;
            return CommunitySurface(
              child: Builder(
                builder: (inner) {
                  inside = Theme.of(inner).colorScheme.primary;
                  return const Scaffold(body: Text('Community'));
                },
              ),
            );
          },
        ),
      ),
    );
    expect(inside, CommunitySapphire.blue);
    expect(outside, isNot(inside));
  });
  for (final dark in [false, true]) {
    testWidgets('outgoing bubbles have deliberate colors dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: CommunityMessageBubble(
                mine: true,
                child: Text(
                  'A long message that wraps naturally instead of becoming a full-width panel.',
                ),
              ),
            ),
          ),
        ),
      );
      final bubble = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CommunityMessageBubble),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((w) => w.decoration is BoxDecoration);
      expect(
        (bubble.decoration as BoxDecoration).color,
        CommunitySapphire.blue,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CommunityMessageBubble)).width, 400);
    });
  }
  test('welcome art is local and registered', () {
    expect(CommunityWelcome.imageAsset, startsWith('assets/'));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains(CommunityWelcome.imageAsset),
    );
    expect(File(CommunityWelcome.imageAsset).existsSync(), isTrue);
  });
  test(
    'presentation and daily projection do not request native permissions',
    () {
      final source = File(
        'lib/features/community/presentation/community_sapphire.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('MethodChannel')));
      final history = File(
        'lib/features/connected_health/connected_health_daily_history.dart',
      ).readAsStringSync();
      expect(history, isNot(contains('requestPermissions')));
      expect(history, isNot(contains("store.remove('health_signals'")));
    },
  );
}
