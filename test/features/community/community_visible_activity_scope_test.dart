import 'dart:async';

import 'package:body_intelligence_log/features/community/presentation/community_visible_activity_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fixture {
  String owner = 'owner-a';
  bool enabled = true;
  int retry = 0;
  bool fail = false;
  Set<String>? partial;
  Completer<Set<String>>? pending;
  final writes = <({String owner, List<String> ids})>[];
  final nav = GlobalKey<NavigatorState>();
  final scroll = ScrollController();
  late StateSetter rebuild;

  Widget app() => MaterialApp(
    navigatorKey: nav,
    home: StatefulBuilder(
      builder: (context, update) {
        rebuild = update;
        return Scaffold(
          body: CommunityVisibleActivityScope(
            ownerId: owner,
            enabled: enabled,
            retryKey: retry,
            unreadIds: {for (var i = 0; i < 12; i++) 'row-$i'},
            onSeen: (ids) async {
              writes.add((owner: owner, ids: List.of(ids)));
              if (fail) throw StateError('Synthetic offline failure');
              final wait = pending;
              if (wait != null) return wait.future;
              return partial ?? ids.toSet();
            },
            builder: (context, marker) => ListView(
              controller: scroll,
              children: [
                for (var i = 0; i < 12; i++)
                  SizedBox(
                    key: marker('row-$i'),
                    height: 200,
                    child: Text('Row $i'),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<_Fixture> _mount(WidgetTester tester, {_Fixture? fixture}) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final value = fixture ?? _Fixture();
  addTearDown(value.scroll.dispose);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(value.app());
  await tester.pump();
  return value;
}

Future<void> _dwell(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 650));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump();
}

void main() {
  testWidgets('only foreground viewport rows pass the continuous dwell', (
    tester,
  ) async {
    final f = await _mount(tester);
    await tester.pump(const Duration(milliseconds: 599));
    expect(f.writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(f.writes, hasLength(1));
    expect(f.writes.single.ids.toSet(), {'row-0', 'row-1', 'row-2'});
    await tester.pump(const Duration(seconds: 3));
    expect(f.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling away before dwell does not acknowledge skipped rows', (
    tester,
  ) async {
    final f = await _mount(tester);
    await tester.pump(const Duration(milliseconds: 200));
    f.scroll.jumpTo(1000);
    await tester.pump();
    await _dwell(tester);
    expect(f.writes.single.ids.toSet(), {'row-5', 'row-6', 'row-7'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('another row arriving does not restart an existing row dwell', (
    tester,
  ) async {
    final f = await _mount(tester);
    await tester.pump(const Duration(milliseconds: 400));
    f.scroll.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump();
    expect(f.writes, isNotEmpty);
    expect(f.writes.first.ids, contains('row-1'));
    expect(f.writes.first.ids, isNot(contains('row-3')));
    await _dwell(tester);
    expect(f.writes.expand((x) => x.ids), contains('row-3'));
  });

  testWidgets('background never qualifies and resume starts fresh dwell', (
    tester,
  ) async {
    final f = await _mount(tester);
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _dwell(tester);
    expect(f.writes, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(f.writes, isEmpty);
    await _dwell(tester);
    expect(f.writes, hasLength(1));
  });

  testWidgets('a covered route is not read even through a transparent route', (
    tester,
  ) async {
    final f = await _mount(tester);
    unawaited(
      f.nav.currentState!.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => const Scaffold(body: Text('Cover')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _dwell(tester);
    expect(f.writes, isEmpty);
    f.nav.currentState!.pop();
    await tester.pumpAndSettle();
    await _dwell(tester);
    expect(f.writes, hasLength(1));
  });

  testWidgets(
    'disabled scope does not mark and becomes eligible when enabled',
    (tester) async {
      final f = await _mount(tester, fixture: _Fixture()..enabled = false);
      await _dwell(tester);
      expect(f.writes, isEmpty);
      f.rebuild(() => f.enabled = true);
      await tester.pump();
      await _dwell(tester);
      expect(f.writes, hasLength(1));
    },
  );

  testWidgets('failed RPC stays unread and does not spin a retry loop', (
    tester,
  ) async {
    final f = await _mount(tester, fixture: _Fixture()..fail = true);
    await _dwell(tester);
    expect(f.writes, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(f.writes, hasLength(1));
    f.rebuild(() {
      f.fail = false;
      f.retry++;
    });
    await tester.pump();
    await _dwell(tester);
    expect(f.writes, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial readback is not guessed into a full acknowledgement', (
    tester,
  ) async {
    final f = await _mount(tester, fixture: _Fixture()..partial = {'row-0'});
    await _dwell(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(f.writes, hasLength(1));
    f.rebuild(() {
      f.partial = null;
      f.retry++;
    });
    await tester.pump();
    await _dwell(tester);
    expect(f.writes.last.ids, containsAll(['row-1', 'row-2']));
  });

  testWidgets('rows entering during an in-flight write are not dropped', (
    tester,
  ) async {
    final wait = Completer<Set<String>>();
    final f = await _mount(tester, fixture: _Fixture()..pending = wait);
    await _dwell(tester);
    expect(f.writes, hasLength(1));
    f.scroll.jumpTo(1000);
    await tester.pump();
    await _dwell(tester);
    expect(f.writes, hasLength(1));
    f.pending = null;
    wait.complete({'row-0', 'row-1', 'row-2'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    expect(f.writes, hasLength(2));
    expect(f.writes.last.ids.toSet(), {'row-5', 'row-6', 'row-7'});
  });

  testWidgets('owner change invalidates the prior pending acknowledgement', (
    tester,
  ) async {
    final wait = Completer<Set<String>>();
    final f = await _mount(tester, fixture: _Fixture()..pending = wait);
    await _dwell(tester);
    f.rebuild(() {
      f.owner = 'owner-b';
      f.pending = null;
    });
    await tester.pump();
    wait.complete({'row-0', 'row-1', 'row-2'});
    await tester.pump();
    await _dwell(tester);
    expect(f.writes.map((x) => x.owner), ['owner-a', 'owner-b']);
    expect(f.writes.last.ids.toSet(), {'row-0', 'row-1', 'row-2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing before dwell cancels all pending callbacks', (
    tester,
  ) async {
    final f = await _mount(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await _dwell(tester);
    expect(f.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late completion after disposal cannot schedule more writes', (
    tester,
  ) async {
    final wait = Completer<Set<String>>();
    final f = await _mount(tester, fixture: _Fixture()..pending = wait);
    await _dwell(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    wait.complete({'row-0'});
    await _dwell(tester);
    expect(f.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
