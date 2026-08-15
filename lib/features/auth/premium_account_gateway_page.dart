import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/environment/app_environment.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/bil_wordmark.dart';
import '../profile/providers/user_profile_provider.dart';
import 'account_gateway_page.dart'
    show localRecoveryServiceProvider, validRecoverySnapshotProvider;
import 'auth_language_selector.dart';
import 'auth_five_locale_copy.dart';

class AccountGatewayPage extends ConsumerStatefulWidget {
  const AccountGatewayPage({super.key});

  @override
  ConsumerState<AccountGatewayPage> createState() => _AccountGatewayPageState();
}

class _AccountGatewayPageState extends ConsumerState<AccountGatewayPage> {
  bool restoring = false;
  final PageController storyController = PageController(viewportFraction: .88);
  int storyIndex = 0;

  bool get arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  @override
  void dispose() {
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
        title: Text(
          authFiveLocaleTextOf(
            context,
            'Restore previous data?',
            'استعادة بياناتك السابقة؟',
          ),
        ),
        content: Text(
          authFiveLocaleTextOf(
            context,
            'BIL will replace the current local data with the validated previous snapshot.',
            'سيستبدل BIL البيانات المحلية الحالية بالنسخة السابقة بعد التحقق منها.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(authFiveLocaleTextOf(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(authFiveLocaleTextOf(context, 'Restore', 'استعادة')),
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
    final snapshot = ref.watch(validRecoverySnapshotProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF7F8FB)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AuthLanguageSelector(),
                      ),
                      const SizedBox(height: 14),
                      const BilWordmark(height: 44),
                      const SizedBox(height: 8),
                      Text(
                        authFiveLocaleTextOf(
                          context,
                          'Your body. Your intelligence.',
                          'ذكاء جسمك، بهويتك أنت.',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        softWrap: true,
                        style: TextStyle(
                          color: const Color(0xFF101828),
                          fontSize: MediaQuery.sizeOf(context).width < 430
                              ? 22
                              : 26,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        authFiveLocaleTextOf(
                          context,
                          'A private health experience built around you. Your data stays yours, and cloud sync is always your choice.',
                          'تجربة صحية شخصية صُممت حولك. بياناتك ملكك، والمزامنة السحابية دائمًا باختيارك.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF667085),
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _GatewayStoryPager(
                        arabic: arabic,
                        controller: storyController,
                        index: storyIndex,
                        onChanged: (value) =>
                            setState(() => storyIndex = value),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          key: Key(
                            AppEnvironment.cloudConfigured
                                ? 'gateway-account-action'
                                : 'gateway-continue-locally',
                          ),
                          onPressed: restoring
                              ? null
                              : AppEnvironment.cloudConfigured
                              ? () => context.go('/login')
                              : _continueLocally,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            AppEnvironment.cloudConfigured
                                ? authFiveLocaleTextOf(
                                    context,
                                    'Continue with BIL account',
                                    'ابدأ بحساب BIL',
                                  )
                                : authFiveLocaleTextOf(
                                    context,
                                    'Continue without an account',
                                    'المتابعة الآن دون حساب',
                                  ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0066EE),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFD0D5DD),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      if (AppEnvironment.cloudConfigured)
                        TextButton(
                          key: const Key('gateway-continue-locally'),
                          onPressed: restoring ? null : _continueLocally,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF344054),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 17,
                            ),
                          ),
                          child: Text(
                            authFiveLocaleTextOf(
                              context,
                              'Continue without an account',
                              'المتابعة الآن دون حساب',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            authFiveLocaleTextOf(
                              context,
                              'Cloud account is not enabled on this build.',
                              'الحساب السحابي غير مفعّل في هذه النسخة.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (snapshot.value == true)
                        TextButton.icon(
                          key: const Key('gateway-restore'),
                          onPressed: restoring ? null : _restore,
                          icon: restoring
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore_rounded),
                          label: Text(
                            authFiveLocaleTextOf(
                              context,
                              'Restore previous data',
                              'استعادة بيانات سابقة',
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        authFiveLocaleTextOf(
                          context,
                          'Privacy first  •  No medical diagnosis  •  You stay in control',
                          'خصوصية أولًا  •  لا تشخيص طبي  •  أنت صاحب القرار',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF667085),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayStoryPager extends StatelessWidget {
  const _GatewayStoryPager({
    required this.arabic,
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  final bool arabic;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final stories = <({String asset, String title, String body})>[
      (
        asset: 'assets/images/flagship/bil_meal_discovery_v1.png',
        title: authFiveLocaleTextOf(
          context,
          'Nutrition without guesswork',
          'التغذية بلا تخمين',
        ),
        body: authFiveLocaleTextOf(
          context,
          'Search, scan, and log with a clear line between verified and custom data.',
          'ابحث وامسح وسجّل مع فصل واضح بين الموثق والمخصص.',
        ),
      ),
      (
        asset: 'assets/images/flagship/bil_sleep_insights_v1.png',
        title: authFiveLocaleTextOf(
          context,
          'Understand your rhythm',
          'افهم إيقاعك',
        ),
        body: authFiveLocaleTextOf(
          context,
          'Connect sleep and recovery using only your real record.',
          'اربط النوم والتعافي بسجلك الحقيقي فقط.',
        ),
      ),
      (
        asset: 'assets/images/flagship/bil_movement_v1.png',
        title: authFiveLocaleTextOf(
          context,
          'Progress built around you',
          'تقدّم يناسب قدرتك',
        ),
        body: authFiveLocaleTextOf(
          context,
          'Reviewable guidance instead of one generic plan for everyone.',
          'توصيات قابلة للمراجعة لا خطة عامة للجميع.',
        ),
      ),
    ];
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: controller,
            itemCount: stories.length,
            onPageChanged: onChanged,
            itemBuilder: (context, itemIndex) {
              final story = stories[itemIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(story.asset, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x12030B18), Color(0xF0030B18)],
                            stops: [.28, 1],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: 18,
                        end: 18,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              story.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            stories.length,
            (itemIndex) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: itemIndex == index ? 22 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: itemIndex == index
                    ? const Color(0xFF22D3EE)
                    : const Color(0xFFD0D5DD),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
