import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/services/local_recovery_service.dart';
import '../../app/environment/app_environment.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/bil_wordmark.dart';
import '../profile/providers/user_profile_provider.dart';
import '../startup/premium_splash_experience.dart';
import 'auth_language_selector.dart';
import 'auth_five_locale_copy.dart';
export 'premium_account_gateway_page.dart' show AccountGatewayPage;

final localRecoveryServiceProvider = Provider<LocalRecoveryService>((ref) {
  return LocalRecoveryService(ref.watch(databaseProvider));
});

final validRecoverySnapshotProvider = FutureProvider<bool>((ref) {
  return ref.watch(localRecoveryServiceProvider).hasValidSnapshot();
});

class LegacyAccountGatewayPage extends ConsumerStatefulWidget {
  const LegacyAccountGatewayPage({super.key});

  @override
  ConsumerState<LegacyAccountGatewayPage> createState() =>
      _LegacyAccountGatewayPageState();
}

class _LegacyAccountGatewayPageState
    extends ConsumerState<LegacyAccountGatewayPage> {
  final nameController = TextEditingController();
  bool restoring = false;

  bool get arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _continueLocally() async {
    final displayName = nameController.text.trim();
    if (displayName.isNotEmpty) {
      await ref
          .read(preferencesRepositoryProvider)
          .set('displayName', displayName);
    }
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
          authFiveLocaleText(
            'Restore previous data?',
            'استعادة بياناتك السابقة؟',
          ),
        ),
        content: Text(
          authFiveLocaleText(
            'BIL will replace the current local data with the validated previous snapshot.',
            'سيستبدل BIL البيانات المحلية الحالية باللقطة السابقة بعد التحقق منها.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(authFiveLocaleText('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(authFiveLocaleText('Restore', 'استعادة')),
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
    } catch (_) {
      if (!mounted) return;
      setState(() => restoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authFiveLocaleText(
              'The local snapshot could not be restored safely. No partial restore was applied.',
              'تعذرت استعادة اللقطة المحلية بأمان. لم تُطبّق استعادة جزئية.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(validRecoverySnapshotProvider);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PremiumSplashBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 500),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Card(
                      color: const Color(0xE80A1827),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: AuthLanguageSelector(),
                            ),
                            const SizedBox(height: 16),
                            const Center(child: BilFullWordmark(height: 54)),
                            const SizedBox(height: 18),
                            Text(
                              authFiveLocaleText(
                                'Start privately. Build your body intelligence locally.',
                                'ابدأ بخصوصية. ابنِ ذكاء جسمك محليًا.',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFFF0F5F8),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              authFiveLocaleText(
                                'Your health data stays on this device. No account is created and no email is uploaded.',
                                'تبقى بياناتك الصحية على هذا الجهاز. لا يتم إنشاء حساب أو رفع بريد إلكتروني.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB9C8D3),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: nameController,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.name],
                              decoration: InputDecoration(
                                labelText: authFiveLocaleText(
                                  'Display name (optional)',
                                  'الاسم المعروض (اختياري)',
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const Key('gateway-continue-locally'),
                              onPressed: restoring ? null : _continueLocally,
                              child: Text(
                                authFiveLocaleText(
                                  'Continue locally',
                                  'المتابعة محليًا',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: AppEnvironment.cloudConfigured
                                  ? () => context.go('/login')
                                  : null,
                              icon: Icon(
                                AppEnvironment.cloudConfigured
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_off_outlined,
                              ),
                              label: Text(
                                AppEnvironment.cloudConfigured
                                    ? authFiveLocaleText(
                                        'Sign in or create account',
                                        'تسجيل الدخول أو إنشاء حساب',
                                      )
                                    : authFiveLocaleText(
                                        'Email sign-in — Coming with Cloud',
                                        'تسجيل البريد — قادم مع Cloud',
                                      ),
                              ),
                            ),
                            if (snapshot.value == true) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const Key('gateway-restore'),
                                onPressed: restoring ? null : _restore,
                                icon: restoring
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.restore_rounded),
                                label: Text(
                                  authFiveLocaleText(
                                    'Restore previous data',
                                    'استعادة البيانات السابقة',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
