import 'dart:async';

import 'package:body_intelligence_log/features/community/circle_management/circle_management.dart';
import 'package:body_intelligence_log/features/community/circle_management/presentation/circle_management_surfaces.dart';
import 'package:body_intelligence_log/features/community/domain/community_circles.dart';
import 'package:body_intelligence_log/features/community/services/community_post_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'circle_management_client_fixture.dart';
import 'circle_management_ui_fixture.dart';

void main() {
  late Bil06FakeGateway gateway;
  late CircleManagementController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = Bil06FakeGateway();
    controller = CircleManagementController(gateway: gateway);
  });

  tearDown(() => controller.dispose());

  testWidgets(
    'capability failure offers a read retry and never a fake create',
    (tester) async {
      await bil06UiSize(tester);
      gateway.capabilityFailure = StateError('Synthetic offline failure');
      await bil06MountPanel(tester, controller);
      expect(
        find.byKey(const Key('bil06-capability-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bil06-create-entry')), findsNothing);
      expect(gateway.createCalls, 0);
      gateway.capabilityFailure = null;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bil06-create-entry')), findsOneWidget);
      expect(gateway.createCalls, 0);
      expect(gateway.sendCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create requires explicit privacy and review before any mutation',
    (tester) async {
      await bil06UiSize(tester);
      await bil06MountPanel(tester, controller);
      await bil06Tap(tester, 'bil06-create-entry');
      await tester.enterText(
        find.byKey(const Key('bil06-create-name')),
        'Synthetic circle',
      );
      await bil06Tap(tester, 'bil06-create-review');
      expect(find.text('Choose privacy.'), findsOneWidget);
      expect(gateway.createCalls, 0);
      await bil06Tap(tester, 'bil06-tools-back');
      await bil06ReviewCreate(tester);
      expect(find.byKey(const Key('bil06-create-review-name')), findsOneWidget);
      expect(find.text('Private · Invitation required'), findsOneWidget);
      expect(gateway.createCalls, 0);
      await bil06Tap(tester, 'bil06-create-edit');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('bil06-create-name')))
            .controller!
            .text,
        'Synthetic circle',
      );
      expect(gateway.createCalls, 0);
    },
  );

  testWidgets(
    'double create is one request and failed readback retries reads only',
    (tester) async {
      await bil06UiSize(tester);
      final pending = Completer<void>();
      gateway.onCreate = (requestId, draft) async {
        await pending.future;
        return gateway.save(requestId, 'create');
      };
      gateway.readbackFailure = StateError('Synthetic receipt fetch failure');
      await bil06MountPanel(tester, controller);
      await bil06ReviewCreate(tester);
      final submit = tester
          .widget<FilledButton>(find.byKey(const Key('bil06-create-submit')))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(gateway.createCalls, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('bil06-create-submit')))
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Circle created and confirmed.'), findsNothing);
      expect(find.byKey(const Key('bil06-readback-create')), findsOneWidget);
      expect(
        controller.operation(CircleOperationKeys.create)!.phase,
        CircleMutationPhase.readbackRequired,
      );
      gateway.readbackFailure = null;
      await bil06Tap(tester, 'bil06-readback-create');
      expect(gateway.createCalls, 1);
      expect(gateway.readbackCalls, 2);
      expect(find.text('Circle created and confirmed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a submitting sheet does not pop parent or replay on reopening',
    (tester) async {
      await bil06UiSize(tester);
      var changed = 0;
      final pending = Completer<void>();
      gateway.onCreate = (requestId, draft) async {
        await pending.future;
        return gateway.save(requestId, 'create');
      };
      await bil06MountPanel(
        tester,
        controller,
        onChanged: () async {
          changed++;
        },
      );
      await bil06ReviewCreate(tester);
      final oldSubmit = tester
          .widget<FilledButton>(find.byKey(const Key('bil06-create-submit')))
          .onPressed!;
      oldSubmit();
      await tester.pump();
      await tester.tap(find.byKey(const Key('bil06-tools-close')));
      await tester.pump(const Duration(milliseconds: 400));
      pending.complete();
      await tester.pumpAndSettle();
      oldSubmit();
      await tester.pumpAndSettle();
      expect(find.text('Outside circle management'), findsOneWidget);
      expect(changed, 0);
      expect(gateway.createCalls, 1);
      expect(
        controller.operation(CircleOperationKeys.create)!.phase,
        CircleMutationPhase.readbackRequired,
      );
      await bil06Tap(tester, 'bil06-open-test-panel');
      await bil06Tap(tester, 'bil06-create-entry');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('bil06-create-submit')))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('bil06-readback-create')),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('bil06-create-form')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('bil06-readback-create')),
        findsOneWidget,
        reason: 'The reopened form must show the retained request.',
      );
      expect(gateway.readbackCalls, 0);
      await bil06Tap(tester, 'bil06-readback-create');
      expect(find.text('Circle created and confirmed.'), findsOneWidget);
      expect(gateway.createCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing during permission preflight sends no create after Close',
    (tester) async {
      await bil06UiSize(tester);
      controller.dispose();
      final transport = Bil06MemoryTransport();
      addTearDown(transport.events.close);
      var capabilityReads = 0;
      final pending = Completer<Object?>();
      final capabilities = <String, Object?>{
        'owner_id': bil06OwnerA,
        'circle_slug': null,
        'available': true,
        'can_create': true,
        'can_search': true,
        'can_read_invites': true,
        'can_invite': false,
        'can_manage_media': false,
        'is_member': false,
        'role': null,
      };
      transport.handler = (name, params) async {
        if (name != 'bil_circle_capabilities_v1') {
          throw StateError('Unexpected request after closed preflight: $name');
        }
        capabilityReads++;
        return capabilityReads == 1 ? capabilities : pending.future;
      };
      final realGateway = RepositoryCircleManagementGateway.withTransport(
        transport: transport,
        isCurrentVisit: () => true,
      );
      controller = CircleManagementController(gateway: realGateway);
      await bil06MountPanel(tester, controller);
      await bil06ReviewCreate(tester);
      await tester.tap(find.byKey(const Key('bil06-create-submit')));
      await tester.pump();
      expect(capabilityReads, 2);
      await tester.tap(find.byKey(const Key('bil06-tools-close')));
      // Complete before waiting for the sheet's exit animation. The explicit
      // close flag, not eventual widget disposal, must already fence dispatch.
      pending.complete(capabilities);
      await tester.pumpAndSettle();
      expect(
        transport.calls.where((call) => call.name == 'bil_circle_create_v1'),
        isEmpty,
      );
      expect(
        transport.calls.where((call) => call.name == 'bil_circle_operation_v1'),
        isEmpty,
      );
      expect(
        controller.operation(CircleOperationKeys.create)!.phase,
        CircleMutationPhase.readbackRequired,
      );
      expect(realGateway.isCurrent, isTrue);
      expect(find.text('Outside circle management'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a third account gets no create or invitation-management actions',
    (tester) async {
      await bil06UiSize(tester);
      controller.dispose();
      gateway = Bil06FakeGateway(ownerId: bil06OwnerC)
        ..capabilities = bil06Capabilities(
          owner: bil06OwnerC,
          create: false,
          manage: false,
        )
        ..invitationRows = [bil06Invite(invitee: bil06OwnerA)];
      controller = CircleManagementController(gateway: gateway);
      await bil06MountPanel(tester, controller);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('bil06-create-entry')))
            .onTap,
        isNull,
      );
      await bil06Tap(tester, 'bil06-invites-entry');
      expect(find.byKey(const Key('bil06-invite-recipient')), findsNothing);
      for (final action in CircleInviteAction.values) {
        expect(
          find.byKey(Key('bil06-invite-${action.name}-$bil06InviteId')),
          findsNothing,
        );
      }
      expect(gateway.actionCalls, 0);
      expect(gateway.sendCalls, 0);
    },
  );

  for (final action in CircleInviteAction.values) {
    testWidgets(
      'reading invitation is inert; explicit ${action.name} returns its state',
      (tester) async {
        await bil06UiSize(tester);
        gateway.invitationRows = [
          bil06Invite(canCancel: action == CircleInviteAction.cancel),
        ];
        await bil06MountPanel(tester, controller);
        await bil06Tap(tester, 'bil06-invites-entry');
        expect(gateway.actionCalls, 0);
        await bil06Tap(tester, 'bil06-invite-${action.name}-$bil06InviteId');
        expect(gateway.actionCalls, 0);
        final confirm = tester
            .widget<FilledButton>(
              find.byKey(const Key('bil06-invite-confirm-$bil06InviteId')),
            )
            .onPressed!;
        confirm();
        confirm();
        await tester.pumpAndSettle();
        expect(gateway.actionCalls, 1);
        final expected = switch (action) {
          CircleInviteAction.accept => 'Accepted',
          CircleInviteAction.decline => 'Declined',
          CircleInviteAction.cancel => 'Cancelled',
        };
        expect(find.text(expected), findsOneWidget);
        expect(
          find.byKey(Key('bil06-invite-${action.name}-$bil06InviteId')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('recipient review and rapid send issue a single invitation', (
    tester,
  ) async {
    await bil06UiSize(tester);
    await bil06MountPanel(tester, controller, circle: bil06Circle());
    await bil06Tap(tester, 'bil06-invites-entry');
    await tester.enterText(
      find.byKey(const Key('bil06-invite-recipient')),
      bil06RecipientCode,
    );
    await bil06Tap(tester, 'bil06-invite-review');
    expect(find.byKey(const Key('bil06-invite-reviewed-code')), findsOneWidget);
    expect(gateway.sendCalls, 0);
    final send = tester
        .widget<FilledButton>(find.byKey(const Key('bil06-invite-send')))
        .onPressed!;
    send();
    send();
    await tester.pumpAndSettle();
    expect(gateway.sendCalls, 1);
    expect(gateway.invitationRows, hasLength(1));
    expect(find.text('Invitation saved and confirmed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invitation pagination appends authoritative rows without accepting them',
    (tester) async {
      await bil06UiSize(tester);
      controller.dispose();
      final paged = Bil06UiPagedInvitesGateway();
      controller = CircleManagementController(gateway: paged);
      await bil06MountPanel(tester, controller);
      await bil06Tap(tester, 'bil06-invites-entry');
      expect(paged.cursors, [null]);
      await bil06Tap(tester, 'bil06-invites-more');
      expect(paged.cursors, [null, bil06InviteId]);
      expect(
        find.byKey(const Key('bil06-invite-$bil06InviteId')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('bil06-invite-${Bil06UiPagedInvitesGateway.secondId}'),
        ),
        findsOneWidget,
      );
      expect(controller.invites, hasLength(2));
      expect(paged.actionCalls, 0);
      expect(find.byKey(const Key('bil06-invites-more')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final received in [true, false]) {
    testWidgets(
      'invitation shows verified ${received ? 'inviter' : 'recipient'} without a private identifier',
      (tester) async {
        await bil06UiSize(tester);
        gateway.invitationRows = [
          CircleInvitation(
            id: bil06InviteId,
            circleSlug: 'synthetic-circle',
            circleName: 'Synthetic circle',
            inviterId: received ? bil06OwnerB : bil06OwnerA,
            inviteeId: received ? bil06OwnerA : bil06OwnerB,
            inviterName: 'Synthetic inviter',
            inviteeName: 'Synthetic recipient',
            status: CircleInviteStatus.pending,
            canAccept: received,
            canDecline: received,
            canCancel: !received,
          ),
        ];
        await bil06MountPanel(tester, controller);
        await bil06Tap(tester, 'bil06-invites-entry');
        expect(
          find.text(
            received
                ? 'Invited by: Synthetic inviter'
                : 'Recipient: Synthetic recipient',
          ),
          findsOneWidget,
        );
        expect(find.textContaining(bil06OwnerA), findsNothing);
        expect(find.textContaining(bil06OwnerB), findsNothing);
        expect(gateway.actionCalls, 0);
      },
    );
  }

  testWidgets(
    'unavailable media, cancelled picker and upload failure never show success',
    (tester) async {
      await bil06UiSize(tester);
      final picker = Bil06UiPicker();
      await bil06MountPanel(
        tester,
        controller,
        circle: bil06Circle(),
        picker: picker,
      );
      await bil06Tap(tester, 'bil06-media-entry');
      expect(find.byType(CircleVerifiedMedia), findsWidgets);
      expect(find.text('Image unavailable'), findsWidgets);
      await bil06Tap(tester, 'bil06-pick-media-avatar');
      expect(gateway.prepareCalls, 0);
      expect(
        find.byKey(const Key('bil06-selected-media-avatar')),
        findsNothing,
      );
      picker.error = const CommunityPostImageException(
        CommunityPostImageFailure.invalidImage,
      );
      await bil06Tap(tester, 'bil06-pick-media-avatar');
      expect(
        find.byKey(const Key('bil06-picker-error-avatar')),
        findsOneWidget,
      );
      expect(gateway.uploadCalls, 0);
      picker.error = null;
      picker.result = bil06UiImage();
      gateway.uploadFailure = StateError('Synthetic byte transfer failure');
      await bil06Tap(tester, 'bil06-pick-media-avatar');
      expect(
        find.byKey(const Key('bil06-selected-media-avatar')),
        findsOneWidget,
      );
      expect(gateway.prepareCalls, 0);
      await bil06Tap(tester, 'bil06-upload-media-avatar');
      expect(gateway.uploadCalls, 1);
      expect(gateway.finishCalls, 0);
      expect(gateway.cancelCalls, 1);
      expect(find.text('Image saved and confirmed.'), findsNothing);
      expect(
        find.text(
          'The image could not be uploaded. Cancellation was confirmed. You can choose the image again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit upload cancellation waits for confirmation and never finalizes',
    (tester) async {
      await bil06UiSize(tester);
      final pending = Completer<void>();
      gateway.onUpload = () => pending.future;
      final picker = Bil06UiPicker()..result = bil06UiImage();
      await bil06MountPanel(
        tester,
        controller,
        circle: bil06Circle(),
        picker: picker,
      );
      await bil06Tap(tester, 'bil06-media-entry');
      await bil06Tap(tester, 'bil06-pick-media-avatar');
      await bil06ReadyToTap(tester, 'bil06-upload-media-avatar');
      await tester.tap(find.byKey(const Key('bil06-upload-media-avatar')));
      await tester.pump();
      expect(gateway.uploadCalls, 1);
      await bil06ReadyToTap(tester, 'bil06-cancel-media-avatar');
      await tester.tap(find.byKey(const Key('bil06-cancel-media-avatar')));
      await tester.pump();
      expect(gateway.cancelCalls, 0);
      expect(find.text('This operation was cancelled.'), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
      expect(gateway.cancelCalls, 1);
      expect(gateway.finishCalls, 0);
      expect(find.text('This operation was cancelled.'), findsOneWidget);
      expect(find.text('Image saved and confirmed.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed cleanup blocks another upload and retry never repeats cancel SQL',
    (tester) async {
      await bil06UiSize(tester);
      controller.dispose();
      final cleanup = Bil06UiCleanupGateway()
        ..uploadFailure = StateError('Synthetic upload failure');
      controller = CircleManagementController(gateway: cleanup);
      final picker = Bil06UiPicker()..result = bil06UiImage();
      await bil06MountPanel(
        tester,
        controller,
        circle: bil06Circle(),
        picker: picker,
      );
      await bil06Tap(tester, 'bil06-media-entry');
      await bil06Tap(tester, 'bil06-pick-media-avatar');
      await bil06Tap(tester, 'bil06-upload-media-avatar');
      final operationKey = CircleOperationKeys.media(
        'synthetic-circle',
        CircleMediaKind.avatar,
      );
      expect(controller.mediaCleanupPending(operationKey), isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('bil06-pick-media-avatar')),
            )
            .onPressed,
        isNull,
      );
      expect(cleanup.cancelCalls, 1);
      cleanup.failCleanup = false;
      await bil06Tap(tester, 'bil06-cleanup-$operationKey');
      expect(controller.mediaCleanupPending(operationKey), isFalse);
      expect(cleanup.cancelCalls, 1);
      expect(cleanup.removeCalls, 2);
      expect(cleanup.finishCalls, 0);
      expect(find.text('Image saved and confirmed.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing during a native picker ignores its late result', (
    tester,
  ) async {
    await bil06UiSize(tester);
    final pending = Completer<CommunityPostImageDraft?>();
    final picker = Bil06UiPicker()..onPick = () => pending.future;
    await bil06MountPanel(
      tester,
      controller,
      circle: bil06Circle(),
      picker: picker,
    );
    await bil06Tap(tester, 'bil06-media-entry');
    await bil06ReadyToTap(tester, 'bil06-pick-media-avatar');
    await tester.tap(find.byKey(const Key('bil06-pick-media-avatar')));
    await tester.pump();
    expect(picker.calls, 1);
    await tester.tap(find.byKey(const Key('bil06-tools-close')));
    await tester.pump(const Duration(milliseconds: 400));
    pending.complete(bil06UiImage());
    await tester.pumpAndSettle();
    expect(find.text('Outside circle management'), findsOneWidget);
    expect(gateway.prepareCalls, 0);
    expect(gateway.uploadCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'server search is explicit, debounced, paged and rejects stale results',
    (tester) async {
      await bil06UiSize(tester);
      final listGateway = Bil06FakeGateway();
      final calls = <({String query, bool mine, String? cursor})>[];
      final old = Completer<CircleSearchPage>();
      listGateway.onSearch = (query, mine, cursor) async {
        calls.add((query: query, mine: mine, cursor: cursor));
        if (query == 'old') return old.future;
        if (query == 'new' && cursor == null) {
          return CircleSearchPage(
            circles: [bil06Circle(slug: 'new-circle', name: 'New result')],
            nextAfterSlug: 'new-circle',
          );
        }
        if (cursor == 'new-circle') {
          return CircleSearchPage(
            circles: [
              bil06Circle(slug: 'next-circle', name: 'Next page result'),
            ],
          );
        }
        return const CircleSearchPage(circles: []);
      };
      await bil06MountList(tester, listGateway);
      expect(calls, isEmpty);
      expect(
        find.text('Search the circles loaded on this page.'),
        findsOneWidget,
      );
      await bil06Tap(tester, 'bil06-search-mode');
      expect(find.text('Search all circles available to you.'), findsOneWidget);
      expect(calls, hasLength(1));
      await tester.enterText(
        find.byKey(const Key('community-circles-search')),
        'old',
      );
      await tester.pump(const Duration(milliseconds: 349));
      expect(calls, hasLength(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.last.query, 'old');
      await tester.enterText(
        find.byKey(const Key('community-circles-search')),
        'new',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsOneWidget);
      old.complete(
        CircleSearchPage(
          circles: [
            bil06Circle(slug: 'old-circle', name: 'Old private result'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old private result'), findsNothing);
      await bil06Tap(tester, 'bil06-search-more-results');
      expect(calls.last, (query: 'new', mine: false, cursor: 'new-circle'));
      expect(find.text('New result'), findsOneWidget);
      expect(find.text('Next page result'), findsOneWidget);
      await bil06Tap(tester, 'community-circles-mine');
      expect(calls.last.mine, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'pre-existing seeded circle image metadata is loaded on the first list visit',
    (tester) async {
      await bil06UiSize(tester);
      const legacy = CommunityCircle(
        slug: 'healthy-eating',
        titleCopyKey: 'community_circle_healthy_eating',
        descriptionCopyKey: 'community_circle_healthy_eating_body',
        rulesCopyKey: 'community_circle_standard_rules',
        access: CommunityCircleAccess.public,
        joinPolicy: CommunityCircleJoinPolicy.open,
        featured: false,
        memberCount: 23,
        postCount: 7,
      );
      final listGateway = Bil06FakeGateway();
      listGateway.onReadCircle = (slug) async => ManagedCommunityCircle(
        circle: legacy,
        avatar: CircleMediaReference(
          bucket: circleMediaBucket,
          objectPath: '$bil06OwnerA/healthy-eating/avatar/$bil06MediaId.png',
          mimeType: 'image/png',
          byteLength: 70,
          width: 1,
          height: 1,
          signedUrl: 'https://bil06-widget.invalid/verified-circle.png',
        ),
      );
      await bil06MountList(tester, listGateway, legacyRows: const [legacy]);
      expect(listGateway.readCircleCalls, 1);
      final media = tester
          .widgetList<CircleVerifiedMedia>(find.byType(CircleVerifiedMedia))
          .first
          .media;
      expect(media?.signedUrl, contains('verified-circle.png'));
      expect(find.text('Healthy Eating'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native names are read for ordinary legacy circles on every new visit',
    (tester) async {
      await bil06UiSize(tester);
      const legacyRows = [
        CommunityCircle(
          slug: 'synthetic-circle',
          titleCopyKey: circleNativeTitleCopyKey,
          descriptionCopyKey: 'community_circle_custom_description',
          rulesCopyKey: 'community_circle_custom_rules',
          access: CommunityCircleAccess.public,
          joinPolicy: CommunityCircleJoinPolicy.request,
          featured: false,
          memberCount: 1,
          postCount: 0,
        ),
      ];
      await bil06MountList(tester, Bil06FakeGateway(), legacyRows: legacyRows);
      expect(find.text('Synthetic circle'), findsOneWidget);
      expect(find.text('synthetic-circle'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bil06MountList(tester, Bil06FakeGateway(), legacyRows: legacyRows);
      expect(find.text('Synthetic circle'), findsOneWidget);
      expect(find.text('synthetic-circle'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an invalidated management visit cannot revive after ABA', (
    tester,
  ) async {
    await bil06UiSize(tester);
    controller.dispose();
    final transport = Bil06MemoryTransport();
    addTearDown(transport.events.close);
    transport.handler = (name, params) async => {
      'owner_id': bil06OwnerA,
      'circle_slug': null,
      'available': true,
      'can_create': true,
      'can_search': true,
      'can_read_invites': true,
      'can_invite': false,
      'can_manage_media': false,
      'is_member': false,
      'role': null,
    };
    final realGateway = RepositoryCircleManagementGateway.withTransport(
      transport: transport,
      isCurrentVisit: () => true,
    );
    controller = CircleManagementController(gateway: realGateway);
    await bil06MountPanel(tester, controller);
    await bil06ReviewCreate(tester);
    final oldSubmit = tester
        .widget<FilledButton>(find.byKey(const Key('bil06-create-submit')))
        .onPressed!;
    transport.changeOwner(const CircleOwnerIdentity(bil06OwnerB, 'session-b'));
    transport.changeOwner(const CircleOwnerIdentity(bil06OwnerA, 'session-a'));
    await tester.pumpAndSettle();
    oldSubmit();
    await tester.pumpAndSettle();
    expect(realGateway.isCurrent, isFalse);
    expect(find.byKey(const Key('bil06-owner-changed')), findsOneWidget);
    expect(
      transport.calls.where((call) => call.name.contains('create_')),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['ar', 'fr']) {
    testWidgets(
      'management copy uses $locale policy at large text without overflow',
      (tester) async {
        await bil06UiSize(tester, width: 360);
        await bil06MountPanel(tester, controller, locale: locale, textScale: 2);
        expect(
          find.text(locale == 'ar' ? 'إدارة الدوائر' : 'Manage circles'),
          findsOneWidget,
        );
        expect(
          find.text(locale == 'ar' ? 'إنشاء دائرة' : 'Create a circle'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
