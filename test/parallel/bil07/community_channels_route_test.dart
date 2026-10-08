import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/features/community/channels/data/supabase_community_channels_repository.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_page.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_route.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _channel = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _hostKey = Key('bil07-test-route-host');

void main() {
  testWidgets('route host is unavailable without an initialized backend', (
    tester,
  ) async {
    expect(AppEnvironment.supabaseRuntimeReady, isFalse);
    await tester.pumpWidget(const MaterialApp(home: CommunityChannelsRoute()));
    await tester.pump();
    expect(find.byKey(const Key('bil07-route-unavailable')), findsOneWidget);
    expect(find.byType(CommunityChannelsPage), findsNothing);
    expect(find.byType(CommunityChannelMessagesPage), findsNothing);
    expect(find.text('This channel is currently unavailable.'), findsOneWidget);
    expect(AppEnvironment.supabaseRuntimeReady, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'host retains one adapter per repository and rebinds replacement',
    (tester) async {
      final httpRequests = <Uri>[];
      Future<SupabaseClient> client() async {
        // SDK worker-isolate lifecycle must stay outside widget fake time.
        final value = (await tester.runAsync(
          () async => SupabaseClient(
            'https://bil07-route-host.invalid',
            'synthetic-bil07-route-host-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              httpRequests.add(request.url);
              throw StateError('Signed-out host must not request a backend');
            }),
          ),
        ))!;
        addTearDown(() => tester.runAsync(value.dispose));
        return value;
      }

      final first = CommunityRepository(await client());
      final second = CommunityRepository(await client());
      Future<void> mount(
        CommunityRepository? repository, {
        String? channelId,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityChannelsRoute(
              key: _hostKey,
              repository: repository,
              channelId: channelId,
            ),
          ),
        );
        await tester.pump();
      }

      await mount(first);
      final directory = tester.widget<CommunityChannelsPage>(
        find.byType(CommunityChannelsPage),
      );
      final adapter =
          directory.repository as SupabaseCommunityChannelsRepository;
      expect(adapter.community, same(first));
      expect(directory.onReviewPolicy, isNotNull);
      expect(find.byKey(const Key('bil07-route-unavailable')), findsNothing);

      await mount(first);
      expect(
        tester
            .widget<CommunityChannelsPage>(find.byType(CommunityChannelsPage))
            .repository,
        same(adapter),
      );
      await mount(first, channelId: _channel);
      final channel = tester.widget<CommunityChannelMessagesPage>(
        find.byType(CommunityChannelMessagesPage),
      );
      expect(channel.channelId, _channel);
      expect(channel.repository, same(adapter));
      expect(channel.onReviewPolicy, isNotNull);

      await mount(second, channelId: _channel);
      final replacement =
          tester
                  .widget<CommunityChannelMessagesPage>(
                    find.byType(CommunityChannelMessagesPage),
                  )
                  .repository
              as SupabaseCommunityChannelsRepository;
      expect(replacement, isNot(same(adapter)));
      expect(replacement.community, same(second));

      await mount(null, channelId: _channel);
      expect(find.byKey(const Key('bil07-route-unavailable')), findsOneWidget);
      expect(find.byType(CommunityChannelMessagesPage), findsNothing);
      expect(httpRequests, isEmpty);
      expect(AppEnvironment.supabaseRuntimeReady, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
