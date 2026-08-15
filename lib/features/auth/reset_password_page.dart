import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'auth_error_localizer.dart';
import 'auth_five_locale_copy.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  StreamSubscription<AuthState>? authSubscription;
  bool recoverySessionReady = false;
  bool loading = false;
  bool obscure = true;
  String? status;

  @override
  void initState() {
    super.initState();
    if (!AppEnvironment.cloudConfigured) return;
    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (!mounted) return;
      // A normal signed-in session must never authorize password recovery.
      // Supabase emits this dedicated event only after validating the recovery
      // callback and installing its short-lived recovery session.
      if (state.event == AuthChangeEvent.passwordRecovery &&
          state.session != null) {
        setState(() => recoverySessionReady = true);
      }
    });
  }

  @override
  void dispose() {
    unawaited(authSubscription?.cancel());
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    if (!AppEnvironment.cloudConfigured ||
        !recoverySessionReady ||
        formKey.currentState?.validate() != true) {
      return;
    }
    setState(() {
      loading = true;
      status = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password.text),
      );
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } on AuthException catch (error) {
      if (mounted) setState(() => status = localizedAuthError(context, error));
    } catch (_) {
      if (mounted) {
        setState(
          () => status = authFiveLocaleText(
            'The password could not be updated. Request a new link.',
            'تعذّر تحديث كلمة المرور. اطلب رابطًا جديدًا.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => authFiveLocaleText(en, ar);
    final cloudConfigured = AppEnvironment.cloudConfigured;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BilFullWordmark(height: 42)),
                    const SizedBox(height: 44),
                    Text(
                      tr('Set a new password', 'تعيين كلمة مرور جديدة'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'Use at least 8 characters, then sign in with your new password.',
                        'استخدم 8 أحرف على الأقل، ثم سجّل الدخول بكلمة المرور الجديدة.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (!recoverySessionReady)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          cloudConfigured
                              ? tr(
                                  'Checking the recovery link…',
                                  'جارٍ التحقق من رابط الاستعادة…',
                                )
                              : tr(
                                  'Cloud account recovery is not enabled in this build.',
                                  'استعادة الحساب السحابي غير مفعّلة في هذا الإصدار.',
                                ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: tr('New password', 'كلمة المرور الجديدة'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : tr(
                              'Use at least 8 characters.',
                              'استخدم 8 أحرف على الأقل.',
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmation,
                      obscureText: obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: tr('Confirm password', 'تأكيد كلمة المرور'),
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                      ),
                      validator: (value) => value == password.text
                          ? null
                          : tr(
                              'Passwords do not match.',
                              'كلمتا المرور غير متطابقتين.',
                            ),
                      onFieldSubmitted: (_) => updatePassword(),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        status!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: recoverySessionReady && !loading
                          ? updatePassword
                          : null,
                      child: loading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('Save password', 'حفظ كلمة المرور')),
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
