import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import '../../app/environment/app_environment.dart';
import '../profile/providers/user_profile_provider.dart';
import '../cloud_platform/providers/cloud_sync_providers.dart';
import '../weight/providers/weight_provider.dart';
import '../auth/auth_five_locale_copy.dart';
import '../onboarding/domain/adult_eligibility.dart';
import 'premium_splash_experience.dart';

/// On a fresh installation, recover an already-consented account profile
/// before deciding that the user needs onboarding again. The attempt is
/// bounded so cloud availability can never recreate the old startup hang.
final startupCloudProfileRestoreProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, ownerId) async {
      if (!AppEnvironment.supabaseRuntimeReady ||
          Supabase.instance.client.auth.currentUser?.id != ownerId) {
        return false;
      }
      try {
        final repository = ref.read(userProfileRepositoryProvider);
        if (await repository.getProfile() != null) return true;

        final binding = await ref.read(localDataAccountBindingProvider.future);
        if (binding == null || binding.requiresAccountResolution) return false;

        final restored = await ref
            .read(startupCloudProfileRestoreServiceProvider)
            .restore(ownerId);
        if (!restored || await repository.getProfile() == null) {
          return false;
        }

        ref.invalidate(userProfileProvider);
        await ref.read(userProfileProvider.future);
        return true;
      } on Object {
        return false;
      }
    });

class StartupPage extends ConsumerStatefulWidget {
  const StartupPage({super.key});

  @override
  ConsumerState<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends ConsumerState<StartupPage>
    with SingleTickerProviderStateMixin {
  // Native Android hands off immediately to Flutter's matching first frame.
  // Keep Flutter visible for one deliberate 2.3-second identity beat. Routing
  // still depends only on data readiness plus this bounded timer, never on the
  // decoder, so a playback failure cannot stall startup.
  static const splashDuration = bilSplashMinimumDisplayDuration;

  late final AnimationController controller;
  Timer? minimumDisplayTimer;
  Timer? authResolutionTimer;
  StreamSubscription<AuthState>? authSubscription;
  Session? authSession;
  bool authStateResolved = !AppEnvironment.cloudConfigured;
  bool minimumDisplayElapsed = false;
  String? readyLocation;
  bool redirectScheduled = false;
  bool retrying = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: splashDuration);
    unawaited(controller.forward());
    beginMinimumDisplayWindow();
    _beginAuthResolution();
  }

  void _beginAuthResolution() {
    if (!AppEnvironment.supabaseRuntimeReady) {
      authStateResolved = true;
      authSession = null;
      return;
    }

    final auth = Supabase.instance.client.auth;
    authSession = auth.currentSession;
    if (authSession != null) {
      authStateResolved = true;
    }

    authSubscription = auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        final resolved =
            state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.signedOut ||
            state.session != null;
        setState(() {
          authSession = state.session;
          if (resolved) authStateResolved = true;
          readyLocation = null;
          redirectScheduled = false;
        });
      },
      onError: (Object _, StackTrace _) {
        if (!mounted) return;
        setState(() {
          authSession = auth.currentSession;
          authStateResolved = true;
          readyLocation = null;
          redirectScheduled = false;
        });
      },
    );

    // `initialSession` normally resolves immediately. This finite fallback keeps
    // startup from hanging if the auth stream is interrupted while offline.
    authResolutionTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || authStateResolved) return;
      setState(() {
        authSession = auth.currentSession;
        authStateResolved = true;
      });
    });
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
    authResolutionTimer?.cancel();
    unawaited(authSubscription?.cancel());
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
    controller.value = 1;
    beginMinimumDisplayWindow();
    setState(() => retrying = true);
    ref.invalidate(userProfileProvider);
    ref.invalidate(dailyCheckInDueProvider);
    ref.invalidate(forceOnboardingProvider);
    ref.invalidate(accountGatewayReviewedProvider);
    ref.invalidate(localDataAccountBindingProvider);
    ref.invalidate(cloudRuntimePreparationProvider);
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
    final localAccountBinding = ref.watch(localDataAccountBindingProvider);
    // Optional Premium cloud preparation must never block local-first startup.
    // It remains transport-locked until inbound merge is closed.
    ref.watch(cloudRuntimePreparationProvider);
    final signedInOwnerId = authSession?.user.id;
    final shouldRestoreCloudProfile =
        signedInOwnerId != null &&
        profile.hasValue &&
        profile.value == null &&
        localAccountBinding.hasValue &&
        localAccountBinding.value?.requiresAccountResolution != true;
    final cloudProfileRestore = shouldRestoreCloudProfile
        ? ref.watch(startupCloudProfileRestoreProvider(signedInOwnerId))
        : const AsyncValue<bool>.data(false);
    final waitingForAuth = AppEnvironment.cloudConfigured && !authStateResolved;
    final error =
        profile.hasError ||
        checkInDue.hasError ||
        forceOnboarding.hasError ||
        accountGatewayReviewed.hasError ||
        localAccountBinding.hasError ||
        cloudProfileRestore.hasError;
    final showError = error && !retrying;

    if (!waitingForAuth &&
        !error &&
        profile.hasValue &&
        checkInDue.hasValue &&
        forceOnboarding.hasValue &&
        accountGatewayReviewed.hasValue &&
        localAccountBinding.hasValue &&
        cloudProfileRestore.hasValue) {
      final user = profile.value;
      final signedIn = AppEnvironment.cloudConfigured && authSession != null;
      final needsAccountChoice =
          AppEnvironment.cloudConfigured &&
          !signedIn &&
          accountGatewayReviewed.value != true;
      final accountConflict =
          localAccountBinding.value?.requiresAccountResolution == true;
      if (accountConflict) {
        // This is now only a corruption/legacy fail-safe. Normal account
        // switching uses a separate local SQLite namespace per BIL account.
        readyLocation = '/account-data-conflict';
      } else if (forceOnboarding.value == true) {
        readyLocation = '/onboarding';
      } else if (user == null && cloudProfileRestore.value != true) {
        // A newly signed-in account owns a clean local database and must be
        // allowed to create its own profile instead of being sent back to the
        // sign-in gateway. Signed-out guest mode still starts at the gateway.
        readyLocation = signedIn ? '/onboarding' : '/account-gateway';
      } else if (user != null && !BilAdultEligibility.isEligibleAge(user.age)) {
        // The production audience is adults only. Legacy local profiles keep
        // a calculated age rather than a full birth date, so they return to
        // the neutral date-of-birth gate instead of entering the product.
        readyLocation = '/onboarding';
      } else if (needsAccountChoice) {
        readyLocation = '/account-gateway';
      } else {
        readyLocation = checkInDue.value == true
            ? '/daily-check-in'
            : '/dashboard';
      }
      _redirectIfReady();
    } else {
      readyLocation = null;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: bilLaunchBlue,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: bilLaunchBlue,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PremiumSplashBackdrop(),
            Center(
              child: showError
                  ? _StartupError(arabic: arabic, onRetry: retry)
                  : PremiumSplashExperience(controller: controller),
            ),
          ],
        ),
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
