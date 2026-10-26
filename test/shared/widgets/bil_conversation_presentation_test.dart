import 'package:body_intelligence_log/shared/widgets/bil_conversation_presentation.dart';
import 'package:body_intelligence_log/features/community/presentation/community_visible_activity_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BilConversationPresentationRow row(
  String id,
  int day, {
  bool mine = false,
  String text = 'Local text',
}) => BilConversationPresentationRow(
  id: id,
  text: text,
  mine: mine,
  createdAt: DateTime(2026, 10, day),
);

void main() {
  test(
    'initial history, pagination and repeated reads do not replay arrivals',
    () {
      final presentation = BilConversationPresentation()
        ..reset('ownerA/peer/1');
      presentation.observe([row('one', 20)]);
      expect(presentation.animateIncoming('one'), isFalse);
      presentation.observe([row('older', 19), row('one', 20), row('two', 21)]);
      expect(presentation.animateIncoming('older'), isFalse);
      expect(presentation.animateIncoming('two'), isTrue);
      presentation.observe([row('one', 20)]);
      expect(presentation.animateIncoming('one'), isFalse);
      presentation.dispose();
    },
  );

  test('a flight uses one newly fetched own row, never delivery authority', () {
    final presentation = BilConversationPresentation()..reset('ownerA/peer/1');
    presentation.observe([row('one', 20, mine: true, text: 'Draft')]);
    const origin = Rect.fromLTWH(10, 450, 250, 48);
    presentation.beginSend('Draft', origin);
    presentation.confirmSend();
    presentation.observe([
      row('one', 20, mine: true, text: 'Draft'),
      row('new', 21, mine: true, text: 'Draft'),
    ]);
    expect(presentation.originFor('one'), isNull);
    expect(presentation.originFor('new'), origin);
    expect(presentation.animateIncoming('new'), isFalse);
    presentation.finishOutgoing('new');
    expect(presentation.originFor('new'), isNull);
    presentation.dispose();
  });

  test('ambiguous copies and failed sends produce no misleading flight', () {
    final presentation = BilConversationPresentation()..reset('ownerA/peer/1');
    presentation.observe([]);
    presentation.beginSend('Draft', const Rect.fromLTWH(10, 450, 250, 48));
    presentation.confirmSend();
    presentation.observe([
      row('one', 20, mine: true, text: 'Draft'),
      row('two', 20, mine: true, text: 'Draft'),
    ]);
    expect(presentation.originFor('one'), isNull);
    expect(presentation.originFor('two'), isNull);
    presentation.beginSend('Failed', const Rect.fromLTWH(10, 450, 250, 48));
    presentation.abandonSend();
    presentation.observe([row('late', 21, mine: true, text: 'Failed')]);
    expect(presentation.originFor('late'), isNull);
    presentation.dispose();
  });

  test(
    'incoming content must be painted and fully arrived before read dwell',
    () {
      final presentation = BilConversationPresentation()
        ..reset('ownerA/peer/1');
      presentation.observe([row('history', 20)]);
      presentation.markPainted('history', true);
      expect(presentation.isPainted('history'), isTrue);
      presentation.observe([row('history', 20), row('new', 21)]);
      presentation.markPainted('new', true);
      expect(presentation.isPainted('new'), isFalse);
      presentation.presentationBecameVisible('new');
      expect(presentation.isPainted('new'), isTrue);
      // A native width/layout change withdraws readability until repaint.
      presentation.markPainted('new', false);
      expect(presentation.isPainted('new'), isFalse);
      presentation.markPainted('new', true);
      expect(presentation.isPainted('new'), isTrue);
      presentation.reset('ownerB/peer/2');
      presentation.presentationBecameVisible('new');
      presentation.markPainted('new', true);
      expect(presentation.isPainted('new'), isFalse);
      presentation.dispose();
    },
  );

  test(
    'owner or conversation replacement withdraws all presentation state',
    () {
      final presentation = BilConversationPresentation()
        ..reset('ownerA/peer/1');
      presentation.observe([row('one', 20)]);
      presentation.markPainted('one', true);
      presentation.beginSend(
        'Private draft',
        const Rect.fromLTWH(0, 400, 200, 40),
      );
      presentation.reset('ownerB/peer/2');
      expect(presentation.isPainted('one'), isFalse);
      presentation.observe([row('one', 20, mine: true, text: 'Private draft')]);
      expect(presentation.originFor('one'), isNull);
      expect(presentation.animateIncoming('one'), isFalse);
      presentation.dispose();
    },
  );

  testWidgets(
    'read dwell begins after painted content, not native layout wait',
    (tester) async {
      final presentation = BilConversationPresentation()
        ..reset('ownerA/peer/1');
      presentation.observe([row('one', 20)]);
      final reads = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityVisibleActivityScope(
              ownerId: 'ownerA/peer/1',
              unreadIds: const {'one'},
              isRowPainted: presentation.isPainted,
              paintChanges: presentation,
              onSeen: (ids) async {
                reads.addAll(ids);
                return ids.toSet();
              },
              builder: (context, marker) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: marker('one'),
                  height: 100,
                  width: 200,
                  child: const Text('Synthetic native layout placeholder'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(reads, isEmpty);
      presentation.markPainted('one', true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 599));
      expect(reads, isEmpty);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(reads, ['one']);
      await tester.pumpWidget(const SizedBox.shrink());
      presentation.dispose();
    },
  );
}
