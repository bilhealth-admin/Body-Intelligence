import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/environment/app_environment.dart';
import '../../data/community_repository.dart';
import '../../presentation/community_messages_page.dart';
import '../../presentation/community_return_button.dart';
import '../data/supabase_community_channels_repository.dart';
import 'community_channels_copy.dart';
import 'community_channels_page.dart';

/// Stable repository binding behind the existing Premium and Community gates.
/// The optional repository is an injection seam for local route verification.
class CommunityChannelsRoute extends StatefulWidget {
  const CommunityChannelsRoute({this.channelId, this.repository, super.key});

  final String? channelId;
  final CommunityRepository? repository;

  @override
  State<CommunityChannelsRoute> createState() => _CommunityChannelsRouteState();
}

class _CommunityChannelsRouteState extends State<CommunityChannelsRoute> {
  CommunityRepository? _community;
  SupabaseCommunityChannelsRepository? _channels;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _community = widget.repository;
    if (_community == null && AppEnvironment.communityConfigured) {
      try {
        final supabase = Supabase.instance;
        if (supabase.isInitialized &&
            supabase.client.auth.currentUser != null) {
          _community = CommunityRepository(supabase.client);
        }
      } on AssertionError {
        // The existing entry gate owns sign-in and configuration recovery.
      } on StateError {
        // No directory or membership is manufactured without a real client.
      }
    }
    final community = _community;
    _channels = community == null
        ? null
        : SupabaseCommunityChannelsRepository(community);
  }

  @override
  void didUpdateWidget(covariant CommunityChannelsRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _bind();
  }

  @override
  Widget build(BuildContext context) {
    final community = _community;
    final channels = _channels;
    if (community == null || channels == null) {
      return Scaffold(
        key: const Key('bil07-route-unavailable'),
        appBar: AppBar(
          leading: const CommunityReturnButton(),
          title: Text(
            CommunityChannelsCopy.text(
              context,
              CommunityChannelsCopyKey.channels,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                CommunityChannelsCopy.text(
                  context,
                  CommunityChannelsCopyKey.channelUnavailable,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    Future<void> reviewPolicy(
      BuildContext context,
      bool Function() isCurrent,
    ) => showCommunityMessagingPolicy(
      context,
      repository: community,
      isCurrent: isCurrent,
    );
    final channelId = widget.channelId;
    return channelId == null
        ? CommunityChannelsPage(
            repository: channels,
            onReviewPolicy: reviewPolicy,
          )
        : CommunityChannelMessagesPage(
            repository: channels,
            channelId: channelId,
            onReviewPolicy: reviewPolicy,
          );
  }
}
