import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class StartupPage extends ConsumerStatefulWidget {
  const StartupPage({super.key});
  @override
  ConsumerState<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends ConsumerState<StartupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool redirectScheduled = false;
  bool retrying = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
    setState(() => retrying = true);
    ref.invalidate(userProfileProvider);
    ref.invalidate(dailyCheckInDueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final profile = ref.watch(userProfileProvider);
    final checkInDue = ref.watch(dailyCheckInDueProvider);
    final forceOnboarding = ref.watch(forceOnboardingProvider);
    final error =
        profile.hasError || checkInDue.hasError || forceOnboarding.hasError;

    if (!error &&
        profile.hasValue &&
        checkInDue.hasValue &&
        forceOnboarding.hasValue) {
      final user = profile.value;
      scheduleRedirect(
        forceOnboarding.value == true || user == null
            ? '/onboarding'
            : (checkInDue.value == true ? '/daily-check-in' : '/dashboard'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/v10_master/bil_hdr_starfield_master.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF01050D)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .78,
                colors: [
                  Color(0x382A8CFF),
                  Color(0x1817CDE4),
                  Color(0x0001050D),
                ],
              ),
            ),
          ),
          Center(
            child: error && !retrying
                ? _StartupError(arabic: arabic, onRetry: retry)
                : _StartupProgress(arabic: arabic, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _StartupProgress extends StatelessWidget {
  const _StartupProgress({required this.arabic, required this.controller});
  final bool arabic;
  final AnimationController controller;
  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: arabic
          ? 'يُجهّز BIL بياناتك المحلية بأمان'
          : 'BIL is preparing your local data safely',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SplashBrand(),
          const SizedBox(height: 30),
          SizedBox(
            width: 220,
            child: reducedMotion
                ? const LinearProgressIndicator(value: .5)
                : AnimatedBuilder(
                    animation: controller,
                    builder: (_, _) =>
                        LinearProgressIndicator(value: controller.value),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storage_outlined,
              size: 52,
              color: Color(0xFFE8EEF3),
            ),
            const SizedBox(height: 18),
            Text(
              arabic
                  ? 'تعذر فتح بياناتك المحلية'
                  : 'Your local data could not be opened',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFF1F5F8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              arabic
                  ? 'لم يتم حذف أي شيء أو رفعه. يمكنك المحاولة مرة أخرى بأمان.'
                  : 'Nothing was deleted or uploaded. You can retry safely.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB8C5D1), height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(arabic ? 'حاول مرة أخرى' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBrand extends StatelessWidget {
  const _SplashBrand();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BIL®',
          style: TextStyle(
            color: Color(0xFFF4F7FA),
            fontSize: 104,
            height: .86,
            fontWeight: FontWeight.w900,
            letterSpacing: -5,
            shadows: [
              Shadow(color: Color(0x805BD8FF), blurRadius: 40),
              Shadow(color: Color(0x60795EFF), blurRadius: 62),
            ],
          ),
        ),
        SizedBox(height: 18),
        Text(
          'BODY INTELLIGENCE LOG',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD9E3EC),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
