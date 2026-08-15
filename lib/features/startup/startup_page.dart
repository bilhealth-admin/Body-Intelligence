import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../auth/auth_five_locale_copy.dart';
import 'light_startup_splash_experience.dart';

class StartupPage extends ConsumerStatefulWidget {
  const StartupPage({super.key});

  @override
  ConsumerState<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends ConsumerState<StartupPage>
    with SingleTickerProviderStateMixin {
  // Native Android/iOS already presents the exact same BIL identity while the
  // engine starts. Keep only a short continuity frame instead of forcing a
  // second full-length splash after Flutter is ready.
  static const splashDuration = Duration(milliseconds: 320);

  late final AnimationController controller;
  Timer? minimumDisplayTimer;
  bool minimumDisplayElapsed = false;
  String? readyLocation;
  bool redirectScheduled = false;
  bool retrying = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: splashDuration)
      ..forward();
    beginMinimumDisplayWindow();
  }

  void beginMinimumDisplayWindow() {
    minimumDisplayTimer?.cancel();
    minimumDisplayElapsed = false;
    minimumDisplayTimer = Timer(splashDuration, () {
      if (!mounted) return;
      setState(() => minimumDisplayElapsed = true);
    });
  }

  @override
  void dispose() {
    minimumDisplayTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _redirectIfReady() {
    final location = readyLocation;
    if (!minimumDisplayElapsed || location == null) return;
    scheduleRedirect(location);
  }

  void scheduleRedirect(String location) {
    if (redirectScheduled) return;
    redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }

  void retry() {
    redirectScheduled = false;
    readyLocation = null;
    controller.forward(from: 0);
    beginMinimumDisplayWindow();
    setState(() => retrying = true);
    ref.invalidate(userProfileProvider);
    ref.invalidate(dailyCheckInDueProvider);
    ref.invalidate(forceOnboardingProvider);
    ref.invalidate(accountGatewayReviewedProvider);
    // Preserve one complete loading frame before surfacing the result of the
    // new attempt. This prevents a stale AsyncError from flashing after the
    // tap, while a repeated failure still becomes visible and retryable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => retrying = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final profile = ref.watch(userProfileProvider);
    final checkInDue = ref.watch(dailyCheckInDueProvider);
    final forceOnboarding = ref.watch(forceOnboardingProvider);
    final accountGatewayReviewed = ref.watch(accountGatewayReviewedProvider);
    final error =
        profile.hasError ||
        checkInDue.hasError ||
        forceOnboarding.hasError ||
        accountGatewayReviewed.hasError;
    final showError = error && !retrying;

    if (!error &&
        profile.hasValue &&
        checkInDue.hasValue &&
        forceOnboarding.hasValue &&
        accountGatewayReviewed.hasValue) {
      final user = profile.value;
      final signedIn =
          AppEnvironment.cloudConfigured &&
          Supabase.instance.client.auth.currentSession != null;
      final needsAccountChoice =
          AppEnvironment.cloudConfigured &&
          !signedIn &&
          accountGatewayReviewed.value != true;
      readyLocation =
          forceOnboarding.value == true || user == null || needsAccountChoice
          ? '/account-gateway'
          : (checkInDue.value == true ? '/daily-check-in' : '/dashboard');
      _redirectIfReady();
    } else {
      readyLocation = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LightStartupSplashBackdrop(
            controller: controller,
            animate: !showError,
          ),
          Center(
            child: showError
                ? _StartupError(arabic: arabic, onRetry: retry)
                : LightStartupSplashExperience(
                    arabic: arabic,
                    controller: controller,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.arabic, required this.onRetry});
  final bool arabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x1F0B2946)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140B2946),
                    blurRadius: 36,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storage_outlined,
                      size: 52,
                      color: Color(0xFF0877D1),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      authFiveLocaleTextFor(
                        arabicLocaleCode(context, arabic),
                        'Your local data could not be opened',
                        'تعذّر فتح بياناتك المحلية',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF0B2946),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      authFiveLocaleTextFor(
                        arabicLocaleCode(context, arabic),
                        'Nothing was deleted or uploaded. You can retry safely.',
                        'لم يتم حذف أي شيء أو رفعه. يمكنك المحاولة مرة أخرى بأمان.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF526779),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        authFiveLocaleTextFor(
                          arabicLocaleCode(context, arabic),
                          'Try again',
                          'حاول مرة أخرى',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
