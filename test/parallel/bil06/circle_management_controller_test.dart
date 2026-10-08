import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';

import 'circle_management_client_fixture.dart';
import 'circle_management_model_test.dart'
    show bil06CapabilitiesJson, bil06ReceiptJson;

Future<void> _flush() => Future<void>.delayed(Duration.zero);

CommunityPostImageDraft _syntheticImage() => CommunityPostImageDraft(
  bytes: Uint8List.fromList([1, 2, 3]),
  mimeType: 'image/png',
  extension: 'png',
  width: 1,
  height: 1,
);

void main() {
  late Bil06FakeGateway gateway;
  late CircleManagementController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = Bil06FakeGateway();
    controller = CircleManagementController(
      gateway: gateway,
      searchDebounce: Duration.zero,
    );
  });
  tearDown(() => controller.dispose());

  group('BIL-06 controller transactions on synthetic gateway', () {
    test(
      'duplicate create taps have one in-flight mutation and receipt',
      () async {
        final pending = Completer<void>();
        gateway.onCreate = (id, draft) async {
          await pending.future;
          return gateway.save(id, 'create');
        };
        final first = controller.createCircle(bil06Draft());
        final second = controller.createCircle(bil06Draft());
        expect(identical(first, second), isTrue);
        pending.complete();
        expect((await first).succeeded, isTrue);
        expect((await second).succeeded, isTrue);
        expect(gateway.createCalls, 1);
        expect(gateway.readbackCalls, 1);
        await controller.createCircle(bil06Draft());
        expect(gateway.createCalls, 1);
      },
    );

    test(
      'committed create survives a later-hidden circle projection',
      () async {
        gateway.onReadOperation = (id) async => CircleMutationReceipt(
          ownerId: bil06OwnerA,
          requestId: id,
          operation: 'create',
          circleSlug: 'synthetic-circle',
        );
        final result = await controller.createCircle(bil06Draft());
        expect(result.succeeded, isTrue);
        expect(gateway.createCalls, 1);
        expect(gateway.readbackCalls, 1);
      },
    );

    test(
      'committed invite action survives a later-hidden invite projection',
      () async {
        gateway.onReadOperation = (id) async => CircleMutationReceipt(
          ownerId: bil06OwnerA,
          requestId: id,
          operation: 'invite_accept',
          circleSlug: 'synthetic-circle',
          inviteId: bil06InviteId,
        );
        final result = await controller.actOnInvite(
          bil06Invite(),
          CircleInviteAction.accept,
        );
        expect(result.succeeded, isTrue);
        expect(gateway.actionCalls, 1);
      },
    );

    test(
      'committed result is recovered after a full controller restart without mutation replay',
      () async {
        gateway.readbackFailure = StateError('synthetic readback unavailable');
        final first = await controller.createCircle(bil06Draft());
        expect(first.phase, CircleMutationPhase.readbackRequired);
        final receipt = gateway.receipts[first.requestId]!;

        controller.dispose();
        final restarted = Bil06FakeGateway();
        restarted.receipts[first.requestId] = receipt;
        gateway = restarted;
        controller = CircleManagementController(
          gateway: restarted,
          searchDebounce: Duration.zero,
        );

        await controller.restorePendingOperations();
        final recovered = controller.operation(CircleOperationKeys.create)!;
        expect(recovered.succeeded, isTrue);
        expect(recovered.requestId, first.requestId);
        expect(restarted.createCalls, 0);
        expect(restarted.readbackCalls, 1);
      },
    );

    test(
      'uncertain dispatch after restart retries the same durable request id',
      () async {
        gateway.onCreate = (id, draft) async =>
            throw StateError('synthetic lost dispatch');
        gateway.onReadOperation = (id) async => null;
        final first = await controller.createCircle(bil06Draft());
        expect(first.phase, CircleMutationPhase.failed);

        controller.dispose();
        final restarted = Bil06FakeGateway();
        restarted.onReadOperation = (id) async => restarted.receipts[id];
        gateway = restarted;
        controller = CircleManagementController(
          gateway: restarted,
          searchDebounce: Duration.zero,
        );
        await controller.restorePendingOperations();
        expect(
          controller.operation(CircleOperationKeys.create)!.phase,
          CircleMutationPhase.failed,
        );

        final retry = await controller.createCircle(bil06Draft());
        expect(retry.succeeded, isTrue);
        expect(retry.requestId, first.requestId);
        expect(restarted.submittedRequestIds, [first.requestId]);
      },
    );

    test('durable journal contains no circle copy or raw payload', () async {
      gateway.onCreate = (id, draft) async => throw StateError('offline');
      gateway.onReadOperation = (id) async => null;
      await controller.createCircle(bil06Draft(name: 'Sensitive circle title'));
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final saved = preferences
          .getKeys()
          .where((key) => key.startsWith('bil.community.circle.operations.v1.'))
          .map((key) => preferences.getString(key) ?? '')
          .join('\n');
      expect(saved, isNotEmpty);
      expect(saved, isNot(contains('Sensitive circle title')));
      expect(saved, isNot(contains('Synthetic description')));
      expect(saved, isNot(contains(bil06RecipientCode)));
    });

    test(
      'known commit followed by readback failure never replays mutation',
      () async {
        gateway.readbackFailure = StateError('synthetic readback unavailable');
        final first = await controller.createCircle(bil06Draft());
        expect(first.phase, CircleMutationPhase.readbackRequired);
        expect(controller.resetSucceededOperation(first.key), isFalse);
        await controller.createCircle(bil06Draft());
        expect(gateway.createCalls, 1);
        gateway.readbackFailure = null;
        final confirmed = await controller.retryReadback(first.key);
        expect(confirmed.succeeded, isTrue);
        expect(confirmed.requestId, first.requestId);
        expect(gateway.createCalls, 1);
      },
    );

    test('missing read after acknowledged receipt stays uncertain', () async {
      gateway.onReadOperation = (id) async => null;
      final result = await controller.createCircle(bil06Draft());
      expect(result.needsReadback, isTrue);
      await controller.createCircle(bil06Draft());
      expect(gateway.createCalls, 1);
      expect(controller.resetDefinitivelyFailedOperation(result.key), isFalse);
    });

    test(
      'failed dispatch with no receipt retries same request ID explicitly',
      () async {
        gateway.onCreate = (id, draft) async =>
            throw StateError('synthetic network');
        final first = await controller.createCircle(bil06Draft());
        expect(first.phase, CircleMutationPhase.failed);
        expect(controller.resetDefinitivelyFailedOperation(first.key), isFalse);
        gateway.onCreate = null;
        final retry = await controller.createCircle(bil06Draft());
        expect(retry.succeeded, isTrue);
        expect(gateway.submittedRequestIds, [first.requestId, first.requestId]);
      },
    );

    test(
      'unresolved create cannot be silently replaced with an edited draft',
      () async {
        gateway.readbackFailure = StateError('synthetic readback unavailable');
        final first = await controller.createCircle(bil06Draft());
        expect(
          () => controller.createCircle(bil06Draft(name: 'Edited name')),
          throwsA(isA<CircleReadbackPending>()),
        );
        expect(
          controller.operation(first.key)!.draft!.displayName,
          'Synthetic circle',
        );
        expect(gateway.createCalls, 1);
      },
    );

    test(
      'only proven pre-dispatch failure allows explicit draft reset',
      () async {
        gateway.capabilities = bil06Capabilities(create: false);
        final result = await controller.createCircle(bil06Draft());
        expect(result.phase, CircleMutationPhase.failed);
        expect(gateway.createCalls, 0);
        expect(controller.resetDefinitivelyFailedOperation(result.key), isTrue);
        gateway.capabilities = bil06Capabilities();
        expect(
          (await controller.createCircle(
            bil06Draft(name: 'New reviewed name'),
          )).succeeded,
          isTrue,
        );
      },
    );

    test('another confirmed create requires explicit reset', () async {
      final first = await controller.createCircle(bil06Draft());
      expect(controller.resetSucceededOperation(first.key), isTrue);
      final second = await controller.createCircle(
        bil06Draft(name: 'Another circle'),
      );
      expect(second.requestId, isNot(first.requestId));
      expect(gateway.createCalls, 2);
    });

    test(
      'invite send double-tap creates one invitation and preserves returned state',
      () async {
        final first = controller.sendInvite(
          circleSlug: 'synthetic-circle',
          recipientCode: bil06RecipientCode,
        );
        final second = controller.sendInvite(
          circleSlug: 'synthetic-circle',
          recipientCode: bil06RecipientCode.toUpperCase(),
        );
        expect(identical(first, second), isTrue);
        await first;
        await second;
        expect(gateway.sendCalls, 1);
        expect(controller.invites.single.status, CircleInviteStatus.pending);
      },
    );

    for (final action in CircleInviteAction.values) {
      test(
        'explicit invite ${action.name} applies authoritative response once',
        () async {
          final invite = bil06Invite(canCancel: true);
          final first = controller.actOnInvite(invite, action);
          final second = controller.actOnInvite(invite, action);
          await first;
          await second;
          expect(gateway.actionCalls, 1);
          expect(controller.invites.single.status, switch (action) {
            CircleInviteAction.accept => CircleInviteStatus.accepted,
            CircleInviteAction.decline => CircleInviteStatus.declined,
            CircleInviteAction.cancel => CircleInviteStatus.cancelled,
          });
        },
      );
    }

    test('third user cannot accept a targeted invitation', () async {
      final result = await controller.actOnInvite(
        bil06Invite(invitee: bil06OwnerB),
        CircleInviteAction.accept,
      );
      expect(result.phase, CircleMutationPhase.failed);
      expect(gateway.actionCalls, 0);
    });

    test(
      'contradictory invitation readback does not claim action succeeded',
      () async {
        gateway.onReadOperation = (id) async => CircleMutationReceipt(
          ownerId: bil06OwnerA,
          requestId: id,
          operation: 'invite_accept',
          circleSlug: 'synthetic-circle',
          inviteId: bil06InviteId,
          circle: bil06Circle(),
          invite: bil06Invite(),
        );
        final result = await controller.actOnInvite(
          bil06Invite(),
          CircleInviteAction.accept,
        );
        expect(result.phase, CircleMutationPhase.readbackRequired);
        expect(controller.invites, isEmpty);
        expect(gateway.actionCalls, 1);
      },
    );

    test('older query cannot replace latest server response', () async {
      await controller.loadCapabilities();
      final old = Completer<CircleSearchPage>();
      gateway.onSearch = (query, mine, cursor) async => query.isEmpty
          ? old.future
          : CircleSearchPage(circles: [bil06Circle(slug: 'new-result')]);
      final original = controller.refreshSearch();
      controller.setSearch('new');
      await _flush();
      expect(controller.searchRows.single.slug, 'new-result');
      old.complete(
        CircleSearchPage(circles: [bil06Circle(slug: 'old-result')]),
      );
      await original;
      expect(controller.searchRows.single.slug, 'new-result');
    });

    testWidgets('typing debounce sends only the latest query', (tester) async {
      controller.dispose();
      gateway = Bil06FakeGateway();
      controller = CircleManagementController(
        gateway: gateway,
        searchDebounce: const Duration(milliseconds: 350),
      );
      await controller.loadCapabilities();
      final queries = <String>[];
      gateway.onSearch = (query, mine, cursor) async {
        queries.add(query);
        return CircleSearchPage(circles: [bil06Circle()]);
      };
      controller.setSearch('old');
      await tester.pump(const Duration(milliseconds: 100));
      controller.setSearch('latest');
      await tester.pump(const Duration(milliseconds: 349));
      expect(queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(queries, ['latest']);
    });

    test(
      'capability revocation fences pending search and clears data',
      () async {
        await controller.loadCapabilities();
        final old = Completer<CircleSearchPage>();
        gateway.onSearch = (query, mine, cursor) => old.future;
        final original = controller.refreshSearch();
        gateway.capabilities = const CircleCapabilities.unavailable(
          ownerId: bil06OwnerA,
        );
        await controller.loadCapabilities();
        old.complete(CircleSearchPage(circles: [bil06Circle()]));
        await original;
        expect(controller.searchRows, isEmpty);
        expect(controller.capabilities!.canSearch, isFalse);
        expect(controller.searchLoading, isFalse);
      },
    );

    test(
      'pagination singleflight preserves earlier rows and next cursor',
      () async {
        await controller.loadCapabilities();
        final secondPage = Completer<CircleSearchPage>();
        var calls = 0;
        gateway.onSearch = (query, mine, cursor) async {
          calls++;
          return cursor == null
              ? CircleSearchPage(
                  circles: [bil06Circle(slug: 'alpha')],
                  nextAfterSlug: 'alpha',
                )
              : secondPage.future;
        };
        await controller.refreshSearch();
        final page = controller.loadMore();
        await controller.loadMore();
        secondPage.complete(
          CircleSearchPage(circles: [bil06Circle(slug: 'beta')]),
        );
        await page;
        expect(calls, 2);
        expect(controller.searchRows.map((row) => row.slug), ['alpha', 'beta']);
        expect(controller.searchHasMore, isFalse);
      },
    );

    test(
      'owner invalidation clears data and stale callback cannot revive visit',
      () async {
        await controller.loadCapabilities();
        final old = Completer<CircleSearchPage>();
        gateway.onSearch = (query, mine, cursor) => old.future;
        final pending = controller.refreshSearch();
        gateway.invalidate();
        gateway.current = true;
        old.complete(CircleSearchPage(circles: [bil06Circle()]));
        await pending;
        expect(controller.isCurrent, isFalse);
        expect(controller.searchRows, isEmpty);
        expect(controller.operations, isEmpty);
      },
    );

    test(
      'upload success requires reservation, bytes, finalize and readback',
      () async {
        final result = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        expect(result.succeeded, isTrue);
        expect(result.receipt!.media!.status, 'published');
        expect(gateway.prepareCalls, 1);
        expect(gateway.uploadCalls, 1);
        expect(gateway.finishCalls, 1);
        expect(gateway.readbackCalls, 2);
      },
    );

    test(
      'failed upload cancels real reservation and never finalizes',
      () async {
        gateway.uploadFailure = StateError('synthetic upload failed');
        final result = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.cover,
          image: _syntheticImage(),
        );
        expect(result.phase, CircleMutationPhase.cancelled);
        expect(result.error, isNotNull);
        expect(gateway.finishCalls, 0);
        expect(gateway.cancelCalls, 1);
        expect(gateway.removeCalls, 1);
      },
    );

    test(
      'cancel during byte upload waits safely and never publishes',
      () async {
        final bytes = Completer<void>();
        gateway.onUpload = () => bytes.future;
        final upload = controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        await _flush();
        final cancel = controller.cancelMedia(
          CircleOperationKeys.media('synthetic-circle', CircleMediaKind.avatar),
        );
        bytes.complete();
        expect((await upload).phase, CircleMutationPhase.cancelled);
        expect((await cancel).phase, CircleMutationPhase.cancelled);
        expect(gateway.finishCalls, 0);
        expect(gateway.cancelCalls, 1);
      },
    );

    test(
      'reservation readback retry sends no bytes until explicit resume',
      () async {
        gateway.readbackFailure = StateError('synthetic readback unavailable');
        final first = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        expect(first.needsReadback, isTrue);
        expect(gateway.uploadCalls, 0);
        gateway.readbackFailure = null;
        expect(
          (await controller.retryReadback(first.key)).phase,
          CircleMutationPhase.awaitingUpload,
        );
        expect(gateway.uploadCalls, 0);
        expect((await controller.resumeMedia(first.key)).succeeded, isTrue);
        expect(gateway.prepareCalls, 1);
        expect(gateway.uploadCalls, 1);
      },
    );

    test(
      'uncertain media finish survives restart and retries the same request id',
      () async {
        gateway.onFinish = (id, reservation) async =>
            throw StateError('synthetic finish reply lost');
        gateway.onReadOperation = (id) async => gateway.receipts[id];
        final first = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        expect(first.phase, CircleMutationPhase.failed);
        expect(first.operation, 'media_finish');
        final requestId = first.requestId;

        controller.dispose();
        final restarted = Bil06FakeGateway();
        restarted.onReadOperation = (id) async => restarted.receipts[id];
        String? retriedRequestId;
        restarted.onFinish = (id, reservation) async {
          retriedRequestId = id;
          return restarted.save(
            id,
            'media_finish',
            media: CircleMediaReservation(
              id: reservation.id,
              ownerId: reservation.ownerId,
              circleSlug: reservation.circleSlug,
              kind: reservation.kind,
              media: reservation.media,
              status: 'published',
            ),
          );
        };
        gateway = restarted;
        controller = CircleManagementController(
          gateway: restarted,
          searchDebounce: Duration.zero,
        );
        await controller.restorePendingOperations();
        expect(
          controller.operation(first.key)!.phase,
          CircleMutationPhase.failed,
        );

        final retried = await controller.retryFailedMedia(first.key);
        expect(retried.succeeded, isTrue);
        expect(retried.requestId, requestId);
        expect(retriedRequestId, requestId);
        expect(restarted.finishCalls, 1);
        expect(restarted.uploadCalls, 0);
        expect(restarted.prepareCalls, 0);
      },
    );

    test(
      'uncertain media cancel survives restart and retries the same request id',
      () async {
        gateway.uploadFailure = StateError('synthetic upload failed');
        gateway.onCancel = (id, reservation) async =>
            throw StateError('synthetic cancel reply lost');
        gateway.onReadOperation = (id) async => gateway.receipts[id];
        final first = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.cover,
          image: _syntheticImage(),
        );
        expect(first.phase, CircleMutationPhase.failed);
        expect(first.operation, 'media_cancel');
        final requestId = first.requestId;

        controller.dispose();
        final restarted = Bil06FakeGateway();
        restarted.onReadOperation = (id) async => restarted.receipts[id];
        String? retriedRequestId;
        restarted.onCancel = (id, reservation) async {
          retriedRequestId = id;
          return restarted.save(
            id,
            'media_cancel',
            media: CircleMediaReservation(
              id: reservation.id,
              ownerId: reservation.ownerId,
              circleSlug: reservation.circleSlug,
              kind: reservation.kind,
              media: reservation.media,
              status: 'cancelled',
            ),
          );
        };
        gateway = restarted;
        controller = CircleManagementController(
          gateway: restarted,
          searchDebounce: Duration.zero,
        );
        await controller.restorePendingOperations();
        expect(
          controller.operation(first.key)!.phase,
          CircleMutationPhase.failed,
        );

        final retried = await controller.cancelMedia(first.key);
        expect(retried.phase, CircleMutationPhase.cancelled);
        expect(retried.requestId, requestId);
        expect(retriedRequestId, requestId);
        expect(restarted.cancelCalls, 1);
        expect(restarted.removeCalls, 1);
        expect(restarted.uploadCalls, 0);
        expect(restarted.prepareCalls, 0);
      },
    );

    test(
      'finalize readback retry never reuploads or repeats finalize',
      () async {
        gateway.onFinish = (id, reservation) async {
          final result = gateway.save(
            id,
            'media_finish',
            media: CircleMediaReservation(
              id: reservation.id,
              ownerId: reservation.ownerId,
              circleSlug: reservation.circleSlug,
              kind: reservation.kind,
              media: reservation.media,
              status: 'published',
            ),
          );
          gateway.readbackFailure = StateError(
            'synthetic readback unavailable',
          );
          return result;
        };
        final first = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        expect(first.needsReadback, isTrue);
        gateway.readbackFailure = null;
        expect((await controller.cancelMedia(first.key)).succeeded, isTrue);
        expect(gateway.uploadCalls, 1);
        expect(gateway.finishCalls, 1);
        expect(gateway.cancelCalls, 0);
      },
    );

    test(
      'revoked permission before finish still allows cancel of real reservation',
      () async {
        gateway.onFinish = (id, reservation) async =>
            throw const CirclePermissionDenied();
        final failed = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        expect(failed.phase, CircleMutationPhase.failed);
        final cancelled = await controller.cancelMedia(failed.key);
        expect(cancelled.phase, CircleMutationPhase.cancelled);
        expect(gateway.uploadCalls, 1);
        expect(gateway.cancelCalls, 1);
        expect(gateway.removeCalls, 1);
      },
    );

    test(
      'confirmed delayed cancellation cleans storage without replaying cancel RPC',
      () async {
        gateway.uploadFailure = StateError('synthetic upload failure');
        gateway.onCancel = (id, reservation) async {
          final result = gateway.save(
            id,
            'media_cancel',
            media: CircleMediaReservation(
              id: reservation.id,
              ownerId: reservation.ownerId,
              circleSlug: reservation.circleSlug,
              kind: reservation.kind,
              media: reservation.media,
              status: 'cancelled',
            ),
          );
          gateway.readbackFailure = StateError(
            'synthetic cancel readback failure',
          );
          return result;
        };
        final uncertain = await controller.uploadMedia(
          circleSlug: 'synthetic-circle',
          kind: CircleMediaKind.avatar,
          image: _syntheticImage(),
        );
        expect(uncertain.needsReadback, isTrue);
        expect(gateway.removeCalls, 0);
        gateway.readbackFailure = null;
        final cancelled = await controller.retryReadback(uncertain.key);
        expect(cancelled.phase, CircleMutationPhase.cancelled);
        expect(gateway.cancelCalls, 1);
        expect(gateway.removeCalls, 1);
        await controller.retryReadback(uncertain.key);
        expect(gateway.cancelCalls, 1);
        expect(gateway.removeCalls, 1);
      },
    );
  });

  group('BIL-06 modal attempt transport fence', () {
    test(
      'closing during capability preflight sends no mutation; next sheet reads same ID',
      () async {
        controller.dispose();
        final transport = Bil06MemoryTransport();
        final concrete = RepositoryCircleManagementGateway.withTransport(
          transport: transport,
          isCurrentVisit: () => true,
        );
        controller = CircleManagementController(gateway: concrete);
        final preflight = Completer<Object?>();
        final preflightStarted = Completer<void>();
        var open = true;
        transport.handler = (name, params) {
          if (!preflightStarted.isCompleted) preflightStarted.complete();
          return preflight.future;
        };
        final attempt = concrete.runForAttempt(
          isCurrentAttempt: () => open,
          action: () => controller.createCircle(bil06Draft()),
        );
        // Durable-journal restore is asynchronous. Wait for the real RPC
        // boundary before closing; do not race it with a fixed pump count.
        await preflightStarted.future.timeout(const Duration(seconds: 3));
        expect(transport.calls.map((call) => call.name), [
          'bil_circle_capabilities_v1',
        ]);
        open = false;
        preflight.complete(bil06CapabilitiesJson());
        await expectLater(
          attempt,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        expect(transport.calls.map((call) => call.name), [
          'bil_circle_capabilities_v1',
        ]);
        final state = controller.operation(CircleOperationKeys.create)!;
        expect(state.needsReadback, isTrue);
        expect(controller.resetSucceededOperation(state.key), isFalse);
        transport.handler = (name, params) async {
          expect(name, 'bil_circle_operation_v1');
          expect(params['p_request_id'], state.requestId);
          return null;
        };
        await controller.retryReadback(state.key);
        expect(transport.calls.length, 2);
        await transport.events.close();
      },
    );

    test(
      'closing after dispatch keeps uncertain request and only reads its receipt',
      () async {
        controller.dispose();
        final transport = Bil06MemoryTransport();
        final concrete = RepositoryCircleManagementGateway.withTransport(
          transport: transport,
          isCurrentVisit: () => true,
        );
        controller = CircleManagementController(gateway: concrete);
        final response = Completer<Object?>();
        var open = true;
        String? requestId;
        transport.handler = (name, params) async {
          if (name == 'bil_circle_capabilities_v1') {
            return bil06CapabilitiesJson();
          }
          requestId = params['p_request_id'] as String;
          return response.future;
        };
        final attempt = concrete.runForAttempt(
          isCurrentAttempt: () => open,
          action: () => controller.createCircle(bil06Draft()),
        );
        await _flush();
        expect(requestId, isNotNull);
        open = false;
        response.complete(bil06ReceiptJson(requestId!, 'create'));
        await expectLater(
          attempt,
          throwsA(isA<CommunityOwnerOperationCancelled>()),
        );
        final state = controller.operation(CircleOperationKeys.create)!;
        expect(state.needsReadback, isTrue);
        transport.handler = (name, params) async {
          expect(name, 'bil_circle_operation_v1');
          return bil06ReceiptJson(requestId!, 'create');
        };
        final confirmed = await controller.retryReadback(state.key);
        expect(confirmed.succeeded, isTrue);
        expect(
          transport.calls
              .where((call) => call.name == 'bil_circle_create_v1')
              .length,
          1,
        );
        await transport.events.close();
      },
    );
  });
}
