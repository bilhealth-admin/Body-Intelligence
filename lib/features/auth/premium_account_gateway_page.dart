import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/bil_wordmark.dart';
import '../profile/providers/user_profile_provider.dart';
import 'account_gateway_page.dart'
    show localRecoveryServiceProvider, validRecoverySnapshotProvider;
import 'auth_entry_locale_copy.dart';
import 'auth_language_selector.dart';

const _gatewayStoryViewportFraction = .87;
const _gatewayStoryCardAspectRatio = 1.0;
const _gatewayStoryGap = 12.0;

class AccountGatewayPage extends ConsumerStatefulWidget {
  const AccountGatewayPage({super.key});

  @override
  ConsumerState<AccountGatewayPage> createState() => _AccountGatewayPageState();
}

class _AccountGatewayPageState extends ConsumerState<AccountGatewayPage> {
  bool restoring = false;
  bool redirectingAuthenticatedUser = false;
  StreamSubscription<AuthState>? authSubscription;
  final PageController storyController = PageController(
    viewportFraction: _gatewayStoryViewportFraction,
  );
  int storyIndex = 0;

  @override
  void initState() {
    super.initState();
    if (!AppEnvironment.supabaseRuntimeReady) {
      return;
    }

    final auth = Supabase.instance.client.auth;
    authSubscription = auth.onAuthStateChange.listen((state) {
      if (state.session != null) _redirectAuthenticatedUser();
    }, onError: (Object _, StackTrace _) {});
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _redirectAuthenticatedUser(),
    );
  }

  bool get _hasAuthenticatedSession =>
      AppEnvironment.supabaseRuntimeReady &&
      Supabase.instance.client.auth.currentSession != null;

  void _redirectAuthenticatedUser() {
    if (!mounted || redirectingAuthenticatedUser || !_hasAuthenticatedSession) {
      return;
    }
    setState(() => redirectingAuthenticatedUser = true);
    context.go('/startup');
  }

  @override
  void dispose() {
    unawaited(authSubscription?.cancel());
    storyController.dispose();
    super.dispose();
  }

  Future<void> _continueLocally() async {
    await ref
        .read(preferencesRepositoryProvider)
        .set('accountGatewayReviewed', 'true');
    final existingProfile = ref.read(userProfileProvider).value;
    if (mounted) {
      context.go(existingProfile == null ? '/onboarding' : '/dashboard');
    }
  }

  Future<void> _restore() async {
    if (restoring) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          authEntryText(context, AuthEntryCopyKey.restorePreviousDataQuestion),
        ),
        content: Text(
          authEntryText(context, AuthEntryCopyKey.restoreDialogBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(authEntryText(context, AuthEntryCopyKey.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(authEntryText(context, AuthEntryCopyKey.restore)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => restoring = true);
    try {
      await ref.read(localRecoveryServiceProvider).restore();
      ref.invalidate(databaseProvider);
      if (mounted) context.go('/dashboard');
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ButtonStyle replaces the surrounding text theme. Re-attach its active
    // family so visual tests keep their real Arabic face while production
    // continues to use the platform-native family.
    final accountActionFontFamily = Theme.of(
      context,
    ).textTheme.labelLarge?.fontFamily;
    final pageBackground = scheme.brightness == Brightness.dark
        ? scheme.surface
        : Colors.white;
    if (_hasAuthenticatedSession || redirectingAuthenticatedUser) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _redirectAuthenticatedUser(),
      );
      return Scaffold(
        backgroundColor: pageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = ref.watch(validRecoverySnapshotProvider);
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final horizontalPadding = constraints.maxWidth < 390 ? 18.0 : 22.0;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 8 : 13,
                  horizontalPadding,
                  compact ? 14 : 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GatewayBrandHeader(compact: compact),
                      SizedBox(height: compact ? 11 : 14),
                      const Align(
                        alignment: Alignment.center,
                        child: AuthLanguageSelector(),
                      ),
                      SizedBox(height: compact ? 18 : 24),
                      _GatewayStoryPager(
                        controller: storyController,
                        index: storyIndex,
                        onChanged: (value) =>
                            setState(() => storyIndex = value),
                      ),
                      SizedBox(height: compact ? 18 : 24),
                      SizedBox(
                        height: compact ? 54 : 58,
                        child: FilledButton(
                          key: const Key('gateway-account-action'),
                          onPressed: restoring
                              ? null
                              : () => context.go('/login'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0877F9),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFD0D5DD),
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.15,
                              fontFamily: accountActionFontFamily,
                            ),
                          ),
                          child: Text(
                            authEntryText(context, AuthEntryCopyKey.signIn),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 5),
                      Center(
                        child: TextButton(
                          key: const Key('gateway-continue-locally'),
                          onPressed: restoring ? null : _continueLocally,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0877F9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            textStyle: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: accountActionFontFamily,
                            ),
                          ),
                          child: Text(
                            authEntryText(
                              context,
                              AuthEntryCopyKey.continueWithoutAccount,
                            ),
                          ),
                        ),
                      ),
                      if (snapshot.value == true)
                        Center(
                          child: TextButton.icon(
                            key: const Key('gateway-restore'),
                            onPressed: restoring ? null : _restore,
                            icon: restoring
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.restore_rounded, size: 18),
                            label: Text(
                              authEntryText(
                                context,
                                AuthEntryCopyKey.restorePreviousData,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF667085),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GatewayBrandHeader extends StatelessWidget {
  const _GatewayBrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        authEntryText(context, AuthEntryCopyKey.welcomeTo),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: compact ? 12 : 13,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: .05,
        ),
      ),
      SizedBox(height: compact ? 4 : 5),
      BilFullWordmark(height: compact ? 40 : 46),
    ],
  );
}

class _GatewayStoryPager extends StatelessWidget {
  const _GatewayStoryPager({
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stories =
        <({String asset, String title, String body, IconData icon})>[
          (
            asset:
                'assets/images/flagship/bil_body_intelligence_journey_v1.png',
            title: authEntryText(context, AuthEntryCopyKey.progressTitle),
            body: authEntryText(context, AuthEntryCopyKey.progressBody),
            icon: Icons.trending_up_rounded,
          ),
          (
            asset: 'assets/images/flagship/bil_sleep_insights_v2.png',
            title: authEntryText(context, AuthEntryCopyKey.rhythmTitle),
            body: authEntryText(context, AuthEntryCopyKey.rhythmBody),
            icon: Icons.nightlight_round,
          ),
          (
            asset: 'assets/images/flagship/bil_meal_discovery_v2.png',
            title: authEntryText(context, AuthEntryCopyKey.nutritionTitle),
            body: authEntryText(context, AuthEntryCopyKey.nutritionBody),
            icon: Icons.restaurant_rounded,
          ),
        ];
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // PageView sizes each page from the viewport fraction. Deriving
            // the viewport height from that exact page width keeps every card
            // and crop geometrically identical while a drag is in progress.
            final cardWidth =
                (constraints.maxWidth * controller.viewportFraction) -
                _gatewayStoryGap;
            final cardHeight = cardWidth / _gatewayStoryCardAspectRatio;
            return SizedBox(
              key: const Key('gateway-story-viewport'),
              height: cardHeight,
              child: PageView.builder(
                controller: controller,
                itemCount: stories.length,
                onPageChanged: onChanged,
                padEnds: false,
                itemBuilder: (context, itemIndex) {
                  final story = stories[itemIndex];
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: _gatewayStoryGap,
                    ),
                    child: Semantics(
                      image: true,
                      label: '${story.title}. ${story.body}',
                      child: DecoratedBox(
                        key: ValueKey('gateway-story-card-$itemIndex'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                story.asset,
                                key: ValueKey('gateway-story-image-$itemIndex'),
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, _, _) => const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFEAF4FF),
                                        Color(0xFFDDF7EF),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.landscape_rounded,
                                      size: 72,
                                      color: Color(0xFF0877F9),
                                    ),
                                  ),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x00000000),
                                      Color(0x05000000),
                                      Color(0x33000000),
                                    ],
                                    stops: [.52, .72, 1],
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                start: 16,
                                bottom: 16,
                                child: _StoryGlassSignal(icon: story.icon),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        IndexedStack(
          key: const Key('gateway-story-copy-slot'),
          index: index.clamp(0, stories.length - 1).toInt(),
          alignment: Alignment.topCenter,
          sizing: StackFit.loose,
          children: [
            for (final story in stories)
              Column(
                children: [
                  Text(
                    story.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 21.5,
                      height: 1.16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      story.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            stories.length,
            (itemIndex) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: itemIndex == index ? 8 : 7,
              height: itemIndex == index ? 8 : 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: itemIndex == index
                    ? scheme.primary
                    : scheme.outlineVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryGlassSignal extends StatelessWidget {
  const _StoryGlassSignal({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 104,
          height: 66,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color:
                (scheme.brightness == Brightness.dark
                        ? scheme.surfaceContainerHighest
                        : Colors.white)
                    .withValues(alpha: .76),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  (scheme.brightness == Brightness.dark
                          ? scheme.outlineVariant
                          : Colors.white)
                      .withValues(alpha: .78),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, color: const Color(0xFF0877F9), size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    const heights = <double>[13, 22, 18, 29, 35];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 5,
                      height: heights[index],
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF0877F9,
                        ).withValues(alpha: .58 + (index * .08)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
