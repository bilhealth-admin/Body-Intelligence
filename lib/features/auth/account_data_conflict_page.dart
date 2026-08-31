import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/bil_wordmark.dart';
import 'auth_five_locale_copy.dart';

/// Fail-closed account-switch surface.
///
/// The local health database is intentionally not deleted, replaced, merged,
/// or uploaded from this page. The only action is to sign out of the mismatched
/// cloud account and preserve the existing local data intact.
class AccountDataConflictPage extends StatefulWidget {
  const AccountDataConflictPage({super.key});

  @override
  State<AccountDataConflictPage> createState() =>
      _AccountDataConflictPageState();
}

class _AccountDataConflictPageState extends State<AccountDataConflictPage> {
  bool signingOut = false;
  String? error;

  Future<void> _signOutAndKeepLocalData() async {
    if (signingOut) return;
    setState(() {
      signingOut = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/account-gateway');
    } on Object {
      if (!mounted) return;
      setState(() {
        signingOut = false;
        error = authFiveLocaleTextOf(
          context,
          'BIL could not sign out safely. Your local data was not changed.',
          'تعذر على BIL تسجيل الخروج بأمان. لم يتم تغيير بياناتك المحلية.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInEmail = Supabase.instance.client.auth.currentUser?.email;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BilFullWordmark(
                        key: Key('account-conflict-wordmark'),
                        height: 40,
                      ),
                      const SizedBox(height: 20),
                      const Icon(
                        Icons.shield_outlined,
                        size: 52,
                        color: Color(0xFF0066EE),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        authFiveLocaleTextOf(
                          context,
                          'This device already has BIL data from another account',
                          'يحتوي هذا الجهاز بالفعل على بيانات BIL مرتبطة بحساب آخر',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        authFiveLocaleTextOf(
                          context,
                          'To protect your health history, BIL will not merge, replace, or upload this local database under a different account.',
                          'لحماية سجلك الصحي، لن يدمج BIL قاعدة البيانات المحلية أو يستبدلها أو يرفعها تحت حساب مختلف.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          height: 1.5,
                        ),
                      ),
                      if (signedInEmail != null &&
                          signedInEmail.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          signedInEmail,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF344054),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('account-conflict-sign-out'),
                          onPressed: signingOut
                              ? null
                              : _signOutAndKeepLocalData,
                          icon: signingOut
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.logout_rounded),
                          label: Text(
                            authFiveLocaleTextOf(
                              context,
                              'Sign out and keep local data',
                              'تسجيل الخروج والاحتفاظ بالبيانات المحلية',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        authFiveLocaleTextOf(
                          context,
                          'No local record has been deleted or uploaded.',
                          'لم يتم حذف أو رفع أي سجل محلي.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
