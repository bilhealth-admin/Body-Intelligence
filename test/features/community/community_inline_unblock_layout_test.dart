import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/presentation/community_blocked_members_sheet.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '00000000-0000-4000-8000-000000009999';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'inline Unblock preserves confirmation at 320dp scale2 $language',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final h = await _mount(tester, language: language, count: 1, scale: 2);
        try {
          final member = h.repository.members.single;
          final name = find.text(member.name!);
          final action = find.byKey(Key('community-unblock-${member.id}'));
          final nameRect = tester.getRect(name);
          final actionRect = tester.getRect(action);
          expect(
            nameRect.top < actionRect.bottom &&
                nameRect.bottom > actionRect.top,
            isTrue,
            reason:
                'Unblock sits beside the name, not in a separate row below.',
          );
          expect(actionRect.height, greaterThanOrEqualTo(44));
          expect(actionRect.width, greaterThanOrEqualTo(44));
          if (language == 'ar') {
            expect(actionRect.right, lessThanOrEqualTo(nameRect.left));
          } else {
            expect(actionRect.left, greaterThanOrEqualTo(nameRect.right));
          }
          expect(find.byType(CircleAvatar), findsOneWidget);
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getSemantics(action).label, contains(member.name!));
          expect(tester.takeException(), isNull);

          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('community-unblock-confirm')),
            findsOneWidget,
          );
          await tester.tap(
            find.widgetWithText(
              TextButton,
              language == 'ar' ? 'إلغاء' : 'Cancel',
            ),
          );
          await tester.pumpAndSettle();
          expect(h.repository.unblocks, isEmpty);
          expect(find.text(member.name!), findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('community-unblock-confirm')));
          await tester.pumpAndSettle();
          expect(h.repository.unblocks, [(_owner, member.id)]);
          expect(h.repository.loads, 2);
          expect(find.text(member.name!), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await h.close(tester);
        }
      },
    );
  }

  testWidgets(
    '300 blocked rows build lazily and the last action removes its exact ID',
    (tester) async {
      final h = await _mount(tester, count: 300);
      try {
        final target = h.repository.members.last;
        expect(
          find.byType(BilPearlMaterialCard).evaluate().length,
          lessThan(40),
          reason:
              'A blocked list of hundreds must not eagerly build every card.',
        );
        final action = find.byKey(Key('community-unblock-${target.id}'));
        expect(action, findsNothing);
        await tester.scrollUntilVisible(
          action,
          1000,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 100,
        );
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        expect(h.repository.loads, 1);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('community-unblock-confirm')));
        await tester.pumpAndSettle();
        expect(h.repository.unblocks, [(_owner, target.id)]);
        expect(h.repository.members.length, 299);
        expect(
          h.repository.members.any((member) => member.id == target.id),
          isFalse,
        );
        expect(h.repository.members.first.id, _id(0));
        expect(h.repository.loads, 2);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
}

String _boundedName(String name) =>
    name.length <= 60 ? name : name.substring(0, 60);

String _id(int index) =>
    '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';

Future<_Harness> _mount(
  WidgetTester tester, {
  String language = 'en',
  required int count,
  double scale = 1,
}) async {
  final client = (await tester.runAsync(() async {
    final client = SupabaseClient(
      'https://inline-unblock.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-token',
        'token_type': 'bearer',
        'user': {
          'id': _owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    return client;
  }))!;
  final name = language == 'ar'
      ? 'عضو تجريبي باسم طويل لاختبار العرض بجوار زر إلغاء الحظر'
      : 'Synthetic blocked member with a long name for inline layout';
  final members = [
    for (var i = 0; i < count; i++)
      CommunityBlockedMember(
        id: _id(i),
        name: _boundedName(
          count == 1 ? name : 'Member ${i.toString().padLeft(3, '0')} $name',
        ),
        createdAt: DateTime.utc(2026, 11, 18),
      ),
  ];
  final h = _Harness(client, _Repository(client, members));
  await tester.binding.setSurfaceSize(const Size(320, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: CommunityBlockedMembersSheet(repository: h.repository),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

class _Harness {
  _Harness(this.client, this.repository);
  final SupabaseClient client;
  final _Repository repository;
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(client.dispose);
  }
}

class _Repository extends CommunityRepository {
  _Repository(super.client, this.members);
  final List<CommunityBlockedMember> members;
  final unblocks = <(String, String)>[];
  int loads = 0;
  @override
  Future<List<CommunityBlockedMember>> loadBlockedMembers() async {
    loads++;
    return List.unmodifiable(members);
  }

  @override
  Future<void> unblockMember(String id) async {
    unblocks.add((currentUserId, id));
    members.removeWhere((member) => member.id == id);
  }
}
