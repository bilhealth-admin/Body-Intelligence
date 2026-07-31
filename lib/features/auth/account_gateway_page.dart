import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/services/local_recovery_service.dart';
import '../../data/database/database_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../startup/premium_splash_experience.dart';

final localRecoveryServiceProvider = Provider<LocalRecoveryService>((ref) {
  return LocalRecoveryService(ref.watch(databaseProvider));
});

final validRecoverySnapshotProvider = FutureProvider<bool>((ref) {
  return ref.watch(localRecoveryServiceProvider).hasValidSnapshot();
});

class AccountGatewayPage extends ConsumerStatefulWidget {
  const AccountGatewayPage({super.key});

  @override
  ConsumerState<AccountGatewayPage> createState() => _AccountGatewayPageState();
}

class _AccountGatewayPageState extends ConsumerState<AccountGatewayPage> {
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
    if (mounted) context.go('/onboarding');
  }

  Future<void> _restore() async {
    if (restoring) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          arabic ? 'استعادة بياناتك السابقة؟' : 'Restore previous data?',
        ),
        content: Text(
          arabic
              ? 'سيستبدل BIL البيانات المحلية الحالية باللقطة السابقة بعد التحقق منها.'
              : 'BIL will replace the current local data with the validated previous snapshot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(arabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(arabic ? 'استعادة' : 'Restore'),
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
            arabic
                ? 'تعذرت استعادة اللقطة المحلية بأمان. لم تُطبّق استعادة جزئية.'
                : 'The local snapshot could not be restored safely. No partial restore was applied.',
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
                            const Text(
                              'BIL®',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFF4F7FA),
                                fontSize: 54,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              arabic
                                  ? 'ابدأ بخصوصية. ابنِ ذكاء جسمك محليًا.'
                                  : 'Start privately. Build your body intelligence locally.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFFF0F5F8),
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              arabic
                                  ? 'تبقى بياناتك الصحية على هذا الجهاز. لا يتم إنشاء حساب أو رفع بريد إلكتروني.'
                                  : 'Your health data stays on this device. No account is created and no email is uploaded.',
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
                                labelText: arabic
                                    ? 'الاسم المعروض (اختياري)'
                                    : 'Display name (optional)',
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
                                arabic ? 'المتابعة محليًا' : 'Continue locally',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.cloud_off_outlined),
                              label: Text(
                                arabic
                                    ? 'تسجيل البريد — قادم مع Cloud'
                                    : 'Email sign-in — Coming with Cloud',
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
                                  arabic
                                      ? 'استعادة البيانات السابقة'
                                      : 'Restore previous data',
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
