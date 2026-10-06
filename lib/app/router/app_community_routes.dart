part of 'app_router.dart';

abstract final class _CommunityRoutes {
  static List<RouteBase> build() {
    return [
      GoRoute(
        path: '/community',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            showWelcome: true,
            child: CommunityHubPage(entryWelcomeHandled: true),
          ),
        ),
      ),
      GoRoute(
        path: '/community/people',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityPeoplePage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/code',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityBilCodePage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/code/scan',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityCodeScannerPage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/member/:code',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(
              child: CommunityMemberCodePage(
                code: state.pathParameters['code']!,
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/community/notifications',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityNotificationsPage()),
          ),
        ),
      ),
      // Referral attribution must be reachable before Premium or even sign-in.
      // Server policy still decides whether tracked invitations are active.
      GoRoute(
        path: '/community/invite/:token',
        builder: (_, state) => CommunitySurface(
          child: CommunityInviteLandingPage(
            token: state.pathParameters['token']!,
          ),
        ),
      ),
      GoRoute(
        path: '/community/drafts',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityDraftsPage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/rewards',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityRewardsPage()),
          ),
        ),
      ),
      // Moderation uses a server-verified role, not a customer purchase.
      // Its RPCs fail closed; a moderator need not own Premium.
      GoRoute(
        path: '/community/moderation',
        builder: (_, _) =>
            const CommunitySurface(child: CommunityPostModerationPage()),
      ),
      GoRoute(
        path: '/community/connections',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityConnectionsPage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/food-review',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityFoodReviewPage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/profile',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunitySurface(child: CommunityProfilePage()),
        ),
      ),
      GoRoute(
        path: '/community/profile/:userId',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(
              child: CommunityMemberProfilePage(
                userId: state.pathParameters['userId']!,
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/community/safety',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunitySurface(child: CommunitySafetyPage()),
        ),
      ),
      GoRoute(
        path: '/community/chat/:userId',
        builder: (_, state) => PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(
              child: CommunityChatPage(
                userId: state.pathParameters['userId']!,
                displayName: state.extra is String
                    ? state.extra! as String
                    : state.uri.queryParameters['name'] ?? 'BIL',
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/community/messages',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: CommunityMessagesPage()),
          ),
        ),
      ),
      GoRoute(
        path: '/community/messages/new',
        builder: (_, _) => const PremiumRouteGlassGate(
          feature: PremiumGateFeature.community,
          child: CommunityEntryGate(
            child: CommunitySurface(child: NewCommunityMessagePage()),
          ),
        ),
      ),
    ];
  }
}
