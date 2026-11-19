import 'dart:async';

import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bubble = Key('bil-crystal-arrow-bubble');
const _crystal = Key('static-style-crystal');
const _owner = '11111111-1111-4111-8111-111111111111';
const _peer = '22222222-2222-4222-8222-222222222222';

typedef _Surface = ({BoxDecoration fill, BoxDecoration shell});

List<_Surface> _surfaces(WidgetTester tester) {
  final result = <_Surface>[];
  for (final element in find.byKey(_bubble).evaluate()) {
    final fill = (element.widget as DecoratedBox).decoration as BoxDecoration;
    BoxDecoration? shell;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        if (decoration.shape == BoxShape.circle &&
            decoration.boxShadow != null) {
          shell = decoration;
          return false;
        }
      }
      return true;
    });
    final resolvedShell = shell;
    if (resolvedShell == null) {
      throw StateError('Actual crystal shadow shell was not found.');
    }
    result.add((fill: fill, shell: resolvedShell));
  }
  return result;
}

Widget _single(MediaQueryData data, bool dark) => MaterialApp(
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  home: MediaQuery(
    data: data,
    child: const Center(
      child: BilCrystalArrow(
        key: _crystal,
        child: Icon(Icons.chevron_left_rounded),
      ),
    ),
  ),
);

class _ArrowChatRepository extends CommunityRepository {
  _ArrowChatRepository(super.client);

  final changes = StreamController<void>.broadcast();
  final rows = <CommunityMessage>[];
  int sends = 0;
  int readCalls = 0;

  @override
  String get currentUserId => _owner;

  @override
  Stream<void> watchConversationChanges(String id) => changes.stream;

  @override
  Future<List<CommunityMessage>> loadMessages(String id) async => List.of(rows);

  @override
  Future<int> markVisibleMessagesRead(List<String> ids) async {
    readCalls++;
    return ids.length;
  }

  @override
  Future<Set<String>> loadReadMessageIds(String peer, List<String> ids) async {
    readCalls++;
    return ids.toSet();
  }

  @override
  Future<void> sendMessageOperation(
    String recipientId,
    String body, {
    required String requestId,
  }) async {
    sends++;
    throw StateError('This visual refresh case must not send a message.');
  }
}

Widget _chat(_ArrowChatRepository repository, MediaQueryData flags) =>
    MaterialApp(
      theme: BilFlagshipTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          highContrast: flags.highContrast,
          accessibleNavigation: flags.accessibleNavigation,
          disableAnimations: flags.disableAnimations,
        ),
        child: child!,
      ),
      home: CommunityChatPage(
        userId: _peer,
        displayName: 'Owned QA arrow refresh',
        repository: repository,
      ),
    );

CommunityMessage _ownMessage({bool read = false}) => CommunityMessage(
  id: 'owned-arrow-read-receipt',
  senderId: _owner,
  recipientId: _peer,
  body: 'Owned QA message for a read acknowledgement only.',
  createdAt: DateTime(2026, 11, 19, 2),
  readAt: read ? DateTime(2026, 11, 19, 2, 1) : null,
);

void main() {
  for (final dark in [false, true]) {
    for (final entry in <String, MediaQueryData>{
      'accessible navigation': const MediaQueryData(accessibleNavigation: true),
      'reduced motion': const MediaQueryData(disableAnimations: true),
    }.entries) {
      testWidgets(
        '${entry.key} omits blur without changing resting style dark=$dark',
        (tester) async {
          await tester.pumpWidget(_single(const MediaQueryData(), dark));
          await tester.pumpAndSettle();
          final before = _surfaces(tester);
          final size = tester.getSize(find.byKey(_bubble));
          expect(before, hasLength(1));
          expect(
            find.descendant(
              of: find.byKey(_crystal),
              matching: find.byType(BackdropFilter),
            ),
            findsOneWidget,
          );
          await tester.pumpWidget(_single(entry.value, dark));
          await tester.pumpAndSettle();
          expect(_surfaces(tester), before);
          expect(tester.getSize(find.byKey(_bubble)), size);
          expect(
            find.descendant(
              of: find.byKey(_crystal),
              matching: find.byType(BackdropFilter),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'high contrast retains its strong opaque static style dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          _single(
            const MediaQueryData(
              highContrast: true,
              accessibleNavigation: true,
              disableAnimations: true,
            ),
            dark,
          ),
        );
        await tester.pumpAndSettle();
        final surface = _surfaces(tester).single;
        final theme = Theme.of(tester.element(find.byKey(_bubble)));
        expect(surface.fill.border!.top.width, 1.5);
        expect(surface.fill.border!.top.color, theme.colorScheme.onSurface);
        expect(surface.shell.boxShadow, isEmpty);
        final colors = (surface.fill.gradient! as LinearGradient).colors;
        expect(colors.every((color) => color.a == 1), isTrue);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in <String, MediaQueryData>{
    'normal': const MediaQueryData(),
    'accessible navigation': const MediaQueryData(accessibleNavigation: true),
    'reduced motion': const MediaQueryData(disableAnimations: true),
    'high contrast': const MediaQueryData(highContrast: true),
  }.entries) {
    testWidgets(
      'actual DM read acknowledgement preserves both crystals ${entry.key}',
      (tester) async {
        var unexpectedHttp = 0;
        // Supabase starts a real JSON isolate in its constructor. Create its
        // ports/completer outside FakeAsync so real disposal can complete.
        final client = await tester.runAsync(
          () async => SupabaseClient(
            'https://arrow-refresh-unit.invalid',
            'unit-test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((_) async {
              unexpectedHttp++;
              throw StateError('The arrow refresh fixture must not call HTTP.');
            }),
          ),
        );
        if (client == null) {
          throw StateError('The real-zone QA client was not created.');
        }
        final repository = _ArrowChatRepository(client)
          ..rows.add(_ownMessage());
        addTearDown(() async {
          debugPrint('ARROW_FIXTURE ${entry.key}: teardown-unmount');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          debugPrint('ARROW_FIXTURE ${entry.key}: unmount-complete');
          // Request close in the controller's FakeAsync zone, then drain it.
          final controllerClosed = repository.changes.close();
          debugPrint('ARROW_FIXTURE ${entry.key}: controller-close-requested');
          await tester.pump();
          debugPrint('ARROW_FIXTURE ${entry.key}: controller-close-pumped');
          final cleanupCompleted = await tester.runAsync<bool>(() async {
            await controllerClosed.timeout(const Duration(seconds: 3));
            debugPrint('ARROW_FIXTURE ${entry.key}: controller-closed');
            debugPrint('ARROW_FIXTURE ${entry.key}: client-dispose-start');
            await client.dispose().timeout(const Duration(seconds: 5));
            debugPrint('ARROW_FIXTURE ${entry.key}: client-disposed');
            return true;
          });
          if (cleanupCompleted != true) {
            throw StateError(
              'Real QA teardown failed; see component milestone.',
            );
          }
          debugPrint('ARROW_FIXTURE ${entry.key}: teardown-complete');
        });
        debugPrint('ARROW_FIXTURE ${entry.key}: mount-start');
        await tester.pumpWidget(_chat(repository, entry.value));
        await tester.pumpAndSettle();
        debugPrint('ARROW_FIXTURE ${entry.key}: initial-frame');
        expect(find.byIcon(Icons.done_rounded), findsOneWidget);
        expect(find.byKey(const Key('community-safe-return')), findsOneWidget);
        expect(find.byKey(const Key('community-chat-send')), findsOneWidget);
        final before = _surfaces(tester);
        expect(before, hasLength(2));
        final sizes = [
          for (final element in find.byKey(_bubble).evaluate())
            tester.getSize(
              find.byElementPredicate(
                (candidate) => identical(candidate, element),
              ),
            ),
        ];
        repository.rows[0] = _ownMessage(read: true);
        debugPrint('ARROW_FIXTURE ${entry.key}: read-notify');
        repository.changes.add(null);
        await tester.pump();
        await tester.pumpAndSettle();
        debugPrint('ARROW_FIXTURE ${entry.key}: read-frame');
        expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
        expect(find.byIcon(Icons.done_rounded), findsNothing);
        expect(_surfaces(tester), before);
        expect([
          for (final element in find.byKey(_bubble).evaluate())
            tester.getSize(
              find.byElementPredicate(
                (candidate) => identical(candidate, element),
              ),
            ),
        ], sizes);
        expect(repository.sends, 0);
        expect(repository.readCalls, 0);
        expect(unexpectedHttp, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
